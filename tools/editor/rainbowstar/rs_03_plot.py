# rs_03_plot.py -- da corpo ao canteiro: dummy do SM_FarmGround + componente no BP.
import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"
BP_PATH = "/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar"
GROUND  = "/Game/Pal/Model/Prop/Architecture/FarmGround/SM_FarmGround"
CUBE    = "/Engine/BasicShapes/Cube"
COMP    = "RS_FarmGround"

lines = []
def log(m):
    lines.append(str(m)); unreal.log("[rs03] " + str(m))

# 1) dummy do chao
if EAL.does_asset_exist(GROUND):
    log("dummy ja existe: %s" % GROUND)
else:
    novo = EAL.duplicate_asset(CUBE, GROUND)
    if novo:
        try: novo.set_editor_property("static_materials", [])
        except Exception: pass
        log("dummy CRIADO %s (save=%s)" % (GROUND, EAL.save_loaded_asset(novo, False)))
    else:
        log("FALHOU criar dummy %s" % GROUND)

# 2) componente no BP do canteiro
bp = EAL.load_asset(BP_PATH)
if not bp:
    log("ABORTADO: BP nao existe %s" % BP_PATH)
else:
    existentes, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if SDL.is_default_scene_root(d): root = h
        n = str(SDL.get_variable_name(d))
        if n and n != "None": existentes[n] = h
    log("componentes ja no BP: %s" % sorted(existentes.keys()))
    log("raiz encontrada: %s" % (root is not None))

    if COMP in existentes:
        log("componente %s ja existe" % COMP)
        h = existentes[COMP]
    elif root is None:
        log("ABORTADO: sem DefaultSceneRoot"); h = None
    else:
        p = unreal.AddNewSubobjectParams()
        p.set_editor_property("parent_handle", root)
        p.set_editor_property("new_class", unreal.StaticMeshComponent)
        p.set_editor_property("blueprint_context", bp)
        p.set_editor_property("conform_transform_to_parent", True)
        h, motivo = sds.add_new_subobject(p)
        if not SDL.is_handle_valid(h):
            log("ERRO add_new_subobject: %s" % motivo); h = None
        else:
            sds.rename_subobject(h, COMP)
            real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
            log("componente criado como '%s'" % real)

    if h is not None:
        d = sds.k2_find_subobject_data_from_handle(h)
        comp = SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)
        if comp:
            comp.set_editor_property("static_mesh", EAL.load_asset(GROUND))
            log("mesh do chao atribuido")
        else:
            log("ERRO: sem template editavel")
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    log("compilado | save=%s" % EAL.save_loaded_asset(bp, False))

with open(OUT, "w") as f: f.write("\n".join(lines))
unreal.log("[rs03] FIM")
