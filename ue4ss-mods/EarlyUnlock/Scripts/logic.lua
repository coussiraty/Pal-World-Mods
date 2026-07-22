-- =====================================================================
--  EarlyUnlock / logic.lua
--  Forca o unlock das tecnologias/selas cedo chamando a funcao NATIVA
--  UPalTechnologyData:RequestUnlockRecipeTechnology(FName) num objeto vivo
--  (a mesma que a UI da arvore de tech chama). Ignora nivel/pontos/pre-req
--  e NAO re-cobra custo. Rodar na GAME THREAD, depois do mundo carregar,
--  com autoridade (single-player ou host). A arvore fica NORMAL e as techs
--  aparecem destravadas nas posicoes vanilla + craftaveis.
--
--  (O antigo UPalCheatManager:UnlockOneTechnology e um STUB vazio no build
--   de shipping -- retorna sem fazer nada. Comprovado via RE.)
--
--  ATALHO: Ctrl+Shift+T = destrava tudo agora (manual)
--  Tambem roda sozinho depois de entrar no mundo.
-- =====================================================================
local M = { VERSION = "v1.0" }

local LOG = false   -- true = escreve status no UE4SS.log (debug)
local function log(s) if LOG then print("[EarlyUnlock] " .. tostring(s) .. "\n") end end
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

-- ---------- destrava tudo (na GAME THREAD!) ----------
-- Chama a funcao nativa RequestUnlockRecipeTechnology(FName) no
-- UPalTechnologyData vivo (FindFirstOf ja pula o CDO). Retorna a qtd
-- destravada, ou -1 se o objeto ainda nao existe (mundo nao carregou)
-- pra gente tentar de novo depois.
local function unlockAllNow()
    local td = FindFirstOf("PalTechnologyData")
    if not isok(td) then return -1 end
    local n = 0
    for _, name in ipairs(TECHS) do
        if pcall(function() td:RequestUnlockRecipeTechnology(FName(name)) end) then n = n + 1 end
    end
    log(string.format("destravadas %d/%d techs (RequestUnlockRecipeTechnology)", n, #TECHS))
    return n
end
M.unlockAll = unlockAllNow

-- marshaling pra game thread (pode ser chamado de qualquer thread com seguranca)
local function unlockAllSafe()
    ExecuteInGameThread(function() unlockAllNow() end)
end
M.unlockAllSafe = unlockAllSafe

-- ---------- auto no load (1x por sessao, com algumas tentativas) ----------
local function autoTry(tries)
    tries = tries or 0
    ExecuteInGameThread(function()
        local n = unlockAllNow()
        -- n == -1 => PalTechnologyData ainda nao existe: tenta de novo
        if n < 0 and tries < 12 then
            ExecuteWithDelay(3000, function() autoTry(tries + 1) end)
        end
    end)
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
            unlockAllSafe()
        end)
    end)

    log("pronto (" .. M.VERSION .. "). Auto no load + Ctrl+Shift+T (unlock). " .. #TECHS .. " techs.")
end

return M
