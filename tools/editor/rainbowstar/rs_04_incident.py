# rs_04_incident.py -- cria o BP do incident que vai fazer o drop na posicao certa.
# UPalIncidentBase::DropItem e BlueprintCallable mas PROTECTED -> so chamavel de
# dentro de uma subclasse. Por isso o BP precisa herdar de UPalIncidentBase.
import unreal
EAL = unreal.EditorAssetLibrary
tools = unreal.AssetToolsHelpers.get_asset_tools()
OUT = r"C:\PMK\rs_out.txt"
MOD = "/Game/Mods/RainbowStar"
NAME = "BP_Incident_RainbowStarDrop"

lines = []
def log(m):
    lines.append(str(m)); unreal.log("[rs04] " + str(m))

path = MOD + "/" + NAME
if EAL.does_asset_exist(path):
    log("ja existe: " + NAME)
    bp = EAL.load_asset(path)
else:
    f = unreal.BlueprintFactory()
    f.set_editor_property("parent_class", unreal.PalIncidentBase)
    bp = tools.create_asset(NAME, MOD, unreal.Blueprint, f)
    log("criado %s (parent UPalIncidentBase)" % NAME if bp else "FALHOU criar")
    if bp: EAL.save_asset(path)

# lista o que da pra chamar de dentro dele, pro passo a passo ficar exato
if bp:
    cdo = unreal.get_default_object(unreal.BlueprintEditorLibrary.generated_class(bp))
    log("--- funcoes uteis herdadas ---")
    for n in sorted(dir(cdo)):
        if any(k in n.lower() for k in ("drop", "getworld", "finish", "getarg")):
            log("   " + n)

with open(OUT, "w") as f: f.write("\n".join(lines))
unreal.log("[rs04] FIM")
