# rs_01_dummies.py -- ROTA A, passo 1: cria os STUBS ("dummying") nos caminhos
# EXATOS do jogo, duplicando /Engine/BasicShapes/Cube.
#
# Esses assets NUNCA podem entrar no pak. A protecao e dupla:
#   1) +DirectoriesToNeverCook=(Path="/Game/Others") e (Path="/Game/Pal") no DefaultGame.ini
#   2) so o pakchunk1000 e distribuido, e o pak e auditado com UnrealPak -List
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_01_dummies.py
# Saida:  C:\PMK\rs_out.txt

import unreal

EAL = unreal.EditorAssetLibrary
OUT = r"C:\PMK\rs_out.txt"
CUBE = "/Engine/BasicShapes/Cube"

# ---------------------------------------------------------------------------
# TABELA DE MESHES VANILLA.
# So estao aqui os caminhos CONFIRMADOS lendo os BP_PalMapObjectFarmCrop_*
# extraidos do Pal-Windows.pak. NAO INVENTAR CAMINHO: um typo nao da erro de
# cook, da planta invisivel. Os 4 marcados como None precisam ser relidos no
# FModel antes de entrar aqui.
# ordem: (estagio1_seeding, estagio2_growup, estagio3_harvestable)
# ---------------------------------------------------------------------------
MESHES = {
    "Tomato": (
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Tomato_01a",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Tomato_02a",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Tomato_03a",
    ),
    "Lettuce": (
        "/Game/Pal/Model/Prop/Resource/Lettuce/FBX/SM_Lettuce_S",
        "/Game/Pal/Model/Prop/Resource/Lettuce/FBX/SM_Lettuce_M",
        "/Game/Pal/Model/Prop/Resource/Lettuce/FBX/SM_Lettuce_L",
    ),
    "Potato": (
        "/Game/Pal/Model/Stage/b00/FarmCrops/Mesh/SM_pal_b00_props_FarmCrops_potato_01",
        "/Game/Pal/Model/Stage/b00/FarmCrops/Mesh/SM_pal_b00_props_FarmCrops_potato_02",
        "/Game/Pal/Model/Stage/b00/FarmCrops/Mesh/SM_pal_b00_props_FarmCrops_potato_03",
    ),
    "Wheat": (
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Wheat_01a",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Wheat_02a",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Wheat_03a",
    ),
    "Carrot": (
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Carrot_01",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Carrot_02",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Carrot_03",
    ),
    "Onion": (
        "/Game/Others/FarmCrops/Meshes/Crops/SM_OnionSeed_01",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Onion_02",
        "/Game/Others/FarmCrops/Meshes/Crops/SM_Onion_04",
    ),
    # Berries nao tem mesh proprio: o BP vanilla reusa vegetacao do mundo.
    # ORDEM DOS ESTAGIOS E INFERIDA (os outros crops tem sufixo numerico que
    # da a ordem; estes nao). Se no jogo a planta crescer "ao contrario",
    # e so trocar a ordem desta tupla.
    "Berries": (
        "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_flower_clovers_NordicConiferBiome",
        "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_bush_BlueBerry_NordicConiferBiome",
        "/Game/Pal/Model/Stage/b00/PN_WildBerries/Meshes/SM_pal_b00_flower_Raspberry_PN_WildBerries_08",
    ),
}

lines = []


def log(m):
    lines.append(str(m))
    unreal.log("[rs01] " + str(m))


log("=== rs_01_dummies ===")
log("cube existe: %s" % EAL.does_asset_exist(CUBE))

criados, ja_existiam, falhas = 0, 0, 0

for crop, paths in MESHES.items():
    if not paths:
        log("PENDENTE  %-8s -> sem caminho mapeado, pulando" % crop)
        continue
    for p in paths:
        if EAL.does_asset_exist(p):
            ja_existiam += 1
            log("ja existe %s" % p)
            continue
        try:
            novo = EAL.duplicate_asset(CUBE, p)
        except Exception as e:
            novo = None
            log("EXCECAO  %s : %s" % (p, e))
        if novo is None:
            falhas += 1
            log("FALHOU    %s" % p)
            continue
        # o dummy nao precisa de material: menos dependencia /Engine pendurada
        try:
            novo.set_editor_property("static_materials", [])
        except Exception:
            pass
        ok = EAL.save_loaded_asset(novo, False)
        criados += 1
        log("CRIADO    %s   (save=%s)" % (p, ok))

log("--- resumo: criados=%d ja_existiam=%d falhas=%d" % (criados, ja_existiam, falhas))
log("LEMBRETE: /Game/Others e /Game/Pal precisam estar em DirectoriesToNeverCook")

with open(OUT, "w") as f:
    f.write("\n".join(lines))
unreal.log("[rs01] FIM -> %s" % OUT)
