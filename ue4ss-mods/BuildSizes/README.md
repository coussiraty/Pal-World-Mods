# BuildSizes

Redimensiona **qualquer construção** do Palworld por um arquivo de config — em Lua puro,
sem PalSchema e sem `.pak`.

A estrutura já nasce no tamanho escolhido **no modo de construção**, então dá pra empilhar
e encostar sem colisão esquisita. A escala é **proporcional**: tamanho, posição das peças e
o footprint (área ocupada) encolhem pelo mesmo fator.

## Como usar

1. Abra `config.lua`, ache a estrutura (493 listadas, nome em inglês, por categoria).
2. Troque `enabled = false` por `enabled = true` e escolha o `size`
   (`1.0` normal · `0.65` menor · `0.3` bem pequeno · `1.5` maior).
3. Salve e aperte **F7** dentro do jogo.
4. No modo de construção, mire com **o fantasma pousado num chão válido**, e depois
   **re-selecione** a estrutura no menu — ela nasce no tamanho novo.

Vale para o que for construído **depois**. O que já está no chão não muda.

As 3 marcadas `[MiniBuilds]` já são tratadas por aquele mod — deixe `false`, senão a escala
é aplicada duas vezes.

O config é em **inglês** (nomes, chaves e instruções) porque o mod é feito pra publicar. Para
gerar em outro idioma, aponte o gerador pro dump do `L10N/<idioma>` correspondente — a tabela
base, sem `L10N`, é em **japonês** (idioma-fonte do jogo).

## Como funciona

O molde de uma classe (CDO) só pode ser lido enquanto ela está viva, ou seja, com a estrutura
no modo de construção. Então um tick de 600 ms na game thread olha
`PalBuildObjectInstallChecker.TargetBuildObject`, descobre a classe do fantasma e escala o
molde uma vez.

Os componentes do molde **não** estão em `BlueprintCreatedComponents` (isso é de instância,
preenchido na construção — no CDO vem vazio). Estão em
`SimpleConstructionScript.AllNodes[i].ComponentTemplate` — os mesmos `<Nome>_GEN_VARIABLE`
que o PalSchema patcheia. O mod sobe também pelas classes-pai, senão perde componente herdado.

Para cada componente, multiplica pelo mesmo fator: `RelativeScale3D`, `RelativeLocation` e o
footprint (`BoxExtent` / `SphereRadius` / `CapsuleRadius` / `CapsuleHalfHeight`). O root fica
de fora (senão a escala dobra). O valor original é cacheado por classe+componente, então
mudar o número no config não multiplica em cima do já escalado.

## Regenerar o config quando o jogo atualizar

`tools/gen_buildsizes_config.py` remonta a lista inteira a partir do cozido do jogo
(`DT_BuildObjectDataTable_Common` + `DT_MapObjectMasterDataTable_Common` + os nomes de
`L10N/en/.../DT_MapObjectNameText_Common`), via `paldump`. Ele **sobrescreve** o `config.lua`
com tudo em `false` — guarde suas escolhas antes de rodar.

## Armadilhas do UE4SS que este mod evita

- `GetName()` não funciona nesta build (devolve nil para `UClass` e componente) — use
  `GetFName():ToString()`. O sintoma é cruel: o código roda inteiro, sem erro, e sai calado.
- Chamar `ExecuteInGameThread()` de dentro de um callback de tecla, com um
  `LoopInGameThreadWithDelay` ativo, **mata a fila de game thread do UE4SS** — as duas morrem
  juntas e não voltam sem reiniciar o jogo. Por isso o F7 só levanta uma flag; quem trabalha é
  o próprio loop, que já está na game thread.
- `return false` no callback do `LoopInGameThreadWithDelay` **mata o loop**. O `false` só é
  correto dentro do `LoopAsync`.
