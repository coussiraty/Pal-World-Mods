-- =====================================================================
--  PalToBox / logic.lua   v2 "src-2"
--  Regra: pal que entra na party POR CAPTURA/CHOCO -> Palbox.
--         pal que voce PUXA do box -> fica (teu time).
--  Como: captura/choco setam _G.__PTB_pending (agora por HOOK, na game
--  thread - nao mais por arquivo). No tick, slot NOVO na party com
--  pending>0 = veio de fora -> move pro box.
--
--  Mesmas regras do AutoHatchLua v2:
--   - tudo roda na game thread (quem agenda e o main.lua);
--   - "if obj then" nao prova nada (ponteiro nulo vira userdata truthy);
--     so alive(obj) vale;
--   - nenhuma chamada de servidor sem precondicao lida de verdade;
--   - pcall e rede pra erro de Lua, nao pra access violation.
-- =====================================================================
local M = { VERSION = "src-2 (game thread + hook de choco)" }

-- pending sobrando sem conseguir mover (party cheia, box cheio...) expira
-- em PENDING_TTL ticks pra nunca mandar pro box um pal que VOCE puxou.
-- 6 ticks x 2s = ~12s: cobre a folga do AutoHatch coletar (passe de 3s).
local PENDING_TTL = 6
local MAX_MOVES_PER_TICK = 2
local PARTY_SLOTS = 4            -- slots 0..4

local function log(s) print("[PalToBox/logic] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end

local function alive(o)
    if o == nil then return false end
    return safe(function() return o:IsValid() end, false) == true
end

local warned = {}
local function warnOnce(k, s) if not warned[k] then warned[k] = true; log(s) end end

local function readGuid(g)
    if g == nil then return nil end
    local a = safe(function() return g.A end, nil)
    if type(a) ~= "number" then return nil end
    return { A = a,
             B = safe(function() return g.B end, 0),
             C = safe(function() return g.C end, 0),
             D = safe(function() return g.D end, 0) }
end

-- devolve guid do container do box e a PAGINA com slot vazio.
-- pagina < 0 (INDEX_NONE) significa "nao ha pagina com espaco" -> devolve
-- nil e o tick nao manda nada. O codigo antigo fazia "pg or 0", o que
-- deixava passar -1 (em Lua -1 e truthy) pro parametro CurrentPage.
local function getBox()
    local sl = FindAllOf("PalPlayerDataPalStorage")
    if not sl then return nil end
    for _, st in ipairs(sl) do
        if alive(st) then
            local cont = safe(function() return st.TargetContainer end, nil)
            if alive(cont) then
                local id = safe(function() return cont:GetId() end, nil)
                local guid = id and readGuid(safe(function() return id.ID end, nil))
                if guid then
                    local pg = safe(function() return st:GetPageIndexExistEmptySlot(0) end, nil)
                    if type(pg) ~= "number" or pg < 0 then return guid, nil end
                    return guid, pg
                end
            end
        end
    end
    return nil
end

-- devolve o OtomoHolder (party) e o guid do container dele.
-- ATENCAO: o UObject devolvido so pode ser usado DENTRO do mesmo tick.
local function getParty()
    local ol = FindAllOf("PalOtomoHolderComponentBase")
    if not ol then return nil end
    for _, oh in ipairs(ol) do
        if alive(oh) then
            local cc = safe(function() return oh.CharacterContainer end, nil)
            if alive(cc) then
                local id = safe(function() return cc:GetId() end, nil)
                local guid = id and readGuid(safe(function() return id.ID end, nil))
                if guid then return oh, guid end
            end
        end
    end
    return nil
end

local function slotPalName(oh, i)
    local a = safe(function() return oh:TryGetOtomoActorBySlotIndex(i) end, nil)
    if not alive(a) then return nil end
    local nm = safe(function() return a:GetFullName() end, nil)
    if type(nm) ~= "string" then return nil end
    return nm:match("BP_([%w_]+)_C") or nm:match("[^/.]+$")
end

local prevOcc = nil
local idle = 0

-- so leitura, nao chama nada no servidor
function M.scan()
    local oh = getParty()
    log("RECON pending=" .. tostring(_G.__PTB_pending or 0))
    if oh then
        for i = 0, PARTY_SLOTS do log("  slot " .. i .. ": " .. (slotPalName(oh, i) or "(vazio)")) end
    else
        log("  sem OtomoHolder valido")
    end
end

function M.tick()
    local oh, partyGuid = getParty()
    if not oh or not partyGuid then return end

    local cur = {}
    for i = 0, PARTY_SLOTS do if slotPalName(oh, i) then cur[i] = true end end
    if not prevOcc then prevOcc = cur; return end   -- baseline: nao mexe no que ja estava

    local pending = _G.__PTB_pending or 0
    local moved = 0

    if pending > 0 then
        local boxGuid, page = getBox()
        local ncc = nil
        local nl = FindAllOf("PalNetworkCharacterContainerComponent")
        if nl then for _, c in ipairs(nl) do if alive(c) then ncc = c; break end end end

        if boxGuid == nil or ncc == nil then
            warnOnce("nobox", "aviso: sem PalBox/NetworkCharacterContainerComponent validos - nao movo nada.")
        elseif page == nil then
            warnOnce("boxfull", "aviso: Palbox sem pagina com slot vazio - nao movo nada (nao mando CurrentPage=-1).")
        else
            for i = 0, PARTY_SLOTS do
                if moved >= MAX_MOVES_PER_TICK or pending <= 0 then break end
                if cur[i] and not prevOcc[i] then          -- slot NOVO
                    local nm = slotPalName(oh, i)
                    local slotId = { ContainerId = { ID = partyGuid }, SlotIndex = i }
                    -- pcall = rede pra erro de Lua. A garantia de memoria vem
                    -- de estarmos na game thread e de tudo acima ter passado
                    -- por alive()/leitura real.
                    local ok, err = pcall(function()
                        ncc:RequestMoveToPalBox_ToServer_Rep(slotId, { ID = boxGuid }, page)
                    end)
                    if ok then
                        log("[auto] " .. (nm or "?") .. " (captura/choco) -> box")
                        pending = pending - 1
                        cur[i] = nil                       -- saiu da party
                        moved = moved + 1
                    else
                        log("erro de Lua no MoveToPalBox: " .. tostring(err))
                    end
                end
            end
        end
    end

    -- pending sobrando sem mover -> expira, pra nao mandar pro box um pal
    -- que voce puxou do box depois.
    if pending > 0 and moved == 0 then idle = idle + 1 else idle = 0 end
    if idle >= PENDING_TTL then pending = 0; idle = 0 end

    _G.__PTB_pending = pending
    prevOcc = cur
end

log("logic " .. M.VERSION .. " ativa")
return M
