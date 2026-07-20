-- Sonda do prédio de expedição. Duas medições:
--   F7            = prédio CONSTRUÍDO (escala/colisão do ator já colocado).
--   Ctrl+Shift+B  = MODO DE CONSTRUÇÃO: le o InstallChecker (footprint de
--                   placement) + o fantasma (ghost) + o construído, pra saber
--                   (a) se o ghost reseta a escala pra 1.0 e (b) se o footprint
--                   vem da nossa CheckOverlapCollision ou de outro pipeline.
--   >> Entre em modo de construção com o fantasma do escritório na tela ANTES
--      de apertar Ctrl+Shift+B (o InstallChecker só existe em build mode).
-- Regra de ouro: callback de keybind roda na thread do UE4SS -> game thread.

local function log(s) print("[ExpSize] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function alive(o) if o == nil then return false end return safe(function() return o:IsValid() end, false) == true end
local function vstr(v)
    if v == nil then return "nil" end
    return safe(function() return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end, "?")
end

local function dumpBox(tag, c)
    if not alive(c) then log("  " .. tag .. " = <nil>"); return end
    local cls = safe(function() return c:GetClass():GetFName():ToString() end, "?")
    local rel = safe(function() return c.RelativeScale3D end, nil)
    local un  = safe(function() return c:GetUnscaledBoxExtent() end, nil)
    local sc  = safe(function() return c:GetScaledBoxExtent() end, nil)
    log(string.format("  %s [%s] relScale=%s extentCru=%s extentEscalado=%s",
        tag, cls, vstr(rel), vstr(un), vstr(sc)))
end

local function medeBuildObjects()
    local l = FindAllOf("PalBuildObject")
    if not l then log("nenhum PalBuildObject (entre numa base)"); return end
    local achou = false
    for i = 1, #l do
        local bo = l[i]
        local nm = safe(function() return bo:GetFullName() end, "")
        if alive(bo) and string.find(nm, "Expedition", 1, true) and not string.find(nm, "Default__", 1, true) then
            achou = true
            local st = safe(function() return bo.CurrentState end, "?")
            log(string.format("Expedition ator: state=%s actorScale=%s",
                tostring(st), vstr(safe(function() return bo:GetActorScale3D() end, nil))))
            dumpBox("CheckOverlapCollision", safe(function() return bo.CheckOverlapCollision end, nil))
            local mesh = safe(function() return bo.SM_PalExpeditionFacilities end, nil)
            if alive(mesh) then
                log("  SM_PalExpeditionFacilities relScale=" ..
                    vstr(safe(function() return mesh.RelativeScale3D end, nil)) ..
                    " worldScale=" .. vstr(safe(function() return mesh:GetComponentScale() end, nil)))
            end
        end
    end
    if not achou then log("nenhum ator Expedition (construido OU fantasma) encontrado") end
end

local function medeInstallChecker()
    local l = FindAllOf("PalBuildObjectInstallChecker")
    if not l or #l == 0 then log("nenhum InstallChecker -- esta em MODO DE CONSTRUCAO com o fantasma na tela?"); return end
    for i = 1, #l do
        local ic = l[i]
        if alive(ic) then
            log("InstallChecker actorScale=" .. vstr(safe(function() return ic:GetActorScale3D() end, nil)))
            dumpBox("InstallChecker.OverlapCheckComponent", safe(function() return ic.OverlapCheckComponent end, nil))
        end
    end
end

-- F7: prédio construído
RegisterKeyBind(Key.F7, function()
    ExecuteInGameThread(function()
        log("==== F7 (construido) ====")
        medeBuildObjects()
        log("==== fim ====")
    end)
end)

-- Ctrl+Shift+B: modo de construção (fantasma + checker)
if not _G.__ExpSize_B then
    _G.__ExpSize_B = true
    RegisterKeyBind(Key.B, { ModifierKey.CONTROL, ModifierKey.SHIFT }, function()
        ExecuteInGameThread(function()
            log("==== Ctrl+Shift+B (placement) ====")
            medeInstallChecker()
            medeBuildObjects()   -- pega o fantasma tambem (state deve ser Simulation)
            log("==== fim ====")
        end)
    end)
end

print("[ExpSize] pronto. F7 = predio construido | Ctrl+Shift+B = em modo de construcao (fantasma).\n")
