# MiniBuilds 2.0

Resize **any** structure in Palworld from a config file — pure Lua, no PalSchema, no `.pak`.

Published on [Nexus 4143](https://www.nexusmods.com/palworld/mods/4143). v1 sized three
buildings through PalSchema; v2 does everything itself, and the PalSchema half is gone — with
both in place the scale compounded on the meshes but not on the part positions, which pulled
the buildings apart.

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

There are two separate problems, and both have to be solved:

**What spawns next** — the class mold. Scaling it makes every future spawn right, including the
build-mode ghost, which is what lets you place things already at size.

**What is already standing** — the buildings in your base. Writing `RelativeScale3D` onto a live
component changes the number and nothing else: Unreal caches the world transform and only
recomputes it when a setter runs. `SetActorScale3D` on the actor is the right tool — one call,
and meshes, child positions and collision all scale together.

Telling the two apart cannot be done by reading values. It is done by fact: at the instant a
mold is patched, everything of that class alive right then predates it; anything appearing later
came out of the fixed mold and is left alone.

The whole thing is driven by `NotifyOnNewObject` on `/Script/Pal.PalBuildObject` — the moment a
build object appears is also the only moment its class is guaranteed to be loaded. Polling was
tried and measured: a `StaticFindObject` for a class that is not loaded costs ~10 ms, and the
`FindFirstOf` that used to detect build mode cost ~10 ms per tick on its own. Doing either every
600 ms hitched the game; backing off instead made the base load at full size.

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
- `FindAllOf` has to name the **native** class (`PalBuildObject`). Asking for the blueprint class
  by name returns a single object and finds none of the buildings in the world.
- Count what actually **changed**, not what was inspected. A counter that reported objects
  visited read as success while nothing was happening.
