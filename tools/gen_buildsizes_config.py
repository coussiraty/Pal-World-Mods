# Gera o config.lua do mod BuildSizes com TODAS as estruturas construiveis do jogo.
#
# Fontes (dumpadas pelo paldump, que le o cozido do pak -- nao inferir por header):
#   DT_BuildObjectDataTable_Common  -> o que e construivel (roda de construcao) + categoria
#   DT_MapObjectMasterDataTable_Common -> BlueprintClassSoft, de onde sai BP_..._C
#   L10N/pt-BR/.../DT_MapObjectNameText_Common -> nome legivel em pt-BR
#
# Uso:  python C:\PMK\gen_buildsizes_config.py
import json, io, sys, os

OUT = r"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Mods\BuildSizes\config.lua"
D = "C:/PMK/paldump/out/"

def rows(fn):
    return json.load(open(D + fn, encoding="utf-8"))[0]["Rows"]

build = rows("DT_BuildObjectDataTable_Common.json")
master = rows("DT_MapObjectMasterDataTable_Common.json")
names = rows("NameText_ptBR.json")

# ja tratadas pelo MiniBuilds (PalSchema). Se ligar aqui tambem, escala em dobro.
MINIBUILDS = {"BP_BuildObject_MonsterFarm_C", "BP_BuildObject_BreedFarm_C",
              "BP_BuildObject_Expedition_C"}

CAT = {
    "Product": "Producao", "Pal": "Pal", "Storage": "Armazenamento", "Food": "Comida",
    "Infrastructure": "Infraestrutura", "Light": "Iluminacao", "Foundation": "Estrutura",
    "Defense": "Defesa", "Other": "Outros", "Furniture": "Mobilia",
    "Dismantle": "Desmontar", "Blueprint": "Planta", "Favorite": "Favoritos",
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
--  BuildSizes - CONFIG   (edite, salve, e aperte F7 dentro do jogo)
--
--  COMO USAR
--    1. Ache a estrutura na lista e troque  ativo = false  por  ativo = true
--    2. Escolha o  tamanho :  1.0 = normal | 0.65 = menor | 0.3 = bem pequeno
--                             1.5 = maior  (da pra AUMENTAR tambem)
--    3. Salve este arquivo e aperte  F7  dentro do jogo
--    4. No modo de construcao, mire com o fantasma pousado no chao. Depois
--       RE-SELECIONE a estrutura no menu -- ela nasce no tamanho novo.
--
--  A escala e PROPORCIONAL: tamanho, posicao das pecas e a area que ela ocupa
--  encolhem juntos. Por isso da pra empilhar/aproximar sem colisao esquisita.
--
--  Vale para o que voce construir DEPOIS. O que ja esta no chao nao muda.
--
--  As 3 marcadas [MiniBuilds] ja sao tratadas por outro mod -- deixe false,
--  senao a escala e aplicada duas vezes.
-- =====================================================================
return {
"""

ORDEM = ["Producao", "Estrutura", "Armazenamento", "Comida", "Pal", "Infraestrutura",
         "Mobilia", "Iluminacao", "Defesa", "Outros", "Planta", "Favoritos", "Desmontar"]

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
        buf.write('    { nome = %-34s classe = %-*s ativo = false, tamanho = 1.0 },%s\n'
                  % ('"%s",' % e["nome"].replace('"', "'"), w, '"%s",' % e["classe"], tag))
        total += 1
buf.write("}\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8").write(buf.getvalue())
print("estruturas escritas:", total)
for c in ORDEM:
    if grupos.get(c):
        print("  %-16s %d" % (c, len(grupos[c])))
