-- =====================================================================
--  FastBreeding / logic.lua  (v1.0 - runtime + SONDA de CDO)
--  Fazenda de reproducao em 30s (BreedRequiredRealTime = 30).
--  O valor vive em COMPONENTES DE INSTANCIA (nao num singleton):
--    UPalMapObjectBreedFarmParameterComponent.BreedRequiredRealTime (@0xA0)
--    UPalMapObjectBreedFarmModel.BreedRequiredRealTime            (@0x24C)
--  v1.0 seta nas instancias VIVAS (fazendas ja construidas/carregadas) e
--  LOGA o fullname dos objetos achados -> pra localizar o CDO do BP e, numa
--  v1.1, cobrir fazendas FUTURAS setando o default da classe. Ate la, F4
--  re-aplica (util depois de construir/chegar perto de uma fazenda nova).
--  Roda no load + F4 manual.
-- =====================================================================
local M = { VERSION = "v1.0" }

local LOG = true
local function log(s) if LOG then print("[FastBreeding] " .. tostring(s) .. "\n") end end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

local VALUE   = 30.0
local CLASSES = { "PalMapObjectBreedFarmParameterComponent", "PalMapObjectBreedFarmModel" }

local function apply()
    local seen, set = 0, 0
    for _, cls in ipairs(CLASSES) do
        local list = FindAllOf(cls)
        if list then
            for i = 1, #list do
                local o = list[i]
                if isok(o) then
                    seen = seen + 1
                    local fn     = safe(function() return o:GetFullName() end, "?")
                    local before = safe(function() return o.BreedRequiredRealTime end, "?")
                    local wok    = pcall(function() o.BreedRequiredRealTime = VALUE end)
                    local after  = safe(function() return o.BreedRequiredRealTime end, "?")
                    if wok and tostring(after) == tostring(VALUE) then set = set + 1 end
                    if seen <= 8 then  -- sonda: revela o path (pra achar o CDO na v1.1)
                        log("  [" .. cls .. "] " .. tostring(fn) .. " : " .. tostring(before) .. " -> " .. tostring(after))
                    end
                end
            end
        end
    end
    log("BreedRequiredRealTime=" .. VALUE .. " setado em " .. set .. "/" .. seen .. " objeto(s) vivo(s)" ..
        (seen == 0 and "  (nenhuma fazenda carregada agora - construa/chegue perto e aperte F4)" or ""))
    return seen, set
end
M.apply = apply

local function runSafe() ExecuteInGameThread(function() apply() end) end
M.run = runSafe

if not _G.__FastBreeding_hooked then
    _G.__FastBreeding_hooked = true

    -- roda 1x pouco depois de entrar no mundo (pega fazendas ja carregadas)
    pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
            if _G.__FastBreeding_ran then return end
            _G.__FastBreeding_ran = true
            ExecuteWithDelay(6000, function() runSafe() end)
        end)
    end)

    -- F4: re-aplicar (depois de construir/carregar uma fazenda nova)
    pcall(function()
        RegisterKeyBind(Key.F4, function() log("F4 -> re-aplicando..."); runSafe() end)
    end)

    log("pronto (" .. M.VERSION .. "). Auto no load + F4.")
end

return M
