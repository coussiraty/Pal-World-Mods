-- =====================================================================
--  MiniBuilds / BuildSizes -- shell. Loads logic.lua and registers the key.
--  Editing this file (or the keybind) needs a game restart; logic.lua is the
--  part that hot-reloads, and config.lua reloads on save all by itself.
-- =====================================================================
local MOD = "BuildSizes"
local function log(s) print("[" .. MOD .. "] " .. tostring(s) .. "\n") end

-- Derive our own folder instead of hardcoding a path -- an absolute path works
-- on the author's machine and silently fails on every other install.
local LOGIC
do
    local src = debug.getinfo(1, "S").source
    local dir = type(src) == "string" and src:sub(2):match("^(.*)[/\\][^/\\]*$")
    LOGIC = dir and (dir .. "\\logic.lua")
end

local function loadLogic()
    if not LOGIC then log("LOAD FAILED: could not resolve the Scripts folder"); return end
    local ok, err = pcall(dofile, LOGIC)
    if ok then log("logic (re)loaded") else log("LOAD FAILED: " .. tostring(err)) end
end
loadLogic()

-- F7 (no modifier): free, and it does not collide with build mode.
-- (Ctrl+Shift+B was no good: the game uses B to go back / cancel while building.)
-- Saving config.lua already reloads it; F7 is the manual nudge, and the only way
-- to pick up edits to logic.lua itself.
if not _G.__BS_keys then
    _G.__BS_keys = true
    local ok, err = pcall(function()
        RegisterKeyBind(Key.F7, function()
            log("F7 -> reload")
            loadLogic()
            if _G.__BS_reload then _G.__BS_reload() end
        end)
    end)
    log(ok and "key F7 registered" or ("key FAILED: " .. tostring(err)))
end
