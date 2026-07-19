# rs_08_rainbow.py -- visual arco-iris, testando 2 hipoteses de uma vez.
#
#   estagio 1 (Growup@0.0)      -> GrassISM  (1 mesh de baga)   = controle conhecido
#   estagio 2 (Growup@0.5)      -> RS_Mid    SceneComponent PAI com 7 ISMs filhos  = HIPOTESE C
#   estagio 3 (Harvestable@1.0) -> 7 ISMs, 7 entradas no array                     = HIPOTESE E
#
# Uma plantacao crescendo mostra qual funciona: se no meio aparecerem 7 -> C vence.
# Se so na colheita aparecerem 7 -> E vence. Se nenhuma -> preciso de mesh combinado.
import math, unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"
BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
RAIO, ESC = 60.0, 0.5

CROPS = {
 "Berries": ("/Game/Mods/RainbowStar/Meshes/SM_pal_b00_flower_clovers_NordicConiferBiome","/Game/Mods/RainbowStar/Meshes/SM_pal_b00_bush_BlueBerry_NordicConiferBiome","/Game/Mods/RainbowStar/Meshes/SM_pal_b00_flower_Raspberry_PN_WildBerries_08"),
 "Wheat":   ("/Game/Mods/RainbowStar/Meshes/SM_Wheat_01a","/Game/Mods/RainbowStar/Meshes/SM_Wheat_02a","/Game/Mods/RainbowStar/Meshes/SM_Wheat_03a"),
 "Tomato":  ("/Game/Mods/RainbowStar/Meshes/SM_Tomato_01a","/Game/Mods/RainbowStar/Meshes/SM_Tomato_02a","/Game/Mods/RainbowStar/Meshes/SM_Tomato_03a"),
 "Carrot":  ("/Game/Mods/RainbowStar/Meshes/SM_Carrot_01","/Game/Mods/RainbowStar/Meshes/SM_Carrot_02","/Game/Mods/RainbowStar/Meshes/SM_Carrot_03"),
 "Onion":   ("/Game/Mods/RainbowStar/Meshes/SM_OnionSeed_01","/Game/Mods/RainbowStar/Meshes/SM_Onion_02","/Game/Mods/RainbowStar/Meshes/SM_Onion_04"),
 "Lettuce": ("/Game/Mods/RainbowStar/Meshes/SM_Lettuce_S","/Game/Mods/RainbowStar/Meshes/SM_Lettuce_M","/Game/Mods/RainbowStar/Meshes/SM_Lettuce_L"),
 "Potato":  ("/Game/Mods/RainbowStar/Meshes/SM_pal_b00_props_FarmCrops_potato_01","/Game/Mods/RainbowStar/Meshes/SM_pal_b00_props_FarmCrops_potato_02","/Game/Mods/RainbowStar/Meshes/SM_pal_b00_props_FarmCrops_potato_03"),
}
ORDEM = ["Berries","Wheat","Tomato","Carrot","Onion","Lettuce","Potato"]

lines=[]
def log(m):
    lines.append(str(m)); unreal.log("[rs08] " + str(m))

def snap(bp):
    m, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if SDL.is_default_scene_root(d): root = h
        n = str(SDL.get_variable_name(d))
        if n and n != "None": m[n] = h
    return m, root

def wipe(bp, pref):
    n = 0
    for _ in range(80):
        comps, _r = snap(bp); alvo = None
        for nome, h in comps.items():
            if any(nome.startswith(p) for p in pref):
                d = sds.k2_find_subobject_data_from_handle(h)
                if d and not SDL.is_inherited_component(d): alvo = h; break
        if alvo is None: break
        try:
            sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo, bp); n += 1
        except Exception as e:
            log("  falha ao apagar: %s" % e); break
    return n

def add(bp, parent, cls, nome, comps):
    if nome in comps: return comps[nome], nome
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", parent)
    p.set_editor_property("new_class", cls)
    p.set_editor_property("blueprint_context", bp)
    p.set_editor_property("conform_transform_to_parent", True)
    h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(h):
        log("  ERRO add %s: %s" % (nome, motivo)); return None, None
    sds.rename_subobject(h, nome)
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
    comps[real] = h
    return h, real

def setup(h, bp, mesh, i=None):
    d = sds.k2_find_subobject_data_from_handle(h)
    c = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
    if not c: return False
    c.set_editor_property("static_mesh", EAL.load_asset(mesh))
    if i is not None:
        ang = 2.0*math.pi*i/7.0
        c.set_editor_property("relative_location",
            unreal.Vector(RAIO*math.cos(ang), RAIO*math.sin(ang), 0.0))
        c.set_editor_property("relative_scale3d", unreal.Vector(ESC, ESC, ESC))
    return True

log("=== arco-iris: 2 hipoteses ===")
bp = EAL.load_asset(BP_PATH)
log("apagados: %d" % wipe(bp, ["GrassISM","GrowupISM","CropISM","RS_"]))
comps, root = snap(bp)

# estagio 1 - controle: 1 ISM de baga
h,_ = add(bp, root, unreal.InstancedStaticMeshComponent, "GrassISM", comps)
if h: setup(h, bp, CROPS["Berries"][0]); log("est1 GrassISM (controle)")

# estagio 2 - HIPOTESE C: pai SceneComponent com 7 ISMs filhos
hm, _ = add(bp, root, unreal.SceneComponent, "RS_Mid", comps)
if hm:
    for i, crop in enumerate(ORDEM):
        hc,_ = add(bp, hm, unreal.InstancedStaticMeshComponent, "RS_Mid_%s" % crop, comps)
        if hc: setup(hc, bp, CROPS[crop][1], i)
    log("est2 RS_Mid (pai) + 7 filhos  <- HIPOTESE C")

# estagio 3 - HIPOTESE E: 7 ISMs soltos, 7 entradas no array
finais = []
for i, crop in enumerate(ORDEM):
    hc, real = add(bp, root, unreal.InstancedStaticMeshComponent, "RS_Crop_%s" % crop, comps)
    if hc: setup(hc, bp, CROPS[crop][2], i); finais.append(real)
log("est3 %d ISMs soltos  <- HIPOTESE E" % len(finais))

BEL.compile_blueprint(bp)
cdo = unreal.get_default_object(BEL.generated_class(bp))
arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
def ent(estado, comp, rate):
    cr = unreal.ComponentReference(); cr.set_editor_property("component_property", comp)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado); s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)

ent(unreal.PalFarmCropState.GROWUP, "GrassISM", 0.0)
ent(unreal.PalFarmCropState.GROWUP, "RS_Mid",   0.5)
for c in finais:
    ent(unreal.PalFarmCropState.HARVESTABLE, c, 1.0)
cdo.set_editor_property("growup_process_sets", arr)
BEL.compile_blueprint(bp)
log("salvo=%s | %d entradas no array" % (EAL.save_loaded_asset(bp, False), len(arr)))
for e in unreal.get_default_object(BEL.generated_class(bp)).get_editor_property("growup_process_sets"):
    log("   %s -> %s @ %s" % (e.get_editor_property("state"),
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))
with open(OUT,"w") as f: f.write("\n".join(lines))
unreal.log("[rs08] FIM")
