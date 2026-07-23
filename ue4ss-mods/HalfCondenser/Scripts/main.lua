-- =====================================================================
--  HalfCondenser - casca (harness). So carrega a logic.lua no boot.
--  Condensador (rank-up de estrela) pede METADE dos pals. Escreve no
--  UPalGameSetting VIVO em runtime, sem tocar o blueprint via PalSchema
--  (assim nao briga com NoSanityLoss, que edita o mesmo BP_PalGameSetting_C).
-- =====================================================================
local MOD = "HalfCondenser"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

package.loaded["logic"] = nil
local ok, res = pcall(require, "logic")
if ok then log("logic carregada") else log("LOAD FALHOU: " .. tostring(res)) end
