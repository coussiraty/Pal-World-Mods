-- =====================================================================
--  EarlyUnlock / logic.lua
--  Forca o unlock das tecnologias que a gente quer cedo, usando o
--  UPalCheatManager:UnlockOneTechnology(FName) -- que ignora nivel,
--  pontos de tecnologia, pre-requisitos e requisito de chefe.
--  Assim a arvore de tech fica NORMAL (sem 124 selas amontoadas no nv1),
--  mas tudo ja vem destravado/craftavel desde o inicio.
--
--  ATALHO: Ctrl+Shift+T = destrava tudo agora (manual)
--  Tambem roda sozinho ~5s depois de entrar no mundo.
-- =====================================================================
local M = { VERSION = "v1.0" }

local function log(s) print("[EarlyUnlock] " .. tostring(s) .. "\n") end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

-- ---------- lista de tecnologias a destravar ----------
-- 3 construcoes (cedo) + TODAS as selas/arreios (SkillUnlock_*)
local TECHS = {
    "Special_HatchingPalEgg", "Expedition", "BreedFarm",
    "SkillUnlock_Boar", "SkillUnlock_Kitsunebi", "SkillUnlock_Alpaca", "SkillUnlock_Garm",
    "SkillUnlock_WeaselDragon", "SkillUnlock_Carbunclo", "SkillUnlock_Monkey", "SkillUnlock_Deer",
    "SkillUnlock_Monkey_Fire", "SkillUnlock_Kirin", "SkillUnlock_FlameBuffalo", "SkillUnlock_HawkBird",
    "SkillUnlock_Serpent", "SkillUnlock_Penguin", "SkillUnlock_ColorfulBird", "SkillUnlock_Penguin_Electric",
    "SkillUnlock_NaughtyCat", "SkillUnlock_FairyDragon", "SkillUnlock_PurpleSpider", "SkillUnlock_MopKing",
    "SkillUnlock_BirdDragon", "SkillUnlock_Deer_Ground", "SkillUnlock_BirdDragon_Ice", "SkillUnlock_KingAlpaca",
    "SkillUnlock_Kitsunebi_Ice", "SkillUnlock_BlueDragon", "SkillUnlock_FlowerDinosaur", "SkillUnlock_Serpent_Ground",
    "SkillUnlock_HadesBird", "SkillUnlock_FengyunDeeper", "SkillUnlock_IceSeal", "SkillUnlock_BlueDragon_Ice",
    "SkillUnlock_FeatherOstrich", "SkillUnlock_GrassMammoth", "SkillUnlock_FireKirin", "SkillUnlock_ThunderBird",
    "SkillUnlock_ThunderDog", "SkillUnlock_GhostAnglerfish", "SkillUnlock_IceDeer", "SkillUnlock_FairyDragon_Water",
    "SkillUnlock_GrassPanda", "SkillUnlock_Manticore", "SkillUnlock_RedArmorBird", "SkillUnlock_SakuraSaurus",
    "SkillUnlock_FireKirin_Dark", "SkillUnlock_GrassPanda_Electric", "SkillUnlock_FlowerDinosaur_Electric",
    "SkillUnlock_Manticore_Dark", "SkillUnlock_TropicalOstrich", "SkillUnlock_Plesiosaur", "SkillUnlock_GhostBeast",
    "SkillUnlock_SkyDragon", "SkillUnlock_BlackMetalDragon", "SkillUnlock_MushroomDragon", "SkillUnlock_MushroomDragon_Dark",
    "SkillUnlock_Umihebi", "SkillUnlock_ElecPanda", "SkillUnlock_WeaselDragon_Fire", "SkillUnlock_WhiteAlienDragon",
    "SkillUnlock_GuardianDog", "SkillUnlock_GrassMammoth_Ice", "SkillUnlock_IceNarwhal", "SkillUnlock_GhostAnglerfish_Fire",
    "SkillUnlock_VolcanicMonster", "SkillUnlock_Suzaku", "SkillUnlock_VolcanicMonster_Ice", "SkillUnlock_Suzaku_Water",
    "SkillUnlock_SakuraSaurus_Water", "SkillUnlock_SkyDragon_Grass", "SkillUnlock_LazyDragon", "SkillUnlock_Yeti",
    "SkillUnlock_KingBahamut", "SkillUnlock_KingAlpaca_Ice", "SkillUnlock_HadesBird_Electric", "SkillUnlock_BlackGriffon",
    "SkillUnlock_LazyDragon_Electric", "SkillUnlock_GrassGolem", "SkillUnlock_Yeti_Grass", "SkillUnlock_BadCatgirl",
    "SkillUnlock_MoonQueen", "SkillUnlock_GoldenHorse", "SkillUnlock_WhiteDeer", "SkillUnlock_IceSeal_Ground",
    "SkillUnlock_KingBahamut_Dragon", "SkillUnlock_NightBlueHorse", "SkillUnlock_FengyunDeeper_Electric",
    "SkillUnlock_AmaterasuWolf", "SkillUnlock_BlackPuppy", "SkillUnlock_BlueThunderHorse", "SkillUnlock_Umihebi_Fire",
    "SkillUnlock_AmaterasuWolf_Dark", "SkillUnlock_Horus", "SkillUnlock_Horus_Water", "SkillUnlock_WhiteShieldDragon",
    "SkillUnlock_SaintCentaur", "SkillUnlock_BlackCentaur", "SkillUnlock_IceHorse", "SkillUnlock_IceHorse_Dark",
    "SkillUnlock_Kirin_Ice", "SkillUnlock_PoseidonOrca", "SkillUnlock_KingSunfish", "SkillUnlock_KingSunfish_Thunder",
    "SkillUnlock_ThunderFluffyBird", "SkillUnlock_DarkMechaDragon", "SkillUnlock_GhostDragon", "SkillUnlock_GrassGolem_Dark",
    "SkillUnlock_LegendDeer", "SkillUnlock_ThunderBird_Ice", "SkillUnlock_IceNarwhal_Fire", "SkillUnlock_SnowTigerBeastman",
    "SkillUnlock_GhostDragon_Fire", "SkillUnlock_NightBlueHorse_Neutral", "SkillUnlock_WhiteDeer_Dark",
    "SkillUnlock_DomeArmorDragon", "SkillUnlock_JetDragon", "SkillUnlock_CubeTurtle", "SkillUnlock_CubeTurtle_Neutral",
    "SkillUnlock_VolcanoDragon", "SkillUnlock_VolcanoDragon_Ice", "SkillUnlock_Thunderdog_Ice", "SkillUnlock_SumoDog",
    "SkillUnlock_ThiefBird", "SkillUnlock_BlueSkyDragon", "SkillUnlock_LotusDragon",
}
M.TECHS = TECHS

-- ---------- pega (ou constroi) um PalCheatManager de verdade ----------
-- O CheatManagerEnablerMod as vezes cria so um UCheatManager base (sem as
-- funcoes do Pal). Por isso a gente garante um UPalCheatManager.
local function getPalCheatManager()
    local c = _G.__EarlyUnlock_cm
    if isok(c) then return c end

    -- ja existe um PalCheatManager? (se sim, e o tipo certo)
    local found = FindFirstOf("PalCheatManager")
    if isok(found) then _G.__EarlyUnlock_cm = found; return found end

    -- senao, constroi um no player controller
    local pc = FindFirstOf("PalPlayerController")
    if not isok(pc) then return nil end
    local cls = StaticFindObject("/Script/Pal.PalCheatManager")
    if not isok(cls) then return nil end
    local cm = safe(function() return StaticConstructObject(cls, pc) end, nil)
    if isok(cm) then
        safe(function() pc.CheatManager = cm end)
        _G.__EarlyUnlock_cm = cm
        return cm
    end
    return nil
end

-- ---------- destrava tudo ----------
local function unlockAll()
    local cm = getPalCheatManager()
    if not isok(cm) then
        log("CheatManager indisponivel — entra num mundo e usa Ctrl+Shift+T")
        return 0
    end
    local n = 0
    for _, name in ipairs(TECHS) do
        if pcall(function() cm:UnlockOneTechnology(FName(name)) end) then n = n + 1 end
    end
    log(string.format("destravadas %d/%d tecnologias (selas + construcoes)", n, #TECHS))
    return n
end
M.unlockAll = unlockAll

-- ---------- sonda: dumpa os row names das DataTables de receita ----------
-- Metodo confiavel: StaticFindObject na DataTable + GetRowNames() (retorna
-- TArray<FName>, que o UE4SS le direto). O metodo antigo via
-- GetRecipeTechlonogy vinha vazio (struct-por-valor com TArray aninhado).
local BUILD_DT = "/Game/Pal/DataTable/MapObject/Building/DT_BuildObjectDataTable_Common.DT_BuildObjectDataTable_Common"
local ITEM_DT  = "/Game/Pal/DataTable/Item/DT_ItemRecipeDataTable_Common.DT_ItemRecipeDataTable_Common"

local function fnameStr(v)
    return safe(function() return v:ToString() end, safe(function() return tostring(v) end, "?"))
end

local function dumpTable(f, label, path)
    local dt = safe(function() return StaticFindObject(path) end, nil)
    if not isok(dt) then f:write("### " .. label .. ": NAO ACHOU (" .. path .. ")\n\n"); return 0 end
    local rows = safe(function() return dt:GetRowNames() end, nil)
    f:write("### " .. label .. " (type=" .. type(rows) .. ") ###\n")
    local c = 0
    if rows ~= nil then
        -- metodo 1: ForEach (TArray-objeto do UE4SS)
        pcall(function()
            rows:ForEach(function(_, elem)
                local v = safe(function() return elem:get() end, elem)
                f:write(fnameStr(v) .. "\n"); c = c + 1
            end)
        end)
        -- metodo 2: tabela Lua indexavel (#/[])
        if c == 0 then pcall(function()
            for i = 1, (safe(function() return #rows end, 0)) do
                f:write(fnameStr(rows[i]) .. "\n"); c = c + 1
            end
        end) end
        -- metodo 3: GetArrayNum + index
        if c == 0 then pcall(function()
            for i = 1, rows:GetArrayNum() do
                f:write(fnameStr(rows[i]) .. "\n"); c = c + 1
            end
        end) end
    end
    f:write("### fim " .. label .. " (" .. c .. " rows) ###\n\n")
    return c
end

local function dumpRecipes()
    local path = "C:/Program Files (x86)/Steam/steamapps/common/Palworld/Pal/Binaries/Win64/ue4ss/Mods/EarlyUnlock/dump_recipes.txt"
    local f = safe(function() return io.open(path, "w") end, nil)
    if not f then log("nao consegui abrir dump_recipes.txt"); return end
    local b = dumpTable(f, "BuildObject", BUILD_DT)
    local i = dumpTable(f, "ItemRecipe", ITEM_DT)
    f:close()
    log(string.format("dump_recipes.txt escrito: %d build + %d item rows.", b, i))
end
M.dumpRecipes = dumpRecipes

-- ---------- auto no load (1x por sessao, com algumas tentativas) ----------
local function autoTry(tries)
    tries = tries or 0
    local n = unlockAll()
    if n == 0 and tries < 4 then
        ExecuteWithDelay(5000, function() autoTry(tries + 1) end)
    end
end

if not _G.__EarlyUnlock_hooked then
    _G.__EarlyUnlock_hooked = true

    -- roda sozinho pouco depois de entrar no mundo
    pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
            if _G.__EarlyUnlock_autoRan then return end
            _G.__EarlyUnlock_autoRan = true
            ExecuteWithDelay(5000, function() autoTry(0) end)
        end)
    end)

    -- atalho manual: Ctrl+Shift+T
    pcall(function()
        RegisterKeyBind(Key.T, { ModifierKey.CONTROL, ModifierKey.SHIFT }, function()
            log("Ctrl+Shift+T -> destravando...")
            unlockAll()
        end)
    end)

    -- sonda de recipes: Ctrl+Shift+R
    pcall(function()
        RegisterKeyBind(Key.R, { ModifierKey.CONTROL, ModifierKey.SHIFT }, function()
            log("Ctrl+Shift+R -> dumpando recipes...")
            dumpRecipes()
        end)
    end)

    log("pronto (" .. M.VERSION .. "). Auto no load + Ctrl+Shift+T (unlock) + Ctrl+Shift+R (dump recipes). " .. #TECHS .. " techs.")
end

return M
