# rs_02_assemble.py -- ROTA A, passo 2: monta o BP da planta por script.
#
# Cria, dentro de BP_PalMapObjectFarmCrop_RainbowStar:
#   DefaultSceneRoot
#     +-- RS_Stage_Seeding      (SceneComponent)  <- TargetCompRef do estagio 1
#     |     +-- RS_S1_Tomato .. RS_S1_Onion       (StaticMeshComponent)
#     +-- RS_Stage_Growup       (SceneComponent)  <- TargetCompRef do estagio 2
#     |     +-- RS_S2_*
#     +-- RS_Stage_Harvestable  (SceneComponent)  <- TargetCompRef do estagio 3
#           +-- RS_S3_*
# ...e preenche GrowupProcessSets no CDO com 3 entradas apontando pros grupos.
#
# IDEMPOTENTE: se um componente com o nome ja existir, ele e reaproveitado.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_02_assemble.py
# Saida:  C:\PMK\rs_out.txt   (o canal remoto trunca output grande -- ler o arquivo)

import math
import unreal

BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
OUT = r"C:\PMK\rs_out.txt"

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)

# mesma tabela do rs_01 -- manter as duas em sincronia
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
    # ordem dos estagios INFERIDA (sem sufixo numerico pra guiar) - ver rs_01
    "Berries": (
        "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_flower_clovers_NordicConiferBiome",
        "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_bush_BlueBerry_NordicConiferBiome",
        "/Game/Pal/Model/Stage/b00/PN_WildBerries/Meshes/SM_pal_b00_flower_Raspberry_PN_WildBerries_08",
    ),
}

# (nome do grupo, enum de estado, process_rate, escala do estagio)
# ATENCAO: process_rate e CHUTE. Confirmar lendo um BP_PalMapObjectFarmCrop_*
# vanilla no FModel antes de considerar isso final.
STAGES = [
    ("RS_Stage_Seeding",     unreal.PalFarmCropState.SEEDING,     1.0, 0.45),
    ("RS_Stage_Growup",      unreal.PalFarmCropState.GROWUP,      1.0, 0.75),
    ("RS_Stage_Harvestable", unreal.PalFarmCropState.HARVESTABLE, 1.0, 1.00),
]

RAIO = 35.0          # cm: raio do circulo onde as 7 culturas ficam
ESCALA_CULTURA = 0.40  # cada cultura encolhida pra caberem as 7 juntas

lines = []


def log(m):
    lines.append(str(m))
    unreal.log("[rs02] " + str(m))


def dump():
    with open(OUT, "w") as f:
        f.write("\n".join(lines))


def handles(bp):
    """{nome_da_variavel: handle} + handle da raiz de anexacao."""
    m, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None:
            continue
        if SDL.is_default_scene_root(d):
            root = h
        nome = str(SDL.get_variable_name(d))
        if nome and nome != "None":
            m[nome] = h
    return m, root


def template(h, bp):
    """objeto EDITAVEL do componente dentro deste Blueprint."""
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None:
        return None
    if hasattr(SDL, "get_object_for_blueprint"):
        o = SDL.get_object_for_blueprint(d, bp)
        if o is not None:
            return o
    return SDL.get_object(d)


def add(bp, parent_handle, classe, nome, existentes):
    """Adiciona (ou reaproveita) um componente e devolve (handle, nome_real)."""
    if nome in existentes:
        return existentes[nome], nome
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", parent_handle)
    p.set_editor_property("new_class", classe)
    p.set_editor_property("blueprint_context", bp)
    p.set_editor_property("conform_transform_to_parent", True)
    h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(h):
        log("  ERRO add_new_subobject %s: %s" % (nome, motivo))
        return None, None
    if not sds.rename_subobject(h, nome):
        log("  ERRO rename_subobject -> %s" % nome)
        return None, None
    # a engine sufixa em caso de colisao: usar SEMPRE o nome real
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
    if real != nome:
        log("  AVISO renomeado para '%s' (pedi '%s')" % (real, nome))
    existentes[real] = h
    return h, real


# ---------------------------------------------------------------------------
log("=== rs_02_assemble ===")
if not EAL.does_asset_exist(BP_PATH):
    log("ABORTADO: BP nao existe: %s" % BP_PATH)
    dump()
    raise SystemExit

bp = EAL.load_asset(BP_PATH)
existentes, root = handles(bp)
log("componentes ja no BP: %s" % sorted(existentes.keys()))
if root is None:
    log("ABORTADO: nao achei DefaultSceneRoot")
    dump()
    raise SystemExit

ativos = [c for c, p in MESHES.items() if p]
log("culturas com caminho mapeado: %s" % ativos)
log("culturas PENDENTES: %s" % [c for c, p in MESHES.items() if not p])
if not ativos:
    log("ABORTADO: nenhuma cultura mapeada")
    dump()
    raise SystemExit

grupos = {}   # nome_do_grupo -> nome real da variavel

for idx, (gnome, estado, rate, gescala) in enumerate(STAGES):
    gh, greal = add(bp, root, unreal.SceneComponent, gnome, existentes)
    if gh is None:
        continue
    grupos[gnome] = greal
    log("grupo %s (estado %s)" % (greal, estado))

    for i, crop in enumerate(ativos):
        mesh_path = MESHES[crop][idx]
        if not EAL.does_asset_exist(mesh_path):
            log("  PULADO %s: mesh nao existe no projeto -> %s" % (crop, mesh_path))
            continue
        cnome = "RS_S%d_%s" % (idx + 1, crop)
        ch, creal = add(bp, gh, unreal.StaticMeshComponent, cnome, existentes)
        if ch is None:
            continue
        comp = template(ch, bp)
        if comp is None:
            log("  ERRO: sem template editavel para %s" % creal)
            continue
        mesh = EAL.load_asset(mesh_path)
        comp.set_editor_property("static_mesh", mesh)
        ang = 2.0 * math.pi * i / float(len(ativos))
        comp.set_editor_property("relative_location", unreal.Vector(
            RAIO * math.cos(ang), RAIO * math.sin(ang), 0.0))
        e = ESCALA_CULTURA * gescala
        comp.set_editor_property("relative_scale3d", unreal.Vector(e, e, e))
        log("  %s -> %s" % (creal, mesh_path))

# ordem que importa: compilar ANTES de escrever o CDO (compile recria o CDO)
unreal.BlueprintEditorLibrary.compile_blueprint(bp)
log("compilado")

gc = unreal.BlueprintEditorLibrary.generated_class(bp)
cdo = unreal.get_default_object(gc)

arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for gnome, estado, rate, _ in STAGES:
    if gnome not in grupos:
        continue
    cr = unreal.ComponentReference()
    cr.set_editor_property("component_property", grupos[gnome])
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado)
    s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)

cdo.set_editor_property("growup_process_sets", arr)
log("GrowupProcessSets escrito: %d entradas" % len(arr))

salvo = EAL.save_loaded_asset(bp, False)
log("save_loaded_asset -> %s" % salvo)

# leitura de volta (nao prova o disco, mas pega perda imediata)
cdo2 = unreal.get_default_object(unreal.BlueprintEditorLibrary.generated_class(bp))
volta = cdo2.get_editor_property("growup_process_sets")
log("releitura do CDO: %d entradas" % len(volta))
for e in volta:
    log("  %s -> comp '%s' rate %s" % (
        e.get_editor_property("state"),
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))

dump()
unreal.log("[rs02] FIM -> %s" % OUT)
