# Disseca o BP vanilla das bagas pra achar o que falta no nosso.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"
lines = []
def log(m):
    lines.append(str(m)); unreal.log("[rs05] " + str(m))

unreal.AssetRegistryHelpers.get_asset_registry().scan_paths_synchronous(
    ["/Game/Pal/Blueprint/MapObject"], True)

ALVOS = [
    ("VANILLA canteiro", "/Game/Pal/Blueprint/MapObject/BuildObject/BP_BuildObject_FarmBlockV2_Berries"),
    ("NOSSO   canteiro", "/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar"),
    ("VANILLA planta",   "/Game/Pal/Blueprint/MapObject/FarmCrop/BP_PalMapObjectFarmCrop_Berries"),
    ("NOSSO   planta",   "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"),
]

for rotulo, path in ALVOS:
    log("=" * 62)
    log("%s  %s" % (rotulo, path))
    if not EAL.does_asset_exist(path):
        log("  NAO EXISTE"); continue
    bp = EAL.load_asset(path)
    gc0 = unreal.BlueprintEditorLibrary.generated_class(bp)
    try: log("  classe gerada: %s" % gc0.get_name())
    except Exception as e: log("  classe gerada: ? %s" % e)

    # hierarquia de componentes
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        nome = str(SDL.get_variable_name(d))
        o = SDL.get_object(d)
        cls = o.get_class().get_name() if o else "?"
        flags = []
        if SDL.is_default_scene_root(d): flags.append("ROOT")
        if SDL.is_inherited_component(d): flags.append("herdado")
        log("    %-28s %-32s %s" % (nome, cls, ",".join(flags)))

    # propriedades nao-default do CDO
    cdo = unreal.get_default_object(unreal.BlueprintEditorLibrary.generated_class(bp))
    log("  --- propriedades relevantes do CDO ---")
    for p in ("crop_data_id", "growup_fx", "crop_actor", "growup_process_sets",
              "current_state", "map_object_id", "concrete_model_class",
              "model_class", "map_object_concrete_model_class"):
        try:
            v = cdo.get_editor_property(p)
            log("    %-32s = %s" % (p, v))
        except Exception:
            pass

with open(OUT, "w") as f: f.write("\n".join(lines))
unreal.log("[rs05] FIM")
