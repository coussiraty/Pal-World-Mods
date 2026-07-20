# rs_28_renomeia.py -- tira o sufixo _0 dos ISMs de estagio.
#
# POR QUE: com o BP filho do BP do Tomate, os nomes CropISM/GrassISM/GrowupISM
# estavam ocupados pelos herdados, entao os nossos nasceram CropISM_0 etc.
# Depois do reparent pro nativo (rs_25) esses nomes ficaram LIVRES.
#
# EVIDENCIA de que o nome importa: em CurrentState=3 (Growup) o
# GrowupProcessSets manda popular GrassISM_0/GrowupISM_0 e eles ficam com 0
# mudas, enquanto um canteiro VANILLA na mesma passada tem 16. Ou seja: o jogo
# nao esta alimentando os nossos. A unica diferenca observavel e o sufixo.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_28_renomeia.py

import unreal

BP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
RENOMEAR = {"CropISM_0": "CropISM", "GrassISM_0": "GrassISM", "GrowupISM_0": "GrowupISM"}
IRMAOS = ["RS_Prisma_Wheat", "RS_Prisma_Tomato", "RS_Prisma_Lettuce",
          "RS_Prisma_Carrot", "RS_Prisma_Onion", "RS_Prisma_Potato"]
OUT = r"C:\PMK\rs_out.txt"

EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
out = []


def log(m):
    out.append(str(m)); unreal.log("[rs28] " + str(m))


def mapa(bp):
    m = {}
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None:
            continue
        n = str(SDL.get_variable_name(d))
        if n and n != "None" and n not in m:
            m[n] = h
    return m


bp = EAL.load_asset(BP)
m = mapa(bp)
log("ANTES: %s" % sorted(m))

for velho, novo in RENOMEAR.items():
    if velho not in m:
        log("  %s nao existe -- pulado" % velho); continue
    if novo in m:
        log("  %s JA existe -- nao renomeio %s" % (novo, velho)); continue
    sds.rename_subobject(m[velho], novo)
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(m[velho])))
    log("  %s -> %s%s" % (velho, real, "  (!! a engine deu outro nome)" if real != novo else ""))

BEL.compile_blueprint(bp)
m = mapa(bp)
log("DEPOIS: %s" % sorted(m))

# GrowupProcessSets tem que seguir os nomes novos
cdo = unreal.get_default_object(BEL.generated_class(bp))
S = unreal.PalFarmCropState
PLANO = [("GrassISM", S.GROWUP, 0.0), ("GrowupISM", S.GROWUP, 0.5),
         ("CropISM", S.HARVESTABLE, 1.0)] + [(n, S.HARVESTABLE, 1.0) for n in IRMAOS]
arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for nome, est, rate in PLANO:
    if nome not in m:
        log("  AVISO: '%s' ausente -- fora do GrowupProcessSets" % nome); continue
    cr = unreal.ComponentReference(); cr.set_editor_property("component_property", nome)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", est); s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)
cdo.set_editor_property("growup_process_sets", arr)
log("GrowupProcessSets: %d entradas" % len(arr))
log("salvo=%s" % EAL.save_loaded_asset(bp, False))

cdo2 = unreal.get_default_object(BEL.generated_class(bp))
for e in cdo2.get_editor_property("growup_process_sets"):
    log("  %-13s %-18s rate=%s" % (
        str(e.get_editor_property("state")).split(".")[-1],
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))
open(OUT, "w").write("\n".join(out))
