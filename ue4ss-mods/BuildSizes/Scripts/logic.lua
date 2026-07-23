-- =====================================================================
--  BuildSizes / logic.lua -- scales any build object through config.lua
--
--  A class mold (CDO) can only be read while the class is alive, i.e. while
--  the structure is up in build mode. So a 600ms game-thread tick watches the
--  placement ghost; when its class is listed and enabled in the config, the
--  mold is scaled PROPORTIONALLY (size + part positions + footprint by the
--  same factor) and the structure spawns at that size from then on.
--
--  Reloaded by F7 (see main.lua). Only this file reloads.
-- =====================================================================
local function log(s) print("[BuildSizes] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function alive(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

-- GetName() does NOT work in this build -- it returns nil for UClass and for
-- components alike. GetFName():ToString() does. The rest is a safety net.
local function nameOf(o)
    local n = safe(function() return o:GetFName():ToString() end)
    if type(n) == "string" and n ~= "" then return n end
    n = safe(function() return o:GetName() end)
    if type(n) == "string" and n ~= "" then return n end
    local fn = safe(function() return o:GetFullName() end)
    if type(fn) == "string" then return fn:match("([^%.:/%s]+)$") end
    return nil
end

-- Derive the mod folder from this script's own path. NEVER hardcode an absolute
-- path: it works here and silently fails on everyone else's install.
local function modDir()
    local src = debug.getinfo(1, "S").source
    if type(src) ~= "string" then return nil end
    local scripts = src:sub(2):match("^(.*)[/\\][^/\\]*$")   -- drop '@' and the file name
    return scripts and scripts:match("^(.*)[/\\][^/\\]*$")   -- .../BuildSizes/Scripts -> .../BuildSizes
end
local MOD_DIR = modDir()
local CONFIG_PATH = MOD_DIR and (MOD_DIR .. "\\config.lua")
if not CONFIG_PATH then log("!! could not resolve the mod folder -- config will not load") end

local BS = _G.__BS or { orig = {} }; _G.__BS = BS

-- ~500 entries in the config. Index them by class so the tick does a lookup
-- instead of walking the whole list 100 times a minute.
local function loadCfg(quiet)
    if not CONFIG_PATH then return false end
    local ok, cfg = pcall(dofile, CONFIG_PATH)
    if not ok or type(cfg) ~= "table" then
        if not quiet then log("!! could not read config.lua: " .. tostring(cfg)) end
        _G.__BS_idx = _G.__BS_idx or {}
        return false
    end
    local idx, on = {}, 0
    for _, e in ipairs(cfg) do
        if type(e) == "table" and type(e.class) == "string" then
            idx[e.class] = e
            if e.enabled then on = on + 1 end
        end
    end
    _G.__BS_idx = idx
    log("config: " .. #cfg .. " structures, " .. on .. " enabled")
    return true
end

local function readRaw()
    if type(io) ~= "table" or not CONFIG_PATH then return nil end
    local f = io.open(CONFIG_PATH, "rb")
    if not f then return nil end
    local raw = f:read("*a")
    f:close()
    return raw
end

loadCfg()
BS.raw = readRaw()      -- baseline, so the watcher does not fire on the first poll

-- Watch config.lua and reload when it changes on disk: just save the file, no
-- F7 needed. Plain file I/O touches no UObject, so doing it on the game thread
-- is safe; every 3rd tick (~1.8s) is plenty and keeps it off the hot path.
-- A half-written file fails to parse, so the previous config is kept and the
-- next poll picks up the finished one.
local WATCH_EVERY = 3
local function watchConfig()
    if type(io) ~= "table" then return end
    BS.wn = (BS.wn or 0) + 1
    if BS.wn % WATCH_EVERY ~= 0 then return end
    local raw = readRaw()
    if type(raw) ~= "string" or raw == BS.raw or raw == BS.rawBad then return end
    if loadCfg(true) then
        BS.raw, BS.rawBad = raw, nil
        BS.applied = {}
        BS.force = true
        log("config.lua changed on disk -> reloaded")
    else
        -- complain once per broken version, then stay quiet until it is fixed
        BS.rawBad = raw
        log("!! config.lua changed but has a syntax error -- keeping the previous one")
    end
end

local EXCLUDE = { Root = true, DefaultSceneRoot = true }   -- scaling the root would double it

local function xyz(v, d)
    if v == nil then return nil end
    local x = safe(function() return v.X end)
    if type(x) ~= "number" then return nil end
    return { X = x, Y = safe(function() return v.Y end, d), Z = safe(function() return v.Z end, d) }
end

-- The mold's components are NOT in BlueprintCreatedComponents -- that one is
-- per-instance, filled during construction, and comes back empty on the CDO.
-- They live in SimpleConstructionScript, one ComponentTemplate per node: the
-- very same "<Name>_GEN_VARIABLE" objects PalSchema patches. Walk the parent
-- classes too, otherwise inherited components are missed.
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

-- PROPORTIONAL scale: size + part positions + footprint by the same factor.
-- That is what keeps a shrunk structure looking like itself. Originals are
-- cached per class+component, otherwise changing the number in the config
-- would multiply on top of the already scaled value.
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

-- Log on state CHANGE, never on a periodic pulse: alt-tabbing out of the game
-- does not leave build mode, so a couple of seconds in there has to be enough
-- to leave a trace in the log.
local function state(s)
    if BS.state ~= s then BS.state = s; log("[state] " .. s) end
end

local function tick()
    watchConfig()
    if BS.force then BS.force = false; BS.state = nil end
    local ic = FindFirstOf("PalBuildObjectInstallChecker")
    if not alive(ic) then state("not in build mode") return end
    -- only valid with the ghost actually placed on valid ground; with the build
    -- wheel merely open and nothing aimed at, this comes back invalid
    local t = safe(function() return ic.TargetBuildObject end)
    if not alive(t) then state("build mode on, no ghost placed") return end
    local cls = safe(function() return t:GetClass() end)
    if not alive(cls) then state("ghost ok, no class") return end
    local cname = nameOf(cls)
    if not cname then state("ghost ok, class name unreadable") return end
    state("ghost = " .. cname)

    local e = (_G.__BS_idx or {})[cname]
    if not e or not e.enabled then return end
    local scale = tonumber(e.size) or 1.0
    local key = cname .. "=" .. scale
    if BS.applied and BS.applied[key] then return end
    BS.applied = BS.applied or {}
    BS.applied[key] = true

    local n, total = applyMold(cls, cname, scale)
    if total == 0 then
        log("[" .. (e.name or cname) .. "] !! no components in SimpleConstructionScript")
    else
        log("[" .. (e.name or cname) .. "] mold " .. string.format("%.2f", scale)
            .. "x -> " .. n .. "/" .. total .. " comps. RE-SELECT the structure.")
    end
end

-- Global on purpose: a reload redefines it, and the loop always calls the
-- current version. The wrapper logs tick errors -- the loop's own pcall used to
-- swallow them silently, which cost an hour of chasing a loop that was fine.
_G.__BS_tick = function()
    local ok, err = pcall(tick)
    if not ok then
        local e = tostring(err)
        if e ~= BS.lasterr then BS.lasterr = e; log("!! tick error: " .. e) end
    end
end

-- F7 is now just a manual nudge -- saving config.lua already reloads it. Kept
-- because it also re-runs dofile on this file, which is how code edits land.
-- The key handler does NOT touch the game thread; it only raises a flag, and
-- the loop -- which already runs on the game thread -- does the work.
-- (Calling ExecuteInGameThread from a key callback while a
--  LoopInGameThreadWithDelay is active KILLS the UE4SS game-thread queue: loop
--  and queue die together and only come back on a game restart.)
-- No loadCfg here: the shell already re-ran dofile on this file, which runs the
-- loadCfg at the top -- calling it again just duplicated the log line.
_G.__BS_reload = function()
    BS.applied = {}
    BS.force = true
    log("config reloaded -> applying on next tick")
end

-- Literal AutoHatchLua pattern, the only scheduling that provably runs in this
-- build. Returning false from the LoopInGameThreadWithDelay callback KILLS the
-- loop -- AutoHatchLua returns nothing, and it has been running for months.
local function everyMsInGameThread(ms, fn)
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, handle = pcall(LoopInGameThreadWithDelay, ms, fn)
        if ok then log("tick: LoopInGameThreadWithDelay(" .. ms .. "ms) handle=" .. tostring(handle)); return true end
        log("LoopInGameThreadWithDelay unavailable (" .. tostring(handle) .. ") - falling back")
    end
    if type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
        LoopAsync(ms, function()
            ExecuteInGameThread(fn)      -- only ever push work to the game thread
            return false                 -- here `false` IS correct: it keeps the clock running
        end)
        log("tick: LoopAsync(" .. ms .. "ms) + ExecuteInGameThread (fallback)")
        return true
    end
    log("!! no game-thread API in this build - tick NOT scheduled")
    return false
end

if not BS.loop then
    BS.loop = true
    everyMsInGameThread(600, function()
        if _G.__BS_tick then pcall(_G.__BS_tick) end
    end)
end

log((type(io) == "table")
    and "ready. Save config.lua and it reloads by itself -- then aim in build mode and re-select."
    or  "ready. NOTE: no io library in this build, config auto-reload is off -- use F7.")
