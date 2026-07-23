-- =====================================================================
--  FastBreeding - casca (harness). So carrega a logic.lua no boot.
--  Fazenda de reproducao em 30s. Escreve BreedRequiredRealTime em runtime,
--  sem tocar o BP via PalSchema -> libera o BP_BuildObject_BreedFarm_C pro
--  MiniBuilds (que ai encolhe a fazenda de verdade, sem conflito).
-- =====================================================================
local MOD = "FastBreeding"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

package.loaded["logic"] = nil
local ok, res = pcall(require, "logic")
if ok then log("logic carregada") else log("LOAD FALHOU: " .. tostring(res)) end
