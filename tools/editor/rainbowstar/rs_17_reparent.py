# Reparenta o canteiro pro BP VANILLA (via dummy), pra herdar o grafo dele.
import unreal
EAL = unreal.EditorAssetLibrary; BEL = unreal.BlueprintEditorLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[rep] " + str(m))

BP   = "/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar"
PAI  = "/Game/Pal/Blueprint/MapObject/BuildObject/BP_BuildObject_FarmBlockV2_Berries"

log("APIs de reparent: %s" % [f for f in dir(BEL) if 'parent' in f.lower()])
log("dummy do pai existe: %s" % EAL.does_asset_exist(PAI))
if not EAL.does_asset_exist(PAI):
    log("ABORTADO: dummy do BP vanilla nao esta no projeto"); 
else:
    bp = EAL.load_asset(BP)
    pai_cls = EAL.load_blueprint_class(PAI)
    log("classe pai carregada: %s" % pai_cls)

    # remove nossos componentes duplicados (vamos herdar os do pai)
    apagados = 0
    for _ in range(40):
        alvo = None
        for h in sds.k2_gather_subobject_data_for_blueprint(bp):
            d = sds.k2_find_subobject_data_from_handle(h)
            if d is None or SDL.is_default_scene_root(d) or SDL.is_inherited_component(d): continue
            n = str(SDL.get_variable_name(d))
            if n in ("Mesh","BuildWorkableBounds","CheckOverlapCollision","VirtualMeshCollision","BP_InteractableBox") or n.startswith("RS_"):
                alvo = h; break
        if alvo is None: break
        try: sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo, bp); apagados += 1
        except Exception as e: log("erro apagando: %s" % e); break
    log("componentes nossos removidos: %d (vamos herdar do pai)" % apagados)

    try:
        BEL.reparent_blueprint(bp, pai_cls)
        log("REPARENTADO para BP_BuildObject_FarmBlockV2_Berries_C")
    except Exception as e:
        log("reparent FALHOU: %s" % e)

    BEL.compile_blueprint(bp)
    cdo = unreal.get_default_object(BEL.generated_class(bp))
    st = cdo.get_editor_property("crop_data_id"); st.set_editor_property("key", "RainbowStar")
    cdo.set_editor_property("crop_data_id", st)
    try: cdo.set_editor_property("concrete_model_class", unreal.PalMapObjectFarmBlockV2Model)
    except Exception as e: log("model class? %s" % e)
    BEL.compile_blueprint(bp)
    log("salvo=%s" % EAL.save_loaded_asset(bp, False))
    c2 = unreal.get_default_object(BEL.generated_class(bp))
    log("CropDataId=%s | ConcreteModelClass=%s" % (
        c2.get_editor_property("crop_data_id").get_editor_property("key"),
        c2.get_editor_property("concrete_model_class")))
    comps = [str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
             for h in sds.k2_gather_subobject_data_for_blueprint(bp)]
    log("componentes agora: %s" % sorted(set(x for x in comps if x and x != "None")))
with open(OUT,"w") as f: f.write("\n".join(lines))
