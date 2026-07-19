# devolve o Mesh do canteiro pro caminho vanilla (dummy), que renderizava marrom.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[rev] " + str(m))

VANILLA = "/Game/Pal/Model/Prop/Architecture/FarmGround/SM_FarmGround"
bp = EAL.load_asset("/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar")
log("dummy vanilla existe no projeto: %s" % EAL.does_asset_exist(VANILLA))
for h in sds.k2_gather_subobject_data_for_blueprint(bp):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None: continue
    if str(SDL.get_variable_name(d)) == "Mesh":
        c = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
        if c:
            c.set_editor_property("static_mesh", EAL.load_asset(VANILLA))
            log("Mesh -> %s (dummy vanilla)" % VANILLA)
unreal.BlueprintEditorLibrary.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))
with open(OUT,"w") as f: f.write("\n".join(lines))
