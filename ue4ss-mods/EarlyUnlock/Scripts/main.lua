-- =====================================================================
--  EarlyUnlock - casca (harness). So carrega a logic.lua no boot.
--  Objetivo: destravar cedo TODAS as selas + incubadora/expedicao/breedfarm
--  via UPalCheatManager:UnlockOneTechnology (ignora nivel/ponto/chefe),
--  SEM amontoar tudo no nivel 1 da arvore (que a UI nao aguenta).
--  Auto no load + atalho Ctrl+Shift+T pra destravar manualmente.
-- =====================================================================
local MOD = "EarlyUnlock"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

local LOGIC = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/EarlyUnlock/Scripts/logic.lua"

local ok, err = pcall(dofile, LOGIC)
if ok then log("logic carregada") else log("CARGA FALHOU: " .. tostring(err)) end
