# BISSECAO: deixa o BP da planta MINIMO (subclasse vazia de APalMapObjectFarmCrop).
# Se plantar funcionar assim, a classe carrega e o problema esta nos componentes.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[min] " + str(m))

BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
bp = EAL.load_asset(BP_PATH)

def snap():
    m = {}
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        n = str(SDL.get_variable_name(d))
        if n and n != "None" and not SDL.is_default_scene_root(d): m[n] = h
    return m

apagados = 0
for _ in range(80):
    comps = snap()
    alvo = None
    for n, h in comps.items():
        d = sds.k2_find_subobject_data_from_handle(h)
        if d and not SDL.is_inherited_component(d): alvo = (n, h); break
    if alvo is None: break
    try:
        sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo[1], bp)
        apagados += 1
    except Exception as e:
        log("falha apagando %s: %s" % (alvo[0], e)); break
log("componentes apagados: %d" % apagados)
log("sobraram: %s" % sorted(snap().keys()))

BEL.compile_blueprint(bp)
cdo = unreal.get_default_object(BEL.generated_class(bp))
cdo.set_editor_property("growup_process_sets", unreal.Array(unreal.PalFarmCropGrowupProcessSet))
BEL.compile_blueprint(bp)
log("GrowupProcessSets zerado | salvo=%s" % EAL.save_loaded_asset(bp, False))
with open(OUT,"w") as f: f.write("\n".join(lines))
