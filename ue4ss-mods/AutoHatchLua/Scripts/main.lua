-- =====================================================================
--  AutoHatchLua - casca (main.lua)   v2 - game thread + evento
--
--  Responsabilidade desta casca: carregar logic.lua, registrar os hooks
--  de evento e agendar o passe periodico NA GAME THREAD.
--  REGRA DE OURO: nada aqui nem em logic.lua pode tocar em UObject fora
--  da game thread.
--
--  POR QUE MUDOU (crashes de 18/07):
--    LoopAsync NAO roda na game thread - o UE4SS executa a callback numa
--    thread propria do mod. Todo o trabalho antigo (FindAllOf, leitura de
--    propriedade, chamada de UFunction de servidor) rodava concorrente com
--    o tick e com o GC do Unreal. Bate com os dumps:
--      - 2 access violations DENTRO do binding Lua da UE4SS.dll, numa
--        thread que nao e a "GameThread";
--      - 3 dumps com "Illegal call to StaticFindObjectFast() while
--        serializing object data or garbage collecting!".
--    pcall NAO protege contra isso: access violation do C++ nao vira erro
--    de Lua, o processo morre na hora.
-- =====================================================================

local MOD = "AutoHatchLua"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

local LOGIC_PATH = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/AutoHatchLua/Scripts/logic.lua"

-- Passe de SEGURANCA. O trabalho normalmente e disparado pelo evento
-- (hook de OnFinishWorkInServer); esse timer so garante que nada fica
-- preso se o hook nao disparar. 3s e de proposito: nao ha pressa nenhuma.
local TICK_MS = 3000

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

-- ---------------------------------------------------------------------
--  Agendador: roda fn a cada ms NA GAME THREAD.
--   1a opcao: LoopInGameThreadWithDelay - sistema de delayed actions.
--             Existe nesta build (confirmado nas strings da UE4SS.dll:
--             "#1: LoopInGameThreadWithDelay(integer delayMs, LuaFunction
--             callback) -> integer handle") e os hooks que ele precisa
--             resolveram no boot ("Found GameEngineTick", "ProcessEvent
--             address" no UE4SS.log).
--   2a opcao: LoopAsync SO como relogio + ExecuteInGameThread pro corpo.
--  Se nenhuma existir, NAO agenda nada: melhor o mod nao rodar do que
--  rodar fora da game thread.
-- ---------------------------------------------------------------------
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
            -- ATENCAO: este corpo roda na thread async do UE4SS.
            -- A UNICA coisa permitida aqui e empurrar o trabalho pra game
            -- thread. Nao ler, nao escrever, nao tocar em UObject.
            ExecuteInGameThread(fn)
            return false          -- nunca para o relogio
        end)
        log("timer: LoopAsync(" .. ms .. "ms) + ExecuteInGameThread (fallback)")
        return true
    end
    log("!! sem API de game thread nesta build - tick NAO agendado (nao vou rodar fora da game thread)")
    return false
end

-- ---------------------------------------------------------------------
--  EVENTO: "o trabalho da incubadora terminou no servidor".
--  O callback de RegisterHook e chamado de dentro do ProcessEvent, ou
--  seja: JA esta na game thread. Mesmo assim ele NAO toca em UObject -
--  so levanta uma flag. Quem age e o passe seguinte, que re-resolve tudo
--  com FindAllOf e revalida o estado.
--  (nunca guardamos ponteiro de UObject entre callbacks)
-- ---------------------------------------------------------------------
local HOOKS = {
    "/Script/Pal.PalMapObjectHatchingEggModel:OnFinishWorkInServer",
    "/Script/Pal.PalMapObjectHatchingEggModelBase:OnFinishWorkInServer",
    "/Script/Pal.PalMapObjectHatchingEggModel:OnUpdateContainerContentInServer",
    "/Script/Pal.PalMapObjectHatchingEggModelBase:OnUpdateContainerContentInServer",
}

if not _G.__AH_HOOKS then
    _G.__AH_HOOKS = true
    for _, path in ipairs(HOOKS) do
        local ok, err = pcall(function()
            RegisterHook(path, function() end, function() _G.__AH_DIRTY = true end)
        end)
        log((ok and "hook OK     " or "hook FALHOU ") .. path .. (ok and "" or (" -> " .. tostring(err))))
    end
end

_G.__AH_CLOCK = _G.__AH_CLOCK or 0
_G.__AH_DIRTY = true      -- primeiro passe ja faz a varredura completa

reload()

if not _G.__AH_TICK_STARTED then
    _G.__AH_TICK_STARTED = everyMsInGameThread(TICK_MS, function()
        _G.__AH_CLOCK = (_G.__AH_CLOCK or 0) + 1
        local f = LOGIC.tick
        if type(f) == "function" then
            local ok, err = pcall(f)      -- rede pra erro de LUA, so isso
            if not ok then log("tick erro: " .. tostring(err)) end
        end
        -- nao retorna nada de proposito: em qualquer semantica de loop
        -- (retorne-true-pra-parar ou roda-ate-CancelDelayedAction) isso
        -- significa "continua".
    end)
end

log("pronto (v2: game thread + evento). Passe de seguranca a cada " .. (TICK_MS / 1000) .. "s.")
