# Generates the MiniBuilds config.lua with EVERY buildable structure in the game.
#
# Sources (dumped by paldump, which reads the cooked pak -- never infer from the
# PMK headers or the dummy blueprints, both of which lie):
#   DT_BuildObjectDataTable_Common      -> what is buildable (build wheel) + category
#   DT_MapObjectMasterDataTable_Common  -> BlueprintClassSoft, which gives BP_..._C
#   L10N/en/.../DT_MapObjectNameText_Common -> readable English names
#     The BASE table, without L10N, is in JAPANESE -- that is the game's source
#     language. To generate another language, point NAMES at that L10N dump.
#
# Run:  python C:\PMK\gen_buildsizes_config.py
# WARNING: overwrites config.lua with everything disabled. Save your picks first.
import json, io, os

OUT = r"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Mods\MiniBuilds\config.lua"
D = "C:/PMK/paldump/out/"
NAMES = "NameText_EN.json"

def rows(fn):
    return json.load(open(D + fn, encoding="utf-8"))[0]["Rows"]

build = rows("DT_BuildObjectDataTable_Common.json")
master = rows("DT_MapObjectMasterDataTable_Common.json")
names = rows(NAMES)

# The three buildings MiniBuilds v1 shipped, at their v1 sizes. They ship ENABLED
# so that upgrading from v1 keeps the base looking exactly the same -- an update
# must never silently blow someone's buildings back up to full size.
# (v1 sized these through PalSchema. v2 owns them here instead: two systems
#  scaling the same building compounded the scale but not the part positions,
#  which pulled the pieces apart.)
DEFAULT_ON = {
    "BP_BuildObject_Expedition_C": 0.3,
    "BP_BuildObject_MonsterFarm_C": 0.65,
    "BP_BuildObject_BreedFarm_C": 0.65,
}

# EPalBuildObjectTypeA -> section title
CAT = {
    "Product": "Production", "Pal": "Pal", "Storage": "Storage", "Food": "Food",
    "Infrastructure": "Infrastructure", "Light": "Light", "Foundation": "Foundation",
    "Defense": "Defense", "Other": "Other", "Furniture": "Furniture",
    "Dismantle": "Dismantle", "Blueprint": "Blueprint", "Favorite": "Favorite",
}

def name_of(rid):
    r = names.get("MAPOBJECT_NAME_" + rid)
    if r:
        t = r.get("TextData") or {}
        s = t.get("LocalizedString") or t.get("SourceString")
        if s:
            return s
    return rid                      # no text row: fall back to the row id

groups = {}
seen = set()
for rid, row in build.items():
    mo = master.get(rid)
    if not mo:
        continue
    ap = (mo.get("BlueprintClassSoft") or {}).get("AssetPathName") or ""
    if not ap or ap == "None":
        continue
    cls = ap.split(".")[-1]         # ...BP_X.BP_X_C -> BP_X_C
    if not cls.endswith("_C") or cls in seen:
        continue
    seen.add(cls)
    cat = CAT.get((row.get("TypeA") or "").split("::")[-1], "Other")
    groups.setdefault(cat, []).append({
        "name": name_of(rid),
        "class": cls,
        "path": ap,                       # lets the mod resolve the class AT STARTUP
        "sort": row.get("SortId") or 0,   # instead of waiting for you to aim at it
    })

HEADER = """-- =====================================================================
--  MiniBuilds - CONFIG   (edit, save, done)
--
--  HOW TO USE
--    1. Find the structure below and change  enabled = false  to  enabled = true
--    2. Pick a  size :  1.0 = normal | 0.65 = smaller | 0.3 = tiny
--                       1.5 = bigger  (you can scale UP too)
--    3. Save this file. It is applied right away, and again automatically
--       every time the game starts.
--
--  Scaling is PROPORTIONAL: size, part positions and the footprint all shrink
--  by the same factor. That is why you can stack and butt them together
--  without weird collision.
--
--  Do not edit "class" or "path" -- those are how the mod finds the building.
--
--  The 3 marked [v1] are the buildings MiniBuilds 1.x shrank. They come turned
--  on at their old sizes so an update does not blow your base back up. Change
--  or turn them off like any other line.
-- =====================================================================
return {
"""

ORDER = ["Production", "Foundation", "Storage", "Food", "Pal", "Infrastructure",
         "Furniture", "Light", "Defense", "Other", "Blueprint", "Favorite", "Dismantle"]

buf = io.StringIO()
buf.write(HEADER)
total = 0
for cat in ORDER + [c for c in groups if c not in ORDER]:
    items = groups.get(cat)
    if not items:
        continue
    items.sort(key=lambda e: (e["sort"], e["name"]))
    buf.write("\n    -- ---------- %s (%d) ----------\n" % (cat.upper(), len(items)))
    w = max(len(e["class"]) for e in items) + 2
    for e in items:
        on = DEFAULT_ON.get(e["class"])
        buf.write('    { name = %-34s enabled = %-6s size = %-5s class = %-*s path = "%s" },%s\n'
                  % ('"%s",' % e["name"].replace('"', "'"),
                     "true," if on else "false,", str(on or 1.0) + ",",
                     w, '"%s",' % e["class"], e["path"],
                     "   -- [v1]" if on else ""))
        total += 1
buf.write("}\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write(buf.getvalue())
print("structures written:", total)
for c in ORDER:
    if groups.get(c):
        print("  %-16s %d" % (c, len(groups[c])))
