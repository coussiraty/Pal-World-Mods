-- =====================================================================
--  EarlyUnlock / logic.lua  (v1.1 - destrava TUDO, de graca)
--  Destrava TODAS as selas/arreios de pal + 3 construcoes cedo, de GRACA:
--  escreve o nome direto na lista UnlockedTechnologyNameArray do
--  UPalTechnologyData (craftabilidade = Contains nessa lista), SEM passar pelo
--  RequestUnlockRecipeTechnology (que COBRA ponto de tecnologia). Depois chama
--  OnRep na mao pra refrescar. Dedupe pela funcao do jogo (IsUnlockRecipeTechnology)
--  pra nao inchar o array.
--
--  O jogo mostra a sela de pal que voce nao tem como "Unknown Item" e revela
--  quando voce pega o pal -- entao destravar tudo fica limpo.
--  Roda sozinho no load (sem apertar nada). Ctrl+Shift+T = re-destravar manual.
-- =====================================================================
local M = { VERSION = "v1.1" }

local LOG = false   -- true = escreve status no UE4SS.log (debug); false no release
local function log(s) if LOG then print("[EarlyUnlock] " .. tostring(s) .. "\n") end end
local function safe(fn, d) local ok, v = pcall(fn); if ok and v ~= nil then return v end return d end
local function isok(o) return o ~= nil and safe(function() return o:IsValid() end, false) end

-- tudo que destrava: 3 construcoes cedo + TODAS as selas (SkillUnlock_*)
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

-- ---------- destrava UMA tech: append direto (GRATIS), deduped ----------
local function unlockTech(td, arr, name)
    if safe(function() return td:IsUnlockRecipeTechnology(FName(name)) end, false) == true then return false end
    local cnt = safe(function() return arr:GetArrayNum() end, safe(function() return #arr end, 0))
    return pcall(function() arr[cnt + 1] = FName(name) end) == true
end

-- ---------- destrava tudo (NA GAME THREAD) ----------
-- retorna qtd nova destravada, ou -1 se PalTechnologyData nao existe ainda.
local function unlockAll()
    local td = FindFirstOf("PalTechnologyData")
    if not isok(td) then return -1 end
    local arr = safe(function() return td.UnlockedTechnologyNameArray end)
    if not arr then return -1 end
    local n = 0
    for _, name in ipairs(TECHS) do if unlockTech(td, arr, name) then n = n + 1 end end
    if n > 0 then pcall(function() td:OnRep_UnlockedTechnologyNameArray() end) end   -- refresh
    log(string.format("unlock: +%d tech(s) nova(s) destravada(s) (sem gastar ponto)", n))
    return n
end
M.unlock = unlockAll

local function unlockSafe() ExecuteInGameThread(function() unlockAll() end) end
M.unlockSafe = unlockSafe

-- ---------- auto no load (retry ate PalTechnologyData existir) ----------
local function autoTry(tries)
    tries = tries or 0
    ExecuteInGameThread(function()
        if unlockAll() < 0 and tries < 12 then
            ExecuteWithDelay(3000, function() autoTry(tries + 1) end)
        end
    end)
end

if not _G.__EarlyUnlock_hooked then
    _G.__EarlyUnlock_hooked = true

    -- roda sozinho ao entrar no mundo (sem apertar nada)
    pcall(function()
        RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
            if _G.__EarlyUnlock_autoRan then return end
            _G.__EarlyUnlock_autoRan = true
            ExecuteWithDelay(5000, function() autoTry(0) end)
        end)
    end)

    -- Ctrl+Shift+T: re-destravar manual (opcional)
    pcall(function()
        RegisterKeyBind(Key.T, { ModifierKey.CONTROL, ModifierKey.SHIFT }, function()
            log("Ctrl+Shift+T -> destravando tudo...")
            unlockSafe()
        end)
    end)

    log("pronto (" .. M.VERSION .. "). Destrava tudo sozinho no load. " .. #TECHS .. " techs.")
end

return M
