-- =====================================================================
--  BuildSizes / logic.lua  -- config on-demand (molde no modo de construcao)
--  O Lua so pega os componentes do molde QUANDO a estrutura esta no menu de
--  construcao. Entao um tick (600ms) ve o preview; se a classe esta no config
--  e ativa, escala o molde PROPORCIONAL (posicao + tamanho + footprint, tudo
--  pelo mesmo fator), lendo os valores originais do proprio molde. Guarda o
--  original por classe+componente (cache) pra mudar o tamanho sem acumular.
--  Depois voce RE-SELECIONA a estrutura e ela nasce no tamanho.
-- =====================================================================
local function log(s) print("[BuildSizes] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function alive(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

-- GetName() NAO funciona nesta build (a sonda devolveu "?" pra tudo). O que
-- funciona e GetFName():ToString(). Deixo os outros como rede de seguranca.
local function nameOf(o)
    local n = safe(function() return o:GetFName():ToString() end)
    if type(n) == "string" and n ~= "" then return n end
    n = safe(function() return o:GetName() end)
    if type(n) == "string" and n ~= "" then return n end
    local fn = safe(function() return o:GetFullName() end)
    if type(fn) == "string" then return fn:match("([^%.:/%s]+)$") end
    return nil
end

local CONFIG_PATH = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Palworld\\Pal\\Binaries\\Win64\\ue4ss\\Mods\\BuildSizes\\config.lua"
local BS = _G.__BS or { orig = {} }; _G.__BS = BS

-- O config tem ~500 estruturas. Indexo por classe pra o tick nao varrer a lista
-- inteira 100x por minuto -- vira uma consulta direta.
local function loadCfg()
    local ok, cfg = pcall(dofile, CONFIG_PATH)
    if not ok or type(cfg) ~= "table" then
        log("!! nao li config.lua: " .. tostring(cfg)); _G.__BS_idx = {}; return
    end
    local idx, ligadas = {}, 0
    for _, e in ipairs(cfg) do
        if type(e) == "table" and type(e.classe) == "string" then
            idx[e.classe] = e
            if e.ativo then ligadas = ligadas + 1 end
        end
    end
    _G.__BS_idx = idx
    log("config: " .. #cfg .. " estruturas, " .. ligadas .. " ligada(s)")
end
loadCfg()

local EXCLUDE = { Root = true, DefaultSceneRoot = true }   -- root nao (escala dupla)

local function xyz(v, d)
    if v == nil then return nil end
    local x = safe(function() return v.X end)
    if type(x) ~= "number" then return nil end
    return { X = x, Y = safe(function() return v.Y end, d), Z = safe(function() return v.Z end, d) }
end

-- Os componentes do MOLDE nao estao em BlueprintCreatedComponents (isso e de
-- instancia, preenchido na construcao). Estao no SimpleConstructionScript, um
-- ComponentTemplate por no -- os mesmos "<Nome>_GEN_VARIABLE" que o PalSchema
-- patcheia. Sobe tambem pelas classes-pai, senao perde componente herdado.
local function moldComponents(cls)
    local out, guard = {}, 0
    local c = cls
    while alive(c) and guard < 8 do
        guard = guard + 1
        local scs = safe(function() return c.SimpleConstructionScript end)
        if alive(scs) then
            local nodes = safe(function() return scs.AllNodes end)
            local nn = safe(function() return nodes:GetArrayNum() end, safe(function() return #nodes end, 0))
            for i = 1, nn do
                local node = safe(function() return nodes[i] end)
                if alive(node) then
                    local tmpl = safe(function() return node.ComponentTemplate end)
                    if alive(tmpl) then out[#out + 1] = tmpl end
                end
            end
        end
        c = safe(function() return c:GetSuperStruct() end)
    end
    return out
end

-- Escala PROPORCIONAL: tamanho + posicao + footprint pelo mesmo fator (foi o que
-- fez a expedicao ficar certa). Guarda o original por classe+componente, senao
-- mudar o numero no config vai multiplicando em cima do ja escalado.
local function applyMold(cls, className, scale)
    local comps = moldComponents(cls)
    if #comps == 0 then return 0, 0 end
    local cache = BS.orig[className] or {}; BS.orig[className] = cache
    local n = 0
    for _, c in ipairs(comps) do
        local nm = (nameOf(c) or ""):gsub("_GEN_VARIABLE", "")
        if nm ~= "" and not EXCLUDE[nm] then
            local o = cache[nm]
            if not o then
                o = {}
                o.scl = xyz(safe(function() return c.RelativeScale3D end), 1) or { X = 1, Y = 1, Z = 1 }
                o.loc = xyz(safe(function() return c.RelativeLocation end), 0)
                o.box = xyz(safe(function() return c.BoxExtent end), 0)
                local sr = safe(function() return c.SphereRadius end)
                if type(sr) == "number" then o.sph = sr end
                local cr = safe(function() return c.CapsuleRadius end)
                if type(cr) == "number" then o.cr = cr end
                local ch = safe(function() return c.CapsuleHalfHeight end)
                if type(ch) == "number" then o.ch = ch end
                cache[nm] = o
            end
            pcall(function() c.RelativeScale3D = { X = o.scl.X * scale, Y = o.scl.Y * scale, Z = o.scl.Z * scale } end)
            if o.loc then pcall(function() c.RelativeLocation = { X = o.loc.X * scale, Y = o.loc.Y * scale, Z = o.loc.Z * scale } end) end
            if o.box then pcall(function() c.BoxExtent = { X = o.box.X * scale, Y = o.box.Y * scale, Z = o.box.Z * scale } end) end
            if o.sph then pcall(function() c.SphereRadius = o.sph * scale end) end
            if o.cr  then pcall(function() c.CapsuleRadius = o.cr * scale end) end
            if o.ch  then pcall(function() c.CapsuleHalfHeight = o.ch * scale end) end
            n = n + 1
        end
    end
    return n, #comps
end

-- so loga quando o estado MUDA (nada de spam de pulso)
local function state(s)
    if BS.state ~= s then BS.state = s; log("[estado] " .. s) end
end

-- O molde so pode ser lido enquanto a classe esta viva -- ou seja, com a
-- estrutura no modo de construcao. Por isso o trabalho e aqui, e nao no load.
local function tick()
    if BS.force then BS.force = false; BS.state = nil end
    -- loga na TRANSICAO, nao em pulso: o usuario precisa sair do jogo pra falar
    -- comigo, entao 2s no modo de construcao ja tem que deixar registro.
    local ic = FindFirstOf("PalBuildObjectInstallChecker")
    if not alive(ic) then state("fora do modo de construcao") return end
    -- so vale com o fantasma POUSADO num chao valido; so com a roda aberta vem invalido
    local t = safe(function() return ic.TargetBuildObject end)
    if not alive(t) then state("construcao ON, sem fantasma pousado") return end
    local cls = safe(function() return t:GetClass() end)
    if not alive(cls) then state("fantasma OK, sem classe") return end
    local cname = nameOf(cls)
    if not cname then state("fantasma OK, nome da classe ilegivel") return end
    state("fantasma = " .. cname)

    local e = (_G.__BS_idx or {})[cname]
    if not e or not e.ativo then return end
    local scale = tonumber(e.tamanho) or 1.0
    local key = cname .. "=" .. scale
    if BS.applied and BS.applied[key] then return end
    BS.applied = BS.applied or {}
    BS.applied[key] = true

    local n, total = applyMold(cls, cname, scale)
    if total == 0 then
        log("[" .. (e.nome or cname) .. "] !! nenhum componente no SimpleConstructionScript")
    else
        log("[" .. (e.nome or cname) .. "] molde " .. string.format("%.2f", scale)
            .. "x -> " .. n .. "/" .. total .. " comps. RE-SELECIONE a estrutura.")
    end
end

-- global: o hot-reload redefine, e o loop sempre chama a versao atual.
-- O wrapper loga erro do tick (antes o pcall do loop engolia calado, e eu
-- passei uma hora achando que o loop tinha morrido).
_G.__BS_tick = function()
    local ok, err = pcall(tick)
    if not ok then
        local e = tostring(err)
        if e ~= BS.lasterr then BS.lasterr = e; log("!! ERRO no tick: " .. e) end
    end
end

-- F7: recarrega o config e pede reaplicacao.
-- A tecla NAO toca na game thread. Ela so levanta a flag `force`; quem faz o
-- trabalho e o proprio loop, que JA roda na game thread.
-- (Chamar ExecuteInGameThread daqui com o LoopInGameThreadWithDelay ativo matou
--  a fila de game thread do UE4SS -- loop e fila morreram juntos no 1o F7.)
-- (nao chama loadCfg aqui: a casca ja fez dofile deste arquivo, e o loadCfg do
--  topo rodou junto -- chamar de novo so duplicava a linha no log)
_G.__BS_reload = function()
    BS.applied = {}
    BS.force = true
    log("config recarregado -> aplica no proximo tick")
end

-- Padrao LITERAL do AutoHatchLua (o unico que comprovadamente gira nesta build).
-- Antes eu dava `return false` no callback do LoopInGameThreadWithDelay e o loop
-- morria na 1a volta -- o AutoHatchLua nao retorna nada, e roda ate hoje.
local function everyMsInGameThread(ms, fn)
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, handle = pcall(LoopInGameThreadWithDelay, ms, fn)
        if ok then log("tick: LoopInGameThreadWithDelay(" .. ms .. "ms) handle=" .. tostring(handle)); return true end
        log("LoopInGameThreadWithDelay indisponivel (" .. tostring(handle) .. ") - fallback")
    end
    if type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
        LoopAsync(ms, function()
            ExecuteInGameThread(fn)      -- so empurra pra game thread
            return false                 -- aqui o `false` E o correto (nao para o relogio)
        end)
        log("tick: LoopAsync(" .. ms .. "ms) + ExecuteInGameThread (fallback)")
        return true
    end
    log("!! sem API de game thread - tick NAO agendado")
    return false
end

if not BS.loop then
    BS.loop = true
    everyMsInGameThread(600, function()
        if _G.__BS_tick then pcall(_G.__BS_tick) end
    end)
end

log("BuildSizes config on-demand pronto. Menu de construcao -> selecione a estrutura -> re-selecione pra ver.")
