# rs_26_fixroot.py -- devolve a hierarquia certa ao BP da planta apos o rs_25.
#
# CONTEXTO: rs_25 reparentou o BP da classe BP_PalMapObjectFarmCrop_Tomato_C para
# a nativa APalMapObjectFarmCrop. Deu certo (os ISMs herdados do tomate sumiram),
# MAS o reparent levou junto o DefaultSceneRoot e a engine promoveu o primeiro
# componente de cena a raiz -- ficou um InstancedStaticMesh (GrassISM_0) como
# raiz do ator, e RootComponent do CDO = None.
#
# O certo e espelhar o vanilla, lido do pak (BP_PalMapObjectFarmCrop_Tomato):
#     SCS_Node_0  DefaultSceneRoot (SceneComponent)  <- raiz, 3 filhos
#       +-- CropISM / GrassISM / GrowupISM
#
# Entao: cria um DefaultSceneRoot, promove a raiz, e pendura os 9 ISMs nele.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_26_fixroot.py
# Saida:  C:\PMK\rs_out.txt

import unreal

BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
RAIZ = "DefaultSceneRoot"
OUT = r"C:\PMK\rs_out.txt"

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)

linhas = []


def log(m):
    linhas.append(str(m))
    unreal.log("[rs26] " + str(m))


def dump():
    open(OUT, "w").write("\n".join(linhas))


def abortar(m):
    log("ABORTADO: " + m)
    dump()
    raise SystemExit


def mapa(bp):
    """{nome: handle} -- k2_gather devolve duplicata, fica o PRIMEIRO handle."""
    m, ordem = {}, []
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None:
            continue
        n = str(SDL.get_variable_name(d))
        if not n or n == "None":
            continue
        if n not in m:
            m[n] = h
            ordem.append(n)
    return m, ordem


def raiz_atual(bp):
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None:
            continue
        if SDL.is_default_scene_root(d) or SDL.is_root_component(d):
            return str(SDL.get_variable_name(d)), h
    return None, None


log("=== rs_26_fixroot ===")
bp = EAL.load_asset(BP_PATH)
if bp is None:
    abortar("nao carreguei %s" % BP_PATH)

m, ordem = mapa(bp)
log("componentes: %s" % ordem)
rn, rh = raiz_atual(bp)
log("raiz ANTES: %s" % rn)

# so os ISMs; qualquer SceneComponent puro ja existente vira candidato a raiz
ISMS = [n for n in ordem if "ISM" in n or n.startswith("RS_Prisma_")]
CENA = [n for n in ordem if n not in ISMS]
log("ISMs: %s" % ISMS)
log("componentes de cena (candidatos a raiz): %s" % CENA)

# ---- 1. garantir um componente de cena pra ser a raiz -------------------
# ATENCAO: "DefaultSceneRoot" e nome RESERVADO -- rename_subobject aceita a
# chamada mas a engine batiza de "Scene". Por isso guardamos o nome REAL.
if CENA:
    # prefere o DefaultSceneRoot (nome que a engine usa no vanilla); sobras
    # de tentativas anteriores ("Scene") sao removidas no fim.
    RAIZ = "DefaultSceneRoot" if "DefaultSceneRoot" in CENA else CENA[0]
    log("reaproveitando componente de cena existente: %s" % RAIZ)
    novo_h = m[RAIZ]
else:
    if rh is None:
        abortar("sem raiz e sem ancora pra criar o %s" % RAIZ)
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", rh)
    p.set_editor_property("new_class", unreal.SceneComponent)
    p.set_editor_property("blueprint_context", bp)
    novo_h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(novo_h):
        abortar("add_new_subobject falhou: %s" % motivo)
    sds.rename_subobject(novo_h, RAIZ)
    RAIZ = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(novo_h)))
    log("criada raiz de cena, nome real: %s" % RAIZ)

# ---- 2. promover a raiz ------------------------------------------------
try:
    ok = sds.make_new_scene_root(sds.k2_gather_subobject_data_for_blueprint(bp)[0], novo_h, bp)
    log("make_new_scene_root -> %s" % ok)
except Exception as e:
    log("make_new_scene_root falhou (%s) -- seguindo, o attach abaixo pode bastar" % e)

BEL.compile_blueprint(bp)

# ---- 3. pendurar os ISMs na raiz ---------------------------------------
m, _ = mapa(bp)
rh2 = m.get(RAIZ)
if rh2 is None:
    abortar("perdi o %s depois de compilar" % RAIZ)

presos, falhos = [], []
for n in ISMS:
    h = m.get(n)
    if h is None:
        falhos.append(n + "(sumiu)")
        continue
    # sem checar antes: attach_subobject e idempotente e is_attached_to exige
    # handle (nao SubobjectData) -- passar data levanta TypeError de nativizacao.
    try:
        if sds.attach_subobject(rh2, h):
            presos.append(n)
        else:
            falhos.append(n)
    except Exception as e:
        falhos.append("%s(%s)" % (n, e))

log("anexados a raiz: %s" % presos)
if falhos:
    log("FALHARAM: %s" % falhos)

# ---- 3b. varrer sobras de cena de tentativas anteriores -----------------
m2, ordem2 = mapa(bp)
sobras = [n for n in ordem2
          if n != RAIZ and "ISM" not in n and not n.startswith("RS_Prisma_")]
for n in sobras:
    try:
        sds.delete_subobject(sds.k2_gather_subobject_data_for_blueprint(bp)[0], m2[n], bp)
        log("removida sobra de cena: %s" % n)
    except Exception as e:
        log("nao removi a sobra %s: %s" % (n, e))

BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))

# ---- 4. conferencia ----------------------------------------------------
log("")
log("--- DEPOIS ---")
rn2, _ = raiz_atual(bp)
log("raiz: %s" % rn2)
m3, ordem3 = mapa(bp)
log("componentes: %s" % ordem3)
cdo = unreal.get_default_object(BEL.generated_class(bp))
try:
    rc = cdo.get_editor_property("root_component")
    log("RootComponent do CDO: %s" % (rc.get_name() if rc else "None"))
except Exception as e:
    log("RootComponent do CDO: (nao legivel: %s)" % e)
for e in cdo.get_editor_property("growup_process_sets"):
    log("  %-14s %-20s rate=%s" % (
        str(e.get_editor_property("state")).split(".")[-1],
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))

dump()
unreal.log("[rs26] FIM -> %s" % OUT)
