# Usa a row VANILLA "Berries" no nosso canteiro, em vez da row custom.
# Motivo: sem CropClassPath valido a row custom nao gera planta nenhuma.
# Com a row do jogo, a planta nasce normal -- e ai da pra mexer nela em runtime.
import unreal
EAL = unreal.EditorAssetLibrary
BEL = unreal.BlueprintEditorLibrary
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[row] " + str(m))

bp = EAL.load_asset("/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar")
cdo = unreal.get_default_object(BEL.generated_class(bp))
st = cdo.get_editor_property("crop_data_id")
log("CropDataId antes: %s" % st.get_editor_property("key"))
st.set_editor_property("key", "Berries")
cdo.set_editor_property("crop_data_id", st)
BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))
cdo2 = unreal.get_default_object(BEL.generated_class(bp))
log("CropDataId depois: %s" % cdo2.get_editor_property("crop_data_id").get_editor_property("key"))
with open(OUT,"w") as f: f.write("\n".join(lines))
