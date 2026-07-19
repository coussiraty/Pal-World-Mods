# Reparenta a PLANTA pro BP de tomate do jogo (via dummy), pra herdar tudo que
# faz a planta funcionar. Depois so trocamos os meshes.
import unreal
EAL = unreal.EditorAssetLibrary; BEL = unreal.BlueprintEditorLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[cr] " + str(m))

BP  = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
PAI = "/Game/Pal/Blueprint/MapObject/FarmCrop/BP_PalMapObjectFarmCrop_Tomato"
log("dummy do pai existe: %s" % EAL.does_asset_exist(PAI))
if EAL.does_asset_exist(PAI):
    bp = EAL.load_asset(BP)
    # tira TUDO que e nosso (inclusive o DefaultSceneRoot, que colide apos reparent)
    for _ in range(60):
        alvo = None
        for h in sds.k2_gather_subobject_data_for_blueprint(bp):
            d = sds.k2_find_subobject_data_from_handle(h)
            if d is None or SDL.is_inherited_component(d): continue
            alvo = h; break
        if alvo is None: break
        try: sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo, bp)
        except Exception as e: log("erro apagando: %s" % e); break
    BEL.reparent_blueprint(bp, EAL.load_blueprint_class(PAI))
    BEL.compile_blueprint(bp)
    log("reparentado para BP_PalMapObjectFarmCrop_Tomato_C | salvo=%s" % EAL.save_loaded_asset(bp, False))
    comps = []
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d: 
            n = str(SDL.get_variable_name(d))
            if n and n != "None": comps.append(n)
    log("componentes: %s" % sorted(set(comps)))
with open(OUT,"w") as f: f.write("\n".join(lines))
