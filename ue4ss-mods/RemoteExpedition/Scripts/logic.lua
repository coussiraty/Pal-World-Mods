-- =====================================================================
--  RemoteExpedition / logic.lua   (SEGURO - RPC/AddHUD + fix de foco)
--  O problema era: AddHUD mostra a tela, mas o input NAO ia pra UI
--  (cliques so funcionavam depois de Alt+Tab). Agora, ao abrir, eu
--  forco o modo de input UI + cursor (o que o Alt+Tab fazia na mao).
--
--  ATALHOS:
--    Ctrl+Shift+J = abre a tela de expedicao + foca (cliques funcionam)
--    Ctrl+Shift+U = SO forca o foco (se abriu e o clique nao pegou)
--    Ctrl+Shift+L = fecha a tela + devolve o controle do jogo
--    Ctrl+Shift+K = recarrega esta logica (debug)
-- =====================================================================
local M = { VERSION = "hud-23 + xp-invest3 (Ctrl+Shift+I = lista Add*/Set* do pal p/ achar o XP writer)" }

local LOGIC_PATH = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/RemoteExpedition/Scripts/logic.lua"

local function log(s) print("[RemoteExp/logic] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end
local function arrNum(a) return safe(function() return a:GetArrayNum() end, safe(function() return #a end, 0)) end

-- pega o id do player (helper comprovado, igual ao AutoHatchLua)
local function getPlayerId()
    local l = FindAllOf("PalPlayerState")
    if l then for _, p in ipairs(l) do
        if isok(p) then
            local id = safe(function() return p:GetPlayerId() end, safe(function() return p.PlayerId end, nil))
            if id ~= nil then return id end
        end
    end end
    return nil
end

-- container de itens da mesa (onde caem as recompensas)
local function contOf(m)
    local mod = safe(function() return m:GetItemContainerModule() end, nil)
    return mod and (safe(function() return mod:GetContainer() end, nil)
                or safe(function() return mod.TargetContainer end, nil))
end

-- dump do conteudo de um container (id + itens com stack > 0)
local function dumpContainer(cont, tag)
    if not cont then log(tag .. ": sem container"); return nil end
    local cid   = safe(function() return cont:GetId() end, nil)
    local slots = safe(function() return cont.ItemSlotArray end, nil)
    local n     = slots and arrNum(slots) or 0
    log(tag .. ": containerId=" .. (cid and "OK" or "nil") .. " slots=" .. tostring(n))
    if slots then
        for i = 1, arrNum(slots) do
            local s = safe(function() return slots[i] end, nil)
            if s then
                local id  = safe(function() return s.ItemId.StaticId:ToString() end, "-")
                local cnt = safe(function() return s.StackCount end, 0) or 0
                if cnt > 0 then
                    log(string.format("   slot %s: %s x%d",
                        tostring(safe(function() return s.SlotIndex end, i-1)), id, cnt))
                end
            end
        end
    end
    return cid
end

-- componente de rede pra mover itens entre containers (igual AutoHatchLua)
local function getNIC()
    local l = FindAllOf("PalNetworkItemComponent")
    if l then for _, n in ipairs(l) do if isok(n) then return n end end end
    return nil
end

-- containers do inventario do player (mochila) -> lista {cont, id, slots}
local function playerContainers()
    local out = {}
    local il = FindAllOf("PalPlayerInventoryData")
    if il then for _, inv in ipairs(il) do
        if isok(inv) then
            local mh = safe(function() return inv.InventoryMultiHelper end, nil)
            local conts = mh and safe(function() return mh.Containers end, nil)
            if conts then
                for ci = 1, arrNum(conts) do
                    local c   = safe(function() return conts[ci] end, nil)
                    local cid = c and safe(function() return c:GetId() end, nil)
                    if cid then
                        local slots = safe(function() return c.ItemSlotArray end, nil)
                        out[#out+1] = { cont = c, id = cid, slots = slots and arrNum(slots) or 0 }
                    end
                end
            end
        end
    end end
    return out
end

-- amostra curta do conteudo de um container (pra identificar qual e a mochila)
local function containerSample(cont, k)
    local slots = safe(function() return cont.ItemSlotArray end, nil)
    if not slots then return "[?]" end
    local parts, n = {}, arrNum(slots)
    for i = 1, n do
        if #parts >= (k or 3) then break end
        local s   = safe(function() return slots[i] end, nil)
        local cnt = s and (safe(function() return s.StackCount end, 0) or 0) or 0
        if cnt > 0 then
            local id = safe(function() return s.ItemId.StaticId:ToString() end, "-")
            parts[#parts+1] = id .. "x" .. cnt
        end
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

-- monta a lista 'froms' de todos os slots ocupados de um container (pra mover tudo)
local function occupiedFroms(cont)
    local tcid  = safe(function() return cont:GetId() end, nil)
    local slots = safe(function() return cont.ItemSlotArray end, nil)
    local froms = {}
    if tcid and slots then
        for i = 1, arrNum(slots) do
            local s   = safe(function() return slots[i] end, nil)
            local cnt = s and (safe(function() return s.StackCount end, 0) or 0) or 0
            local si  = s and safe(function() return s.SlotIndex end, i-1) or (i-1)
            if cnt > 0 then
                froms[#froms+1] = { SlotId = { ContainerId = tcid, SlotIndex = si }, Num = cnt }
            end
        end
    end
    return tcid, froms
end

-- deixa o id do item mais legivel (fallback: UE4SS nao le a DT_ItemNameText)
-- ex.: WorldTreeOre -> "World Tree Ore" ; PalSphere_Ancient_2 -> "Sphere Ancient 2"
local function prettyName(id)
    local s = tostring(id or "?")
    s = s:gsub("^Pal(%u)", "%1")       -- tira prefixo "Pal"
    s = s:gsub("_", " ")                -- _ -> espaco
    s = s:gsub("(%l)(%u)", "%1 %2")     -- camelCase -> "camel Case"
    s = s:gsub("(%a)(%d)", "%1 %2")     -- letra|digito
    s = s:gsub("%s+", " ")
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- lista {name,count} dos itens ocupados de um container (pra mostrar na HUD)
local function containerItems(cont, cap)
    local out = {}
    local slots = safe(function() return cont.ItemSlotArray end, nil)
    if slots then
        for i = 1, arrNum(slots) do
            local s   = safe(function() return slots[i] end, nil)
            local cnt = s and (safe(function() return s.StackCount end, 0) or 0) or 0
            if cnt > 0 then
                out[#out+1] = { name = safe(function() return s.ItemId.StaticId:ToString() end, "?"), count = cnt }
                if cap and #out >= cap then break end
            end
        end
    end
    return out
end

-- ============ HUD custom: overlay proprio (tecnica do mod de arma) ============
-- Hook em ReceiveDrawHUD + DrawRect/DrawText (API de canvas, args primitivos =
-- SEM crash). Mostra os itens coletados por alguns segundos e some.
local HUDMOD = {}
do
    local DRAWHOOK = "/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD"
    local mathlib, font, colorCache = nil, nil, {}
    local panel = nil                                   -- { title, items, ticksLeft }
    local ticks, hookBeat, lastArm = 0, -1000, -1000
    local preId, postId, installed = nil, nil, false

    local function getMath()
        if mathlib then return mathlib end
        mathlib = safe(function() return StaticFindObject("/Script/Engine.Default__KismetMathLibrary") end)
        return mathlib
    end
    local function getFont()
        if font then return font end
        for _, p in ipairs({ "/Engine/EngineFonts/Roboto.Roboto", "/Game/Pal/Font/Ft_PalDefaultFont.Ft_PalDefaultFont" }) do
            local c = safe(function() return StaticFindObject(p) end); if c then font = c; return c end
        end
    end
    local function col(r,g,b,a)
        a = a or 1
        local k = string.format("%.2f_%.2f_%.2f_%.2f", r,g,b,a)
        if colorCache[k] ~= nil then return colorCache[k] end
        local m = getMath(); if not m then return nil end
        local c = safe(function() return m:MakeColor(r,g,b,a) end)
        colorCache[k] = c; return c
    end
    local function rect(hud,c,x,y,w,h) if c and w>0 and h>0 then safe(function() hud:DrawRect(c,x,y,w,h) end) end end
    local function text(hud,s,c,x,y,sc) if c then safe(function() hud:DrawText(tostring(s), c, x, y, getFont(), sc, false) end) end end

    local function draw(hud)
        local p = panel
        local pad, x, y, lineH, w = 10, 40, 440, 22, 280
        local n = #p.items
        local h = pad + 22 + n*lineH + pad
        rect(hud, col(0.015,0.028,0.045,0.88), x, y, w, h)          -- fundo
        rect(hud, col(0.30,0.82,1.0,1),   x, y, w, 2)              -- accent topo
        rect(hud, col(1.0,0.80,0.22,1),   x, y, 2, 12)            -- cantos
        rect(hud, col(1.0,0.80,0.22,1),   x+w-2, y, 2, 12)
        rect(hud, col(0.30,0.82,1.0,0.22),x, y+h-1, w, 1)
        local cy = y + pad
        text(hud, p.title, col(0.30,0.82,1.0,0.92), x+pad, cy, 0.82); cy = cy + 22
        for _, it in ipairs(p.items) do
            text(hud, prettyName(it.name) .. "  x" .. tostring(it.count), col(1,1,1,1), x+pad, cy, 0.86)
            cy = cy + lineH
        end
    end

    local function drawCallback(self)
        hookBeat = ticks
        if not panel then return end
        if (panel.ticksLeft or 0) <= 0 then panel = nil; return end
        local hud = self:get(); if hud then safe(function() draw(hud) end) end
    end

    local function registerDraw()
        lastArm = ticks
        if preId then pcall(function() UnregisterHook(DRAWHOOK, preId, postId) end); preId, postId = nil, nil end
        local ok, a, b = pcall(function() return RegisterHook(DRAWHOOK, drawCallback) end)
        if ok then preId, postId = a, b end
        return ok
    end

    function HUDMOD.install()
        if installed then return end
        installed = true
        registerDraw()
        local function tick()
            ticks = ticks + 1
            if panel and panel.ticksLeft then panel.ticksLeft = panel.ticksLeft - 1 end
            -- so re-arma o hook enquanto ha painel ativo (evita stutter/freeze no menu/mapa)
            if panel and (ticks - hookBeat) > 4 and (ticks - lastArm) > 20 then registerDraw() end
            ExecuteWithDelay(500, tick)
        end
        ExecuteWithDelay(500, tick)
    end

    -- mostra o painel: title (string) + items ({{name,count},...}) por 'seconds' seg
    function HUDMOD.show(title, items, seconds)
        HUDMOD.install()
        panel = { title = title, items = items or {}, ticksLeft = math.max(1, math.floor((seconds or 5) * 2)) }
        log("HUD.show: '" .. tostring(title) .. "' com " .. #(items or {}) .. " item(ns)")
    end
end

-- ============ NOTIFICACAO NATIVA de "item obtido" (WBP_ItemGet) ============
-- Os labels flutuantes reais de pickup, iguais aos de pegar item do chao.
-- Via oficial: UPalLogUtility::AddItemGetLog(WorldContextObject, {StaticItemId, Num})
-- (PalLogUtility.h:94; struct FPalStaticItemIdAndNum = { FName StaticItemId; int32 Num }).
-- E BlueprintFunctionLibrary estatica -> chama no CDO Default__PalLogUtility.
-- Roda dentro do M.collect, que e callback de tecla (game thread) -> seguro.
local function nativeItemGet(items)
    if not items or #items == 0 then return false end
    local lib = StaticFindObject("/Script/Pal.Default__PalLogUtility")
    if not isok(lib) then log("itemget: sem PalLogUtility"); return false end
    local world = FindFirstOf("PalPlayerController")
    if not isok(world) then world = FindFirstOf("PalHUDInGame") end
    if not isok(world) then log("itemget: sem WorldContext"); return false end
    local n = 0
    for _, it in ipairs(items) do
        local ok = pcall(function()
            lib:AddItemGetLog(world, { StaticItemId = FName(it.name), Num = it.count })
        end)
        if ok then n = n + 1 end
    end
    log(string.format("itemget: %d/%d label(s) nativo(s) de pickup", n, #items))
    return n > 0
end

local function getModel() return FindFirstOf("PalMapObjectCharacterTeamMissionModel") end
local function wbl() return StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary") end
local function expeditionWidget()
    local ws = FindAllOf("WBP_PalExpedition_C")
    if ws and #ws > 0 then return ws[#ws] end
    return nil
end

-- ==== FOCAR: joga o input pra UI (o que o Alt+Tab fazia) ====
function M.focus()
    local pc = FindFirstOf("PalPlayerController")
    if not isok(pc) then log("focus: sem PC"); return end
    pcall(function() pc.bShowMouseCursor = true end)
    local lib, w = wbl(), expeditionWidget()
    if isok(lib) then
        -- UIOnly: cliques vao 100% pra tela (igual menu normal)
        local ok = pcall(function() lib:SetInputMode_UIOnlyEx(pc, w, 0) end)
        log("focus: SetInputMode_UIOnly ok=" .. tostring(ok) .. " widget=" .. (w and "sim" or "nil"))
    else
        log("focus: WidgetBlueprintLibrary nao achado")
    end
end

-- ==== ABRIR de verdade: dispara a interacao NATIVA na mesa ====
-- (o jogo abre a UI ele mesmo, com input/botoes funcionando como se voce
--  estivesse la). Metodo direto no build object, sem tocar em interface-list.
function M.open()
    local model = getModel()
    if not isok(model) then log("open: SEM model"); return end
    local st = safe(function() return model.State end, nil)
    log("open: State=" .. tostring(st) .. " (1=Ready 2=Rodando 3=Reward)")
    -- se a mesa TERMINOU (Reward), coleta (M.collect loga tudo)
    if st == 3 then
        M.collect()
        return
    end
    local hud = FindFirstOf("PalHUDInGame")
    if not isok(hud) then log("open: SEM HUD"); return end
    local widget = safe(function() return model.MissionSelectUI end, nil)
    if not widget then log("open: SEM MissionSelectUI"); return end
    local uimodel = FindFirstOf("PalUIMapObjectCharacterTeamMissionModel")
    local param = FindFirstOf("PalHUDDispatchParameter_MapObjectCharacterTeamMission")
    if not isok(param) then
        local pcls = StaticFindObject("/Script/Pal.PalHUDDispatchParameter_MapObjectCharacterTeamMission")
        if pcls then param = safe(function() return StaticConstructObject(pcls, hud) end, nil) end
    end
    if isok(param) and isok(uimodel) then pcall(function() param.Model = uimodel end) end
    -- MODAL gerenciado: o jogo cuida do input sozinho (cliques SEM Alt+Tab)
    local ok, r = pcall(function() return hud:PushWidgetStackableUI(widget, param) end)
    log("open: PushWidgetStackableUI ok=" .. tostring(ok) .. " ret=" .. tostring(r))
end

-- ==== ABRIR por fora (AddHUD) - metodo antigo, fallback (tecla U) ====
function M.openHUD()
    local hud = FindFirstOf("PalHUDInGame")
    if not isok(hud) then log("openHUD: SEM HUD"); return end
    local model = getModel()
    if not isok(model) then log("openHUD: SEM model"); return end
    local widget = safe(function() return model.MissionSelectUI end, nil)
    local uimodel = FindFirstOf("PalUIMapObjectCharacterTeamMissionModel")
    local param = FindFirstOf("PalHUDDispatchParameter_MapObjectCharacterTeamMission")
    if not isok(param) then
        local pcls = StaticFindObject("/Script/Pal.PalHUDDispatchParameter_MapObjectCharacterTeamMission")
        if pcls then param = safe(function() return StaticConstructObject(pcls, hud) end, nil) end
    end
    if isok(param) and isok(uimodel) then pcall(function() param.Model = uimodel end) end
    pcall(function() hud:AddHUD(widget, 0, param) end)
    M.focus()
    pcall(function()
        LoopAsync(200, function()
            if not expeditionWidget() then return true end
            M.focus()
            return false
        end)
    end)
    log("openHUD: AddHUD + foco")
end

-- ==== FECHAR + devolver o controle do jogo ====
function M.close()
    local hud = FindFirstOf("PalHUDInGame")
    local n = 0
    local ws = FindAllOf("WBP_PalExpedition_C")
    if ws then
        for _, w in ipairs(ws) do
            if isok(w) then
                if isok(hud) then pcall(function() hud:CloseHUDWidget(w) end) end
                pcall(function() w:RemoveFromParent() end)
                n = n + 1
            end
        end
    end
    -- devolve input pro jogo (senao fica cursor preso)
    local pc = FindFirstOf("PalPlayerController")
    if isok(pc) then
        pcall(function() pc.bShowMouseCursor = false end)
        local lib = wbl()
        if isok(lib) then pcall(function() lib:SetInputMode_GameOnly(pc) end) end
    end
    log("close: fechei " .. n .. " widget(s) + input->jogo")
    return n
end

function M.recon()
    local m = getModel()
    log("RECON: State=" .. tostring(m and safe(function() return m.State end,"?") or "-") ..
        " (1=Ready 2=Rodando 3=Reward)")
end

-- ==== SONDA 2: descobre a FUNCAO que adiciona linha no feed de item-get ====
-- Testa existencia de metodos candidatos no HUD e no WBP_SimpleLog vivo.
-- Classifica pelo erro: "TrivialObject" = nao existe; outro/ok = EXISTE.
local function methodExists(obj, name)
    local ok, err = pcall(function() return obj[name](obj) end)
    if ok then return "EXISTE(ok)" end
    local e = tostring(err)
    if e:find("TrivialObject") then return nil end       -- nao existe
    return "EXISTE? err=" .. e:sub(1, 80)                 -- existe mas args errados
end

local function liveOf(cn)
    local l = FindAllOf(cn)
    if l then for _, w in ipairs(l) do
        if isok(w) and safe(function() return w:GetFullName() end, ""):find("Transient") then return w end
    end end
    if l then for _, w in ipairs(l) do if isok(w) then return w end end end
    return nil
end

-- enumera funcoes de uma classe (ForEachFunction; fallback = anda em Children)
local function dumpFuncs(obj, label, filterKw, cap)
    if not isok(obj) then log("  " .. label .. ": obj invalido"); return end
    local cls = safe(function() return obj:GetClass() end, nil)
    if not cls then log("  " .. label .. ": sem class"); return end
    local shown, total = 0, 0
    local function consider(name)
        total = total + 1
        local low = string.lower(name)
        local pass = true
        if filterKw then
            pass = false
            for _, kw in ipairs(filterKw) do if low:find(kw) then pass = true break end end
        end
        if pass and shown < (cap or 80) then log("  " .. label .. "::" .. name); shown = shown + 1 end
    end
    local okIter = pcall(function()
        cls:ForEachFunction(function(fn)
            consider(safe(function() return fn:GetFName():ToString() end,
                     safe(function() return fn:GetFullName() end, "?")))
        end)
    end)
    if not okIter then
        -- fallback: percorre a linked list Children (UFunctions ficam aqui)
        local child, guard = safe(function() return cls.Children end, nil), 0
        while isok(child) and guard < 600 do
            consider(safe(function() return child:GetFName():ToString() end,
                     safe(function() return child:GetFullName() end, "?")))
            child = safe(function() return child.Next end, nil); guard = guard + 1
        end
        if guard == 0 then log("  " .. label .. ": ForEachFunction e Children indisponiveis") end
    end
    log("  " .. label .. ": " .. shown .. " mostrada(s) de " .. total .. " total")
end

-- INVESTIG 3 (so-leitura): achar a funcao que ESCREVE/adiciona XP no pal.
function M.probe()
    log("===== INVESTIG 3: escrever XP =====")
    local p = FindFirstOf("PalIndividualCharacterParameter")
    dumpFuncs(p, "Add",   { "add" },  40)
    dumpFuncs(p, "Set",   { "set" },  40)
    dumpFuncs(p, "Other", { "reward","gain","level","rank" }, 40)
    log("===== fim investig 3 =====")
end

-- ==== COLETA (Plano B): puxa os itens do container da mesa -> mochila ====
-- Descoberto: nao ha RPC de "obtain reward" (RequestObtainCharacters nao existe;
-- RequestStartMission nao coleta). Entao movemos os itens direto do container da
-- mesa pro inventario do player, com o mesmo RequestMoveToContainer_ToServer que
-- o AutoHatchLua usa. Loga tudo e re-le o container/State pra confirmar.
function M.collect()
    local model = getModel()
    if not isok(model) then log("collect: SEM model"); return end
    local s0 = safe(function() return model.State end, "?")
    log("collect: ===== State=" .. tostring(s0) .. " (3=Reward) — puxando itens da mesa =====")
    local cont = contOf(model)
    if not cont then log("collect: SEM container da mesa"); return end
    dumpContainer(cont, "collect/mesa ANTES")
    local coletados = containerItems(cont, 14)   -- lista pra mostrar na HUD (antes do move)

    local tcid, froms = occupiedFroms(cont)
    if not tcid then log("collect: container da mesa sem id"); return end
    if #froms == 0 then log("collect: mesa ja esta VAZIA (nada pra puxar)"); return end

    local nic = getNIC()
    if not nic then log("collect: SEM NetworkItemComponent"); return end

    -- destino = maior container do player COM ate 100 slots (mochila = 42;
    -- ignora o de 230 que e o Palbox/deposito e nao aceita itens)
    local pcs = playerContainers()
    local dest = nil
    for idx, pc in ipairs(pcs) do
        log(string.format("collect: player cont #%d slots=%d %s", idx, pc.slots, containerSample(pc.cont, 3)))
        if pc.slots <= 100 and (not dest or pc.slots > dest.slots) then dest = pc end
    end
    if not dest then log("collect: sem container destino no player"); return end

    log(string.format("collect: movendo %d pilha(s) da mesa -> mochila(slots=%d)", #froms, dest.slots))
    local ok, err = pcall(function()
        nic:RequestMoveToContainer_ToServer({ A=0, B=0, C=0, D=0 }, dest.id, froms)
    end)
    log("collect: RequestMoveToContainer ok=" .. tostring(ok) .. (ok and "" or ("  err=" .. tostring(err))))

    dumpContainer(cont, "collect/mesa DEPOIS")
    local st = safe(function() return model.State end, "?")
    log("collect: State DEPOIS=" .. tostring(st) .. "  (se a mesa esvaziou, os itens foram pra mochila)")

    -- mostra o que foi coletado com a NOTIFICACAO NATIVA de pickup do jogo
    -- (labels flutuantes, igual pegar item do chao) -- sem HUD custom.
    if ok and #coletados > 0 then
        nativeItemGet(coletados)
    end
end

-- ==== expoe funcoes ====
_G.__RE_open  = M.open      -- J = abrir (PushWidgetStackableUI)
_G.__RE_focus = M.collect   -- a tecla U (registrada no boot) chama __RE_focus -> coleta
_G.__RE_close = M.close
_G.__RE_recon = M.recon
_G.__RE_start = M.collect
_G.__RE_probe = M.probe

-- ==== atalhos (cada um com guard) ====
local function bind(guard, key, fn)
    if not _G[guard] then _G[guard] = true
        pcall(function() RegisterKeyBind(key, { ModifierKey.CONTROL, ModifierKey.SHIFT }, fn) end)
    end
end
bind("__RE_K", Key.K, function() pcall(function() dofile(LOGIC_PATH) end); if _G.__RE_recon then pcall(_G.__RE_recon) end end)
bind("__RE_L", Key.L, function() if _G.__RE_close then pcall(_G.__RE_close) end end)
bind("__RE_J", Key.J, function() if _G.__RE_open  then pcall(_G.__RE_open)  end end)
bind("__RE_U", Key.U, function() if _G.__RE_start then pcall(_G.__RE_start) end end)
bind("__RE_I", Key.I, function() if _G.__RE_probe then pcall(_G.__RE_probe) end end)

-- tecla SIMPLES: J sozinho abre a expedicao (sem Ctrl+Shift)
if not _G.__RE_Jplain then
    _G.__RE_Jplain = true
    pcall(function() RegisterKeyBind(Key.J, function() if _G.__RE_open then pcall(_G.__RE_open) end end) end)
    log("tecla simples J = abrir (registrada)")
end

log("logic " .. M.VERSION .. " ativa. J=abrir U=focar L=fechar K=reload")
return M
