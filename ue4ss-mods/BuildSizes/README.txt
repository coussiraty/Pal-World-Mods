MiniBuilds 2.0 - resize any building
====================================

Everything you need is in ONE file next to this one:

    config.lua

1. Open it and find the building (493 listed, real in-game names, by category).
2. Change  enabled = false  to  enabled = true  and pick a size:

       1.0 = normal | 0.65 = smaller | 0.3 = tiny | 1.5 = bigger

3. Save the file. It reloads in game by itself about a second later.
4. In build mode, aim until the ghost is placed on valid ground, then re-select
   the building in the menu. It now spawns at your size.

Example line, straight from the file:

    { name = "Primitive Workbench",  class = "BP_BuildObject_WorkBench_C",  enabled = true,  size = 0.65 },


GOOD TO KNOW
------------
- The size lands on the build PREVIEW and on the FOOTPRINT, not just the model.
  That is what lets you stack buildings and butt them together.
- Buildings you already placed keep their old size. Rebuild them to update.
- Below about 0.25 a building can get hard to click. Bump the number back up,
  save, rebuild.
- If you break the file (missing comma, missing quote), the mod says so in
  UE4SS.log and keeps the previous config - nothing is lost, just fix and save.
- F7 forces a reload if you ever want it. You should not need it.
- Expedition Office, Ranch and Breeding Farm are marked [MiniBuilds] and left
  off here: the PalSchema part of the mod already sizes those three. Turning
  them on here too would apply the scale twice.


ADDING A BUILDING BY HAND
-------------------------
Copy any line and swap the class name (BP_BuildObject_<something>_C). Every
buildable structure in the game is already listed, so you should not need to.


REQUIRES
--------
UE4SS. PalSchema is needed for the three original buildings.
