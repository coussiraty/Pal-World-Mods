# TESTE: o jogo popula instancias por NOME FIXO de componente?
# 3 ISMs com os nomes exatos do vanilla, mas com mesh de TOMATE.
# Se aparecer tomate no canteiro -> nomes sao hardcoded, e sabemos o teto.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[nom] " + str(m))

BP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
D = "/Game/Mods/RainbowStar/Meshes/"
# tomate nos 3 estagios: inconfundivel se aparecer
ESTAGIOS = [("GrassISM", D+"SM_Tomato_01a"), ("GrowupISM", D+"SM_Tomato_02a"), ("CropISM", D+"SM_Tomato_03a")]

bp = EAL.load_asset(BP)
def snap():
    m, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if SDL.is_default_scene_root(d): root = h
        n = str(SDL.get_variable_name(d))
        if n and n != "None": m[n] = h
    return m, root

# limpa tudo que nao e herdado
for _ in range(80):
    comps, _r = snap(); alvo = None
    for n, h in comps.items():
        d = sds.k2_find_subobject_data_from_handle(h)
        if d and not SDL.is_inherited_component(d) and not SDL.is_default_scene_root(d): alvo = h; break
    if alvo is None: break
    try: sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo, bp)
    except Exception as e: log("erro apagando: %s" % e); break

comps, root = snap()
log("limpo. sobrou: %s" % sorted(comps.keys()))

for nome, mesh in ESTAGIOS:
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", root)
    p.set_editor_property("new_class", unreal.InstancedStaticMeshComponent)
    p.set_editor_property("blueprint_context", bp)
    p.set_editor_property("conform_transform_to_parent", True)
    h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(h): log("ERRO %s: %s" % (nome, motivo)); continue
    sds.rename_subobject(h, nome)
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
    d = sds.k2_find_subobject_data_from_handle(h)
    c = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
    c.set_editor_property("static_mesh", EAL.load_asset(mesh))
    log("%s (pedi %s) -> %s" % (real, nome, mesh.split("/")[-1]))

BEL.compile_blueprint(bp)
cdo = unreal.get_default_object(BEL.generated_class(bp))
arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for estado, comp, rate in ((unreal.PalFarmCropState.GROWUP,"GrassISM",0.0),
                           (unreal.PalFarmCropState.GROWUP,"GrowupISM",0.5),
                           (unreal.PalFarmCropState.HARVESTABLE,"CropISM",1.0)):
    cr = unreal.ComponentReference(); cr.set_editor_property("component_property", comp)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado); s.set_editor_property("target_comp_ref", cr); s.set_editor_property("process_rate", rate)
    arr.append(s)
cdo.set_editor_property("growup_process_sets", arr)
BEL.compile_blueprint(bp)
log("salvo=%s | 3 entradas, igual ao vanilla" % EAL.save_loaded_asset(bp, False))
with open(OUT,"w") as f: f.write("\n".join(lines))
