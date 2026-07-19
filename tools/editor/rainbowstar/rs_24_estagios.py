# rs_24_estagios.py -- conserta os dois defeitos do BP da planta RainbowStar.
#
# DEFEITO 1 (visivel pro usuario): os estagios de crescimento herdaram os meshes
#   do BP de TOMATE (SM_Tomato_01a / SM_Tomato_02a). Enquanto a planta cresce o
#   canteiro parece uma plantacao de tomate -- foi exatamente o que o usuario viu
#   ("ficou grande e so tinha tomates"). So o estagio final tinha sido trocado.
#   Conserto: brotos NEUTROS, os mesmos que a plantacao de bagas vanilla usa.
#
# DEFEITO 2: no estagio colhivel so o CropISM (framboesa) e alimentado, entao a
#   colheita mostra uma cultura so. Aqui entram as outras 6 no GrowupProcessSets,
#   todas em Harvestable@1.0.
#
#   ATENCAO -- ISSO E UM EXPERIMENTO CONTROLADO: nenhuma das 9 culturas vanilla
#   usa duas entradas no mesmo estado+limiar, entao NAO se sabe se a engine honra
#   todas ou so a primeira. O IDA esta fora do ar pra confirmar no binario. Os
#   dois desfechos sao seguros (no pior caso aparece so a framboesa, como hoje) e
#   o main.lua cobre os dois casos. O teste in-game decide.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_24_estagios.py
# Saida:  C:\PMK\rs_out.txt

import unreal

BP_PATH = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
OUT = r"C:\PMK\rs_out.txt"

# brotos neutros -- identicos aos da plantacao de bagas vanilla, que e a unica
# cultura cujos estagios 1 e 2 nao sao a propria fruta em miniatura.
#
# ATENCAO AO CAMINHO: existem DUAS copias de cada mesh neste projeto.
#   /Game/Pal/Model/...  e /Game/Others/...  -> DUMMIES (cubo de 48 tris, 0 materiais),
#       criados so pra reparentar classes. Cozinhar isso empacota um CUBO.
#   /Game/Mods/RainbowStar/Meshes/...        -> geometria REAL com materiais reais.
# O BP tem que apontar SEMPRE pra copia em /Game/Mods/RainbowStar/Meshes/.
MOD_MESHES = "/Game/Mods/RainbowStar/Meshes/"
BROTO = MOD_MESHES + "SM_pal_b00_flower_clovers_NordicConiferBiome"
MEIO = MOD_MESHES + "SM_pal_b00_bush_BlueBerry_NordicConiferBiome"

IRMAOS = ["RS_Prisma_Wheat", "RS_Prisma_Tomato", "RS_Prisma_Lettuce",
          "RS_Prisma_Carrot", "RS_Prisma_Onion", "RS_Prisma_Potato"]

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)

linhas = []


def log(m):
    linhas.append(str(m))
    unreal.log("[rs24] " + str(m))


def dump():
    open(OUT, "w").write("\n".join(linhas))


def abortar(m):
    log("ABORTADO: " + m)
    dump()
    raise SystemExit


log("=== rs_24_estagios ===")
if not EAL.does_asset_exist(BP_PATH):
    abortar("BP nao existe: %s" % BP_PATH)
for p in (BROTO, MEIO):
    if not EAL.does_asset_exist(p):
        abortar("mesh de estagio ausente no projeto: %s" % p)

bp = EAL.load_asset(BP_PATH)

# ---- mapa nome -> (handle, objeto editavel) ------------------------------
comps = {}
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
    if obj is None:
        obj = SDL.get_object(d)
    comps[nome] = obj

log("componentes no BP: %s" % sorted(comps.keys()))

log("")
log("--- ANTES ---")
for n in sorted(comps):
    o = comps[n]
    if o is not None and hasattr(o, "static_mesh"):
        try:
            m = o.get_editor_property("static_mesh")
            log("  %-22s %s" % (n, m.get_path_name() if m else "None"))
        except Exception as e:
            log("  %-22s (nao legivel: %s)" % (n, e))

# ---- DEFEITO 1: meshes dos estagios de crescimento -----------------------
log("")
log("--- consertando estagios de crescimento ---")
for nome, caminho in (("GrassISM", BROTO), ("GrowupISM", MEIO)):
    alvo = comps.get(nome) or comps.get(nome + "_0")
    if alvo is None:
        log("  AVISO: componente %s nao encontrado -- pulado" % nome)
        continue
    alvo.set_editor_property("static_mesh", EAL.load_asset(caminho))
    log("  %s -> %s" % (nome, caminho.rsplit("/", 1)[-1]))

# ---- DEFEITO 2: as 7 culturas no estagio colhivel ------------------------
# compilar ANTES de escrever o CDO: compile recria o CDO e descartaria a escrita.
BEL.compile_blueprint(bp)
log("")
log("compilado (pre-CDO)")

cdo = unreal.get_default_object(BEL.generated_class(bp))

S = unreal.PalFarmCropState
PLANO = [("GrassISM", S.GROWUP, 0.0), ("GrowupISM", S.GROWUP, 0.5),
         ("CropISM", S.HARVESTABLE, 1.0)]
PLANO += [(n, S.HARVESTABLE, 1.0) for n in IRMAOS]

arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for nome, estado, rate in PLANO:
    real = nome if nome in comps else (nome + "_0" if (nome + "_0") in comps else None)
    if real is None:
        log("  AVISO: '%s' nao existe no BP -- fora do GrowupProcessSets" % nome)
        continue
    cr = unreal.ComponentReference()
    cr.set_editor_property("component_property", real)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", estado)
    s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)

cdo.set_editor_property("growup_process_sets", arr)
log("GrowupProcessSets escrito: %d entradas" % len(arr))

log("save_loaded_asset -> %s" % EAL.save_loaded_asset(bp, False))

# ---- releitura (pega perda imediata; nao prova o disco) ------------------
log("")
log("--- DEPOIS (releitura do CDO) ---")
cdo2 = unreal.get_default_object(BEL.generated_class(bp))
for e in cdo2.get_editor_property("growup_process_sets"):
    log("  %-14s %-28s rate=%s" % (
        str(e.get_editor_property("state")).split(".")[-1],
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))

for n in ("GrassISM", "GrowupISM", "CropISM"):
    o = comps.get(n) or comps.get(n + "_0")
    if o is not None:
        m = o.get_editor_property("static_mesh")
        log("  mesh %-12s %s" % (n, m.get_path_name() if m else "None"))

dump()
unreal.log("[rs24] FIM -> %s" % OUT)
