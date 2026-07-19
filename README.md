# Pal-World-Mods

Mods de Palworld feitos à mão, mais as ferramentas que uso pra construí-los.

Tudo aqui é código-fonte. **Nenhum asset do jogo é redistribuído** — as ferramentas
extraem e geram o que for preciso a partir da sua própria cópia instalada do Palworld.

---

## Instalação

Os mods se dividem em três mecanismos, cada um com seu destino:

| Pasta do repo | Vai para | Precisa de |
|---|---|---|
| `ue4ss-mods/<Nome>/` | `Palworld/Pal/Binaries/Win64/ue4ss/Mods/<Nome>/` | [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) |
| `palschema-mods/<Nome>/` | `.../ue4ss/Mods/PalSchema/mods/<Nome>/` | [PalSchema](https://github.com/Okaetsu/PalSchema) |
| `paks/` (gerado) | `Palworld/Pal/Content/Paks/LogicMods/` | UE4SS + Modding Kit pra recompilar |

Cada mod Lua é ativado por um arquivo vazio `enabled.txt` dentro da própria pasta.
**Não** edite `mods.txt` — se você usa Vortex, ele sobrescreve esse arquivo no deploy.

### Passo extra: gerar os ícones

A **RainbowStar** precisa de dois PNGs que **não estão no repo** — são derivados das
texturas do Palworld, e arte do jogo não se redistribui. Gere a partir da sua cópia:

```bash
cd tools/paldump && dotnet build          # uma vez
cd ../icones && pip install pillow numpy  # uma vez
python montar_icone.py
```

Ele extrai as texturas do seu jogo e escreve
`palschema-mods/RainbowStar/resources/images/{rainbow,rainbow_item}.png`.
Sem isso, o mod carrega mas a construção fica sem ícone.

---

## Os mods

### UE4SS (Lua)

| Mod | O que faz |
|---|---|
| **RainbowStar** | Plantação Prismática: uma colheita rende as 7 culturas de uma vez |
| **AutoHatchLua** | Chocar ovos automaticamente |
| **PalToBox** | Manda pal recém-chocado direto pra Palbox |
| **RemoteExpedition** | Coletar expedição de qualquer lugar |
| **ExpeditionXP** | XP pros pals que voltam de expedição |
| **EarlyUnlock** | Destrava tecnologia mais cedo |

### PalSchema (JSON)

| Mod | O que faz |
|---|---|
| **RainbowStar** | Item, construção, ícone e receita da Plantação Prismática |
| **EarlyTech** | Reordena a árvore de tecnologia |
| **BiggerRanch** | Rancho maior |
| **CakeFlourOnly** | Bolo só com farinha |
| **FastExpeditions** | Expedições mais rápidas |
| **StaminaElixir** | Elixir de estamina |
| **CustomTweaks** | Ajustes variados |

---

## Ferramentas (`tools/`)

O que tornou esses mods possíveis, em ordem de utilidade:

### `paldump/` — ler (e escrever) asset cozido do jogo, sem GUI
C#/.NET sobre CUE4Parse + UAssetAPI. Dispensa FModel e Blender.

```bash
dotnet run -- "Pal/Content/<caminho>"          # asset cozido -> JSON
dotnet run -- --mesh "<caminho>"               # mesh -> .glb
dotnet run -- --tex  "<caminho>"               # textura -> .png
dotnet run -- --dt-inspect "<DataTable>"       # ler DataTable
dotnet run -- --dt-write "<DataTable>" ...     # escrever DataTable
```

É a diferença entre adivinhar como o jogo funciona e simplesmente ler.

### `editor/ue_remote.py` — dirigir o Unreal Editor pelo terminal
Usa o Python Remote Execution oficial da Epic (vem no PythonScriptPlugin, sem
plugin de terceiro). Executa Python **dentro** do editor que já está aberto.

```bash
python ue_remote.py --ping
python ue_remote.py -c "unreal.log('oi')"
python ue_remote.py meu_script.py
```

⚠️ Serialize as chamadas — dois processos mandando ao mesmo tempo derrubam o editor.

### `editor/rainbowstar/` — os scripts que construíram a Plantação Prismática
`rs_01` … `rs_24`, na ordem em que rodaram. Servem de referência de como montar
blueprint por script: criar componente, reparentar, escrever no CDO, corrigir raiz.

### `icones/montar_icone.py` — ícone de construção no estilo do jogo
Os 7 ícones de plantação vanilla são **pixel-idênticos** fora de um retângulo
(`x 24..80, y 160..217`) — o "slot da fruta". Então dá pra recuperar o canteiro
**sem fruta** tirando a mediana dos 7: em cada pixel do slot a maioria das culturas
não cobre aquele ponto. O resultado é o canteiro vanilla de verdade, com a arte
nova só no lugar certo.

---

## Armadilhas que custaram caro

Anotadas porque cada uma queimou horas:

- **`LoopAsync` não roda na game thread.** Tocar em UObject ali derruba o jogo
  (5 minidumps até cair a ficha). Use `LoopInGameThreadWithDelay`.
- **Ponteiro nulo não vira `nil`** — vira userdata *truthy*. Só `obj:IsValid()` prova.
- **Out param muda a assinatura.** `GetInstanceTransform(idx, OutTransform, bWorldSpace)`
  tem 3 parâmetros; chamar com 2 faz o argumento escorregar pra vaga errada e não
  volta nada, em silêncio. Passe placeholder `{}` e leia o **2º retorno**.
- **Indexar TArray além do fim CRESCE o array real do jogo** (`AddZeroed`). Releia
  `GetArrayNum()` a cada volta.
- **`DT_MapObjectFarmCrop` casa a linha pelo campo `CropItemId`, não pelo nome da
  linha.** O invariante vanilla é `RowName == CropItemId`. Se divergirem, a planta
  não nasce — e não há erro nenhum no log.
- **Blueprint filho herda os componentes do pai.** Um crop BP filho do BP do Tomate
  carrega os ISMs do tomate *além* dos seus; se o `GrowupProcessSets` apontar pros
  herdados, o jogo alimenta os do tomate e os seus nunca recebem instância.
- **`FindAllOf` inclui subclasses e NÃO devolve CDO** (verificado em desassembly).
  Então "a lista veio vazia" nunca se explica por CDO.

---

## Licença

Código deste repo: MIT (veja `LICENSE`).

Palworld é da Pocketpair, Inc. Este repositório não é afiliado à Pocketpair e não
contém nenhum asset do jogo.
