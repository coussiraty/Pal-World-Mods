# Os 7 componentes passam a usar os MESHES REAIS de cada cultura (estagio de
# colheita), cada um com o material proprio dele. Sem tint: a cor ja e natural.
import unreal
EAL = unreal.EditorAssetLibrary; BEL = unreal.BlueprintEditorLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[real] " + str(m))

BP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
D  = "/Game/Mods/RainbowStar/Meshes/"
# componente -> mesh do estagio de COLHEITA de cada cultura
ALVOS = {
    "CropISM_0":         D + "SM_pal_b00_flower_Raspberry_PN_WildBerries_08",  # Berries
    "RS_Prisma_Wheat":   D + "SM_Wheat_03a",
    "RS_Prisma_Tomato":  D + "SM_Tomato_03a",
    "RS_Prisma_Lettuce": D + "SM_Lettuce_L",
    "RS_Prisma_Carrot":  D + "SM_Carrot_03",
    "RS_Prisma_Onion":   D + "SM_Onion_04",
    "RS_Prisma_Potato":  D + "SM_pal_b00_props_FarmCrops_potato_03",
}

bp = EAL.load_asset(BP)
for h in sds.k2_gather_subobject_data_for_blueprint(bp):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None: continue
    n = str(SDL.get_variable_name(d))
    alvo = ALVOS.get(n)
    if not alvo: continue
    if not EAL.does_asset_exist(alvo):
        log("MESH AUSENTE: %s" % alvo); continue
    c = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
    if not c: log("sem template: %s" % n); continue
    c.set_editor_property("static_mesh", EAL.load_asset(alvo))
    c.set_editor_property("override_materials", [])   # usa o material proprio do mesh
    log("%-20s -> %s" % (n, alvo.split("/")[-1]))

BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))
with open(OUT,"w") as f: f.write("\n".join(lines))
