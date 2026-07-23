-- =====================================================================
--  HalfCondenser / logic.lua  (v1.0)
--  Condensador pede METADE dos pals pra subir estrela.
--  UPalGameSetting.CharacterRankUpRequiredNumMap = {1:2, 2:4, 3:6, 4:12}
--  e CharacterRankUpRequiredNumDefault = 4  (vanilla = 4/8/12/24, Default 8).
--  Escreve no UPalGameSetting VIVO (singleton) em runtime -> NAO toca o
--  BP via PalSchema -> nao conflita com NoSanityLoss no mesmo blueprint.
--  ⚠ regra de ouro: NUNCA deixar um valor virar 0, nunca esvaziar o mapa.
--  Roda no load (retenta ate confirmar). F9 = forcar manual.
-- =====================================================================
local M = { VERSION = "v1.0" }

local LOG = true
local function log(s) if LOG then print("[HalfCondenser] " .. tostring(s) .. "\n") end end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

local TARGET  = { {1,2}, {2,4}, {3,6}, {4,12} }   -- rank -> qtd (metade do vanilla)
local DEFAULT = 4

-- acha o UPalGameSetting VIVO (pula o CDO 'Default__')
local function findGS()
    local list = FindAllOf("PalGameSetting")
    if list then
        for i = 1, #list do
            local g = list[i]
            if isok(g) and not string.find(tostring(safe(function() return g:GetFullName() end, "")), "Default__", 1, true) then
                return g
            end
        end
    end
    local g = FindFirstOf("PalGameSetting")
    if isok(g) then return g end
    return nil
end

local function apply()
    local gs = findGS()
    if not isok(gs) then return false, "PalGameSetting nao pronto" end
    log("GS = " .. safe(function() return gs:GetFullName() end, "?"))

    local before = safe(function() return gs.CharacterRankUpRequiredNumDefault end, "?")
    pcall(function() gs.CharacterRankUpRequiredNumDefault = DEFAULT end)

    local m = safe(function() return gs.CharacterRankUpRequiredNumMap end)
    local mok = (m ~= nil)
    if mok then
        for _, kv in ipairs(TARGET) do
            -- tenta as duas formas de escrever no TMap; nunca deixa 0
            if not pcall(function() m:Add(kv[1], kv[2]) end) then
                pcall(function() m[kv[1]] = kv[2] end)
            end
        end
    end

    local after = safe(function() return gs.CharacterRankUpRequiredNumDefault end, "?")
    local read1 = "?"
    if mok then read1 = tostring(safe(function() return m:Find(1) end, safe(function() return m[1] end, "?"))) end
    log("Default " .. tostring(before) .. " -> " .. tostring(after) .. " (alvo " .. DEFAULT ..
        ") | map[1]=" .. read1 .. " (alvo 2) | map_obtido=" .. tostring(mok))

    -- sucesso comprovado pelo efeito no campo Default (o map[1] confirma se marshalou)
    local ok = (tostring(after) == tostring(DEFAULT))
    return ok, ("Default=" .. tostring(after) .. " map[1]=" .. read1)
end
M.apply = apply

local MAX = 40
local function autoTry(t)
    t = t or 0
    ExecuteInGameThread(function()
        if _G.__HalfCondenser_done then return end
        local ok, msg = apply()
        if ok then
            _G.__HalfCondenser_done = true
            log("OK na tentativa " .. t .. ": " .. msg)
        elseif t < MAX then
            if t == 0 or (t % 5) == 0 then log("esperando GS (" .. msg .. "), tentativa " .. t) end
            ExecuteWithDelay(3000, function() autoTry(t + 1) end)
        else
            log("!! DESISTI apos " .. MAX .. " tentativas: " .. msg)
        end
    end)
end

local function forceNow() _G.__HalfCondenser_done = false; autoTry(0) end
M.force = forceNow

if not _G.__HalfCondenser_hooked then
    _G.__HalfCondenser_hooked = true

    pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
            _G.__HalfCondenser_done = false
            ExecuteWithDelay(5000, function() if not _G.__HalfCondenser_done then autoTry(0) end end)
        end)
    end)

    pcall(function()
        RegisterKeyBind(Key.F9, function() log("F9 -> forcando..."); forceNow() end)
    end)

    log("pronto (" .. M.VERSION .. "). Auto no load + F9.")
end

return M
