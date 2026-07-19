-- =====================================================================
--  ExpeditionXP / logic.lua
--  Pals ganham XP ao VOLTAR de uma expedicao (automatico).
--  Deteccao: vigia o flag IsAssignedToExpedition de cada pal; quando um pal
--  passa de "em expedicao" -> "voltou" (e o mod viu ele COMECAR), ganha XP.
--  Escreve Exp+Level de forma consistente (nivel natural a partir do Exp).
--
--  ATALHOS:
--    Ctrl+Shift+U = TESTE manual: da XP no pal renomeado "Teste"
--    Ctrl+Shift+P = liga/desliga o modo automatico
--    Ctrl+Shift+O = recarrega esta logica (debug)
-- =====================================================================
local M = { VERSION = "v3.2 (HUD estilo jogo: texto limpo + barra de XP)" }

local LOGIC = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/ExpeditionXP/Scripts/logic.lua"

local CONFIG = {
    ENABLED           = true,    -- modo automatico ligado
    XP_PER_EXPEDITION = 0.5,     -- XP por expedicao, em FRACAO de nivel (0.5 = meio nivel)
    MAX_LEVEL         = 60,      -- teto de nivel
    POLL_SECONDS      = 5,       -- de quanto em quanto tempo verifica
    SHOW_HUD          = true,    -- mostra notificacao na tela
    TEST_NICK         = "Teste", -- tecla U mira no pal com esse apelido
}

local function log(s) print("[ExpeditionXP] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

-- estado persistente entre reloads (hot-reload nao perde o tracking)
_G.__EXP_wasAssigned = _G.__EXP_wasAssigned or {}
_G.__EXP_seen        = _G.__EXP_seen or {}
_G.__EXP_cycle       = _G.__EXP_cycle or {}
local W = _G.__EXP_wasAssigned   -- estava em expedicao no tick anterior?
local S = _G.__EXP_seen          -- ja vi esse pal ao menos 1x?
local C = _G.__EXP_cycle         -- vi essa expedicao COMECAR (nao conta as ja em curso)?

-- ---------- identidade do pal ----------
local function nickOf(p)
    return safe(function() return p.SaveParameter.NickName:ToString() end,
           safe(function() return tostring(p.SaveParameter.NickName) end, "")) or ""
end
local function palIdent(p)
    local sp = safe(function() return p.SaveParameter end, nil)
    local id = sp and safe(function() return sp.CharacterID:ToString() end,
                          safe(function() return tostring(sp.CharacterID) end, "?")) or "?"
    local nick = nickOf(p)
    local lv = safe(function() return p:GetLevel() end, "?")
    if nick and nick ~= "" and nick ~= "?" then nick = " '" .. nick .. "'" else nick = "" end
    return string.format("%s%s Lv%s", tostring(id), nick, tostring(lv))
end
-- nome sem o Lv (pra HUD limpa, tipo o jogo)
local function palName(p)
    local sp = safe(function() return p.SaveParameter end, nil)
    local id = sp and safe(function() return sp.CharacterID:ToString() end,
                          safe(function() return tostring(sp.CharacterID) end, "?")) or "?"
    local nick = nickOf(p)
    if nick and nick ~= "" and nick ~= "?" then return tostring(id) .. " '" .. nick .. "'" end
    return tostring(id)
end

-- ---------- tabela de Exp por nivel: menor Exp NAO-zero visto em cada nivel ----------
-- (pals com Exp=0 num nivel>1 sao anomalos/spawned; ignora, senao dessincroniza)
local expByLevel = {}
local function buildExpTable()
    expByLevel = {}
    local l = FindAllOf("PalIndividualCharacterParameter")
    local n, levels = 0, 0
    if l then for _, p in ipairs(l) do
        if isok(p) then
            local lv = safe(function() return p:GetLevel() end, nil)
            local ex = safe(function() return p.SaveParameter.Exp end, nil)
            if type(lv) == "number" and type(ex) == "number" and lv >= 1 and (lv == 1 or ex > 0) then
                if expByLevel[lv] == nil then levels = levels + 1 end
                if expByLevel[lv] == nil or ex < expByLevel[lv] then expByLevel[lv] = ex end
                n = n + 1
            end
        end
    end end
    log(string.format("tabela de exp: %d pals validos, %d niveis com dado", n, levels))
    return levels
end
local function ensureExpTable() if next(expByLevel) == nil then buildExpTable() end end

-- exp cumulativo (aprox) no inicio do nivel L: amostra, ou interpola dos vizinhos
local function expAtLevel(L)
    if L <= 1 then return 0 end
    if expByLevel[L] then return expByLevel[L] end
    local lo, loV, hi, hiV
    for k = L - 1, 1, -1 do if expByLevel[k] then lo, loV = k, expByLevel[k]; break end end
    for k = L + 1, CONFIG.MAX_LEVEL do if expByLevel[k] then hi, hiV = k, expByLevel[k]; break end end
    if loV and hiV then return math.floor(loV + (hiV - loV) * (L - lo) / (hi - lo)) end
    return loV or 0
end

-- nivel correspondente a um total de exp
local function levelForExp(exp)
    local best = 1
    for L = 2, CONFIG.MAX_LEVEL do
        local e = expAtLevel(L)
        if e and e > 0 and exp >= e then best = L else if e and e > exp then break end end
    end
    return best
end

-- da XP (fracao de nivel) a um pal; escreve Exp+Level consistentes (level natural do exp)
local function grantXP(p, fractionOfLevel)
    local lv = safe(function() return p:GetLevel() end, nil)
    if type(lv) ~= "number" then return false, "sem level" end
    if lv >= CONFIG.MAX_LEVEL then return false, "ja no maximo (Lv" .. lv .. ")" end
    local curExp = safe(function() return p.SaveParameter.Exp end, nil)
    if type(curExp) ~= "number" then return false, "sem exp" end
    local span = expAtLevel(lv + 1) - expAtLevel(lv)     -- xp de 1 nivel aqui
    if span <= 0 then span = 2000 end                    -- fallback se sem dado
    local gained = math.max(1, math.floor(span * fractionOfLevel))
    local newExp = curExp + gained
    local newLv  = math.min(levelForExp(newExp), CONFIG.MAX_LEVEL)
    if newLv < lv then newLv = lv end                    -- nunca abaixa
    pcall(function() p.SaveParameter.Exp   = newExp end)
    pcall(function() p.SaveParameter.Level = newLv end)
    -- progresso dentro do nivel novo (pra barra de XP na HUD)
    local base, nextE = expAtLevel(newLv), expAtLevel(newLv + 1)
    local frac = (nextE > base) and ((newExp - base) / (nextE - base)) or 1
    return true, string.format("Lv%d->Lv%d (+%d xp)", lv, newLv, gained),
           { old = lv, new = newLv, gained = gained, frac = frac }
end

-- =====================================================================
--  HUD (modulo compartilhado PalHud) - accent verde, canto esquerdo
-- =====================================================================
local HUDMOD = dofile("C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/PalHudShared/PalHud.lua")(
    "EXP", { accent = { 0.45, 1.0, 0.35 }, x = 40, y = 280, w = 380 })

-- =====================================================================
--  AUTOMATICO: vigia os pals e da XP a quem VOLTA da expedicao
-- =====================================================================
function M.tick()
    if not CONFIG.ENABLED then return end
    ensureExpTable()
    local l = FindAllOf("PalIndividualCharacterParameter")
    if not l then return end
    local returned = {}
    for _, p in ipairs(l) do
        if isok(p) then
            local key = safe(function() return p:GetFullName() end, nil)
            if key then
                local a = safe(function() return p:IsAssignedToExpedition() end, false) == true
                if S[key] then
                    if not W[key] and a then                  -- COMECOU uma expedicao (testemunhado)
                        C[key] = true
                    elseif W[key] and not a then              -- VOLTOU da expedicao
                        if C[key] then                        -- so se a gente viu comecar
                            local nm = palName(p)
                            local ok, msg, ex = grantXP(p, CONFIG.XP_PER_EXPEDITION)
                            if ok then
                                local lvtxt = (ex.new > ex.old) and (ex.old .. "->" .. ex.new) or tostring(ex.new)
                                if #returned < 12 then
                                    returned[#returned+1] = { text = string.format("%s  Lv%s  +%d", nm, lvtxt, ex.gained), frac = ex.frac }
                                end
                                log("  +xp (voltou): " .. nm .. " " .. tostring(msg))
                            end
                        end
                        C[key] = nil
                    end
                end
                S[key] = true
                W[key] = a
            end
        end
    end
    if #returned > 0 then
        log(">>> " .. #returned .. " pal(s) voltaram da expedicao e ganharam XP")
        if CONFIG.SHOW_HUD then HUDMOD.show("EXPEDICAO: +XP", returned, 7) end
    end
end

-- =====================================================================
--  MANUAL: teste no pal "Teste" / toggle
-- =====================================================================
local function targetPal()
    local want = string.lower(CONFIG.TEST_NICK)
    local l = FindAllOf("PalIndividualCharacterParameter")
    if l then for _, p in ipairs(l) do
        if isok(p) and string.lower(nickOf(p)) == want then return p end
    end end
    return nil
end

function M.testGrant()
    log("===== TESTE GRANT (pal '" .. CONFIG.TEST_NICK .. "') =====")
    ensureExpTable()
    local p = targetPal()
    if not isok(p) then log("nenhum pal renomeado '" .. CONFIG.TEST_NICK .. "'"); return end
    local nm = palName(p)
    log("antes = " .. palIdent(p))
    local ok, msg, ex = grantXP(p, CONFIG.XP_PER_EXPEDITION)
    log((ok and ">>> " or "falhou: ") .. tostring(msg))
    log("depois = " .. palIdent(p) .. " Exp=" .. tostring(safe(function() return p.SaveParameter.Exp end, "?")))
    if ok and CONFIG.SHOW_HUD then
        local lvtxt = (ex.new > ex.old) and (ex.old .. "->" .. ex.new) or tostring(ex.new)
        HUDMOD.show("TESTE: +XP", { { text = string.format("%s  Lv%s  +%d", nm, lvtxt, ex.gained), frac = ex.frac } }, 6)
    end
end

function M.toggle()
    CONFIG.ENABLED = not CONFIG.ENABLED
    log("modo automatico = " .. (CONFIG.ENABLED and "LIGADO" or "DESLIGADO"))
    if CONFIG.SHOW_HUD then HUDMOD.show("ExpeditionXP", { "Automatico: " .. (CONFIG.ENABLED and "LIGADO" or "DESLIGADO") }, 3) end
end

-- ==== TEMP: sonda das linhas da DT_TechnologyRecipeUnlock (ovo/expedicao/fazenda/sela) ====
local function arrNum2(a) return safe(function() return a:GetArrayNum() end, safe(function() return #a end, 0)) end
function M.probeTechRows()
    log("===== PROBE TECH ROWS =====")
    local dt = nil
    local l = FindAllOf("DataTable")
    if l then for _, d in ipairs(l) do
        if isok(d) and safe(function() return d:GetFullName() end, ""):find("TechnologyRecipeUnlock") then dt = d; break end
    end end
    if not isok(dt) then log("DT_TechnologyRecipeUnlock nao carregada"); return end
    log("dt = " .. safe(function() return dt:GetFullName() end, "?"))
    local names = safe(function() return dt:GetRowNames() end, nil)
    if not names then log("GetRowNames falhou"); return end
    local n = arrNum2(names)
    log("techs: " .. n .. " linhas; filtrando ovo/expedicao/fazenda/sela:")
    local shown = 0
    for i = 1, n do
        local nm = safe(function() return names[i]:ToString() end, nil)
                or safe(function() return tostring(names[i]) end, "?")
        local low = string.lower(tostring(nm))
        if low:find("egg") or low:find("incub") or low:find("expedi") or low:find("teammission")
           or low:find("breed") or low:find("saddle") or low:find("gear") or low:find("pasture") or low:find("ranch") then
            log("  >> " .. tostring(nm)); shown = shown + 1
        end
    end
    if shown == 0 then log("  (nada filtrado; mostrando 20 primeiras p/ ver o formato:)")
        for i = 1, math.min(n, 20) do
            log("  row" .. i .. " = " .. tostring(safe(function() return names[i]:ToString() end, nil) or tostring(names[i])))
        end
    end
    -- despeja TODAS as linhas num arquivo pra eu grep (selas etc.)
    pcall(function()
        local f = io.open("C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/tech_rows.txt", "w")
        if f then
            for i = 1, n do
                f:write(tostring(safe(function() return names[i]:ToString() end, nil) or tostring(names[i])) .. "\n")
            end
            f:close()
            log("todas as " .. n .. " linhas -> ue4ss/tech_rows.txt")
        end
    end)
    log("===== fim tech rows =====")
end

-- ==== STAMINA: pega o PARAMETRO do pal ativo (invocado/montado) ====
local function activePalParam()
    local holder = FindFirstOf("PalOtomoHolderComponentBase")
    if not isok(holder) then return nil, "sem OtomoHolder" end
    local actor = safe(function() return holder:TryGetOtomoActorBySlotIndex(0) end, nil)
    if not isok(actor) then return nil, "sem pal ativo (invoca um pal)" end
    local comp  = safe(function() return actor:GetCharacterParameterComponent() end, nil)
    local param = comp and safe(function() return comp.IndividualParameter end, nil)
    if not isok(param) then return nil, "sem parametro do pal ativo" end
    return param
end

-- ==== EFEITO do item de stamina: +STAMINA_PER_USE no pal ativo, ate STAMINA_CAP ====
local STAMINA_PER_USE = 30      -- quanto cada uso soma (stamina)
local STAMINA_CAP      = 400    -- teto de stamina (progresso, nao infinito)
function M.boostActiveStamina()
    local p, err = activePalParam()
    if not p then log("stamina: " .. tostring(err)); if CONFIG.SHOW_HUD then HUDMOD.show("STAMINA", { tostring(err) }, 3) end; return end
    local raw = safe(function() return p.SaveParameter.MaxSP end, nil)
    local cur = raw and safe(function() return raw.Value end, nil)
    if type(cur) ~= "number" then log("stamina: MaxSP.Value invalido"); return end
    local newv = math.min(cur + STAMINA_PER_USE * 1000, STAMINA_CAP * 1000)
    pcall(function() p.SaveParameter.MaxSP.Value = newv end)
    local after = tonumber(safe(function() return p.SaveParameter.MaxSP.Value end, cur)) or newv
    local sNow = math.floor(after / 1000)
    log(string.format("stamina: %s  %d -> %d (~%d)", palIdent(p), math.floor(cur/1000), sNow, sNow))
    if CONFIG.SHOW_HUD then
        local capped = (after >= STAMINA_CAP * 1000)
        HUDMOD.show("STAMINA +", { palIdent(p) .. "  ~" .. sNow .. (capped and " (MAX)" or "") }, 5)
    end
end

-- ==== hook "usar item NUM pal": se for o StaminaElixir, +stamina no pal ====
if not _G.__EXP_itemhook then
    _G.__EXP_itemhook = true
    local ok, err = pcall(function()
        RegisterHook("/Script/Pal.PalItemUseProcessor:UseItemToCharacter_ServerInternal", function(self, a, b)
            local id = "?"
            pcall(function() id = a:get():GetStaticItemId():ToString() end)
            if id == "?" or id == nil then pcall(function() id = a:get().StaticItemId:ToString() end) end
            if id == "?" or id == nil then pcall(function() id = a:get():GetItemId().StaticId:ToString() end) end
            log("HOOK use-on-pal: item=" .. tostring(id) .. "  (a=" .. type(a) .. " b=" .. type(b) .. ")")
            if tostring(id):find("Stamina") then
                log("  >>> StaminaElixir! aplicando boost")
                pcall(function() M.boostActiveStamina() end)
            end
        end)
    end)
    log("hook use-on-pal: " .. (ok and "instalado" or ("FALHOU: " .. tostring(err))))
end

-- =====================================================================
--  atalhos + loop (chamam globais fixos p/ sobreviver ao hot-reload)
-- =====================================================================
_G.__EXP_write   = M.testGrant     -- tecla U (ja registrada em versoes antigas) -> teste
_G.__EXP_probe   = M.toggle        -- tecla P (ja registrada) -> toggle
_G.__EXP_test    = M.testGrant
_G.__EXP_exp     = M.toggle
_G.__EXP_tick    = M.tick
_G.__EXP_mission = nil             -- tecla M antiga (sonda de debug) desativada
_G.__EXP_stam    = M.boostActiveStamina  -- tecla Y = da stamina no pal ativo (efeito do item)
_G.__EXP_tech    = M.probeTechRows       -- TEMP: tecla N = sonda tech rows

local function bind(guard, key, fn)
    if not _G[guard] then _G[guard] = true
        pcall(function() RegisterKeyBind(key, { ModifierKey.CONTROL, ModifierKey.SHIFT }, fn) end)
    end
end
bind("__EXP_U", Key.U, function() if _G.__EXP_test then pcall(_G.__EXP_test) end end)
bind("__EXP_P", Key.P, function() if _G.__EXP_exp  then pcall(_G.__EXP_exp)  end end)
bind("__EXP_O", Key.O, function() pcall(function() dofile(LOGIC) end) end)
bind("__EXP_Y", Key.Y, function() if _G.__EXP_stam then pcall(_G.__EXP_stam) end end)  -- TEMP: teste stamina
bind("__EXP_N", Key.N, function() if _G.__EXP_tech then pcall(_G.__EXP_tech) end end)  -- TEMP: sonda tech

-- loop automatico: registra 1 vez, mas sempre chama o _G.__EXP_tick atual
if not _G.__EXP_ticking then
    _G.__EXP_ticking = true
    local function loop()
        if _G.__EXP_tick then pcall(_G.__EXP_tick) end
        ExecuteWithDelay((CONFIG.POLL_SECONDS or 5) * 1000, loop)
    end
    ExecuteWithDelay(3000, loop)
    log("loop automatico iniciado (a cada " .. CONFIG.POLL_SECONDS .. "s)")
end

log("logic " .. M.VERSION .. " ativa. auto=" .. tostring(CONFIG.ENABLED) ..
    "  U=teste  P=liga/desliga  O=reload")
return M
