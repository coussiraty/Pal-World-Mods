-- =====================================================================
--  RemoteExpedition - casca (harness).
--  So carrega a logic.lua no boot. TODOS os atalhos sao Ctrl+Shift+<>,
--  registrados dentro da logic (sem conflito com o jogo). NAO usa mais
--  as teclas F (elas batiam com o jogo).
-- =====================================================================
local MOD = "RemoteExpedition"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

local LOGIC_PATH = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/RemoteExpedition/Scripts/logic.lua"

local function reload()
    local ok, res = pcall(dofile, LOGIC_PATH)
    if ok then log("logic carregada") else log("RELOAD FALHOU: " .. tostring(res)) end
end

reload()
log("pronto. Ctrl+Shift+J=abrir  Ctrl+Shift+U=iniciar  Ctrl+Shift+L=fechar  Ctrl+Shift+K=recarregar")
