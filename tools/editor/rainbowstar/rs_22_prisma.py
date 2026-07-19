# Monta a planta prismatica: 7 ISMs com o MESMO mesh de tomate, cada um com
# uma cor. O CropISM_0 herdado vira a cor 1; os outros 6 sao novos.
import unreal
EAL = unreal.EditorAssetLibrary; BEL = unreal.BlueprintEditorLibrary
SDL = unreal.SubobjectDataBlueprintFunctionLibrary
sds = unreal.get_engine_subsystem(unreal.SubobjectDataSubsystem)
OUT = r"C:\PMK\rs_out.txt"; lines=[]
def log(m): lines.append(str(m)); unreal.log("[pri] " + str(m))

BP   = "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
MESH = "/Game/Mods/RainbowStar/Meshes/SM_Tomato_03a"
MATS = "/Game/Mods/RainbowStar/Materials/MI_Prisma_%s"
ORDEM = ["Berries","Wheat","Tomato","Lettuce","Carrot","Onion","Potato"]

bp = EAL.load_asset(BP)
def mapa():
    m, root = {}, None
    for h in sds.k2_gather_subobject_data_for_blueprint(bp):
        d = sds.k2_find_subobject_data_from_handle(h)
        if d is None: continue
        if SDL.is_default_scene_root(d): root = h
        n = str(SDL.get_variable_name(d))
        if n and n != "None": m[n] = h
    return m, root

def alvo(h):
    d = sds.k2_find_subobject_data_from_handle(h)
    return (SDL.get_object_for_blueprint(d, bp) or SDL.get_object(d)) if d else None

comps, root = mapa()
log("componentes herdados: %s" % sorted(comps.keys()))

# 1) o CropISM herdado recebe a cor da 1a cultura
nome_crop = next((n for n in comps if n.startswith("CropISM")), None)
if nome_crop:
    c = alvo(comps[nome_crop])
    if c:
        mi = EAL.load_asset(MATS % ORDEM[0])
        c.set_editor_property("override_materials", [mi])
        log("%s -> cor de %s" % (nome_crop, ORDEM[0]))

# 2) os outros 6 como componentes novos
mesh = EAL.load_asset(MESH)
for crop in ORDEM[1:]:
    nome = "RS_Prisma_%s" % crop
    if nome in comps: log("%s ja existe" % nome); continue
    p = unreal.AddNewSubobjectParams()
    p.set_editor_property("parent_handle", root)
    p.set_editor_property("new_class", unreal.InstancedStaticMeshComponent)
    p.set_editor_property("blueprint_context", bp)
    p.set_editor_property("conform_transform_to_parent", True)
    h, motivo = sds.add_new_subobject(p)
    if not SDL.is_handle_valid(h): log("ERRO %s: %s" % (nome, motivo)); continue
    sds.rename_subobject(h, nome)
    real = str(SDL.get_variable_name(sds.k2_find_subobject_data_from_handle(h)))
    c = alvo(h)
    if c:
        c.set_editor_property("static_mesh", mesh)
        c.set_editor_property("override_materials", [EAL.load_asset(MATS % crop)])
        log("%s -> cor de %s" % (real, crop))

BEL.compile_blueprint(bp)
log("salvo=%s" % EAL.save_loaded_asset(bp, False))
comps2, _ = mapa()
log("componentes finais: %s" % sorted(set(comps2.keys())))
with open(OUT,"w") as f: f.write("\n".join(lines))
