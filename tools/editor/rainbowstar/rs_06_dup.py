import unreal
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"
lines=[]
def log(m):
    lines.append(str(m)); unreal.log("[rs06] " + str(m))

for path in ("/Game/Mods/RainbowStar/BP_BuildObject_RainbowStar",
             "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"):
    bp = EAL.load_asset(path)
    log("=== %s ===" % path.split("/")[-1])
    nomes = []
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        n = str(SDL.get_variable_name(d))
        if n and n != "None": nomes.append(n)
    from collections import Counter
    c = Counter(nomes)
    log("  entradas totais: %d | nomes unicos: %d" % (len(nomes), len(c)))
    dups = {k:v for k,v in c.items() if v > 1}
    log("  DUPLICADOS: %s" % (dups if dups else "nenhum"))

    # o SCS (Simple Construction Script) e a fonte da verdade do que e salvo
    try:
        scs = bp.get_editor_property("simple_construction_script")
        nodes = scs.get_editor_property("all_nodes") if scs else []
        log("  nos no SCS (fonte da verdade): %d" % len(nodes))
        snames = [str(n.get_editor_property("internal_variable_name")) for n in nodes]
        cs = Counter(snames)
        log("  SCS duplicados: %s" % ({k:v for k,v in cs.items() if v>1} or "nenhum"))
    except Exception as e:
        log("  SCS ? %s" % e)

with open(OUT,"w") as f: f.write("\n".join(lines))
unreal.log("[rs06] FIM")
