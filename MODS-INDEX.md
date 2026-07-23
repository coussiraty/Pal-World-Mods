# Índice dos mods — efeito → mod → arquivo

Princípio: **1 efeito = 1 mod**. Quando dois efeitos são obrigados a dividir o mesmo
blueprint (o PalSchema só deixa 1 arquivo editar cada BP — ver nota no fim), um deles é
feito em **Lua** (runtime) pra manter a separação.

## Progressão / desbloqueio

| Efeito | Mod | Tipo | Arquivo-chave |
|---|---|---|---|
| Destrava **todas as selas/arreios** de pal (+ auto-destrava as 3 construções abaixo) | `EarlyUnlock` | Lua | `Scripts/logic.lua` |
| Incubadora/Expedição/Fazenda **aparecem cedo na árvore** (nível 1, custo 0) + material barato | `EarlyBuildings` | PalSchema | `raw/tech.json`, `raw/build.json` |

## Base / QoL

| Efeito | Mod | Tipo | Arquivo-chave |
|---|---|---|---|
| **Condensador** pede metade dos pals (`{1:2, 2:4, 3:6, 4:12}`, vanilla `4/8/12/24`) | `HalfCondenser` | Lua | `Scripts/logic.lua` |
| **Sanidade** não cai (fome/fadiga/dano = 0) | `NoSanityLoss` | PalSchema | `blueprints/sanity.json` |
| **Fazenda de reprodução** em 30s | `FastBreeding` | Lua | `Scripts/logic.lua` |
| Construções **menores** (fazenda / expedição / rancho) | `MiniBuilds` | PalSchema | `blueprints/*.json` |
| **Rancho** com mais pals | `BiggerRanch` | PalSchema | `raw/ranch.json` |
| **Expedições** mais rápidas | `FastExpeditions` | PalSchema | `raw/expeditions.json` |
| **Cooldown** de skills de pal menor | `FastPalSkills` | PalSchema | `raw/waza.json`, `raw/partnerskill.json` |
| Incubadora **choca sozinha** | `AutoHatchLua` | Lua | `Scripts/logic.lua` |

## Conteúdo novo

| Efeito | Mod | Tipo | Arquivo-chave |
|---|---|---|---|
| Fazenda "Rainbow Star" (colhe tudo junto) | `RainbowStar` | Lua + PalSchema + pak | vários |
| Item Elixir de Stamina | `StaminaElixir` | PalSchema (+`StaminaElixirEffect` Lua) | `items/stamina.json` |
| Pals ganham XP na expedição | `ExpeditionXP` | Lua | `Scripts/logic.lua` |
| Coleta remota de expedição | `RemoteExpedition` | Lua | `Scripts/logic.lua` |

## ⚠️ Limitação do PalSchema (por que alguns efeitos são Lua)

O PalSchema (v0.6.1) só permite **1 arquivo JSON editar cada blueprint** — mesmo dentro do
mesmo mod. Dois arquivos no mesmo BP → só o **1º em ordem alfabética** aplica, o outro é
**ignorado em silêncio** (o log ainda diz "Loaded changes" pros dois — engana). Confirmado na
[issue #10 oficial](https://github.com/Okaetsu/PalSchema/issues/10), fechada sem correção.

Por isso: sanidade e condensador (ambos `BP_PalGameSetting_C`) e tamanho/tempo da fazenda
(ambos `BP_BuildObject_BreedFarm_C`) não podem ser mods PalSchema separados. O **condensador**
e o **tempo de fazenda** viram mods **Lua** (editam em runtime, sem tocar o blueprint),
liberando o BP pro `NoSanityLoss` e pro `MiniBuilds` respectivamente.
