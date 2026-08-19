# Vepxis

3D Action-RPG in Godot 4.7, set in the world of *The Knight in the Panther's Skin*.
This repo currently holds the **placeholder third-person controller** used for
greyboxing while the Blender models are in production.

```
godot --path .                                        # run the game
godot -e --path .                                     # open the editor instead
godot --path . --headless --script res://tests/smoke_test.gd   # movement checks
godot --path . --script res://tests/combat_test.gd -- /tmp      # creature + combat checks
```

`INSTRUCTION.md` has the same thing in Georgian, with the control scheme and the
usual first-run problems.

Stretch is **disabled**, so the viewport always matches the window exactly and
nothing is ever letterboxed — `canvas_items` with the default `keep` aspect puts
black bars around the game on any display that is not 16:9. F11 toggles
fullscreen.

`res://scenes/world/greybox_world.tscn` is the main scene: 120 × 120 m of flat
ground walled in at the edges, a 15° ramp, a 55° face that cannot be stood on, a
6-step staircase up to a platform, pillars to test camera collision, and a
watchtower, a medieval house and cart, boulders, meadows of grass and stone
clusters, and a handful of creatures wandering about.

## Node structure

```
Player (CharacterBody3D)          scripts/player.gd, collision layer "player"
├── CollisionShape3D              CapsuleShape3D, r 0.4 / h 1.85, offset y +0.925
├── Visuals (Node3D)              scripts/tariel_rig.gd, yawed 180°
│   └── Tariel                    assets/tariel/tariel.glb
└── CameraRig (Node3D)            top_level = true — yaw lives here
    └── SpringArm3D               spring_length 4.5, margin 0.3, mask "world"
        └── Camera3D              pitch lives on the arm
```

`Visuals` is yawed 180° because the model faces **+Z** while Godot's forward is
**-Z**.

The camera rig is `top_level`, so it never inherits the body's rotation: the
body turns to face where it is moving while the camera keeps its own yaw. The
script re-positions the rig every frame in `_process()` with exponential
damping, which also smooths out the y-pop when climbing stairs.

The `SpringArm3D` casts along its local **+Z**, so the `Camera3D` sits behind
and above the player and is pushed in automatically when a wall gets between
the two. The player's own capsule is excluded from that cast in `_ready()`.

## Input map

Already configured in `project.godot` — this table is for reference when you
add actions in **Project → Project Settings → Input Map**. All keys are bound by
*physical* keycode, so AZERTY/QWERTZ keyboards get ZQSD/WASD placement for free.

| Action         | Keyboard    | Gamepad          | Deadzone |
| -------------- | ----------- | ---------------- | -------- |
| `move_forward` | W           | Left stick up    | 0.2      |
| `move_back`    | S           | Left stick down  | 0.2      |
| `move_left`    | A           | Left stick left  | 0.2      |
| `move_right`   | D           | Left stick right | 0.2      |
| `jump`         | Space       | A / Cross        | 0.5      |
| `dash`         | Shift       | B / Circle       | 0.5      |
| `walk`         | Ctrl        | Left shoulder    | 0.5      |
| `attack`       | Left mouse  | X / Square       | 0.5      |
| `block`        | Right mouse | Right shoulder   | 0.5      |
| `toggle_fullscreen` | F11    | —                | 0.5      |
| `ui_cancel`    | Escape      | —                | built-in |

Escape releases the mouse; click-free re-capture is on the same key.

Mouse-look is read from `_unhandled_input()` because it needs the relative
motion of the event. Everything else is polled with
`Input.is_action_just_pressed()` in `_physics_process()`, so a press is never
lost between physics ticks and simulated input works in tests.

## Controller notes

- **Camera-relative movement.** `get_movement_direction()` builds the direction
  from the rig's basis, flattened on Y, so W is always "away from camera".
- **Jump.** `jump_height` is in metres and converted to an impulse from the
  project gravity (18 m/s², tuned for an action game). Coyote time (0.12 s) and
  a jump buffer (0.12 s) are in; releasing the button early cuts the arc short.
- **Dodge.** Fixed-duration state, not an impulse: rolls towards the input or
  straight ahead when standing still — 0.45 s at 11 m/s, i-frames for the first
  0.3 s via `is_invulnerable`, then a 0.22 s cooldown, and an eased exit that
  leaves a little momentum. It is deliberately *slower* than sprinting: a dodge
  buys invulnerability, not distance. It drives the somersault on the rig, and
  drops the shield.
- **Speeds.** Running is the default gait: 9 m/s with nothing held, 4.5 m/s
  while `walk` is held. Acceleration and deceleration are high (60 / 75) on
  purpose — at speed, low values read as ice: the character keeps sliding after
  the key is released and drifts the old way through a turn. The rig derives its stride rate from the actual ground
  speed, so changing these never makes the feet skate — and the stride *length*
  grows with speed (`run_stride_bonus`), because otherwise the legs would just
  churn faster and faster instead of reaching further per step.
- **Slopes.** `floor_constant_speed` keeps the solver from trading speed for
  height on a ramp, and `_slope_factor()` then applies a deliberate cost on top:
  running straight uphill loses up to `slope_climb_penalty` of the gait at the
  steepest walkable angle, running down gains a smaller `slope_descend_bonus`.
  Anything past `floor_max_angle` is not floor at all — `_slide_off_steep_ground()`
  redirects gravity along the face and cancels the component driving into it, so
  the player slithers off a boulder instead of juddering against its side.
- **In the air.** Air control steers the arc, it does not power it: the jump is
  capped at the speed it launched with (`_air_speed_cap`), and with no input the
  horizontal speed only bleeds off at `air_drag`, far gentler than the ground
  figure. Falls are capped at `max_fall_speed` so a long drop cannot tunnel, a
  ceiling kills the climb rather than scraping along it, and coming down faster
  than `hard_landing_speed` costs momentum on touchdown — `landed` carries the
  impact speed for the rig and the sound to use.
- **Contacts.** `_resolve_contacts()` reads back what the move actually hit:
  the steepest un-standable normal (for the slide above), the ceiling, and any
  `RigidBody3D` in the way, which takes an impulse scaled by how hard the
  capsule drove into it.
- **Stairs.** `CharacterBody3D` has no built-in stair stepping in 4.7, so
  `_step_up()` does the classic up → forward → down sweep with `test_move()`.
  It only fires against wall-like normals, so real walls still block, and the
  forward probe (`step_forward_probe`, 0.55) must stay larger than the capsule
  radius or the sweep lands on the ledge's edge instead of its top face.
- All tuning is exported and grouped in the inspector.

## The character: Tariel

`assets/tariel/tariel.glb` is the Tariel design exported from Claude — gold
armour over a crimson tunic, panther skin as a cape, sword in the left hand and
a round shield strapped to the right forearm. It is ~1.85 m tall with its origin
at the feet.

It ships with **no skeleton and no animation clips**: it is 135 meshes parented
into a joint hierarchy (`hips → spine → chest → shoulder_l → upperarm_l_end →
forearm_l_end → hand_l → sword`, and the mirror for the legs), plus trailing
chains for the cape (`cape_j0…j5`) and the ponytail (`tail_j0…j4`).

`scripts/tariel_rig.gd` animates it by rotating those joints:

- **Base pose.** The transforms inside the GLB are the *authored idle stance*,
  not a rest pose. The rig captures them on load and layers animation on top as
  offsets, so the silhouette that was tuned in the design is preserved. Only the
  leg joints are reset to their true rest values (from `extras.rest` in the
  file) — the shipped stance is a static contrapposto that would bias the walk.
- **Locomotion.** One stride cycle per `stride_length` of ground covered, so the
  feet keep pace at any speed. Hips and shoulders counter-swing, knees fold only
  on the back half of the stride, hips bob twice per cycle, and the torso leans
  in with speed.
- **States.** Airborne swaps the stride for a tuck; dashing adds a hard forward
  lean.
- **Shield.** The authored guard — shield up and across the chest — is only
  reached while `block` is held. Otherwise the arm blends down to
  `SHIELD_LOWERED` and the shield stows on the wrist, lying flat along the
  forearm. That stowed orientation is *solved*, not hand-tuned: `_setup_shield()`
  poses the arm as it hangs, then gives the shield the local rotation that puts
  its disc normal (the shield's own +Z) straight out from the body, so the plate
  never cuts through the torso. A raised guard is held rock steady — the walk
  counter-swing and dash tuck scale out as the shield comes up, and dashing
  drops it.
- **Sword.** Two swings, in `AttackStyle`: `OVERHEAD` raises the whole arm above
  the head and chops straight down; `SIDE` lifts the blade to shoulder height,
  draws it out wide and sweeps it flat across the body. The wrist is animated
  too (the `w` component of `_attack_pose()`) — carried, the blade points
  forward and down out of the hand, which is right for a chop but makes a
  horizontal swing read as waving the arm about, so the side cut rolls the wrist
  to lay the blade out along the arm and lead with the edge. `attack()` with no
  argument chains the two, so repeated clicks never land the same cut twice.
- **Swings are whole-body.** Driving the arm alone is what makes a character
  look mechanical, so `_update_attack()` produces a body pose alongside the arm
  pose: the torso coils away on the wind-up and unwinds through the strike, the
  hips lead the turn, the head counter-rotates to stay on the target while the
  shoulders swing underneath it, and the shield-side leg steps through and takes
  the weight (damped while already striding, so it never fights the walk cycle).
  The side cut also abducts the shoulder for the whole swing — swept across the
  chest at that height the upper arm would otherwise pass through the ribs, and
  the reach it loses comes back from the torso.
- **Air-cut streak.** `scripts/sword_trail.gd` keeps a short ring of world
  positions for the blade's base and tip and stitches them into a triangle
  strip, so the ribbon is the surface the edge actually swept — it follows any
  swing without being authored per attack. The streak fades off behind the blade
  rather than snapping away. It only emits while the blade is travelling.
  `sample_count`, `fade_time` and `tint` are exported.

  The mesh is allocated **once** and only its vertex positions are rewritten
  after that. Building a fresh surface every frame — `ImmediateMesh`, or
  re-adding one to an `ArrayMesh` — costs tens of milliseconds a frame on this
  renderer *no matter how few vertices are in it*: with two claw trails on one
  wolf it put 15% of frames over 50 ms, which hitched the whole game every time
  anything swung. Writing into the buffer that is already there costs nothing
  measurable. Two things follow from allocating up front: the ribbon always has
  `sample_count` slots and the samples are spread across all of them (repeats
  give zero-area triangles, which do not draw), and the fade is baked into the
  vertex colours once with the overall fade-out riding on the material alpha, so
  no attribute buffer is ever touched.
- **Sprint.** Not just faster: the lean deepens, the elbows pump in and the
  shoulders swing wider (`Sprint` group in the inspector). The sword arm keeps
  more of its extension than the shield arm and is carried further out from the
  body, since a long blade cannot fold in without sweeping over the shield.
- **Dodge roll.** `dodge(duration)` runs a forward somersault: a full turn about
  the hips eased in and out (so it starts and lands upright), with the body
  curling into a tight ball at the halfway point. The controller calls it when a
  dash starts, so the roll and the movement stay in sync.
- **Secondary motion.** The cape and ponytail chains chase the body with a
  per-link delay, so they sweep back in sequence rather than snapping.

Everything is exported and grouped in the inspector — stride, swing amplitudes,
lean, cloth stiffness.

> The model's own axes are used throughout: it faces +Z, so a *positive* X
> rotation on a limb swings that limb **backwards**.

### Import note

`nodes/use_name_suffixes` is **off** in `tariel.glb.import`. The gorget mesh is
named `neck_col`, and with suffixes on Godot reads `_col` as a collision marker
and builds a `StaticBody3D` with a concave shape inside the player — which then
fights the character body and launches it across the level.

## Props

The level carries a ~6 m watchtower at `Level/Tower` (world 14, 0, 8), a 12 m
medieval house at `Level/House` (-18, 0, -16) and a cart at `Level/Cart`
(-13, 0, -11). All three get their colliders from the importer.

`assets/tower/tower1.glb` is a ~6 m watchtower, sitting at `Level/Tower`
(world 14, 0, 8). Two things about it are worth knowing:

- **Its origin is nowhere near the tower.** The mesh sits about 13.6 m along -X
  and 3.6 m along +Z of the file's origin, so the instance under `Level/Tower`
  carries a counter-offset and the parent node is what you actually move.
- **Collision comes from the importer, not the scene.** `tower1.glb.import`
  carries a `_subresources` entry for `PATH:Tower/tower` with
  `generate/physics` and `physics/shape_type = 2` (trimesh), which builds a
  `StaticBody3D` with a concave shape around the model. That is the right tool
  for static level geometry — unlike the character, where the same mechanism
  firing on the `neck_col` mesh put a static body inside a moving body. The node
  path in that key is relative to the imported scene root and includes the
  intermediate node; `PATH:tower` alone silently does nothing.
- **Those paths use the *imported* node names, not the ones in the file.** Godot
  cannot put `.`, `:`, `@`, `/`, `"` or `%` in a node name, so the house's
  `beam long lp.001` arrives as `beam long lp_001`. A key written with the
  original name matches nothing and the collider is skipped in silence — which
  is exactly how the house ended up walk-through the first time.

### Weapons

Tariel's sword and shield are modelled into `tariel.glb`, but the ones actually
seen are `assets/sword/sword.glb` and `assets/shield/shield.glb`. `_swap_weapons()`
hides the built-in meshes and hangs the replacements off the same two attachment
points, so every pose, swing and block keeps working untouched.

The blade is also rolled about its own length (`sword_roll`). It is authored
lying flat, so without that it swings edge-up and lands with the side of the
steel rather than the edge.

Both replacements are authored on different axes than the mounts expect — the
sword lies along -Z with its grip offset from the origin, the shield lies flat
in XZ — so each is turned onto the mount's axes and, for the sword, slid back by
`sword_grip_offset` so the fist holds the grip rather than the model origin. The
trail's blade ends are marked out along the mount's +Y instead of being looked
up by name, since the replacement has no `blade_tip` node.

### Scatter

`Level/Scatter` holds ~1 700 grass clumps (`grass2.glb`) and 32 stone clusters
(`rock.glb`), and it is generated, not placed by hand:
`tools/build_scatter.py` rewrites that block of the scene.

The meadows are built out of `grass2.glb` alone. The other grass asset,
`grass.glb`, is a tenth of the triangles, but it ships untextured and reads as
flat green leaf cards rather than blades, so mixing it in makes the field look
worse rather than cheaper — `TUFTS_PER_CLUMP` is there if a textured version
ever arrives.

Grass is laid down as **meadows** rather than as an even scatter. A single tuft
every metre or so across the whole ground reads as noise; instead the script
fills a set of meandering ribbons and blobs (`RIBBONS`, `BLOBS`) on a jittered
hex lattice at `SPACING`, which is tight enough that neighbours overlap and the
patch merges into one continuous mat. Density and blade height both follow the
distance to the middle of the patch, so a meadow is deep in its core and thins
out to a soft border instead of ending on a hard circle. Everything else is left
as open ground.

`NO_GRASS` and `NO_ROCK` keep both out of the structures, and rocks additionally
out of the spawn clearing and the corridors the headless tests dash through. The
seed is fixed, so the same parameters always produce the same field:

```
python3 tools/build_scatter.py --dry-run   # report the counts
python3 tools/build_scatter.py             # rewrite the scene
```

The stones are solid: `rock.glb.import` carries a `_subresources` entry per rock
mesh (`PATH:Rocks/rock_big_1` and friends) with `generate/physics` and
`physics/shape_type = 1`, giving each one a convex hull. Convex rather than
trimesh because these are seven blobby lumps per cluster, and a hull is both
cheaper and smoother to walk over — they are about 0.4 m tall, so the
controller's step-up carries the player onto them. Grass has no collision; it is
meant to be walked through.

The scatter node runs `scripts/grass_field.gd`, which bends grass out of the way
and keeps the field swaying. Each clump keeps the orientation it was placed with;
the lean is layered on top as a rotation about a horizontal axis through the
clump's base, so blades tip away from whatever is pushing them and spring back
once it has passed. Rocks are left alone — only children whose name starts with
`grass_prefix` are touched.

Thousands of clumps cannot all be integrated every frame, so they are bucketed
into a uniform grid at startup and the work is split by what is actually needed:
clumps under a pusher run every frame, clumps still standing back up stay awake
until they have, everything else within `wind_radius` only gets the wind and is
spread over `wind_slices` frames, and anything further out is left alone. The
wind itself is a travelling wave — a pure function of position and time, which
is what lets a clump be skipped for a frame and pick the gust up where it is.
Beyond `draw_distance` the meshes stop being drawn at all.

The player is not the only thing that flattens grass: every body in the `enemy`
group pushes too, over a wider radius (`enemy_reach_scale`) since the creatures
are bigger.

### What the grass costs

`grass2.glb` is **8 256 triangles a clump**, so a meadow of them is by far the
most expensive thing in the scene and the settings that hold it down matter more
than they look:

- `casts_shadows` is **off**. Every clump would otherwise be re-drawn once per
  directional shadow cascade on top of the visible pass — measured at roughly
  half the frame, for shadows that at this size of blade are nearly invisible.
  The grass still *receives* shadows.
- `lod_bias` is **0.06**, so the LODs the importer generates are used far
  sooner than the default. Set per clump rather than through the viewport, so
  the buildings and creatures keep their detail. This alone halves the triangle
  count with no visible difference.
- `SPACING` in the generator is the count dial — instances go as 1/spacing², so
  it is the first thing to raise if the field has to get cheaper.

Standing in the deepest meadow with the creatures fighting, on an M1: 62 fps at
1600×900, 46 fps at 1080p, no frame over 25 ms. Before these three, the same
spot ran at 19 fps.

`grass.glb` ships with a `Leaf` material but no texture, so it renders as white
cards out of the box. `assets/grass/leaf_material.tres` is wired in through the
import's `use_external` material override to make it plain green until the real
texture arrives — the clumps in `grass2.glb` are textured and need nothing.

## Creatures

`scenes/enemies/` holds two, both placed under `Enemies` in the world.

**Wolf** (`wolf.gd` + `wolf_rig.gd`) — the model is the same kind of thing as
Tariel: a joint hierarchy with no skeleton and no clips, so it is animated the
same way. What it adds is a change of gait. Running on all fours and rearing up
to fight are two poses of the same joints, written out as offsets from rest
(`ON_ALL_FOURS` / `REARED`) and cross-faded by one `stance` value; stride, claw
swipes and tail are layered on whatever that blend produced. Gait is not decided
separately from the AI — covering ground means all fours, being within reach
means standing up, because that is where the claws are.

`_plant_feet()` measures the lowest hind paw after posing and lifts the hips by
that much, every frame. The creature swaps between two very different stances
and strides in both, so where its feet land is not worth hand-tuning per pose —
this way the stances can be changed freely without it sinking or hovering.

Claws use the same `SwordTrail` as the knight's blade, one per paw.

Creatures only travel the way they are facing — their speed is scaled by how
well their heading matches where they want to go. Turning and moving at once is
what made them crab sideways and back out of a turn. The wolf's gait is measured
against its *prowl* speed rather than its charge speed too; against the charge
speed a walk came out at 18% amplitude, which is a slide, not a step.

**Dismemberment.** The knight's blade is exposed as a world-space line segment
while it is travelling (`TarielRig.get_cutting_edge()`). If it passed within
`hit_tolerance` of anything still attached, a limb comes off — *which* one is
picked at random from what is left, because a fight where the same cut always
lands the same way stops being interesting after the second one. The severed
piece keeps its pose, is reparented into the world and falls
(`severed_limb.gd`), bleeding again where it lands.

The piece is built as a real node with the limb hung under it, not the limb
duplicated and given a script afterwards — a script attached to a node already
in the tree never gets its `_ready`, so the limb would hang in the air instead
of falling.

Losing both arms sends the creature into `FLEE`: it has nothing left to fight
with. Losing the head is fatal on its own, and death topples the body over. A
corpse has its `collision_layer` cleared rather than its shapes disabled: that
hides it from everything else while it keeps its own mask, so it stops blocking
the way but still rests on the ground instead of falling through the world.

A `HealthBar` floats over its head — two billboarded quads, the fill parented to
an offset pivot so it drains from one end rather than shrinking towards its
middle.

There is no navigation mesh, so a creature can walk itself into a rock.
`_watch_for_snags()` notices when it is asking to move and going nowhere and
sends it sideways for a moment. It watches the speed the creature *asked* for,
not the one it has: a body pinned against scenery reports almost none. A segment rather than a collision body,
because the point of a swing is *where* along the creature it lands — and this
needs no per-limb colliders. Each swing carries a serial so one cut takes one
limb; three limbs puts it down.

**Golem** (`golem.gd`) — a single mesh with no joints at all. Its legs
physically cannot move: there is nothing in the file to rotate. What it does
instead is carry the walk in the body — rocking side to side in time with its
steps, dipping on each footfall, leaning into turns. If the legs need to move,
the model has to come back rigged.

## Blood

`scripts/blood.gd` is built entirely in code from plain meshes and unshaded
materials — no texture to author, nothing to keep in sync with an art pass. A
hit throws a burst of droplets along the blow, lays flat patches on the ground
around it, and tints anything standing within `SPLATTER_RADIUS` by giving its
meshes a red `material_overlay` — an overlay rather than a replacement, so the
grass and stones keep their own texture and simply read as wet. The blade
darkens as it works, a third per cut.

The pool shape is a soft, ragged blob generated once as an image
(`Blood.splat_texture()`): a radial alpha falloff whose edge wanders in and out
around the circle. That wandering edge is the whole point — a straight falloff
still reads as the square quad it is drawn on.

`Blood.world_of()` is what everything parents effects to. `current_scene` is the
obvious answer but it is null whenever a scene was assembled by hand instead of
loaded as the main scene, which is exactly what the test harness does.

### Layers and bounds

Creatures sit on physics layer `enemy`, and the player's mask includes it, so
the knight is stopped by them instead of walking through. `Level` carries four
walls around the edge of the ground: without them a charging creature runs
straight off the world.

Both creature models are authored facing **+Z**, so both `Visuals` nodes carry
the 180° yaw the knight's does. Missing it does not look broken standing still —
it only shows up as the creature walking backwards. Two ways that went wrong
here, both worth remembering: the golem's per-frame body sway wrote the whole
`rotation` and wiped the yaw out, and the wolf model's `m_neck_col` mesh tripped
the importer's `_col` suffix rule exactly as the knight's `neck_col` did, giving
the creature a static collider inside itself that shoved it around the map.
`nodes/use_name_suffixes` is off for that file too now.

## Swapping in the real models

Replace the scene under `Visuals` with the imported knight, keep the origin at
the feet, and either keep driving it with `TarielRig` (if the joints are named
the same) or swap in an `AnimationTree` fed by the `state` enum plus the
`jumped` / `landed(impact_speed)` / `dash_started` / `attack_started` signals. Resize the
`CollisionShape3D` to the model and keep `max_step_height` below the capsule
radius.

## Layout

```
project.godot            input map, physics layers, gravity
icon.svg
scripts/player.gd        the controller
scripts/grass_field.gd   grass bending, wind, LOD and culling
scripts/sword_trail.gd   the streak a blade leaves, on a fixed vertex buffer
tools/build_scatter.py   generates the meadows in the world scene
scripts/tariel_rig.gd    procedural animation for the character
assets/tariel/tariel.glb the Tariel model
scenes/player/player.tscn
scenes/world/greybox_world.tscn
tests/smoke_test.gd      headless checks: movement, jump, dash, slopes, camera
tests/combat_test.gd     creature facing, arena bounds, blocking, dismemberment
tests/pose_shots.gd      renders one PNG per animation state
tests/screenshot.gd      renders a single frame to a PNG
```

```
godot --script res://tests/pose_shots.gd -- /tmp/poses   # idle, walk, run, jump, attack
```
