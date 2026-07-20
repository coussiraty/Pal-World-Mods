# rs_30_instancias.py -- GRAVA AS MUDAS DENTRO DOS ISMs DO BP DA PLANTA.
#
# CAUSA (provada no asset, nao suposta):
#   As mudas de um canteiro NAO sao criadas em runtime. Elas sao dado autorado,
#   o array PerInstanceSMData, gravado dentro do proprio ComponentTemplate de
#   cada InstancedStaticMeshComponent no .uasset da planta. O codigo nativo so
#   liga/desliga a VISIBILIDADE do ISM certo por estado (GrowupProcessSets).
#
#   Todas as 9 culturas vanilla dumpadas tem esse array cheio:
#       Berries 16/9/9 | Lettuce 16/16/16 | Wheat 36/36/36
#       Carrot, Corn, Onion, Potato, Pumpkin, Tomato 9/9/9
#   O nosso BP tem a chave AUSENTE nos 9 ISMs (CropISM, GrassISM, GrowupISM e os
#   6 RS_Prisma_*). Num=0 -> GetInstanceCount()=0 em todo estado. E o sintoma.
#
#   Por isso trocar mesh, reparentar, renomear ISM e mexer no GrowupProcessSets
#   nao mudaram nada: nenhuma dessas coisas cria instancia.
#
# O QUE ESTE SCRIPT FAZ:
#   copia os transforms EXATOS do BP_PalMapObjectFarmCrop_Berries vanilla
#   (16 no CropISM em grade 4x4, 9 no GrassISM e 9 no GrowupISM em grade 3x3)
#   para os templates dos nossos ISMs, e iguala as propriedades de componente
#   que o vanilla tem e o nosso nao tinha (Z=10, sem colisao, sem nav,
#   Grass/Growup invisiveis).
#
#   Os 6 RS_Prisma_* ficam VAZIOS de proposito: quem enche eles e o main.lua
#   (bloco "visual prismatico"), que reparte as 16 instancias do CropISM entre
#   as 7 culturas em runtime. Se eu gravasse instancias neles, ficariam visiveis
#   para sempre -- eles nao estao no GrowupProcessSets, entao ninguem os esconde.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_30_instancias.py
# Depois: cozinhar + repackar, e ANTES de testar no jogo conferir:
#   cd C:\PMK\paldump && dotnet run --no-build -- "Pal/Content/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
#   -> no JSON, CropISM_GEN_VARIABLE tem que ter PerInstanceSMData com 16
#      entradas, e Grass/Growup com 9. Hoje a chave nem existe.

import unreal

BP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
OUT = r"C:\PMK\rs_out.txt"

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
out = []


def log(m):
    out.append(str(m))
    unreal.log("[rs30] " + str(m))


def gravar():
    open(OUT, "w").write("\n".join(out))


# ---------------------------------------------------------------------
#  transforms VANILLA, extraidos de C:\PMK\paldump\out\BP_PalMapObjectFarmCrop_Berries.json
#  (X, Y, Z, Yaw)  -- Z=0 na instancia; o offset de altura vem do componente
# ---------------------------------------------------------------------
CROP16 = [
    (-110.0, -110.0, 0.0,   68.09), (-110.0,  -36.7, 0.0, -107.26),
    (-110.0,   36.7, 0.0,   -8.92), (-110.0,  110.0, 0.0,  -13.36),
    ( -36.7, -110.0, 0.0,  131.97), ( -36.7,  -36.7, 0.0,   62.92),
    ( -36.7,   36.7, 0.0,  -64.71), ( -36.7,  110.0, 0.0,  -78.54),
    (  36.7, -110.0, 0.0,  144.93), (  36.7,  -36.7, 0.0,  -19.22),
    (  36.7,   36.7, 0.0,  -68.58), (  36.7,  110.0, 0.0,   31.32),
    ( 110.0, -110.0, 0.0,   42.64), ( 110.0,  -36.7, 0.0, -168.52),
    ( 110.0,   36.7, 0.0,  -18.19), ( 110.0,  110.0, 0.0, -111.41),
]
GRASS9 = [
    (-100.0, -100.0, 0.0,  -89.46), (-100.0,    0.0, 0.0,   41.67),
    (-100.0,  100.0, 0.0,  141.40), (   0.0, -100.0, 0.0,  126.04),
    (   0.0,    0.0, 0.0,  -37.42), (   0.0,  100.0, 0.0,   57.37),
    ( 100.0, -100.0, 0.0, -103.11), ( 100.0,    0.0, 0.0,  137.77),
    ( 100.0,  100.0, 0.0,  -77.61),
]
GROWUP9 = [
    (-100.0, -100.0, 0.0,  126.86), (-100.0,    0.0, 0.0,  -50.43),
    (-100.0,  100.0, 0.0,  135.09), (   0.0, -100.0, 0.0,   67.21),
    (   0.0,    0.0, 0.0,  -83.47), (   0.0,  100.0, 0.0,   70.15),
    ( 100.0, -100.0, 0.0,   94.15), ( 100.0,    0.0, 0.0,  -21.22),
    ( 100.0,  100.0, 0.0,   -7.00),
]

# nome do componente -> (transforms, visivel_por_padrao)
# Grass/Growup nascem invisiveis igual ao vanilla: quem acende e o nativo,
# pelo GrowupProcessSets.
PLANO = [
    ("CropISM",   CROP16,  True),
    ("GrassISM",  GRASS9,  False),
    ("GrowupISM", GROWUP9, False),
]
SO_PARIDADE = ["RS_Prisma_Wheat", "RS_Prisma_Tomato", "RS_Prisma_Lettuce",
               "RS_Prisma_Carrot", "RS_Prisma_Onion", "RS_Prisma_Potato"]


def mk_transform(x, y, z, yaw):
    return unreal.Transform(
        location=unreal.Vector(x, y, z),
        rotation=unreal.Rotator(0.0, 0.0, yaw),   # (roll, pitch, YAW) -- yaw e o 3o!
        scale=unreal.Vector(1.0, 1.0, 1.0))


def prop(comp, nome, valor):
    """set_editor_property que nao derruba o script se o nome mudar de versao."""
    try:
        comp.set_editor_property(nome, valor)
        return True
    except Exception as e:
        log("    aviso: nao consegui setar %s (%s)" % (nome, e))
        return False


def paridade_vanilla(comp, visivel):
    """iguala o template ao do Berries -- tudo isso faltava no nosso BP."""
    prop(comp, "relative_location", unreal.Vector(0.0, 0.0, 10.0))
    prop(comp, "generate_overlap_events", False)
    prop(comp, "multi_body_overlap", False)
    prop(comp, "has_per_instance_hit_proxies", True)
    prop(comp, "can_ever_affect_navigation", False)
    prop(comp, "visible", visivel)
    try:
        comp.set_editor_property("can_character_step_up_on",
                                 unreal.CanBeCharacterBase.ECB_NO)
    except Exception as e:
        log("    aviso: can_character_step_up_on (%s)" % e)
    try:
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    except Exception as e:
        log("    aviso: colisao (%s)" % e)


def povoar(comp, lista):
    """
    Rota 1: add_instance (a UFUNCTION que a propria engine usa).
    Rota 2 (se a 1 nao pegar no template): montar o array PerInstanceSMData na
    mao. PerInstanceSMData e UPROPERTY(EditAnywhere) do tipo
    TArray<FInstancedStaticMeshInstanceData>, e a struct so tem FMatrix Transform
    (UHTHeaderDump/Engine/Public/InstancedStaticMeshInstanceData.h).
    """
    try:
        comp.clear_instances()
    except Exception:
        pass

    ok = 0
    for (x, y, z, yaw) in lista:
        try:
            comp.add_instance(mk_transform(x, y, z, yaw), False)
            ok += 1
        except TypeError:
            try:
                comp.add_instance(mk_transform(x, y, z, yaw))
                ok += 1
            except Exception as e:
                log("    add_instance falhou: %s" % e)
                break
        except Exception as e:
            log("    add_instance falhou: %s" % e)
            break

    n = comp.get_instance_count()
    if n == len(lista):
        return n, "add_instance"

    # rota 2
    log("    add_instance deu %d/%d -- caindo pra PerInstanceSMData direto" % (n, len(lista)))
    arr = unreal.Array(unreal.InstancedStaticMeshInstanceData)
    for (x, y, z, yaw) in lista:
        d = unreal.InstancedStaticMeshInstanceData()
        d.set_editor_property(
            "transform",
            unreal.MathLibrary.conv_transform_to_matrix(mk_transform(x, y, z, yaw)))
        arr.append(d)
    comp.set_editor_property("per_instance_sm_data", arr)
    return comp.get_instance_count(), "per_instance_sm_data"


# ---------------------------------------------------------------------
bp = EAL.load_asset(BP)
if bp is None:
    log("ABORTADO: nao carreguei %s" % BP)
    gravar()
    raise SystemExit

comps = {}
for h in sds.k2_gather_subobject_data_for_blueprint(bp):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None:
        continue
    nome = str(SDL.get_variable_name(d))
    if not nome or nome == "None":
        continue
    obj = None
    for getter in ("get_object_for_blueprint", "get_object"):
        try:
            f = getattr(SDL, getter)
            obj = f(d, bp) if getter.endswith("blueprint") else f(d)
        except Exception:
            obj = None
        if obj is not None:
            break
    if isinstance(obj, unreal.InstancedStaticMeshComponent):
        comps[nome] = obj

log("ISMs achados no BP: %s" % sorted(comps.keys()))

faltando = [n for (n, _, _) in PLANO if n not in comps]
if faltando:
    log("ABORTADO: componentes ausentes -> %s" % faltando)
    gravar()
    raise SystemExit

for nome, lista, visivel in PLANO:
    c = comps[nome]
    paridade_vanilla(c, visivel)
    n, via = povoar(c, lista)
    log("%-10s -> %d/%d instancias (via %s) visivel=%s"
        % (nome, n, len(lista), via, visivel))

for nome in SO_PARIDADE:
    c = comps.get(nome)
    if c is None:
        log("%-16s nao existe no BP (ok, o Lua so usa quem existir)" % nome)
        continue
    paridade_vanilla(c, True)   # visivel: o main.lua enche eles em runtime
    log("%-16s so paridade, 0 instancias de proposito (quem enche e o main.lua)" % nome)

BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))

# --------------------------- verificacao ----------------------------
log("--- conferencia pos-save ---")
for h in sds.k2_gather_subobject_data_for_blueprint(EAL.load_asset(BP)):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None:
        continue
    nome = str(SDL.get_variable_name(d))
    obj = None
    try:
        obj = SDL.get_object_for_blueprint(d, bp)
    except Exception:
        try:
            obj = SDL.get_object(d)
        except Exception:
            obj = None
    if isinstance(obj, unreal.InstancedStaticMeshComponent):
        log("  %-16s instancias=%d" % (nome, obj.get_instance_count()))

log("")
log("PROXIMO PASSO: cozinhar + repackar e conferir ANTES de abrir o jogo:")
log('  cd C:\\PMK\\paldump && dotnet run --no-build -- "Pal/Content/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"')
log("  esperado no JSON: CropISM_GEN_VARIABLE PerInstanceSMData=16, Grass=9, Growup=9")
log("  se a chave PerInstanceSMData nao aparecer, o pak saiu errado de novo.")
gravar()
