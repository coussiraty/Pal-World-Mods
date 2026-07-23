# BuildSizes — the engine behind MiniBuilds 2.0

Resize **any** structure in Palworld from a config file — pure Lua, no PalSchema, no `.pak`.

Published as **MiniBuilds v2.0** ([Nexus 4143](https://www.nexusmods.com/palworld/mods/4143)).
The PalSchema half of MiniBuilds still sizes the original three (Expedition Office, Ranch,
Breeding Farm); those are listed here marked `[MiniBuilds]` and left disabled, so the scale is
never applied twice.

The structure already spawns at the chosen size **in build mode**, so you can stack pieces and
butt them together without weird collision. Scaling is **proportional**: size, part positions
and the footprint all shrink by the same factor.

## How to use

1. Open `config.lua` and find the structure (493 listed, English names, grouped by category).
2. Change `enabled = false` to `enabled = true` and pick a `size`
   (`1.0` normal · `0.65` smaller · `0.3` tiny · `1.5` bigger).
3. Save. The mod notices the file changed and reloads it on its own (~2 s). **F7** forces a
   reload if you want it — and it is the only way to pick up edits to `logic.lua` itself.
4. In build mode, aim until **the ghost is placed on valid ground**, then **re-select** the
   structure in the menu — it spawns at the new size.

Applies to what you build **afterwards**. Already-placed structures are untouched.

The 3 marked `[MiniBuilds]` are handled by that mod — leave them `false`, or the scale gets
applied twice.

## How it works

A class mold (CDO) can only be read while the class is alive, i.e. while the structure is up in
build mode. So a 600 ms game-thread tick watches
`PalBuildObjectInstallChecker.TargetBuildObject`, resolves the ghost's class and scales the mold
once.

The mold's components are **not** in `BlueprintCreatedComponents` — that one is per-instance,
filled during construction, and comes back empty on the CDO. They live in
`SimpleConstructionScript.AllNodes[i].ComponentTemplate`: the very same `<Name>_GEN_VARIABLE`
objects PalSchema patches. The mod walks the parent classes too, otherwise inherited components
are missed.

For every component it multiplies by the same factor: `RelativeScale3D`, `RelativeLocation` and
the footprint (`BoxExtent` / `SphereRadius` / `CapsuleRadius` / `CapsuleHalfHeight`). The root is
left alone, or the scale would be applied twice. Originals are cached per class+component, so
changing the number in the config does not multiply on top of the already scaled value.

## Regenerating the config after a game update

`tools/gen_buildsizes_config.py` rebuilds the whole list from the cooked game data
(`DT_BuildObjectDataTable_Common` + `DT_MapObjectMasterDataTable_Common` + the names from
`L10N/en/.../DT_MapObjectNameText_Common`), via `paldump`. It **overwrites** `config.lua` with
everything disabled — save your picks first.

To generate another language, point the script at that `L10N` dump. The base table, without
`L10N`, is in **Japanese** — that is the game's source language.

## UE4SS pitfalls this mod works around

- `GetName()` does not work in this build (returns nil for `UClass` and for components) — use
  `GetFName():ToString()`. The symptom is nasty: the code runs end to end, no error, and stays
  silent.
- Calling `ExecuteInGameThread()` from a key callback while a `LoopInGameThreadWithDelay` is
  active **kills the UE4SS game-thread queue** — loop and queue die together and only come back
  on a game restart. That is why F7 only raises a flag; the loop, already on the game thread,
  does the work.
- Returning `false` from a `LoopInGameThreadWithDelay` callback **kills the loop**. `false` is
  only correct inside `LoopAsync`.
- Never hardcode an absolute path. It works on the author's machine and silently fails on every
  other install. Both files derive their own folder from `debug.getinfo(1, "S").source`.
