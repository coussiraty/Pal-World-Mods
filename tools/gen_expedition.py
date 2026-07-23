import json

SCALE = 0.3
SRC = "C:/PMK/paldump/out/BP_BuildObject_Expedition.json"
DST = "C:/PMK/expedition_generated.json"

dump = json.load(open(SRC, encoding="utf-8"))
if isinstance(dump, dict):
    dump = dump.get("Exports") or dump.get("exports") or list(dump.values())

def mul(d, s):
    return {k: round((d.get(k) or 0) * s, 4) for k in ("X", "Y", "Z")}

# NAO escalar o root (dupla escala + nao pega no preview) nem componentes so-de-cena vazios
EXCLUDE = {"Root", "DefaultSceneRoot"}

out = {}
for comp in dump:
    if not isinstance(comp, dict):
        continue
    name = comp.get("Name", "")
    if "_GEN_VARIABLE" not in name:
        continue                      # so os componentes do BP (templates)
    clean = name.replace("_GEN_VARIABLE", "")
    if clean in EXCLUDE:
        continue
    props = comp.get("Properties", {}) or {}
    entry = {}
    base = props.get("RelativeScale3D") or {"X": 1, "Y": 1, "Z": 1}
    entry["RelativeScale3D"] = {k: round((base.get(k) if base.get(k) is not None else 1) * SCALE, 4) for k in ("X", "Y", "Z")}
    loc = props.get("RelativeLocation")
    if loc:
        entry["RelativeLocation"] = mul(loc, SCALE)
    box = props.get("BoxExtent")
    if box:
        entry["BoxExtent"] = mul(box, SCALE)
    out[clean] = entry

final = {"BP_BuildObject_Expedition_C": out}
json.dump(final, open(DST, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
print("componentes escalados:", len(out))
for k in out:
    print("  -", k)
