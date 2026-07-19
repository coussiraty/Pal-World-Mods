-- =====================================================================
--  AutoHatchLua / logic.lua   v2 "auto-2"
--  Ciclo: deposita ovo da mochila -> incubadora vazia; coleta o pal
--  quando o choco TERMINOU DE VERDADE.
--
--  REGRAS DESTA VERSAO (todas por causa dos crashes de 18/07):
--   1) Tudo aqui roda NA GAME THREAD (quem agenda e o main.lua).
--   2) Nada de "if obj then". No UE4SS um ponteiro NULO nao vira nil em
--      Lua: vira um userdata valido embrulhando nullptr, que e truthy.
--      So alive(obj) (== obj:IsValid()) prova alguma coisa.
--   3) NENHUMA chamada de servidor sem precondicao PROVADA. Se nao deu
--      pra ler o estado, nao chama (fail-closed).
--   4) pcall e rede pra erro de LUA. Ele NAO captura access violation do
--      C++. A seguranca de memoria vem das precondicoes, nao dele.
--   5) Nunca guardar UObject entre passes - so string (GetFullName) e
--      numero. Todo ponteiro e re-resolvido dentro do passe.
--   6) Nunca indexar TArray com um Num lido antes do laco: no UE4SS
--      indexar fora do fim nao da erro, ele chama AddZeroed no array REAL
--      do jogo (cresce e realoca um container replicado).
-- =====================================================================

local M = { VERSION = "auto-2 (game thread + gate por CharacterID + evento)" }

-- ------------------------------ config -------------------------------
local DO_AUTO          = true    -- ciclo automatico ligado
local DEBUG            = false   -- true: loga o estado de cada incubadora TODO passe
local HANDLE_MULTI     = true    -- tambem cuidar da incubadora multi-ovo (familia ...ModelBase)
local COLLECT_COOLDOWN = 15      -- s: depois de mandar coletar, so tenta essa incubadora de novo depois disso
local MULTI_COOLDOWN   = 5       -- s: idem pra multi-ovo (menor porque la o estado e lido por slot)
local DEPOSIT_COOLDOWN = 5       -- s: idem pro deposito
local NO_EGG_BACKOFF   = 30      -- s: sem ovo na mochila, nao varre o inventario de novo por esse tempo
local MAX_COLLECT_PASS = 1       -- no maximo N coletas por passe
local MAX_DEPOSIT_PASS = 1       -- no maximo N depositos por passe
local ALT_GATE         = false   -- plano B do gate de coleta (ver readyToCollect)

local function log(s) print("[AutoHatchLua/logic] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end

-- O UNICO teste de existencia que vale pra UObject no UE4SS.
local function alive(o)
    if o == nil then return false end
    return safe(function() return o:IsValid() end, false) == true
end

local function arrNum(a)
    local n = safe(function() return a:GetArrayNum() end, nil)
    if type(n) ~= "number" then n = safe(function() return #a end, nil) end
    if type(n) ~= "number" or n < 0 then return 0 end
    return n
end

-- estado que sobrevive entre passes: SO string/numero, nunca UObject.
local coolCollect = {}    -- fullname -> os.time() em que libera
local coolDeposit = {}    -- fullname -> os.time() em que libera
local noEggUntil  = 0
local warned      = {}
local reported    = false
local function warnOnce(k, s) if not warned[k] then warned[k] = true; log(s) end end

-- ---------------------------------------------------------------------
--  Percorre o ItemSlotArray de um container chamando fn(slot, i).
--  Devolve true se percorreu com seguranca, false se abortou (estado
--  ilegivel -> quem chamou trata como "NAO SEI" e nao age).
--  O Num e relido a CADA iteracao (ver regra 6 no topo).
-- ---------------------------------------------------------------------
local function iterSlots(cont, fn)
    if not alive(cont) then return false end
    local slots = safe(function() return cont.ItemSlotArray end, nil)
    if slots == nil then return false end
    if arrNum(slots) <= 0 then return false end
    local i = 1
    while true do
        local n = arrNum(slots)
        if i > n then return true end
        local s = safe(function() return slots[i] end, nil)
        if not alive(s) then return false end   -- slot podre no meio: aborta
        if fn(s, i) == true then return true end
        i = i + 1
    end
end

-- true = tem item, false = vazio, nil = NAO SEI (nao age em cima de nil)
local function containerOccupied(cont)
    local occupied, bad = false, false
    local ok = iterSlots(cont, function(s)
        local cnt = safe(function() return s.StackCount end, nil)
        if type(cnt) ~= "number" then bad = true; return true end
        if cnt > 0 then occupied = true; return true end
    end)
    if not ok or bad then return nil end
    return occupied
end

-- container da incubadora (com IsValid em cada elo da cadeia)
local function incContainer(m)
    local mod = safe(function() return m:GetItemContainerModule() end, nil)
    if not alive(mod) then return nil end
    local c = safe(function() return mod:GetContainer() end, nil)
    if not alive(c) then c = safe(function() return mod.TargetContainer end, nil) end
    if not alive(c) then return nil end
    return c
end

-- ---------------------------------------------------------------------
--  id do player local.
--  Devolve nil quando NAO da pra determinar. O codigo antigo devolvia 0
--  nesse caso, e 0 e truthy em Lua - ou seja, mandava um id inventado pra
--  uma funcao de servidor. Se o PlayerState existe e o id lido e mesmo 0,
--  a gente usa 0 (e avisa uma vez), porque ai o valor foi LIDO, nao
--  inventado.
-- ---------------------------------------------------------------------
local function playerId()
    local l = FindAllOf("PalPlayerState")
    if not l then return nil end
    local zeroSeen = false
    for _, p in ipairs(l) do
        if alive(p) then
            local id = safe(function() return p:GetPlayerId() end, nil)
            if type(id) ~= "number" then id = safe(function() return p.PlayerId end, nil) end
            if type(id) == "number" then
                if id > 0 then return id end
                zeroSeen = true
            end
        end
    end
    if zeroSeen then
        warnOnce("pid0", "aviso: PlayerId lido como 0 (raro). Usando 0 mesmo, foi lido e nao inventado.")
        return 0
    end
    return nil
end

local function getNIC()
    local l = FindAllOf("PalNetworkItemComponent")
    if l then for _, n in ipairs(l) do if alive(n) then return n end end end
    return nil
end

-- ---------------------------------------------------------------------
--  PRECONDICAO DE COLETA - familia "single" (UPalMapObjectHatchingEggModel)
--
--  Sinal usado: HatchedCharacterSaveParameter.CharacterID ~= None.
--  Esse e o campo com ReplicatedUsing=OnRep_HatchedCharacterSaveParameter
--  (PalMapObjectHatchingEggModel.h:41-42), ou seja, e ele que o jogo
--  preenche/replica quando o personagem chocado passa a existir - e o que
--  dispara o OnHatchedCharacterDelegate. FName vazio = nao tem ninguem
--  pra coletar -> nao chama nada.
--
--  Nao uso IsWorkable() como gate de proposito: a polaridade dele NAO
--  esta provada (pode significar "ainda ha trabalho" OU "pode trabalhar"),
--  e um gate invertido mataria o mod em silencio. Ele so aparece no LOG,
--  pra voce confirmar a semantica olhando o relatorio.
-- ---------------------------------------------------------------------
local function hatchedCharacterId(m)
    local sp = safe(function() return m.HatchedCharacterSaveParameter end, nil)
    if sp == nil then return nil end
    local cid = safe(function() return sp.CharacterID end, nil)
    if cid == nil then return nil end
    local s = safe(function() return cid:ToString() end, nil)
    if type(s) ~= "string" then return nil end
    return s
end

-- true = tem personagem chocado esperando; false = nao tem;
-- nil = nao consegui LER (fail-closed: nao chama servidor)
local function readyToCollect(m)
    local s = hatchedCharacterId(m)
    if s ~= nil and s ~= "" and s ~= "None" then return true, s end
    -- PLANO B (ALT_GATE, desligado por padrao): so ligue se o relatorio
    -- mostrar CharacterID sempre "None" mesmo com ovo pronto na incubadora.
    -- Aceita como pronto: HatchedPalEggData valido E IsWorkable()==false.
    -- Esta desligado porque a polaridade de IsWorkable NAO esta provada -
    -- se estiver invertida, esse gate coleta na hora errada.
    if ALT_GATE then
        local egg = safe(function() return m.HatchedPalEggData end, nil)
        local wk  = safe(function() return m:IsWorkable() end, nil)
        if alive(egg) and wk == false then return true, "alt_gate" end
    end
    if s == nil then return nil end
    return false
end

-- ---------------------------------------------------------------------
--  PRECONDICAO DE COLETA - familia multi-ovo (UPalMapObjectHatchingEggModelBase
--  e derivadas, ex.: UPalMapObjectMultiHatchingEggModel).
--  Aqui existe API PUBLICA e por slot:
--    GetHatchedStateArray() -> TArray<bool>   (quais slots ja chocaram)
--    RequestObtainSingleHatchedCharacter(SlotIndex)
--    RequestObtainAllHatchedCharacter()
--  Nao uso a _ServerInternal dessa familia: la a assinatura e outra
--  (int32 + FPalNetArchive) e nao da pra montar o Archive por aqui.
--  Se nao der pra ler o array de estado, essa incubadora e PULADA.
-- ---------------------------------------------------------------------
local function multiHatchedSlots(m)
    local arr = safe(function() return m:GetHatchedStateArray() end, nil)
    if arr == nil then return nil end
    local out, i = {}, 1
    while true do
        local n = arrNum(arr)
        if i > n then break end
        local v = safe(function() return arr[i] end, nil)
        if v == true then out[#out + 1] = i - 1 end   -- Lua 1-based -> indice do UE 0-based
        i = i + 1
    end
    return out
end

-- ---------------------------------------------------------------------
--  Acha 1 PalEgg SO NA MOCHILA do player (InventoryMultiHelper), nao em baus.
--  Devolve containerId, slotIndex, itemId.
-- ---------------------------------------------------------------------
local function findOnePalEgg()
    local il = FindAllOf("PalPlayerInventoryData")
    if not il then return nil end
    for _, inv in ipairs(il) do
        if alive(inv) then
            local mh = safe(function() return inv.InventoryMultiHelper end, nil)
            if alive(mh) then
                local conts = safe(function() return mh.Containers end, nil)
                if conts ~= nil then
                    local ci = 1
                    while true do
                        local n = arrNum(conts)
                        if ci > n then break end
                        local cont = safe(function() return conts[ci] end, nil)
                        if not alive(cont) then break end   -- lista mexendo: para por aqui
                        local cid = safe(function() return cont:GetId() end, nil)
                        if cid ~= nil then
                            local foundSlot, foundId
                            iterSlots(cont, function(s)
                                local cnt = safe(function() return s.StackCount end, nil)
                                if type(cnt) ~= "number" or cnt <= 0 then return end
                                local id = safe(function() return s.ItemId.StaticId:ToString() end, nil)
                                if type(id) == "string" and string.find(id, "PalEgg", 1, true) then
                                    local si = safe(function() return s.SlotIndex end, nil)
                                    if type(si) == "number" then
                                        foundSlot, foundId = si, id
                                        return true
                                    end
                                end
                            end)
                            if foundSlot then return cid, foundSlot, foundId end
                        end
                        ci = ci + 1
                    end
                end
            end
        end
    end
    return nil
end

-- nome estavel pra usar como chave de cooldown (string, nunca o objeto)
local function keyOf(m) return safe(function() return m:GetFullName() end, nil) end

-- ---------------------------------------------------------------------
--  RELATORIO - so LEITURA, nao chama nada no servidor.
--  Roda automatico no primeiro passe (pra voce ter no log o estado real)
--  e sempre que DEBUG = true.
-- ---------------------------------------------------------------------
function M.report()
    log("======== RELATORIO (so leitura) ========")
    log("playerId = " .. tostring(playerId()))
    local n = 0
    local l = FindAllOf("PalMapObjectHatchingEggModel")
    if l then for _, m in ipairs(l) do
        if alive(m) then
            n = n + 1
            local cont = incContainer(m)
            log(string.format("  single#%d ocupado=%s CharacterID=%s IsWorkable=%s bWorkable=%s eggDataValido=%s",
                n,
                tostring(containerOccupied(cont)),
                tostring(hatchedCharacterId(m)),
                tostring(safe(function() return m:IsWorkable() end, "?")),
                tostring(safe(function() return m.bWorkable end, "?")),
                tostring(alive(safe(function() return m.HatchedPalEggData end, nil)))))
        end
    end end
    local k = 0
    local b = FindAllOf("PalMapObjectHatchingEggModelBase")
    if b then for _, m in ipairs(b) do
        if alive(m) then
            k = k + 1
            local hs = multiHatchedSlots(m)
            log(string.format("  multi#%d slotsChocados=%s IsWorkable=%s",
                k,
                hs and ("[" .. table.concat(hs, ",") .. "]") or "ILEGIVEL(pulo)",
                tostring(safe(function() return m:IsWorkable() end, "?"))))
        end
    end end
    log(string.format("======== fim (%d single, %d multi) ========", n, k))
end

-- ---------------------------------------------------------------------
--  PASSE. Chamado pelo main.lua, sempre na game thread.
--  Ordem: coleta (gate forte) -> deposito (so em incubadora comprovada
--  vazia). No maximo MAX_*_PASS acoes de cada tipo por passe: sem rajada
--  de RPC, o jogo replica em paz.
-- ---------------------------------------------------------------------
function M.tick()
    if not DO_AUTO then return end

    if not reported then reported = true; M.report() end
    if DEBUG then M.report() end

    -- evento de choco/mudanca de container chegou desde o ultimo passe?
    -- se chegou, vale a pena olhar o inventario de novo mesmo estando em
    -- backoff (uma incubadora acabou de esvaziar).
    local dirty = (_G.__AH_DIRTY == true)
    _G.__AH_DIRTY = false

    local now = os.time()
    if dirty then noEggUntil = 0 end
    local coletei, depositei = 0, 0
    local pid = playerId()

    -- ------------------------- familia single -------------------------
    local l = FindAllOf("PalMapObjectHatchingEggModel")
    if l then
        for _, m in ipairs(l) do
            if coletei >= MAX_COLLECT_PASS and depositei >= MAX_DEPOSIT_PASS then break end
            if alive(m) then
                local key = keyOf(m)
                local ready = readyToCollect(m)

                if ready == true then
                    -- TEM personagem chocado esperando -> pode coletar
                    if pid == nil then
                        warnOnce("nopid", "aviso: sem PlayerState valido, nao vou chamar a funcao de servidor.")
                    elseif key and now >= (coolCollect[key] or 0) and coletei < MAX_COLLECT_PASS then
                        coolCollect[key] = now + COLLECT_COOLDOWN
                        -- pcall aqui e SO pra erro de Lua (aridade etc.).
                        -- A seguranca de memoria vem do gate acima.
                        local ok, err = pcall(function() m:ObtainHatchedCharacter_ServerInternal(pid) end)
                        if ok then coletei = coletei + 1
                        else log("erro de Lua no Obtain: " .. tostring(err)) end
                    end
                else
                    -- ready == false (nao tem pal pra coletar) ou nil (nao
                    -- consegui ler o estado). Nos dois casos o deposito
                    -- continua permitido, porque ele NAO depende desse gate:
                    -- so acontece com o container COMPROVADAMENTE vazio.
                    if ready == nil then
                        warnOnce("gate", "AVISO: nao consegui ler HatchedCharacterSaveParameter.CharacterID - " ..
                                         "coleta desligada por seguranca (deposito continua). Veja o RELATORIO acima.")
                    end
                    local cont = incContainer(m)
                    local occ  = containerOccupied(cont)
                    if occ == false and key and depositei < MAX_DEPOSIT_PASS
                       and now >= (coolDeposit[key] or 0) and now >= noEggUntil then
                        local nic = getNIC()
                        local toCid = safe(function() return cont:GetId() end, nil)
                        if nic and toCid then
                            local srcCid, slot, eggId = findOnePalEgg()
                            if srcCid and slot then
                                local froms = { { SlotId = { ContainerId = srcCid, SlotIndex = slot }, Num = 1 } }
                                -- RequestID zerado: mantido de proposito, e o
                                -- comportamento que ja funciona hoje e nao ha
                                -- nenhuma evidencia de que ele cause crash.
                                local ok = pcall(function()
                                    nic:RequestMoveToContainer_ToServer({ A = 0, B = 0, C = 0, D = 0 }, toCid, froms)
                                end)
                                if ok then
                                    coolDeposit[key] = now + DEPOSIT_COOLDOWN
                                    depositei = depositei + 1
                                    if DEBUG then log("depositei " .. tostring(eggId)) end
                                end
                            else
                                noEggUntil = now + NO_EGG_BACKOFF   -- sem ovo: para de varrer inventario
                            end
                        end
                    end
                end
            end
        end
    end

    -- -------------------- familia multi-ovo (opcional) ----------------
    if HANDLE_MULTI and coletei < MAX_COLLECT_PASS then
        local b = FindAllOf("PalMapObjectHatchingEggModelBase")
        if b then
            for _, m in ipairs(b) do
                if coletei >= MAX_COLLECT_PASS then break end
                if alive(m) then
                    local key = keyOf(m)
                    local hs  = multiHatchedSlots(m)     -- nil = ilegivel -> pula
                    if hs and #hs > 0 and key and now >= (coolCollect[key] or 0) then
                        coolCollect[key] = now + MULTI_COOLDOWN
                        local ok, err = pcall(function() m:RequestObtainSingleHatchedCharacter(hs[1]) end)
                        if ok then coletei = coletei + 1
                        else log("erro de Lua no RequestObtainSingle: " .. tostring(err)) end
                    end
                end
            end
        end
    end

    if coletei > 0 or depositei > 0 then
        log(string.format("[auto] coletei %d, depositei %d", coletei, depositei))
    end
end

log("logic " .. M.VERSION .. " ativa")
return M
