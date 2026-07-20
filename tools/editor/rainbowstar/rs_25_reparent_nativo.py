# rs_25_reparent_nativo.py -- tira o BP da planta de baixo do BP do Tomate.
#
# POR QUE: rs_19 reparentou nosso crop BP para BP_PalMapObjectFarmCrop_Tomato_C.
# Consequencia que so apareceu agora: o ator em runtime carrega os ISMs HERDADOS
# do tomate (CropISM/GrassISM/GrowupISM, com SM_Tomato_*) ALEM dos nossos
# (CropISM_0/GrassISM_0/GrowupISM_0 + os 6 RS_Prisma_*). Duas geracoes de
# componente no mesmo ator, e os herdados apontam pra tomate.
#
# As culturas vanilla herdam direto da classe NATIVA (confirmado no header dump:
# 'class ABP_PalMapObjectFarmCrop_Tomato_C : public APalMapObjectFarmCrop'), que
# e o que este script faz. Some com os herdados e sobra so o que e nosso.
#
# O BP do Tomate so agregava 3 coisas (lidas do pak, nao supostas):
#   SimpleConstructionScript (os 3 ISMs)  -> temos os nossos
#   GrowupProcessSets                     -> reescrito aqui
#   GrowupFX = NS_Grow_Smoke              -> reaplicado aqui, senao perdia o efeito
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_25_reparent_nativo.py
# Saida:  C:\PMK\rs_out.txt

import unreal

BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
NATIVO = "/Script/Pal.PalMapObjectFarmCrop"
FX_CRESCIMENTO = "/Game/Pal/Effect/Common/Smoke/NS_Grow_Smoke"
OUT = r"C:\PMK\rs_out.txt"

IRMAOS = ["RS_Prisma_Wheat", "RS_Prisma_Tomato", "RS_Prisma_Lettuce",
          "RS_Prisma_Carrot", "RS_Prisma_Onion", "RS_Prisma_Potato"]

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)

linhas = []


def log(m):
    linhas.append(str(m))
    unreal.log("[rs25] " + str(m))


def dump():
    open(OUT, "w").write("\n".join(linhas))


def abortar(m):
    log("ABORTADO: " + m)
    dump()
    raise SystemExit


def componentes(bp):
    """{nome_da_variavel: (handle, objeto_editavel)}"""
    m = {}
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None:
            continue
        nome = str(SDL.get_variable_name(d))
        if not nome or nome == "None":
            continue
        obj = None
        if hasattr(SDL, "get_object_for_blueprint"):
            obj = SDL.get_object_for_blueprint(d, bp)
        m[nome] = (h, obj if obj is not None else SDL.get_object(d))
    return m


log("=== rs_25_reparent_nativo ===")
if not EAL.does_asset_exist(BP_PATH):
    abortar("BP nao existe: %s" % BP_PATH)

bp = EAL.load_asset(BP_PATH)

antes = componentes(bp)
log("componentes ANTES: %s" % sorted(antes.keys()))
pai_antes = "?"
try:
    pai_antes = BEL.generated_class(bp).get_super_class().get_name()
except Exception as e:
    log("  (nao consegui ler a classe-pai: %s)" % e)
log("classe-pai ANTES: %s" % pai_antes)

# ---- reparentar --------------------------------------------------------
alvo = getattr(unreal, "PalMapObjectFarmCrop", None)
if alvo is None:
    alvo = unreal.load_object(None, NATIVO)
if alvo is None:
    abortar("nao resolvi a classe nativa %s" % NATIVO)

BEL.reparent_blueprint(bp, alvo)
BEL.compile_blueprint(bp)
log("reparentado para %s" % NATIVO)

# ---- raiz: reparent costuma deixar DefaultSceneRoot duplicado ----------
depois = componentes(bp)
raizes = [n for n in depois if n.startswith("DefaultSceneRoot")]
if len(raizes) > 1:
    log("AVISO: %d raizes apos reparent -> %s" % (len(raizes), raizes))
    for n in sorted(raizes)[1:]:
        if sds.delete_subobject(depois[n][0], depois[n][0], bp):
            log("  removida raiz duplicada: %s" % n)
    BEL.compile_blueprint(bp)
    depois = componentes(bp)

log("componentes DEPOIS: %s" % sorted(depois.keys()))
sumiram = sorted(set(antes) - set(depois))
log("sumiram (herdados do Tomate): %s" % (sumiram or "nenhum"))

for n in ("CropISM_0", "GrassISM_0", "GrowupISM_0"):
    if n not in depois:
        abortar("componente NOSSO sumiu no reparent: %s -- nao salvei nada" % n)

# ---- CDO: GrowupProcessSets + o efeito que vinha do pai ----------------
cdo = unreal.get_default_object(BEL.generated_class(bp))

S = unreal.PalFarmCropState
PLANO = [("GrassISM_0", S.GROWUP, 0.0), ("GrowupISM_0", S.GROWUP, 0.5),
         ("CropISM_0", S.HARVESTABLE, 1.0)]
PLANO += [(n, S.HARVESTABLE, 1.0) for n in IRMAOS]

arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for nome, estado, rate in PLANO:
    if nome not in depois:
        log("  AVISO: '%s' nao existe -- fora do GrowupProcessSets" % nome)
        continue
    cr = unreal.ComponentReference()
    cr.set_editor_property("component_property", nome)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado)
    s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)
cdo.set_editor_property("growup_process_sets", arr)
log("GrowupProcessSets: %d entradas" % len(arr))

if EAL.does_asset_exist(FX_CRESCIMENTO):
    try:
        cdo.set_editor_property("growup_fx", EAL.load_asset(FX_CRESCIMENTO))
        log("GrowupFX reaplicado (vinha do BP do Tomate)")
    except Exception as e:
        log("AVISO: nao consegui setar GrowupFX: %s" % e)
else:
    log("AVISO: %s nao existe no projeto -- sem efeito de crescimento" % FX_CRESCIMENTO)

log("save_loaded_asset -> %s" % EAL.save_loaded_asset(bp, False))

# ---- releitura ---------------------------------------------------------
log("")
log("--- releitura ---")
try:
    log("classe-pai: %s" % BEL.generated_class(bp).get_super_class().get_name())
except Exception:
    pass
cdo2 = unreal.get_default_object(BEL.generated_class(bp))
for e in cdo2.get_editor_property("growup_process_sets"):
    log("  %-14s %-20s rate=%s" % (
        str(e.get_editor_property("state")).split(".")[-1],
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))
for n in sorted(componentes(bp)):
    _, o = componentes(bp)[n]
    if o is not None and hasattr(o, "static_mesh"):
        try:
            m = o.get_editor_property("static_mesh")
            log("  mesh %-18s %s" % (n, m.get_name() if m else "None"))
        except Exception:
            pass

dump()
unreal.log("[rs25] FIM -> %s" % OUT)
