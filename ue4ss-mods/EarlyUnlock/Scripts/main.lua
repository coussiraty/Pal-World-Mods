-- =====================================================================
--  EarlyUnlock - casca (harness). So carrega a logic.lua no boot (portavel).
--  Destrava cedo TODAS as selas/arreios de pal (+ incubadora, expedicao,
--  fazenda de reproducao) chamando a funcao NATIVA do jogo
--  (UPalTechnologyData:RequestUnlockRecipeTechnology) na game thread.
--  Auto ao entrar no mundo + atalho Ctrl+Shift+T pra destravar manualmente.
-- =====================================================================
local MOD = "EarlyUnlock"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

-- PORTAVEL: require resolve logic.lua na pasta Scripts/ deste mod (sem caminho
-- absoluto). package.loaded=nil forca recarregar se ja tiver sido carregado.
package.loaded["logic"] = nil
local ok, res = pcall(require, "logic")
if ok then log("logic carregada") else log("LOAD FALHOU: " .. tostring(res)) end
