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
    -- PROPRIEDADES direto (getter-methods voltam 0 no UE4SS):
    local rel = safe(function() return c.RelativeScale3D end, nil)   -- FVector
    local ext = safe(function() return c.BoxExtent end, nil)         -- FVector (cru, sem escala)
    log(string.format("  %s [%s] relScale=%s BoxExtent=%s", tag, cls, vstr(rel), vstr(ext)))
end

local function actorScale(a)
    -- RootComponent.RelativeScale3D via propriedade
    local rc = safe(function() return a.RootComponent end, nil)
    if not alive(rc) then rc = safe(function() return a.Root end, nil) end
    return vstr(safe(function() return rc.RelativeScale3D end, nil))
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
            log(string.format("Expedition ator: state=%s (1=Simulation/fantasma 3=Available/construido) rootScale=%s",
                tostring(st), actorScale(bo)))
            dumpBox("CheckOverlapCollision", safe(function() return bo.CheckOverlapCollision end, nil))
            local mesh = safe(function() return bo.SM_PalExpeditionFacilities end, nil)
            if alive(mesh) then
                log("  SM_PalExpeditionFacilities relScale=" ..
                    vstr(safe(function() return mesh.RelativeScale3D end, nil)))
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
            log("InstallChecker rootScale=" .. actorScale(ic))
            -- tenta varios nomes possiveis do componente de colisao do checker
            for _, prop in ipairs({ "OverlapCheckComponent", "CollisionComponent", "OverlapChecker", "Collision" }) do
                local c = safe(function() return ic[prop] end, nil)
                if alive(c) then dumpBox("InstallChecker." .. prop, c) end
            end
            -- e enumera TODAS as shapes do checker (pega o que existir)
            local shapes = safe(function()
                return ic:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.ShapeComponent"))
            end, nil)
            if shapes then
                local n = safe(function() return shapes:GetArrayNum() end, 0) or 0
                log("  InstallChecker tem " .. tostring(n) .. " ShapeComponent(s)")
                for j = 1, n do
                    local c = shapes[j]
                    if alive(c) then dumpBox("  shape#" .. j, c) end
                end
            end
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
