import glob, unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[gnd] " + str(m))

# importa o SM_FarmGround pro nosso Content
f = glob.glob(r"C:\PMK\paldump\meshes\**\SM_FarmGround.glb", recursive=True)
if f:
    t = unreal.AssetImportTask()
    t.set_editor_property("filename", f[0])
    t.set_editor_property("destination_path", "/Game/Mods/RainbowStar/Meshes")
    for k in ("automated","replace_existing","save"): t.set_editor_property(k, True)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([t])
    log("importado: %s" % list(t.get_editor_property("imported_object_paths")))

# aponta o Mesh do canteiro pro nosso
bp = EAL.load_asset("/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar")
alvo = "/Game/Mods/RainbowStar/Meshes/SM_FarmGround"
if not EAL.does_asset_exist(alvo):
    log("ABORTADO: %s nao existe" % alvo)
else:
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if str(SDL.get_variable_name(d)) == "Mesh":
            c = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
            if c:
                c.set_editor_property("static_mesh", EAL.load_asset(alvo))
                log("Mesh do canteiro -> nosso SM_FarmGround")
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    log("salvo=%s" % EAL.save_loaded_asset(bp, False))
with open(OUT,"w") as fo: fo.write("\n".join(lines))
