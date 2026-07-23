MiniBuilds 2.0 - resize any building
====================================

Everything you need is in ONE file next to this one:

    config.lua

1. Open it and find the building (493 listed, real in-game names, by category).
2. Change  enabled = false  to  enabled = true  and pick a size:

       1.0 = normal | 0.65 = smaller | 0.3 = tiny | 1.5 = bigger

3. Save the file. That is it - the size is applied right away, and again every
   time you load in.

Example line, straight from the file:

    { name = "Primitive Workbench",  enabled = true,  size = 0.65,  class = ... },


GOOD TO KNOW
------------
- The size lands on the build PREVIEW and on the FOOTPRINT, not just the model.
  That is what lets you stack buildings and butt them together.
- Buildings already standing are resized too - nothing to tear down.
- Below about 0.25 a building can get hard to click. Bump the number up, save.
- If you break the file (missing comma, missing quote), the mod says so in
  UE4SS.log and keeps the previous config - nothing is lost, just fix and save.
- F7 forces a reload if you ever want it. You should not need it.
- Do not edit "class" or "path" - that is how the mod finds the building.
- Expedition Office, Ranch and Breeding Farm are the three v1 shrank. They come
  pre-enabled at their old sizes, so updating changes nothing until you say so.
  If you are coming from v1, DELETE the old PalSchema/mods/MiniBuilds folder -
  leaving it in place scales those three twice.


ADDING A BUILDING BY HAND
-------------------------
Copy any line and swap the class name (BP_BuildObject_<something>_C). Every
buildable structure in the game is already listed, so you should not need to.


REQUIRES
--------
UE4SS. PalSchema is not needed.
