#!/usr/bin/env python3
"""
Gera os icones da Plantacao Prismatica a partir da SUA copia instalada do
Palworld. Nenhuma arte do jogo e redistribuida neste repositorio -- por isso
este script existe: clonou, rodou, tem os icones.

Produz dois arquivos em palschema-mods/RainbowStar/resources/images/:

    rainbow_item.png   as 7 culturas em circulo (icone do item colhido)
    rainbow.png        o canteiro vanilla com o circulo no lugar da fruta
                       (icone da construcao, na roda de construcao)

COMO FUNCIONA (a parte interessante)
------------------------------------
Os 7 icones de plantacao do jogo -- T_icon_buildObject_FarmBlockV2_<Cultura> --
sao PIXEL-IDENTICOS fora de um unico retangulo, x 24..80 / y 160..217, que e o
"slot da fruta". Entao da pra recuperar o canteiro SEM FRUTA NENHUMA tirando a
mediana dos 7: em cada pixel do slot, a maioria das culturas nao cobre aquele
ponto, e a mediana devolve o canteiro (ou a transparencia) de verdade.

O resultado e o canteiro vanilla legitimo, com arte nova so onde deve.
Tentar escurecer/recolorir na mao o icone generico (o de /Texture/BuildObject/
Icon/, que e palido e sem fruta) nao chega perto -- ja tentei, varias vezes.

REQUISITOS
----------
  * paldump compilado    (tools/paldump)
  * pip install pillow numpy

USO
---
  python montar_icone.py [--paldump <dir>] [--saida <dir>]
"""

import argparse
import math
import os
import subprocess
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
    import numpy as np
except ImportError:
    sys.exit("faltou dependencia:  pip install pillow numpy")

# nomes como estao NO JOGO -- repare que trigo e "wheet" (typo do proprio jogo)
CULTURAS = ["Berries", "wheet", "tomato", "Lettuce", "Carrot", "Onion", "Potato"]
ICONE_CANTEIRO = "Pal/Content/Pal/Texture/BuildObject/PNG/T_icon_buildObject_FarmBlockV2_%s"

# ordem do circulo: comeca em cima e gira no sentido horario
ITENS = ["Berries", "Tomato", "Carrot", "Wheat", "Lettuce", "Onion", "Potato"]
ICONE_ITEM = "Pal/Content/Others/InventoryItemIcon/Texture/T_itemicon_Food_%s"

# slot da fruta no icone vanilla -- medido comparando os 7, nao chutado
SLOT_CX, SLOT_CY = 54, 190
SLOT_LADO = 80


def paldump(dirdump, caminhos):
    """Extrai texturas do jogo. Devolve o diretorio onde os .png cairam."""
    cmd = ["dotnet", "run", "--no-build", "--", "--tex"] + caminhos
    r = subprocess.run(cmd, cwd=dirdump, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("paldump falhou:\n" + (r.stderr or r.stdout))
    return os.path.join(dirdump, "tex")


def recorta(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def circulo_das_7(tex, lado=256):
    """As 7 culturas em circulo, a partir dos icones de item do jogo."""
    tela = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    raio = lado * 0.30
    tam = int(lado * 0.34)
    for i, nome in enumerate(ITENS):
        p = os.path.join(tex, "T_itemicon_Food_%s.png" % nome)
        if not os.path.exists(p):
            print("  aviso: sem icone de %s -- pulado" % nome)
            continue
        ic = recorta(Image.open(p).convert("RGBA"))
        w, h = ic.size
        esc = tam / float(max(w, h))
        ic = ic.resize((max(1, int(w * esc)), max(1, int(h * esc))), Image.LANCZOS)
        ang = -math.pi / 2 + 2 * math.pi * i / len(ITENS)
        cx = lado / 2 + raio * math.cos(ang)
        cy = lado / 2 + raio * math.sin(ang)
        tela.alpha_composite(ic, (int(cx - ic.width / 2), int(cy - ic.height / 2)))
    return tela


def canteiro_sem_fruta(tex):
    """Mediana dos 7 icones de plantacao -> o canteiro limpo, sem fruta."""
    pilha = []
    for c in CULTURAS:
        p = os.path.join(tex, "T_icon_buildObject_FarmBlockV2_%s.png" % c)
        if not os.path.exists(p):
            sys.exit("faltou o icone extraido: %s" % p)
        pilha.append(np.array(Image.open(p).convert("RGBA")).astype(np.float32))
    med = np.median(np.stack(pilha), axis=0)
    # a mediana suaviza a borda do alpha; endurece pra nao sobrar franja
    med[..., 3] = np.where(med[..., 3] > 128, 255, 0)
    return Image.fromarray(med.astype(np.uint8), "RGBA")


def compor(base, circ):
    circ = recorta(circ)
    w, h = circ.size
    esc = SLOT_LADO / float(max(w, h))
    circ = circ.resize((max(1, int(w * esc)), max(1, int(h * esc))), Image.LANCZOS)

    # sombra de contato, como as frutas vanilla tem
    sombra = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sombra).ellipse(
        [SLOT_CX - circ.width * 0.34, SLOT_CY + circ.height * 0.22,
         SLOT_CX + circ.width * 0.34, SLOT_CY + circ.height * 0.44],
        fill=(40, 22, 10, 105))
    base = Image.alpha_composite(base, sombra.filter(ImageFilter.GaussianBlur(4)))
    base.paste(circ, (SLOT_CX - circ.width // 2, SLOT_CY - circ.height // 2), circ)
    return base


def main():
    aqui = os.path.dirname(os.path.abspath(__file__))
    raiz = os.path.abspath(os.path.join(aqui, "..", ".."))
    ap = argparse.ArgumentParser()
    ap.add_argument("--paldump", default=os.path.join(raiz, "tools", "paldump"))
    ap.add_argument("--saida", default=os.path.join(
        raiz, "palschema-mods", "RainbowStar", "resources", "images"))
    a = ap.parse_args()

    if not os.path.isdir(a.paldump):
        sys.exit("nao achei o paldump em %s (use --paldump)" % a.paldump)

    print("extraindo texturas do jogo...")
    alvos = [ICONE_CANTEIRO % c for c in CULTURAS] + [ICONE_ITEM % i for i in ITENS]
    tex = paldump(a.paldump, alvos)

    os.makedirs(a.saida, exist_ok=True)

    print("montando o circulo das 7 culturas...")
    circ = circulo_das_7(tex)
    p_item = os.path.join(a.saida, "rainbow_item.png")
    circ.save(p_item)
    print("  ->", p_item)

    print("recuperando o canteiro vanilla (mediana dos 7 icones)...")
    base = canteiro_sem_fruta(tex)

    print("compondo o icone da construcao...")
    p_build = os.path.join(a.saida, "rainbow.png")
    compor(base, circ).save(p_build)
    print("  ->", p_build)

    print("\npronto.")


if __name__ == "__main__":
    main()
