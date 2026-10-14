# Third-party packs in the project (added 2026-10-15)

The user brought these in from the Godot Asset Library. They were unpacked into the project's **root**, not under `assets/`, and are **not in git yet**. Moving them later must be done in the Godot editor (FileSystem dock → Move), so the paths inside their scenes follow.

## 1. Stylized Nature MegaKit (Quaternius) — for the environment
**What it is for:** the user's word — we build the world's nature with it: trees, bushes, grass, flowers, rocks, paths.

- **Licence:** CC0 (public domain); see `License_Standard.txt`. This is the free version: 68 of the kit's 116 models.
- **Where it is:**
  - `glTF/`: the format to use in Godot (157 files with textures).
  - `FBX/`, `FBX (Unity)/` and `OBJ/`: the same models in other formats.
  - `Textures/`: the bark and leaf textures, shared with Slavic World.
  - `Preview_1..4.jpg`: preview images.
- **Models:**
  - Trees: CommonTree 1–5, Pine 1–5, DeadTree 1–5, and the twisted / giant-pine leaves.
  - Bushes: Bush_Common, Bush_Common_Flowers.
  - Grass: Grass_Common Short/Tall, Grass_Wispy Short/Tall.
  - Flowers and plants: Clover 1–2, Fern, Flower 3/4 Group/Single, Petal 1–5, Plant 1/7 (+Big).
  - Mushrooms: Mushroom_Common, Mushroom_Laetiporus.
  - Rocks: Pebble Round 1–5, Pebble Square 1–6, RockPath Round/Square (Small 1–3, Thin, Wide).
- **How to use it:**
  - Trees, rocks and paths: instance them by hand or from `Forest` / `LandsPlaces`, scaled to our heroes (Tariel is about 1.95 m).
  - Grass and flowers: use a MultiMesh, as `Meadows` / `GrassField` already do. Keep the batches cheap, because smoke_test watches the physics tick.

## 2. Slavic World Free (EmacEArt)
It came in alongside the MegaKit; the user has not said what it is for yet.

- **Licence:** free for personal and commercial use; the assets may not be resold or redistributed on their own (see `LICENSE.txt`).
- **Contents:** 238 ready scenes in `Prefabs/`:
  - buildings, roofs, walls, fences;
  - roads, bridges, rocks;
  - furniture and crockery;
  - trees, bushes and grass.
- **Collision:** buildings, rocks and trees come with StaticBody collision; grass and bushes have none.
- **Other folders:** `Objects/`, `Materials/`, `Terrain/`, `Skybox/`, `SourceFiles/`, `Demo/` (demo scenes "Slavica Free") and `Documentation/`.
- **Its shaders:** `shaders/EA_GrassWind`, `EA_Skybox`, `EA_Water`. The palette is `Textures/EA03_FREE_Slavica.png`.
- It is the same artist as our graveyard kit (NecroPOLY, `assets/necropoly`), so the two styles match.

## 3. Shard Shatter (Joyless) — `addons/ShardShatter`
**What it is for:** the user's word — maybe for skills or magic.

- **Licence:** MIT.
- **What it does:** `ShardShatter.shatter_target(node)` runs in two steps:
  1. It covers the node's meshes with a glowing overlay that fades over `fade_duration`.
  2. It hides the node and breaks it into `shatter_amount` glowing shards (GPUParticles3D), which fly apart and fade.
  - `on_finished(target)` is emitted at the end.
  - Colour, glow, speed, damping and size can all be set.
  - It is a `@tool` script, so a "Shatter" button tries it in the editor.
- **Where it could fit:**
  - The mage's frost: a frozen enemy shatters into ice shards (Frost Nova / FrostShell); a pale blue colour fits.
  - Death of skeletons, golems and summoned creatures, instead of sinking into the ground.
  - Illusions and decoys that break when struck (the assassin's blink and clones).
  - The black sun or a dark rift: a dark crimson shatter.
- **Before using it:**
  - The default 1024 shards are too heavy for many at once; 150–300 are enough for an ordinary enemy.
  - Particles are added to the tree root, so on a network each peer has to run it itself, as our other effects do.

## Also untracked: `addons/simplegrasstextured` (IcterusGames, v2.1.0)
- An editor plugin that paints textured grass.
- It is in the project but not enabled in project.godot.
