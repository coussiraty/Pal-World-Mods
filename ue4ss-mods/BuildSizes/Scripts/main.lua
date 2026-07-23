-- =====================================================================
--  BuildSizes - casca. Carrega a logic.lua e a tecla de reload do config.
--  Ctrl+Shift+B = recarrega o config.lua e reaplica (sem reiniciar).
-- =====================================================================
local MOD = "BuildSizes"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

local LOGIC = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Palworld\\Pal\\Binaries\\Win64\\ue4ss\\Mods\\BuildSizes\\Scripts\\logic.lua"

local function loadLogic()
    local ok, err = pcall(dofile, LOGIC)
    if ok then log("logic (re)carregada") else log("LOAD FALHOU: " .. tostring(err)) end
end
loadLogic()

-- F7 (sem modificador): livre, e NAO colide com o modo de construcao.
-- (Ctrl+Shift+B nao servia: o jogo usa B pra voltar/cancelar na construcao.)
if not _G.__BS_keys then
    _G.__BS_keys = true
    local ok, err = pcall(function()
        RegisterKeyBind(Key.F7, function()
            log("F7 -> recarrega config")
            loadLogic()
            if _G.__BS_reload then _G.__BS_reload() end
        end)
    end)
    log(ok and "tecla F7 OK" or ("tecla FALHOU: " .. tostring(err)))
end
