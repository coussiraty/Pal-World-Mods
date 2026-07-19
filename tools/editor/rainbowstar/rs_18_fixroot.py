# Remove o DefaultSceneRoot LOCAL: depois do reparent ele vem do pai e colide.
import unreal
EAL = unreal.EditorAssetLibrary; BEL = unreal.BlueprintEditorLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[fix] " + str(m))

bp = EAL.load_asset("/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar")
def listar():
    r = []
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        n = str(SDL.get_variable_name(d))
        if n and n != "None":
            r.append((n, h, SDL.is_inherited_component(d), SDL.is_default_scene_root(d)))
    return r

for n,h,herd,root in listar():
    log("  %-22s herdado=%s root=%s" % (n, herd, root))

alvo = None
for n,h,herd,root in listar():
    if root and not herd: alvo = (n,h); break
if alvo:
    try:
        sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], alvo[1], bp)
        log("removido DefaultSceneRoot local (%s)" % alvo[0])
    except Exception as e:
        log("FALHOU remover: %s" % e)
else:
    log("nenhum DefaultSceneRoot local (ja esta so o herdado)")

BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))
log("componentes finais: %s" % [n for n,_,_,_ in listar()])
with open(OUT,"w") as f: f.write("\n".join(lines))
