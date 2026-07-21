-- =====================================================================
--  RemoteExpedition - casca (harness). So carrega a logic.lua no boot.
--  Atalhos (registrados dentro da logic): Ctrl+Shift+J=abrir, U=focar,
--  L=fechar, K=recarregar (debug). NAO usa mais as teclas F (batiam com o jogo).
-- =====================================================================
local MOD = "RemoteExpedition"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

-- PORTAVEL: require resolve logic.lua na pasta Scripts/ deste mod (sem caminho
-- absoluto). package.loaded=nil forca recarregar se ja tiver sido carregado.
package.loaded["logic"] = nil
local ok, res = pcall(require, "logic")
if ok then log("logic carregada") else log("LOAD FALHOU: " .. tostring(res)) end

log("pronto. Ctrl+Shift+J=abrir  Ctrl+Shift+U=focar  Ctrl+Shift+L=fechar  Ctrl+Shift+K=recarregar")
