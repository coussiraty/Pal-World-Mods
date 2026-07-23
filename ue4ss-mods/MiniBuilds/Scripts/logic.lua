-- =====================================================================
--  MiniBuilds / logic.lua -- scales any build object through config.lua
--
--  Two things have to happen for a size to actually be right:
--    1. the class MOLD is scaled, so everything spawned from then on is right
--    2. whatever is ALREADY alive is scaled too -- the buildings standing in
--       your base, and the ghost you are holding at that moment
--
--  Work is driven by the spawn hook (main.lua -> _G.__MB_onNew), never polled.
--  Polling cost real hitching: a class lookup that misses runs ~10ms, and the
--  FindFirstOf that detected build mode ran ~10ms on its own, every tick. The
--  hook fires exactly when a build object appears, which is also the only
--  moment its class is guaranteed to be loaded.
--
--  Reloaded by F7. config.lua reloads on save all by itself.
-- =====================================================================
local function log(s) print("[MiniBuilds] " .. tostring(s) .. "\n") end
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
local CONFIG_PATH
do
    local src = debug.getinfo(1, "S").source
    local scripts = type(src) == "string" and src:sub(2):match("^(.*)[/\\][^/\\]*$")
    local dir = scripts and scripts:match("^(.*)[/\\][^/\\]*$")
    CONFIG_PATH = dir and (dir .. "\\config.lua")
end
if not CONFIG_PATH then log("!! could not resolve the mod folder -- config will not load") end

local MB = _G.__MB or { orig = {} }; _G.__MB = MB
MB.molded = MB.molded or {}
MB.skip = MB.skip or {}

-- ~500 entries: index by class so the hook does a lookup, not a walk.
local function loadCfg(quiet)
    if not CONFIG_PATH then return false end
    local ok, cfg = pcall(dofile, CONFIG_PATH)
    if not ok or type(cfg) ~= "table" then
        if not quiet then log("!! could not read config.lua: " .. tostring(cfg)) end
        return false
    end
    local idx, on = {}, 0
    for _, e in ipairs(cfg) do
        if type(e) == "table" and type(e.class) == "string" then
            idx[e.class] = e
            if e.enabled then on = on + 1 end
        end
    end
    _G.__MB_idx = idx
    MB.skip = {}                       -- classes ruled out under the previous config
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
MB.raw = readRaw()                     -- baseline, so the watcher does not fire at once

local EXCLUDE = { Root = true, DefaultSceneRoot = true }   -- scaling the root doubles it

local function xyz(v, d)
    if v == nil then return nil end
    local x = safe(function() return v.X end)
    if type(x) ~= "number" then return nil end
    return { X = x, Y = safe(function() return v.Y end, d), Z = safe(function() return v.Z end, d) }
end

-- ---------------------------------------------------------------- the mold --
-- The mold's components are NOT in BlueprintCreatedComponents -- that is
-- per-instance, filled during construction, and empty on the CDO. They live in
-- SimpleConstructionScript, one ComponentTemplate per node: the same
-- "<Name>_GEN_VARIABLE" objects PalSchema patches. Parent classes too, or
-- inherited components are missed.
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

-- Remember a component's untouched values the first time it is seen. Everything
-- after that is computed from these, so changing the number in the config never
-- multiplies on top of an already scaled value.
local function baseline(cache, nm, c)
    local o = cache[nm]
    if o then return o end
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
    return o
end

-- PROPORTIONAL: size + part positions + footprint by the same factor. That is
-- what keeps a shrunk building looking like itself instead of a pile of parts.
local function scaleComponent(c, o, scale)
    pcall(function() c.RelativeScale3D = { X = o.scl.X * scale, Y = o.scl.Y * scale, Z = o.scl.Z * scale } end)
    if o.loc then pcall(function() c.RelativeLocation = { X = o.loc.X * scale, Y = o.loc.Y * scale, Z = o.loc.Z * scale } end) end
    if o.box then pcall(function() c.BoxExtent = { X = o.box.X * scale, Y = o.box.Y * scale, Z = o.box.Z * scale } end) end
    if o.sph then pcall(function() c.SphereRadius = o.sph * scale end) end
    if o.cr  then pcall(function() c.CapsuleRadius = o.cr * scale end) end
    if o.ch  then pcall(function() c.CapsuleHalfHeight = o.ch * scale end) end
end

local function applyMold(cls, cname, scale)
    local comps = moldComponents(cls)
    if #comps == 0 then return 0, 0 end
    local cache = MB.orig[cname] or {}; MB.orig[cname] = cache
    local n = 0
    for _, c in ipairs(comps) do
        local nm = (nameOf(c) or ""):gsub("_GEN_VARIABLE", "")
        if nm ~= "" and not EXCLUDE[nm] then
            scaleComponent(c, baseline(cache, nm, c), scale)
            n = n + 1
        end
    end
    return n, #comps
end

-- --------------------------------------------------------- what is alive ----
-- Writing RelativeScale3D straight onto a LIVE component changes the number and
-- nothing else: Unreal caches the world transform and only recomputes it when a
-- setter runs. That is why the log once said "resized" while the building on
-- screen stayed huge. On the mold it works, because nothing is live there yet.
--
-- For something already standing, scaling the ACTOR is the right tool: one call,
-- and meshes, child positions and collision all scale together.
--
-- Telling "already standing" from "spawned correct" cannot be done by reading
-- values -- an earlier version of this mod wrote scaled numbers onto live
-- components, so the numbers lie. Use the fact instead: at the instant the mold
-- is patched, everything of that class alive right then predates it. Anything
-- appearing later comes out of the fixed mold and must not be touched.
local function resetComps(a, cname)
    local cache = MB.orig[cname]
    if not cache then return end
    local bcc = safe(function() return a.BlueprintCreatedComponents end)
    local bn = safe(function() return bcc:GetArrayNum() end, safe(function() return #bcc end, 0))
    for i = 1, bn do
        local c = safe(function() return bcc[i] end)
        if alive(c) then
            local o = cache[nameOf(c) or ""]
            if o then                      -- put the untouched values back, so the
                scaleComponent(c, o, 1.0)  -- actor scale is the only factor at play
            end
        end
    end
end

local function rescaleExisting(a, cname, scale)
    resetComps(a, cname)
    return pcall(function() a:SetActorScale3D({ X = scale, Y = scale, Z = scale }) end)
end

-- One pass over every build object in the world. FindAllOf on the NATIVE base
-- class is what actually returns the buildings -- asking for the blueprint class
-- by name came back with a single object and fixed nothing at all.
-- Expensive, so it only runs when the hook says something appeared.
local function sweep()
    local all = FindAllOf("PalBuildObject")
    local total = (type(all) == "table") and #all or 0
    if total == 0 then return end

    local idx = _G.__MB_idx or {}
    local byClass = {}
    for i = 1, total do
        local a = all[i]
        if alive(a) then
            local cls = safe(function() return a:GetClass() end)
            local cname = cls and nameOf(cls)
            if cname and idx[cname] and idx[cname].enabled then
                local g = byClass[cname]
                if not g then g = { cls = cls, actors = {} }; byClass[cname] = g end
                g.actors[#g.actors + 1] = a
            end
        end
    end

    for cname, g in pairs(byClass) do
        local e = idx[cname]
        local scale = tonumber(e.size) or 1.0
        local key = cname .. "=" .. scale
        if not MB.molded[key] then
            MB.molded[key] = true
            local n, t = applyMold(g.cls, cname, scale)
            local fixed = 0
            for _, a in ipairs(g.actors) do
                if rescaleExisting(a, cname, scale) then fixed = fixed + 1 end
            end
            log("[" .. (e.name or cname) .. "] " .. string.format("%.2f", scale)
                .. "x -> mold " .. n .. "/" .. t .. " comps, "
                .. fixed .. " already standing rescaled")
        end
    end
end

-- ------------------------------------------------------------- the driver ---
-- Called from the spawn hook, inside construction: does the least possible.
_G.__MB_onNew = function(obj)
    local idx = _G.__MB_idx
    if not idx then return end
    local cls = safe(function() return obj:GetClass() end)
    if not cls then return end
    local cname = nameOf(cls)
    if not cname or MB.skip[cname] then return end
    local e = idx[cname]
    if not e or not e.enabled then
        MB.skip[cname] = true          -- not ours: never inspect this class again
        return
    end
    MB.dirty = true                    -- the next tick sweeps
end

-- Watch config.lua and reload it when it changes on disk: saving is enough, no
-- key needed. Plain file I/O touches no UObject, so the game thread is fine --
-- it measured at 0ms. A half-written file fails to parse, so the previous
-- config stays up and the next poll picks up the finished one.
local WATCH_EVERY = 8                  -- ~5s
local function watchConfig()
    if type(io) ~= "table" then return end
    MB.wn = (MB.wn or 0) + 1
    if MB.wn % WATCH_EVERY ~= 0 then return end
    local raw = readRaw()
    if type(raw) ~= "string" or raw == MB.raw or raw == MB.rawBad then return end
    if loadCfg(true) then
        MB.raw, MB.rawBad = raw, nil
        MB.molded = {}                 -- re-mold with the new numbers
        MB.dirty = true
        log("config.lua changed on disk -> reloaded")
    else
        MB.rawBad = raw                -- complain once per broken version
        log("!! config.lua changed but has a syntax error -- keeping the previous one")
    end
end

MB.dirty = true                        -- first tick catches whatever already exists

local function tick()
    watchConfig()
    if not MB.dirty then return end    -- idle ticks cost nothing at all
    MB.dirty = false
    sweep()
end

-- Global on purpose: a reload redefines it and the loop always calls the current
-- version. The wrapper logs tick errors -- the loop's own pcall swallowed them
-- silently once, which cost an hour of chasing a loop that was fine.
_G.__MB_tick = function()
    local ok, err = pcall(tick)
    if not ok then
        local e = tostring(err)
        if e ~= MB.lasterr then MB.lasterr = e; log("!! tick error: " .. e) end
    end
end

-- F7: force a reload. Saving config.lua already does this by itself; F7 is also
-- the only way to pick up edits to this file.
-- It must NOT touch the game thread: calling ExecuteInGameThread from a key
-- callback while LoopInGameThreadWithDelay is active kills the UE4SS
-- game-thread queue, and both stay dead until the game restarts. So: flags only.
_G.__MB_reload = function()
    MB.molded = {}
    MB.skip = {}
    MB.dirty = true
    log("reload requested -> sweeping on next tick")
end

-- Literal AutoHatchLua pattern, the only scheduling that provably runs in this
-- build. Returning false from a LoopInGameThreadWithDelay callback KILLS the
-- loop -- AutoHatchLua returns nothing, and it has run for months.
local function everyMsInGameThread(ms, fn)
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, handle = pcall(LoopInGameThreadWithDelay, ms, fn)
        if ok then log("tick: LoopInGameThreadWithDelay(" .. ms .. "ms) handle=" .. tostring(handle)); return true end
        log("LoopInGameThreadWithDelay unavailable (" .. tostring(handle) .. ") - falling back")
    end
    if type(LoopAsync) == "function" and type(ExecuteInGameThread) == "function" then
        LoopAsync(ms, function()
            ExecuteInGameThread(fn)    -- only ever push work to the game thread
            return false               -- here `false` IS correct: keeps the clock running
        end)
        log("tick: LoopAsync(" .. ms .. "ms) + ExecuteInGameThread (fallback)")
        return true
    end
    log("!! no game-thread API in this build - tick NOT scheduled")
    return false
end

if not MB.loop then
    MB.loop = true
    everyMsInGameThread(600, function()
        if _G.__MB_tick then pcall(_G.__MB_tick) end
    end)
end

log("ready -- sizes apply as buildings appear; save config.lua to change them.")
