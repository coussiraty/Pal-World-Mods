# rs_07_rebuild.py -- reconstroi os 2 BPs seguindo a ESPECIFICACAO EXATA lida do
# pak (paldump). Fase 1: clone fiel do vanilla, so trocando o CropDataId.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"
lines = []
def log(m):
    lines.append(str(m)); unreal.log("[rs07] " + str(m))

FARM = "/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar"
CROP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
GROUND = "/Game/Pal/Model/Prop/Architecture/FarmGround/SM_FarmGround"
IBOX = "/Game/Pal/Blueprint/MapObject/Components/BP_InteractableBox"

# meshes das bagas (fase 1 = clone fiel)
M_GRASS  = "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_flower_clovers_NordicConiferBiome"
M_GROWUP = "/Game/Pal/Model/Stage/b00/NordicConiferBiome/Meshes/SM_pal_b00_bush_BlueBerry_NordicConiferBiome"
M_CROP   = "/Game/Pal/Model/Stage/b00/PN_WildBerries/Meshes/SM_pal_b00_flower_Raspberry_PN_WildBerries_08"


def snapshot(bp):
    m, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if SDL.is_default_scene_root(d): root = h
        n = str(SDL.get_variable_name(d))
        if n and n != "None": m[n] = h
    return m, root


def wipe(bp, prefixos):
    """apaga componentes nossos (nao mexe em herdado)."""
    apagados = 0
    for _ in range(60):                    # varias passadas: apagar invalida handles
        comps, _r = snapshot(bp)
        alvo = None
        for n, h in comps.items():
            if any(n.startswith(p) for p in prefixos):
                d = sds.k2_find_subobject_data_from_handle(h)
                if d and not SDL.is_inherited_component(d):
                    alvo = (n, h); break
        if alvo is None: break
        try:
            sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo[1], bp)
            apagados += 1
        except Exception as e:
            log("  falha ao apagar %s: %s" % (alvo[0], e)); break
    return apagados


def add(bp, parent, classe, nome, comps):
    if nome in comps: return comps[nome], nome
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", parent)
    p.set_editor_property("new_class", classe)
    p.set_editor_property("blueprint_context", bp)
    p.set_editor_property("conform_transform_to_parent", True)
    h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(h):
        log("  ERRO add %s: %s" % (nome, motivo)); return None, None
    sds.rename_subobject(h, nome)
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
    comps[real] = h
    return h, real


def obj(h, bp):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None: return None
    o = SDL.get_object_for_blueprint(d, bp)
    return o if o is not None else SDL.get_object(d)


def V(x, y, z): return unreal.Vector(x, y, z)

# ===================== CANTEIRO =====================
log("=== CANTEIRO ===")
bp = EAL.load_asset(FARM)
log("apagados antigos: %d" % wipe(bp, ["RS_"]))
comps, root = snapshot(bp)
log("apos limpeza: %s" % sorted(comps.keys()))

h, _ = add(bp, root, unreal.StaticMeshComponent, "Mesh", comps)
if h:
    c = obj(h, bp)
    c.set_editor_property("static_mesh", EAL.load_asset(GROUND))
    c.set_editor_property("relative_scale3d", V(0.65, 0.65, 1.0))
    log("  Mesh -> SM_FarmGround esc 0.65/0.65/1.0")

# as 3 caixas, com extent e posicao EXATOS do vanilla
for nome, ext, loc in (
        ("BuildWorkableBounds",  V(250.0, 250.0, 12.0), V(0.0, 0.0, 12.0)),
        ("CheckOverlapCollision", V(150.0, 150.0, 4.0), V(0.0, 0.0, 10.0)),
        ("VirtualMeshCollision", V(185.0, 185.0, 18.0), V(0.0, 0.0, -2.0))):
    h, _ = add(bp, root, unreal.BoxComponent, nome, comps)
    if h:
        c = obj(h, bp)
        c.set_editor_property("box_extent", ext)
        c.set_editor_property("relative_location", loc)
        log("  %s extent=%s loc=%s" % (nome, ext, loc))

# caixa interativa (classe BP do jogo, via dummy)
try:
    ib = unreal.EditorAssetLibrary.load_blueprint_class(IBOX)
    h, _ = add(bp, root, ib, "BP_InteractableBox", comps)
    if h:
        c = obj(h, bp)
        c.set_editor_property("box_extent", V(250.0, 250.0, 12.0))
        c.set_editor_property("relative_location", V(0.0, 0.0, 12.0))
        log("  BP_InteractableBox ok")
except Exception as e:
    log("  BP_InteractableBox FALHOU: %s" % e)

BEL.compile_blueprint(bp)
cdo = unreal.get_default_object(BEL.generated_class(bp))
# *** o que faltava e crashou o jogo ***
cdo.set_editor_property("concrete_model_class", unreal.PalMapObjectFarmBlockV2Model)
st = cdo.get_editor_property("crop_data_id"); st.set_editor_property("key", "RainbowStar")
cdo.set_editor_property("crop_data_id", st)
try:
    ref = unreal.ComponentReference(); ref.set_editor_property("component_property", "CheckOverlapCollision")
    cdo.set_editor_property("overlap_check_collision_ref", ref)
except Exception as e: log("  overlap ref? %s" % e)
try: cdo.set_editor_property("destroy_fx_type", unreal.PalMapObjectDestroyFXType.NORMAL_WOOD)
except Exception as e: log("  destroy fx? %s" % e)
try: cdo.set_editor_property("b_exists_arrow_in_simulating_transform", True)
except Exception as e: log("  arrow? %s" % e)
BEL.compile_blueprint(bp)
log("  salvo=%s" % EAL.save_loaded_asset(bp, False))
cdo2 = unreal.get_default_object(BEL.generated_class(bp))
log("  ConcreteModelClass = %s" % cdo2.get_editor_property("concrete_model_class"))
log("  CropDataId         = %s" % cdo2.get_editor_property("crop_data_id"))

# ===================== PLANTA =====================
log("=== PLANTA ===")
bp2 = EAL.load_asset(CROP)
log("apagados antigos: %d" % wipe(bp2, ["RS_"]))
comps2, root2 = snapshot(bp2)
log("apos limpeza: %s" % sorted(comps2.keys()))

for nome, mesh in (("GrassISM", M_GRASS), ("GrowupISM", M_GROWUP), ("CropISM", M_CROP)):
    h, _ = add(bp2, root2, unreal.InstancedStaticMeshComponent, nome, comps2)
    if h:
        c = obj(h, bp2)
        c.set_editor_property("static_mesh", EAL.load_asset(mesh))
        log("  %s -> %s" % (nome, mesh.split("/")[-1]))

BEL.compile_blueprint(bp2)
cdo3 = unreal.get_default_object(BEL.generated_class(bp2))
arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for estado, comp, rate in ((unreal.PalFarmCropState.GROWUP, "GrassISM", 0.0),
                           (unreal.PalFarmCropState.GROWUP, "GrowupISM", 0.5),
                           (unreal.PalFarmCropState.HARVESTABLE, "CropISM", 1.0)):
    cr = unreal.ComponentReference(); cr.set_editor_property("component_property", comp)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado)
    s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)
cdo3.set_editor_property("growup_process_sets", arr)
BEL.compile_blueprint(bp2)
log("  salvo=%s" % EAL.save_loaded_asset(bp2, False))
for e in unreal.get_default_object(BEL.generated_class(bp2)).get_editor_property("growup_process_sets"):
    log("    %s -> %s @ %s" % (e.get_editor_property("state"),
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))

with open(OUT, "w") as f: f.write("\n".join(lines))
unreal.log("[rs07] FIM")
