# importa os 21 .glb exportados do pak pro nosso Content.
# Agora os meshes ficam DENTRO do nosso pak: sem dummy, sem import morto.
import os, glob, unreal
EAL = unreal.EditorAssetLibrary
OUT = r"C:\PMK\rs_out.txt"
DEST = "/Game/Mods/RainbowStar/Meshes"
lines=[]
def log(m):
    lines.append(str(m)); unreal.log("[imp] " + str(m))

# limpa o triangulo de teste
if EAL.does_asset_exist(DEST + "/tri"):
    EAL.delete_asset(DEST + "/tri"); log("removido tri de teste")

arquivos = sorted(glob.glob(r"C:\PMK\paldump\meshes\**\*.glb", recursive=True))
log("glb encontrados: %d" % len(arquivos))

tasks = []
for f in arquivos:
    t = unreal.AssetImportTask()
    t.set_editor_property("filename", f)
    t.set_editor_property("destination_path", DEST)
    t.set_editor_property("automated", True)
    t.set_editor_property("replace_existing", True)
    t.set_editor_property("save", True)
    tasks.append(t)

unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks(tasks)

meshes, mats = [], []
for a in EAL.list_assets(DEST, recursive=True, include_folder=False):
    nome = a.split("/")[-1].split(".")[0]
    if nome.startswith("SM_"): meshes.append(nome)
    else: mats.append(nome)
log("StaticMesh importados: %d" % len(meshes))
for m in sorted(meshes): log("   " + m)
log("materiais/texturas vindos junto: %d" % len(mats))

with open(OUT,"w") as f: f.write("\n".join(lines))
unreal.log("[imp] FIM")
