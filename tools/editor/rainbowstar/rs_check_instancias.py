# rs_check_instancias.py -- portao de qualidade ANTES de abrir o jogo.
#
# Le o JSON que o paldump gerou e conta PerInstanceSMData por ISM.
# Enquanto isso der 0/ausente, o mod continua com 0 mudas, ponto.
#
# Uso:
#   cd C:\PMK\paldump
#   dotnet run --no-build -- "Pal/Content/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"
#   python C:\PMK\rs_check_instancias.py
#
# (sem argumento compara o nosso com o Berries vanilla)

import json
import os
import sys

OUT = r"C:\PMK\paldump\out"
ESPERADO = {"CropISM": 16, "GrassISM": 9, "GrowupISM": 9}


def conta(nome_json):
    caminho = os.path.join(OUT, nome_json)
    if not os.path.isfile(caminho):
        return None
    with open(caminho, encoding="utf-8") as f:
        dados = json.load(f)
    r = {}
    for e in dados:
        if e.get("Type") == "InstancedStaticMeshComponent":
            pi = e.get("PerInstanceSMData")
            r[e["Name"].replace("_GEN_VARIABLE", "")] = -1 if pi is None else len(pi)
    return r


alvo = sys.argv[1] if len(sys.argv) > 1 else "BP_PalMapObjectFarmCrop_RainbowStar.json"
nosso = conta(alvo)
if nosso is None:
    print("ERRO: nao achei %s -- rode o paldump primeiro." % os.path.join(OUT, alvo))
    raise SystemExit(2)

van = conta("BP_PalMapObjectFarmCrop_Berries.json") or {}
print("componente         nosso   vanilla(Berries)")
falhou = False
for nome in sorted(nosso):
    n = nosso[nome]
    txt = "AUSENTE" if n < 0 else str(n)
    print("  %-16s %-7s %s" % (nome, txt, van.get(nome, "-")))
    if nome in ESPERADO and n != ESPERADO[nome]:
        falhou = True

print()
if falhou:
    print("REPROVADO: CropISM/GrassISM/GrowupISM precisam de 16/9/9. NAO instale o pak.")
    raise SystemExit(1)
print("APROVADO: instancias gravadas. Pode instalar o pak e testar no jogo.")
