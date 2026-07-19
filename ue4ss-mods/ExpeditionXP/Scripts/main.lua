-- =====================================================================
--  ExpeditionXP - casca (harness). So carrega a logic.lua no boot.
--  Todos os atalhos sao registrados dentro da logic (Ctrl+Shift+<>).
--  Objetivo do mod: dar XP aos pals quando a expedicao termina.
--  (v1 = investigacao: achar como escrever Exp/Level no pal com seguranca)
-- =====================================================================
local MOD = "ExpeditionXP"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

local LOGIC = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/ExpeditionXP/Scripts/logic.lua"

local ok, err = pcall(dofile, LOGIC)
if ok then log("logic carregada") else log("CARGA FALHOU: " .. tostring(err)) end
log("pronto. Ctrl+Shift+P=sonda  Ctrl+Shift+O=reload")
