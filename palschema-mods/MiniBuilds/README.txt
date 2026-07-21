MiniBuilds — make base buildings smaller (or bigger)
=====================================================

Requires UE4SS + PalSchema.

HOW TO CHANGE A BUILDING'S SIZE
-------------------------------
Every building has its own file in the "blueprints" folder. Open it in Notepad and
change the RelativeScale3D numbers. That's it.

  0.65 = 65% of normal size      0.5 = half size      1.0 = normal (no change)
  0.25 = quarter size            1.5 = 50% bigger

Keep X, Y and Z the same for a uniform resize (e.g. all three = 0.5).

  blueprints/expedition.json   -> Expedition Office
  blueprints/monsterfarm.json  -> Ranch
  blueprints/breedfarm.json    -> Breeding Farm  (has two meshes — change both)

After editing: restart the game. Buildings you ALREADY placed keep their old size —
rebuild them to see the change (the placement preview shows the new size right away).

ADD ANOTHER BUILDING
--------------------
Copy one of the files, rename it, and put the building's blueprint id + its mesh
component name inside. Mesh/box component names differ per building; the safe ones to
resize are free-standing buildings (tables, chests, decoration, farms). Walls, foundations,
roofs and stairs use grid snapping and may misalign if resized — avoid those.

ADVANCED — placement footprint (Expedition only)
------------------------------------------------
"CheckOverlapCollision" with a "BoxExtent" controls how much space the building needs when
placing (so you can put buildings closer together). It does NOT scale with RelativeScale3D —
you set the box size directly. To match a new scale, use: original x scale.
Expedition original BoxExtent = X 1267.93, Y 493.26, Z 361.57
(e.g. for 0.25: X 316.98, Y 123.32, Z 90.39). This is optional — the visual size is the
RelativeScale3D numbers above.
