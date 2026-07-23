# Gera o config.lua do mod BuildSizes com TODAS as estruturas construiveis do jogo.
#
# Fontes (dumpadas pelo paldump, que le o cozido do pak -- nao inferir por header):
#   DT_BuildObjectDataTable_Common  -> o que e construivel (roda de construcao) + categoria
#   DT_MapObjectMasterDataTable_Common -> BlueprintClassSoft, de onde sai BP_..._C
#   L10N/en/.../DT_MapObjectNameText_Common -> nome em ingles
#     (a tabela BASE, sem L10N, e em JAPONES -- e o idioma-fonte do jogo. Nao usar.)
#     Para gerar em outro idioma, troque NAMES abaixo pelo dump do L10N daquele idioma.
#
# Uso:  python C:\PMK\gen_buildsizes_config.py
import json, io, sys, os

OUT = r"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Mods\BuildSizes\config.lua"
D = "C:/PMK/paldump/out/"

def rows(fn):
    return json.load(open(D + fn, encoding="utf-8"))[0]["Rows"]

build = rows("DT_BuildObjectDataTable_Common.json")
master = rows("DT_MapObjectMasterDataTable_Common.json")
names = rows("NameText_EN.json")

# ja tratadas pelo MiniBuilds (PalSchema). Se ligar aqui tambem, escala em dobro.
MINIBUILDS = {"BP_BuildObject_MonsterFarm_C", "BP_BuildObject_BreedFarm_C",
              "BP_BuildObject_Expedition_C"}

CAT = {
    "Product": "Production", "Pal": "Pal", "Storage": "Storage", "Food": "Food",
    "Infrastructure": "Infrastructure", "Light": "Light", "Foundation": "Foundation",
    "Defense": "Defense", "Other": "Other", "Furniture": "Furniture",
    "Dismantle": "Dismantle", "Blueprint": "Blueprint", "Favorite": "Favorite",
}

def nome_de(rid):
    r = names.get("MAPOBJECT_NAME_" + rid)
    if r:
        t = (r.get("TextData") or {})
        s = t.get("LocalizedString") or t.get("SourceString")
        if s:
            return s
    return rid

grupos = {}
vistos = set()
for rid, row in build.items():
    mo = master.get(rid)
    if not mo:
        continue
    ap = (mo.get("BlueprintClassSoft") or {}).get("AssetPathName") or ""
    if not ap or ap == "None":
        continue
    classe = ap.split(".")[-1]          # ...BP_X.BP_X_C -> BP_X_C
    if not classe.endswith("_C") or classe in vistos:
        continue
    vistos.add(classe)
    cat = CAT.get((row.get("TypeA") or "").split("::")[-1], "Outros")
    grupos.setdefault(cat, []).append({
        "nome": nome_de(rid),
        "classe": classe,
        "sort": row.get("SortId") or 0,
    })

CAB = """-- =====================================================================
--  BuildSizes - CONFIG   (edit, save, then press F7 in game)
--
--  HOW TO USE
--    1. Find the structure below and change  enabled = false  to  enabled = true
--    2. Pick a  size :  1.0 = normal | 0.65 = smaller | 0.3 = tiny
--                       1.5 = bigger  (you can scale UP too)
--    3. Save this file and press  F7  in game
--    4. In build mode, aim until the ghost is placed on valid ground. Then
--       RE-SELECT the structure in the menu -- it spawns at the new size.
--
--  Scaling is PROPORTIONAL: size, part positions and the footprint all shrink
--  by the same factor. That is why you can stack and butt them together
--  without weird collision.
--
--  Applies to what you build AFTERWARDS. Already-placed structures are untouched.
--
--  Adding one by hand: copy a line and swap the class (BP_BuildObject_<x>_C).
--
--  The 3 marked [MiniBuilds] are handled by that mod -- leave them false, or
--  the scale gets applied twice.
-- =====================================================================
return {
"""

ORDEM = ["Production", "Foundation", "Storage", "Food", "Pal", "Infrastructure",
         "Furniture", "Light", "Defense", "Other", "Blueprint", "Favorite", "Dismantle"]

buf = io.StringIO()
buf.write(CAB)
total = 0
for cat in ORDEM + [c for c in grupos if c not in ORDEM]:
    itens = grupos.get(cat)
    if not itens:
        continue
    itens.sort(key=lambda e: (e["sort"], e["nome"]))
    buf.write("\n    -- ---------- %s (%d) ----------\n" % (cat.upper(), len(itens)))
    w = max(len(e["classe"]) for e in itens) + 2
    for e in itens:
        tag = "   -- [MiniBuilds]" if e["classe"] in MINIBUILDS else ""
        buf.write('    { name = %-34s class = %-*s enabled = false, size = 1.0 },%s\n'
                  % ('"%s",' % e["nome"].replace('"', "'"), w, '"%s",' % e["classe"], tag))
        total += 1
buf.write("}\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write(buf.getvalue())
print("estruturas escritas:", total)
for c in ORDEM:
    if grupos.get(c):
        print("  %-16s %d" % (c, len(grupos[c])))
