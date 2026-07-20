# rs_29_tres_entradas.py -- volta o GrowupProcessSets ao formato VANILLA (3 entradas).
#
# EXPERIMENTO DECISIVO. Fatos do log:
#   * canteiro vanilla: 9 mudas.
#   * o nosso: 0 mudas em TODO componente, em Growup E em Harvestable,
#     antes e depois de renomear pros nomes vanilla.
# Ou seja: nome nao era a causa. A unica diferenca que sobra e a FORMA do array
# -- 9 entradas, sendo 7 no mesmo estado+limiar (Harvestable@1.0). Nenhuma das
# 9 culturas vanilla faz isso; eu assumi que a engine honraria e nunca provei.
#
# Se com 3 entradas a planta voltar a nascer (framboesa), esta provado que o
# array duplicado e o que quebra, e as 7 culturas passam a ser trabalho do Lua
# (que ja sabe repartir instancias).
#
# Os 6 RS_Prisma_* CONTINUAM no BP, so saem do array -- o Lua precisa deles.
#
# Rodar:  cd /c/PMK && python ue_remote.py rs_29_tres_entradas.py

import unreal

BP = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
OUT = r"C:\PMK\rs_out.txt"
EAL = unreal.EditorAssetLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
BEL = unreal.BlueprintEditorLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
out = []


def log(m):
    out.append(str(m)); unreal.log("[rs29] " + str(m))


bp = EAL.load_asset(BP)
nomes = set()
for h in sds.k2_gather_subobject_data_for_blueprint(bp):
    d = sds.k2_find_subobject_data_from_handle(h)
    if d is None:
        continue
    n = str(SDL.get_variable_name(d))
    if n and n != "None":
        nomes.add(n)
log("componentes: %s" % sorted(nomes))

S = unreal.PalFarmCropState
PLANO = [("GrassISM", S.GROWUP, 0.0),
         ("GrowupISM", S.GROWUP, 0.5),
         ("CropISM", S.HARVESTABLE, 1.0)]

cdo = unreal.get_default_object(BEL.generated_class(bp))
arr = unreal.Array(unreal.PalFarmCropGrowupProcessSet)
for nome, est, rate in PLANO:
    if nome not in nomes:
        log("ABORTADO: componente '%s' nao existe" % nome)
        open(OUT, "w").write("\n".join(out))
        raise SystemExit
    cr = unreal.ComponentReference(); cr.set_editor_property("component_property", nome)
    s = unreal.PalFarmCropGrowupProcessSet()
    s.set_editor_property("state", est)
    s.set_editor_property("target_comp_ref", cr)
    s.set_editor_property("process_rate", rate)
    arr.append(s)
cdo.set_editor_property("growup_process_sets", arr)
log("GrowupProcessSets: %d entradas (formato vanilla)" % len(arr))
log("os 6 RS_Prisma_* seguem no BP, fora do array -- o Lua usa eles")
log("salvo=%s" % EAL.save_loaded_asset(bp, False))

cdo2 = unreal.get_default_object(BEL.generated_class(bp))
for e in cdo2.get_editor_property("growup_process_sets"):
    log("  %-13s %-12s rate=%s" % (
        str(e.get_editor_property("state")).split(".")[-1],
        e.get_editor_property("target_comp_ref").get_editor_property("component_property"),
        e.get_editor_property("process_rate")))
open(OUT, "w").write("\n".join(out))
