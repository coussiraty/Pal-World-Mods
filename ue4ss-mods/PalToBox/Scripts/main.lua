-- =====================================================================
--  PalToBox - casca (main.lua)   v2 - game thread + evento
--  Captura/choco setam _G.__PTB_pending; o tick move o pal novo pro box.
--
--  POR QUE MUDOU:
--   1) O tick rodava em LoopAsync, que NAO e a game thread. Ele chamava
--      TryGetOtomoActorBySlotIndex (5x por tick) e
--      RequestMoveToPalBox_ToServer_Rep concorrendo com o tick do jogo e
--      com o GC. Mesma familia de bug dos crashes do AutoHatchLua.
--   2) O sinal de "chocou" vinha por ARQUIVO (hatch_signal.txt), escrito
--      pelo AutoHatchLua e truncado aqui. Isso tinha corrida real: todo
--      byte que o AutoHatch escrevesse entre o read e o truncate sumia,
--      e bytes de sessoes antigas voltavam do disco. Agora o sinal vem do
--      proprio jogo, por hook, na game thread.
-- =====================================================================

local function log(s) print("[PalToBox] " .. tostring(s) .. "\n") end

local LOGIC_PATH = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/PalToBox/Scripts/logic.lua"
local LEGACY_SIGNAL = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/PalToBox/hatch_signal.txt"

local TICK_MS = 2000

local LOGIC = {}
local function reload()
    local ok, res = pcall(dofile, LOGIC_PATH)
    if ok and type(res) == "table" then
        LOGIC = res
        log("### logic -> " .. tostring(res.VERSION))
    else
        LOGIC = {}
        log("### RELOAD FALHOU: " .. tostring(res))
    end
end

-- mesmo agendador do AutoHatchLua: o corpo SEMPRE na game thread.
local function everyMsInGameThread(ms, fn)
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, handle = pcall(LoopInGameThreadWithDelay, ms, fn)
        if ok then
            log("timer: LoopInGameThreadWithDelay(" .. ms .. "ms) handle=" .. tostring(handle))
            return true
        end
        log("LoopInGameThreadWithDelay indisponivel (" .. tostring(handle) .. ") - usando fallback")
    end
    if type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
        LoopAsync(ms, function()
            -- roda na thread async: so empurra pra game thread, nada mais.
            ExecuteInGameThread(fn)
            return false
        end)
        log("timer: LoopAsync(" .. ms .. "ms) + ExecuteInGameThread (fallback)")
        return true
    end
    log("!! sem API de game thread nesta build - tick NAO agendado")
    return false
end

_G.__PTB_pending = _G.__PTB_pending or 0

-- ---------------------------------------------------------------------
--  EVENTOS (todos rodam dentro do ProcessEvent = game thread).
--  Nenhum callback toca em UObject: so incrementa um contador.
--   - PalCaptureSuccess          -> capturei um pal
--   - OnFinishWorkInServer       -> uma incubadora terminou de chocar
--     (nas duas familias de incubadora: single e multi-ovo)
-- ---------------------------------------------------------------------
if not _G.__PTB_HOOKS then
    _G.__PTB_HOOKS = true

    local function hook(path, tag)
        local ok, err = pcall(function()
            RegisterHook(path, function() end, function()
                _G.__PTB_pending = (_G.__PTB_pending or 0) + 1
            end)
        end)
        log((ok and "hook OK     " or "hook FALHOU ") .. tag .. (ok and "" or (" -> " .. tostring(err))))
    end

    hook("/Script/Pal.PalUtility:PalCaptureSuccess", "captura")
    hook("/Script/Pal.PalMapObjectHatchingEggModel:OnFinishWorkInServer", "choco (single)")
    hook("/Script/Pal.PalMapObjectHatchingEggModelBase:OnFinishWorkInServer", "choco (multi)")

    -- canal antigo por arquivo: apaga UMA vez, pra byte velho de sessao
    -- passada nunca mais virar "pal novo" e mandar teu pal pro box.
    pcall(function()
        if os.remove(LEGACY_SIGNAL) then log("hatch_signal.txt antigo removido (canal por arquivo aposentado)") end
    end)
end

reload()

if not _G.__PTB_TICK then
    _G.__PTB_TICK = everyMsInGameThread(TICK_MS, function()
        local f = LOGIC.tick
        if type(f) == "function" then
            local ok, err = pcall(f)
            if not ok then log("tick erro: " .. tostring(err)) end
        end
    end)
end

log("pronto (v2: game thread + evento) - captura/choco -> Palbox automatico")
