# Cria 7 material instances tingidas -- uma "cultura" por cor -- sobre o
# material do tomate. O parametro se chama "Color Tint" (visto no MI_Tomato_01).
import unreal
EAL = unreal.EditorAssetLibrary
tools = unreal.AssetToolsHelpers.get_asset_tools()
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[cor] " + str(m))

DEST = "/Game/Mods/RainbowStar/Materials"
# cores das 7 culturas
CORES = [
    ("Berries", (0.90, 0.20, 0.25)),
    ("Wheat",   (0.95, 0.80, 0.30)),
    ("Tomato",  (0.95, 0.35, 0.20)),
    ("Lettuce", (0.45, 0.85, 0.35)),
    ("Carrot",  (1.00, 0.55, 0.15)),
    ("Onion",   (0.75, 0.55, 0.95)),
    ("Potato",  (0.80, 0.65, 0.45)),
]

# acha o material importado junto com o mesh do tomate
pai = None
for cand in ("/Game/Mods/RainbowStar/Meshes/MI_Tomato_01",
             "/Game/Mods/RainbowStar/Meshes/MI_TomatoLeaves_01"):
    if EAL.does_asset_exist(cand): pai = cand; break
if not pai:
    achados = [a for a in EAL.list_assets("/Game/Mods/RainbowStar/Meshes", recursive=True, include_folder=False) if "MI_" in a or "Material" in a]
    log("materiais no projeto: %s" % achados[:10])
    pai = achados[0].split(".")[0] if achados else None
log("material pai: %s" % pai)

if pai:
    EAL.make_directory(DEST)
    fac = unreal.MaterialInstanceConstantFactoryNew()
    for nome, (r,g,b) in CORES:
        path = "%s/MI_Prisma_%s" % (DEST, nome)
        mi = EAL.load_asset(path) if EAL.does_asset_exist(path) else \
             tools.create_asset("MI_Prisma_%s" % nome, DEST, unreal.MaterialInstanceConstant, fac)
        if not mi: log("FALHOU criar %s" % nome); continue
        mi.set_editor_property("parent", EAL.load_asset(pai))
        unreal.MaterialEditingLibrary.set_material_instance_vector_parameter_value(
            mi, "Color Tint", unreal.LinearColor(r, g, b, 1.0))
        EAL.save_asset(path)
        log("MI_Prisma_%-8s tint=(%.2f, %.2f, %.2f)" % (nome, r, g, b))
with open(OUT,"w") as f: f.write("\n".join(lines))
