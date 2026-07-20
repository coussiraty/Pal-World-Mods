# rs_31_materiais.py -- planta branca: reaponta os materiais pros caminhos VANILLA.
#
# CAUSA (lida no pak, nao suposta):
#   As malhas em /Game/Mods/RainbowStar/Meshes/ vieram com os materiais que o
#   import gerou -- e esses sao CASCAS BRANCAS. Dump de MI_Tomato_01 do nosso pak:
#       "Type": "Material"        (nem e MaterialInstanceConstant)
#       TextureValues: []   ReferencedTextures: []
#       VectorValues: FFFFFF, FFFFFF, FFFFFF
#   Ou seja: geometria certa, material vazio -> planta branca.
#
# CORRECAO:
#   Reaponta cada slot de material das nossas malhas para o caminho VANILLA
#   (ex.: /Game/Others/FarmCrops/MaterialInstances/MI_Tomato_01), que foi lido do
#   proprio mesh vanilla. Em runtime o jogo resolve pelos paks DELE, com textura
#   e tudo. Como o response file do pak so inclui Mods/RainbowStar, o dummy criado
#   aqui no caminho vanilla NAO vai junto -- e so uma ancora pro editor.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_31_materiais.py

import unreal

NOSSO = "/Game/Mods/RainbowStar/Meshes"
OUT = r"C:\PMK\rs_out.txt"

# nome do material -> pasta VANILLA (extraida do pak_list do jogo)
VANILLA = {
    "MI_Carrot_01":            "/Game/Others/FarmCrops/MaterialInstances",
    "MI_CarrotLeaves_01":      "/Game/Others/FarmCrops/MaterialInstances",
    "MI_OnionGarlic_01":       "/Game/Others/FarmCrops/MaterialInstances",
    "MI_OnionGarlicLeaves_01": "/Game/Others/FarmCrops/MaterialInstances",
    "MI_Tomato_01":            "/Game/Others/FarmCrops/MaterialInstances",
    "MI_TomatoLeaves_01":      "/Game/Others/FarmCrops/MaterialInstances",
    "MI_WheatLeaves_01":       "/Game/Others/FarmCrops/MaterialInstances",
    "MI_PalProp_FarmGround":       "/Game/Pal/Model/Prop/Architecture/FarmGround/Material",
    "MI_PalProp_FarmGround_Fence": "/Game/Pal/Model/Prop/Architecture/FarmGround/Material",
    "MI_PalProp_Lettuce":          "/Game/Pal/Model/Prop/Resource/Lettuce/Material",
    "MI_pal_b00_bush_BlueBerry_NordicConiferBiome":  "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Materials",
    "MI_pal_b00_flower_clovers_NordicConiferBiome":  "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Materials",
    "MI_pal_b00_flower_Raspberry_PN_WildBerries_01": "/Game/Pal/Model/Stage/b00/PN_WildBerries/Materials",
    "MI_pal_b00_leaves_FarmCrops_potato_Leaves_01":  "/Game/Pal/Model/Stage/b00/FarmCrops/Material",
    "MI_pal_b00_props_FarmCrops_potato_01":          "/Game/Pal/Model/Stage/b00/FarmCrops/Material",
}

EAL = unreal.EditorAssetLibrary
AT = unreal.AssetToolsHelpers.get_asset_tools()
out = []


def log(m):
    out.append(str(m)); unreal.log("[rs31] " + str(m))


def ancora(nome):
    """Devolve o asset no caminho VANILLA, criando um stub se nao existir.
    O stub nunca vai pro pak: o response file so pega Mods/RainbowStar."""
    pasta = VANILLA.get(nome)
    if not pasta:
        return None, None
    caminho = "%s/%s" % (pasta, nome)
    if EAL.does_asset_exist(caminho):
        return EAL.load_asset(caminho), caminho
    a = AT.create_asset(nome, pasta, unreal.MaterialInstanceConstant,
                        unreal.MaterialInstanceConstantFactoryNew())
    if a is None:
        return None, caminho
    EAL.save_loaded_asset(a, False)
    log("   (criada ancora vanilla: %s)" % caminho)
    return a, caminho


trocados, intactos, falhos = 0, 0, []
for p in sorted(EAL.list_assets(NOSSO, recursive=True)):
    base = p.split(".")[0]
    a = EAL.load_asset(base)
    if not isinstance(a, unreal.StaticMesh):
        continue
    mats = a.get_editor_property("static_materials")
    mudou = False
    for i in range(len(mats)):
        sm = mats[i]
        mi = sm.get_editor_property("material_interface")
        if mi is None:
            continue
        nome = mi.get_name()
        atual = mi.get_path_name()
        if "/Game/Mods/RainbowStar/" not in atual:
            intactos += 1
            continue                      # ja aponta pra fora do mod
        novo, caminho = ancora(nome)
        if novo is None:
            falhos.append("%s :: %s" % (base.split("/")[-1], nome))
            continue
        sm.set_editor_property("material_interface", novo)
        mats[i] = sm
        mudou = True
        trocados += 1
    if mudou:
        a.set_editor_property("static_materials", mats)
        EAL.save_loaded_asset(a, False)
        log("%-46s %d slots reapontados" % (base.split("/")[-1], len(mats)))

log("")
log("slots trocados: %d | ja fora do mod: %d | falhas: %d" % (trocados, intactos, len(falhos)))
for f in falhos:
    log("  FALHOU: %s" % f)

log("")
log("--- conferencia ---")
for p in sorted(EAL.list_assets(NOSSO, recursive=True)):
    base = p.split(".")[0]
    a = EAL.load_asset(base)
    if not isinstance(a, unreal.StaticMesh):
        continue
    for sm in a.get_editor_property("static_materials"):
        mi = sm.get_editor_property("material_interface")
        if mi is not None and "/Game/Mods/RainbowStar/" in mi.get_path_name():
            log("  AINDA NO MOD: %s -> %s" % (base.split("/")[-1], mi.get_path_name()))

open(OUT, "w").write("\n".join(out))
