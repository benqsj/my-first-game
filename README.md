# Vepxis

3D Action-RPG in Godot 4.7, set in the world of *The Knight in the Panther's Skin*.
This repo currently holds the **placeholder third-person controller** used for
greyboxing while the Blender models are in production.

```
godot --path .                                        # the menu, then the game
godot -e --path .                                     # open the editor instead
godot --path . --headless --script res://tests/smoke_test.gd   # movement checks
godot --path . --headless --script res://tests/archer_test.gd  # bow + target lock
godot --path . --headless --script res://tests/menu_test.gd    # menu + graphics
godot --path . --script res://tests/combat_test.gd -- /tmp      # creature + combat checks
godot --path . --headless --script res://tests/multiplayer_test.gd  # who owns what
godot --path . --headless --script res://tests/fighter_test.gd     # imps and puglins: bands, block, dash, combo, death
godot --path . --script res://tests/draw_budget.gd             # where the draw calls go
godot --path . --headless --script res://tests/physics_budget.gd  # where the physics tick goes
sh tools/two_peers.sh                                  # two processes, one world
```

`INSTRUCTION.md` has the same thing in Georgian, with the control scheme and the
usual first-run problems.

Stretch is **disabled**, so the viewport always matches the window exactly and
nothing is ever letterboxed — `canvas_items` with the default `keep` aspect puts
black bars around the game on any display that is not 16:9. F11 toggles
fullscreen.

`res://scenes/ui/main_menu.tscn` is the main scene — play, settings, out. Play
asks solo or co-op, then who you are, then loads the level.

`res://scenes/ui/main_menu.tscn
scenes/world/greybox_world.tscn` is that level: 240 × 575 m of
ground walled in at the edges — the old 240 m square, a marsh strip south of it
with a mere and a misty village on an island in it, and past that a bay with a
plank pier and orcs in the shallows — a 15° ramp, a 55° face that cannot be stood on, a
6-step staircase up to a platform, pillars to test camera collision, and a
watchtower, a medieval house and cart, boulders, meadows of grass and stone
clusters, and a handful of creatures wandering about.

The greybox proper is the clearing in the middle, about 30 m out from the spawn.
Past that the map is **divided**: a thousand trees of **woodland** filling the
west, a **settlement** of thatched huts along a street to the east with its
fields and hedgerows around it, and open meadow between the two. A ring of
**mountains** stands behind the boundary wall so the map ends in a skyline rather
than in thin air. None of that is in the scene file: the wood, the hedgerows, the
skyline and the meadows are each grown at load from a seed and a table of
numbers.

## Node structure

```
Player (CharacterBody3D)          scripts/player.gd, collision layer "player"
├── CollisionShape3D              CapsuleShape3D, r 0.4 / h 1.85, offset y +0.925
├── Visuals (Node3D)              built in _ready() from the chosen character
│   └── Tariel | Avtandil         the model, under its rig script
└── CameraRig (Node3D)            top_level = true — yaw lives here
    └── SpringArm3D               spring_length 4.5, margin 0.3, mask "world"
        └── Camera3D              pitch lives on the arm
```

`Visuals` is not in `player.tscn`: the controller builds it on spawn from
whichever [character](#characters) is being played, because the body, the camera
and every move are shared and the model is the thing that differs. Whatever is
built there is yawed 180°, because the models face **+Z** while Godot's forward
is **-Z**.

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
| `crouch`       | C           | Left stick click | 0.5      |
| `stow`         | Q           | Y / Triangle     | 0.5      |
| `lock_on`      | E           | Right stick click | 0.5     |
| double-tap `dash` | Shift Shift | B / Circle ×2 | 0.5      |
| `attack`       | Left mouse  | X / Square       | 0.5      |
| `block`        | Right mouse | Right shoulder   | 0.5      |
| `toggle_fullscreen` | F11    | —                | 0.5      |
| `ui_cancel`    | Escape      | —                | built-in |

Escape pauses: resume, settings, or out to the main menu. It is also what goes
back a page in a menu, and out of the game from the front one.

Nothing new is bound for climbing: on a wall, the move actions drive the body
along the face, `jump` pushes off it and `crouch` lets go.

`lock_on` takes the enemy in front of the camera and holds it. Both characters
have it: the knight circles what he is fighting, the archer shoots it. While
locked, a **flick of the mouse to one side takes the next enemy that way** —
accumulated over `target_switch_flick` pixels, so aiming never does it by
accident.

`stow` puts the sword and shield over the shoulder and takes them back off it.
Anything that needs them takes them back by itself — attacking, or raising the
shield — and climbing stows them of its own accord and hands the choice back
when the player lets go of the wall.

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
- **Dodge.** Fixed-duration state, not an impulse: towards the input, or
  straight ahead when standing still. It is deliberately *slower* than
  sprinting — a dodge buys invulnerability, not distance — and it drops the
  shield. The button does two things depending on how it is pressed:
  - **one tap** is the quick tumbling roll, 0.45 s at 11 m/s with 0.3 s of
    i-frames, animated procedurally as a somersault;
  - **two taps** inside `double_tap_time` upgrade the roll already under way
    into the library's `Sword_Dash`, 0.7 s at 8.5 m/s with 0.45 s of i-frames.

  The second tap *converts* the roll rather than the first tap waiting to see
  whether another is coming: holding the first press back until the window
  closed would put a visible stall on every single tap.
- **Crouch.** Held on `crouch`, at `crouch_speed` with the capsule at
  `crouch_height`. The pose is procedural — the library has no crouch of any
  kind — and folds under the walk cycle rather than replacing it, so creeping
  forward is the same stride, only lower and shorter. The hips are dropped by
  exactly as much as the folded legs shorten, worked out from the model's own
  thigh and shin, so the boots stay on the ground without a second number that
  has to be kept in step with the knee angle.
- **Speeds.** Running is the default gait: 7.2 m/s with nothing held, 3.6 m/s
  while `walk` is held. Everything that *travels* — both characters, the wolves
  and the golems — was taken down by a fifth from what it was, because the whole
  level read as being on fast-forward. The evades were left where they were: a
  roll is a burst and the complaint was about running. Acceleration and deceleration are high (60 / 75) on
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
- **Slide.** `crouch` off a run only: below `slide_min_speed` (5 m/s) there is
  nothing to slide on and it would just be a squat. It keeps the momentum that
  was already there plus `slide_boost`, bleeds off at `slide_drag`, and shrinks
  the capsule to `slide_height` about the **feet**, so going low never lifts the
  body or drops it through the floor. Standing back up is gated on there being
  room for the full capsule — under a low gap the slide simply carries on until
  the player is out from under it.
- **Ledge climb.** A ledge in front turns into a pull-up: on `jump` from the
  ground, and **on its own in mid-air**, so running at a wall and jumping is
  enough to get over it without timing a second button.
  `_find_ledge()` asks three questions in the order that rules the most out
  soonest: is there a face to grab at chest height, does it have a top edge
  between `climb_min_height` and `climb_max_height`, and is there `climb_headroom`
  to stand there. The floor of that band sits above `max_step_height`, so
  anything that can simply be walked up never becomes a climb. The body is then
  carried up *and then* in over `climb_duration` — a straight lerp between the
  two ends would drag it through the wall — with the clip stretched to match.
- **Wall climb.** Anything too tall to be mantled is climbed instead. `jump`
  against a face steeper than `wall_min_angle` takes hold of it, and so does
  meeting one in mid-air — so a house is something to go *up* rather than
  something to bounce off. The mid-air catch asks for *intent*, not speed: the
  stick pointing at the face, or the capsule already touching one. Asking how
  fast the body was travelling into it does not work, because by the time it is
  against a wall `move_and_slide()` has already cancelled the speed that drove
  it there, and a jump at a wall reads as having no interest in it.
  The mantle is always tried first: if the top is already in reach, pulling over
  it beats hanging off it.

  Hanging is its own state. Gravity is off, the stick is read in the *face's*
  frame rather than the camera's — forward is up the wall however the view is
  pointed — and the body is re-fitted against the surface every tick: the face
  is felt for at chest, hip and shoulder height and then round to either side,
  so a window, a beam or the corner of a building is worked across rather than
  dropped. Only the distance to the face is corrected, never the position along
  it, because sliding along it is what the stick is for.

  Three ways off. `jump` pushes away from the face; `crouch` lets go; and
  climbing to the top hands over to the mantle, which is checked *before* each
  upward move, because the face runs out at exactly the moment there is
  somewhere to stand. A top only counts when there is no wall left in front of
  the head — otherwise a first floor found inside a building would post the
  player through the wall they were climbing. Running out of holds sideways or
  upward puts the body back where its hands still had something and stops: a
  climber who runs out of wall stops climbing, they do not fall off.
- **Stairs.** `CharacterBody3D` has no built-in stair stepping in 4.7, so
  [StepUp] does the classic up → forward → down sweep with `test_move()`.
  It only fires against wall-like normals, so real walls still block, and the
  forward probe (`step_forward_probe`, 0.55) must stay larger than the capsule
  radius or the sweep lands on the ledge's edge instead of its top face.

  **The creatures use it too.** A wolf that cannot follow you up six greybox
  steps is a wolf you beat by standing on a step, which is not a fight. It is
  called before `move_and_slide()`, from the velocity the body is *about* to
  move with — afterwards that velocity has already been flattened against the
  step it failed to climb.
- **Bodies get in each other's way.** Everything with legs collides with
  everything else with legs: the enemy mask includes the enemy layer, so two
  wolves cannot stand in the same place and neither can walk through the player.
- All tuning is exported and grouped in the inspector.

## Characters

Two so far, and the number is meant to grow. A character is a
`CharacterProfile` resource — `scenes/player/*.tres` — holding a model, a weapon
and the handful of figures that differ:

| | Tariel | Avtandil |
| --- | ------ | -------- |
| weapon | sword and shield | bow |
| run | 5.6 m/s | 6.4 m/s |
| roll | 11 m/s × 0.45 s = 4.9 m | 13.5 m/s × 0.5 s = 6.8 m |
| crit | 10% | 30% |

Everything else — walking, jumping, dodging, crouching, sliding, climbing, the
target lock — is the same code for both, which is the point. The controller
takes the profile's numbers on spawn, hangs its model under `Visuals`, and
carries on. The fourth character is a fourth `.tres` and a fourth model, not a
fourth controller.

Who is played is held by the `Game` autoload, which the character-select screen
sets. It also reads the command line, which is how a test — or anyone who would
rather not click through — plays somebody without the menu:

    godot --path . -- avtandil

`scripts/character_rig.gd` is the shared rig (it was `tariel_rig.gd`; the knight
is no longer the only one wearing it) and `scripts/archer_rig.gd` extends it
with the bow. A model only has to name its joints the way the rig expects —
`hips`, `spine`, `chest`, `shoulder_l`, and the rest — to get the stride, the
climb and the jumps for nothing.

### Avtandil, and building a character in code

He is built by `tools/build_avtandil.gd`, which writes
`assets/avtandil/avtandil.tscn`:

    godot --path . --headless --script res://tools/build_avtandil.gd

That is the same shape of thing Tariel is — primitives on named joints, no
skeleton, no skinning — because that is what the rig drives. The output is a
`.tscn` rather than a `.glb` on purpose: it is text, so it reads in a diff, and
nothing has to be imported before it can be used. Re-running it is how his
proportions, palette or kit change; there is no binary to hand-edit.

He is leaner through the shoulders and longer in the leg than the knight, hooded
rather than helmeted, and dressed in greens and leather, with a quiver on his
back and a recurve in his hand. Same height, so the same capsule fits.

### The bow

Hold to draw, let go to loose, and how long it was held is the whole of it:

- a **tap** is away at once and lands for `snap_share` of a full draw (25%);
- a **full draw** takes `draw_time` (0.85 s) and lands for all of it, and the
  arrow leaves faster, so it drops less on the way;
- anything between is between.

So the choice is rate against weight rather than one button against another.
Drawing costs most of the run (`draw_speed_scale`), because an archer at a
sprint cannot aim and being able to would make every other approach pointless.
Rolling or climbing loses the draw — it is not banked.

Arrows fly slowly enough to be seen and stepped out of — 34 m/s off a full draw,
21 off a snap. That is necessary and nowhere near sufficient. An arrow is a
centimetre across crossing half a metre a frame, seen mostly end-on because that
is where the camera is; at that size the shaft is never actually on screen where
anyone is looking. What carries the shot is **the air it cuts**:

- a thin **line** down the flight path — the same ribbon the sword leaves, given
  a segment lying across the flight instead of along it. It is hung off a node
  that undoes the roll, so the band stays a flat sheet instead of winding into a
  corkscrew and pinching to nothing twice a turn;
- a wider, fainter **wake** around it, gone sooner. Two ribbons rather than one
  wide one because that is the difference between air parting and a searchlight:
  the edge of the wake has to be soft where the line down the middle is not;
- the shaft **rolls** as it goes, at `spin` turns a second, because fletching
  spins an arrow and a shaft that never turns over reads as a decal sliding
  across the screen.

**None of it is light.** An earlier pass gave the head a glow and put a flare at
each end of the flight, and what that read as was an explosion crossing the
field — the shot stopped looking like an arrow at all. Every colour in here is
capped at white on every channel, because past one they run into the glow pass;
`archer_test.gd` checks that and checks nothing flares. A critical shot cuts the
same air, only a little warmer. All of this matters most for a fight between two
players, where a shot nobody can see coming is a shot nobody can answer.

**The arrow leaves along the body, not along the camera.** The camera can be
looking anywhere; an arrow that leaves at forty degrees to the bow held on
screen is an arrow the player cannot aim, however correct the maths behind it.
`_shot_heading()` takes the *pitch* from the aim — so a shot can still be lofted
or put into something below without the body leaning — and the *bearing* from
the character. `_face_aim()` is the other half: while the string is held the
body turns onto the shot, at the target if there is one and down the camera if
there is not, so by the time it is loosed the two are one line. The rig leans on
the same number (`_aim_pitch()`), so what the body does and what the arrow does
are one figure rather than two that happen to agree.

**Aiming levels the camera.** The running camera sits twenty degrees above the
player looking down, which puts the middle of the screen — the crosshair — on
the ground a few metres ahead. Shot from there an arrow went into the dirt three
paces away, in a tenth of a second: it read as no arrow at all. While the string
is held the view eases towards level (`aim_camera_pitch`), and the mouse moves it
from there; with something locked the lock already owns the camera and this
stays out of it. A hit under the crosshair closer than `aim_min_range` is also
ignored, because that is the floor you are standing on rather than a target.

Arrows are **not** physics bodies. One crosses more ground in a tick than it is
long, so a collider would fly through a wolf as often as it hit one; instead
each tick draws a line from where the arrow was to where it is going and asks
what that line crossed, which cannot be tunnelled. What it hits it tells, via
`take_hit(damage, at, blow, critical)` — the same door the sword now goes
through, so a hit does not read differently for the weapon that landed it. Then
it sticks in what it hit and rides it until it sinks away.

The animation is procedural, like the crouch and the climb and for the same
reason: the library has forty-three clips and not one of them touches a bow. The
bow hand and the drawing hand are *solved* to where the bow and the string have
to be, and the string is pointed at wherever the drawing hand actually ended up
rather than at where a number says it should be.

A shot is four beats, not one pose, and the first three run on **different
clocks** — which is the whole of what makes it read as archery:

1. **Raise.** The bow arm goes straight out at the target and the drawing hand
   comes onto the string beside it, both in `aim_raise_time` (0.17 s) however
   long the draw is going to take. An archer puts the bow on the target and
   *then* pulls; an arm that comes up in step with the string spends the whole
   0.85 s of a draw being winched into place and at a quarter draw is still
   somewhere near the hip. Everything that is *held* — the bow, the hand on the
   string, the arrow across the rest, the bow's orientation — rides this rather
   than the draw. So does the follow-through: the arm stays up through the
   loose, because an arm that drops the moment the string goes has not shot
   anything.
2. **Set.** The feet go with the bow, not with the string: the bow-side foot
   steps forward, the weight settles between them, and the whole body turns
   side-on to the shot (`aim_torso_turn`, split across hips, spine and chest so
   what turns is the man and not his shoulders on top of a body still facing
   front). This is posture *and* mechanics. Square to the target there is
   nowhere for the drawing hand to go but out sideways, and the elbow ends up
   sticking off the ribs — which is what a wrong-looking draw **is**. Turning
   the body is what puts the elbow in behind the arrow, and it is why the stance
   is solved in `_pose_stance()`, with the legs, rather than with the arms.
3. **Draw.** The hand takes the string back to the jaw on an eased curve, the
   body leans back into it
   (`draw_lean`), the head stays on the arrow whatever the shoulders do under
   it, and the hands shake a little at the top (`draw_strain`) — a pose that is
   perfectly still does not read as effort. All of it is scaled by the draw
   *squared*, so a snap shot barely leaves the run and a full draw commits the
   whole body. The bow is built as a chain — grip → limb → horn → string — and
   the limbs bend back by `limb_flex` as the string comes in. That is what a
   drawn bow *is*: the limbs give and the string is straight between two ends
   that have moved. With rigid limbs the string bends round a shape that is not
   giving, which is exactly the thing that looks wrong.
4. **Loose.** `loose_bow()` snaps the limbs straight, throws the drawing hand
   open behind the ear and unwinds the torso over `loose_time`. That is the half
   of a shot that says it happened.

There is no reach-over-the-shoulder to fetch an arrow. It was built and then
taken out: it put a beat of rummaging in front of every shot, including the
tapped ones the archer is supposed to be fast at, and what the hands do while
aiming matters more than where the arrow came from. The model still carries the
spare (`bow_spare`); it is simply never shown.

Four things had to be right before it looked like archery rather than like a man
holding a stick:

- **The elbow has to be told where to go.** Two bones and a pinned hand leave
  exactly one thing free — which way round the shoulder-to-hand axis the elbow
  swings — and for an arm that one thing is most of the pose. Solved without
  choosing it, the drawing arm came out with the upper arm pointing at the sky
  and the forearm folded back down it: the hand in the right place and the arm
  a chicken wing. `_reach_with()` takes a **pole** per arm — the bow elbow rolls
  down and out of the string's way, the drawing elbow goes back and out behind
  the hand, level with the arrow — and gives the shoulder a whole basis rather
  than a pitch and a yaw, because a pitch and a yaw *are* the version with no
  elbow control. The basis is eased in by `slerp`, not by interpolating its
  three angles: an arm held out level sits on the euler singularity, where two
  sets of angles that mean the same orientation interpolate to something that
  means nothing at all.
- **A draw stops at the face.** The string comes back to the jaw — `0.71 m` from
  grip to hand on this model. Past that is not a longer draw, it is an arm
  coming out of its socket.
- **And it stops on its *own side* of the face.** The anchor reached 9 cm past
  the head's centre line and sat under the far cheek, and what that reads as is
  an arm wrapped round the archer's own neck. `archer_test.gd` measures all
  three: the draw length, where the elbow ends up, and that the hand never
  crosses the centre line.
- **The bow is placed after the body, not before.** It hangs off a hand whose
  orientation `_apply_pose()` has not written yet, so standing it upright before
  that used last frame's arm. `_place_props()` runs after, which is also where
  the string is pointed and the arrow slid back.
- **The string is aimed in the horn's frame, not the bow's.** Each half hangs
  off the horn the limb flex has just moved, so a pull point measured in the
  bow's frame and compared against a position in the horn's is two different
  rooms. It still looked like a string from some angles — it just also trailed
  off to a point near the archer's feet, 1.76 m from the hand that was supposedly
  holding it. `archer_test.gd` measures that gap now.
- **The bow is upright at rest too, not only when aimed.** Left to hang off the
  wrist it goes wherever the arm does, which lays it flat across the hip when he
  walks. Both ends of the carry are given in the model's frame instead: canted
  out from the leg while carried (`carry_cant`, `carry_lean`), square to the
  target while drawn.

### Target lock

`lock_on` takes the enemy nearest the middle of the view — angle first, distance
second, because what the player is looking at matters more than what happens to
be nearest — and holds it until it dies, leaves `lock_break_range`, or the
button is pressed again.

The camera swings onto the target and follows, rather than snapping: a lock that
jumps the view is a lock that loses the player.

What the **body** does under a lock is three rules, and they are what decide
where a shot and a cut go, because both leave along the way the character is
facing:

- **Standing, walking, or backing straight off** — faces the target. Holding
  ground is what a lock is for, and backing away from something while watching
  it is a thing people do.
- **Running anywhere else** — faces the way it is *going* (`lock_run_turns`).
  Once the player is running they are going somewhere, and a character
  sprinting sideways with his head over his shoulder is not going there.
- **Attacking** — snaps onto the target, instantly, before the swing or the
  shot is thrown. So running past something and cutting at it is not a free
  miss: movement belongs to the player, the attack belongs to the fight.

It watches from **above** the fight. The pitch it takes is the aim at the target
*minus* `lock_camera_tilt`, and both halves matter: negative pitch is what puts
the camera up and looks down, and the tilt is what keeps the ground between the
two of you on screen — the rig already rides above a wolf, so a pure aim comes
out nearly level and everything reads as a silhouette. Aimed the other way round
the camera ends up on the floor looking up the target's nose, which is the one
thing a lock-on camera must never do.

What is being fought is **marked**: one white dot on its body, drawn over
everything so it is never hidden behind the thing it is marking. With two wolves
in front of you a lock that shows nothing is a lock you have to guess at.

The dot is brighter than white — past 1 the colour runs into the glow pass, so
it reads as lit rather than as a sticker — with a small, faint halo, and it is
small itself (`size` 0.091, `grow_with_range` 0.007). Both have to be: its job
is to say *which*, and anything past the size that takes is sitting on top of
the thing being fought rather than pointing at it.

A locked shot **leads** its target. An arrow takes a beat to arrive and a wolf
does not wait where it was standing, so the aim is offset by where the target
will be, and lifted by the drop over the same flight. Without it a slow shot at
a moving target is a miss the player did nothing wrong to earn.


**Parts of a big creature.** Anything taller than 1.9 m has three places a
lock can sit — its legs, its belly and its head (`TargetPoints`, measured once
off the creature's own meshes; a head bone, where there is one, carries the top
point). A lock lands on the belly; a **flick of the mouse up or down** moves it
along the body, the same way a flick to the side changes creature. The camera,
the mark and the archer's shot all go to the part the lock is on. Anything
smaller keeps the single point it always had. The mark itself is a third of
the size it was.

    godot --path . --headless --script res://tests/target_parts_test.gd

## Commitment

**Once an attack is thrown it plays out.** No dodging out of it, no jumping out
of it, no cancelling it, no running out of it, and no second attack until the
first has finished. This is the Souls rule, and it is the single decision that
makes the rest of a fight mean anything.

The reason is worth stating, because the alternative looks generous and is not.
An attack that can be called off the instant it starts going wrong **costs
nothing to throw** — so there is no reason not to throw one at every opportunity,
and no reason for an opponent to read anything, because nothing they read can be
punished. Committing the swing is what puts a price on it, and the price is what
turns a fight into a sequence of decisions: *is this the moment, and can I afford
to be wrong about it?* It is also the half of this that will matter most when
there is a second player on the other end, which is where this is going.

**The first cut keeps its feet.** Committed does not mean slowed: the swing a
player ran in with is the one they meant to throw, and damping it the instant
the button goes down reads as slow motion rather than as weight. So the first
cut of a flurry — and anything thrown in the air, where the arc belongs to the
jump — moves at the speed it was thrown at. Everything chained off it is damped,
which is where the weight belongs: standing there hitting something is not a way
to cross ground. A flurry lapses after `chain_window`, so running in and hitting
something is always the fast swing however many were thrown a moment ago.

**And the legs run under it.** Mixamo's swings are played on the spot, so a cut
thrown out of a run kept the run's pace on a pair of planted feet and he skated
across the ground under the swing. `StrideModifier` (`scripts/stride_modifier.gd`),
a skeleton modifier the skinned rig adds, puts the stride back: while a swing
plays and the body is moving, the thighs, calves, feet and toes come from the
walk or run cycle that fits the way he is going, carried on from the phase the
run was at when the button went down, and the swing keeps the hips, the trunk
and the arms. It fades in and out over `stride_blend` (0.12 s);
`SkinnedRig.swing_strides` turns it off.

| | |
| --- | --- |
| `attacks_commit` | the rule itself, so it can be turned off to measure against |
| `commit_speed_scale` | 0.18 — what is left of the run, **for the cuts after the first** |
| `chain_window` | 0.5 s — how long a flurry is still running, after which the next cut is a first one again |
| `plunge_recovery` | 0.85 s — the blade in the ground at the end of a jumping attack, and the climb back out of it |
| `loose_recovery` | 0.34 s — the archer's equivalent, after the string goes |
| `attack_buffer_time` | 0.22 s — a press during a swing is *remembered*, not eaten, so a flurry is one press per cut at the player's own rhythm rather than a timing test |

**An attack off a jump comes down from over the head.** `AttackStyle.OVERHEAD`,
forced rather than taken in turn: a horizontal cut thrown off a jump is a man
swinging at the air he is passing through.

**And a plunge is owed its landing.** The chop happens in the air; what ends it
is the ground. The blade goes in in front of the feet, the knees fold under the
landing, the body comes over it — and then it takes `plunge_recovery` (0.85 s)
to pull it out and stand back up, committed the whole way. The fall is committed
too: there is no rolling out of a plunge halfway down.

That last part is the whole move. A jumping attack that ends with the character
on his feet and ready **costs nothing**, so there would be no reason ever to
throw anything else and nothing for an opponent to punish. Burying the sword and
getting it back out is what it is paid for with — the same price every
Souls-like charges for the same move. There is no stamina yet; this is the
stamina.

Measured: the tip comes down to **0.08 m** in front of the boots and is back at
the carry 0.85 s later. `plunge_arm` / `plunge_wrist` are what put it there —
the sword leaves the hand pointing forward and down, so the wrist is what turns
the point at the ground rather than at the horizon. The knee fold goes through
the same `_knee_fold()` the crouch uses, so the hips drop by exactly what the
folded legs cost and the boots stay on the floor without a second number.
[`DustRing`](scripts/dust_ring.gd) throws up dirt where it goes in: a ring lying
*on* the ground rather than a billboard facing the camera, dull and
alpha-blended, because displaced earth does not shine.

Choosing the chop turned out not to be the same as *playing* it. A procedural
swing is written into `_pose`, and `_apply_pose()` lets a running clip overrule
that joint by joint — and in the air the running clip is the fall loop, at full
weight over the whole body. The chop was being computed every frame and painted
straight over: the blade tip moved **7 cm** through an entire swing while the
damage landed on schedule, which is a man falling with his sword held still
while something invisible takes a limb off a wolf. `attack()` now **cuts**
whatever clip is holding the body, and `_track_airborne()` knows not to put the
fall loop back until the swing is done. Same measurement afterwards: **1.47 m**.
`combat_test.gd` drops him from a height — a jump's airtime is shorter than a
swing, so the landing clip would otherwise answer for it — and checks the tip
sweeps at least 0.8 m.

How long a swing commits for is the rig's answer, not a number in the
controller: `CharacterRig.swing_time()` reports the length of whichever clip it
chose to play, or the procedural swing's own duration when there is no library.
So a longer cut commits you for longer without anything being kept in step by
hand.

The draw is **not** committed — it can be held or let go of, which is the whole
of what a bow is — but the shot is: `_tick_bow()` treats the recovery as busy,
so the next draw cannot start until the arm has come down.

## The menu

`scripts/main_menu.gd` builds all four pages — the front, solo-or-co-op,
character select, settings — in code rather than in the editor, because almost
all of it is the same three widgets with the same styling and a script that
makes one button well makes twenty. Everything that decides how it looks is a
constant at the top of that file.

**Character select is three columns**: the roster down the left, whoever is
picked in the middle, and what picking them means on the right.

- The **roster** is a tile each — the character's *face*, with their name over
  it. A face rather than a figure because at that size a whole man is a shape,
  and small on purpose: the roster is for choosing, and everything there is to
  know about the choice is already on screen beside it. Four of them fit.
- The **stage** is the one picked, head to boots, turning. One portrait per
  character is built and only the picked one is shown — a `SubViewport` is not a
  thing to throw away and rebuild every time the player moves down a list, and
  the hidden ones neither draw nor pose anyone
  (`UPDATE_WHEN_VISIBLE`, plus an `is_visible_in_tree()` guard on `_process`).
- The **dossier** is generated from the profile: name, weapon, run speed, roll
  distance, crit chance, whether there is a shield to put up, and the blurb,
  with a "— faster" or "— further" against the knight wherever the numbers
  differ. So it cannot drift from the numbers the game actually uses. With one
  character on screen there is room to lay it out instead of stacking it under a
  portrait.

All three portraits are the same node ([`CharacterPortrait`](scripts/character_portrait.gd)),
with the camera in one of two places — `Frame.FULL` or `Frame.FACE`. What a
player chooses between is a hooded archer and an armoured knight, and neither of
those is a table of numbers.

It is the **same model the game spawns**, under the **same rig**, with
`animate()` called once a frame at a standstill — so the breathing, the weight
on the feet and where the weapons hang all come for free, and a change to the
archer's bow or the way he carries it shows up on his card without the menu
knowing anything about it. A rendered portrait would be a second thing to keep
in step, out of date the first time the model changed. Each portrait owns its
own `World3D`, so two of them side by side neither light nor see each other.

Two things the portrait has to undo: the `Visuals` scene carries a half turn —
the models face +Z and the body they hang off faces Godot's -Z — so left in
front of a camera it presents its back, and the *stand* is turned rather than
the model so what the game spawns stays exactly what the game spawns. And the
fill light is cool and weak: a warm fill as strong as the key turns anything
broad, like the knight's cape, into a flat gold slab with no shape left in it.

Choosing **MULTIPLAYER** goes to one more page after the character select —
host, or type an address and join. The character has to be picked first because
it is sent with the announcement; see [Multiplayer](#multiplayer).

`scripts/pause_menu.gd` is the same widgets again, in the level rather than in
front of it: resume, settings, or out to the main menu. It runs while the tree
is paused — it is the one thing that has to — and unpauses on the way out, or
the front menu would load paused and nothing on it could be clicked.

## Multiplayer

Two to four people, one world, PvE. A **listen server**: the host is peer 1 and
is also playing, so there is no dedicated server, no matchmaking and no lobby
browser. [`scripts/net.gd`](scripts/net.gd) is the whole of the connection.

    godot --path . -- --host tariel
    godot --path . -- --join 127.0.0.1 avtandil

or **PLAY → MULTIPLAYER →** pick who you are **→ HOST GAME** / type an address
and **JOIN**. In the editor, `Debug → Run Multiple Instances → 2`, then
`Debug → Customize Run Instances…` and give the two the arguments above.

### Who simulates what

| | |
| --- | --- |
| your own body and camera | your own client |
| somebody else's body | nobody — it arrives over the wire and is interpolated |
| wolves, golems | the host |
| "did this sword cut this wolf?" | the host |
| blood, severed limbs, corpses | decided by the host, replayed everywhere |

Movement is **client-authoritative**: you are trusted about where you are. A
malicious client can lie, and that is accepted for now — there is no prediction,
no reconciliation and no rollback, and there is no tick buffer to write.

### The one thing combat needed

**Hit detection here is enemy-driven, not player-driven.** A player's swing
never looks for a target; the wolf does. `Wolf._take_hits()` notices a new
`attack_serial` on an attacker, asks that attacker's rig for the blade as a line
segment, and severs whatever it passed through.

That turns out to be exactly the right shape. Gate the wolves' thinking to the
host, replicate the *swing* so that the host's copy of a remote knight throws
the same cut at the same moment, and hit detection becomes host-authoritative
**with no change to the combat logic at all**. One RPC does it:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func net_attack(style: int) -> void
```

`call_local` because the attacker has to play its own swing too; `reliable`
because a dropped swing is a missed kill.

**The bow is the same trick twice.** An arrow here is not a physics body — it is
a start, a velocity and a sweep, which is deterministic — so `net_loose` tells
every peer where one left and how fast, and every peer builds the same flight
and draws the same streak. What they do not all do is the damage:
`Wolf.take_hit()` is the host's, so a client's copy of an arrow flies and sticks
and hurts nobody, while the host's copy of that same arrow is the one that
counts. The *draw* is replicated separately (`net_draw`, `net_aim`), because it
is worked out in `_tick_bow()` — which is physics, which a body somebody else is
driving never runs. Without it a remote archer stands with his bow down and an
arrow appears out of him.

**A creature goes after whoever is hurting it most.** `Wolf` keeps a tally of
what each attacker has taken off it and chases the top of it, falling back to
the nearest player only while nobody has touched it. A creature that always goes
for the closest body is one you beat by standing a step further back than your
friend, and it makes the archer's whole way of fighting free: shoot from the
trees, let the knight be nearest, never be answered for it. The tally is
cumulative and undecayed, which is the rule as asked for and also one a player
can hold in their head — *hurt it more than they did, and it is yours*. It lives
in `take_hit()` because that is the one door every kind of damage comes through;
a tally each weapon had to remember separately would be wrong the first time a
weapon was added.

**A corpse leaves every window.** `queue_free()` is a local decision about a
local node and does not replicate, and the sinking runs in `_physics_process`,
which only the host has — so a wolf cleared away on the host lay in every other
window for the rest of the game, posing a rig every frame and never coming back.
`Wolf.net_clear()` says it out loud.

Two more things did have to change, and both were real single-player assumptions
rather than tidying:

- `Wolf` cached **one** player at `_ready()` — looked up before anybody had
  spawned, and only ever one of them. It asks for the nearest one now, every
  think.
- `_last_hit_serial` was a single number, so **two players swinging in the same
  tick collapsed into one hit**: the second attacker's serial already looked
  seen. It is a dictionary keyed by attacker now.

The consequences of a hit are replicated rather than re-derived. The host
decides *which* limb came away and tells everyone (`Wolf.net_sever`); a client
that re-ran the geometry would disagree, because its copy of the blade is a
frame of interpolation behind, and the two windows would end up missing
different legs. `WolfRig.sever_along_edge()` is split for exactly this: deciding
is the host's, `detach()` is everyone's. Death goes the other way — `is_dead` is
replicated and its **setter** runs the cosmetic half, so there is one
description of what a corpse is.

### Spawning

The player used to be baked into `greybox_world.tscn`. It cannot be: there may
be four, each a different character, and which ones exist is not known until
people have connected. [`scripts/world.gd`](scripts/world.gd) holds a
`MultiplayerSpawner`, four marks, and a spawn function whose data carries the
**character** — which is the whole answer to "why does everyone look like the
host". The profile is assigned before the body enters the tree, so
`Player._spawn_character()` uses it instead of asking the local `Game`.

Offline this is the same path with one peer in it. A solo game is a multiplayer
game with nobody else in it, not a second way of working.

Two things that bite, written down because they cost time:

- **`leave()` puts back an `OfflineMultiplayerPeer`, not null.** A tree with no
  peer at all is not "not networked", it is broken: `MultiplayerSpawner.spawn()`
  refuses to run without one, so a solo game loads a level with nobody in it.
- **Authority is gated by turning `_physics_process` off**, not by guards. Every
  one of the twenty `Input.` call sites in `player.gd` is reached from there, so
  one line covers all of them and there is nothing to forget at the twentieth.
  `_process` stays on for everyone — that is what animates the other knights,
  off the replicated mirrors (`net_state`, `net_airborne`, …) rather than off an
  `is_on_floor()` that is the answer from a tick that body never took.

### Pausing

Escape does **not** stop the world when there is anyone else in it. A paused
tree stops that peer's synchronizers and its ENet polling, so one player opening
a menu would freeze their knight in everybody else's window and eventually time
the connection out — and nobody else agreed to be paused. What the menu keeps
either way is the mouse: releasing it is the only way out of capture.

### Not in this phase

- **PvP.** Players cannot damage each other. (They do have health now — see
  *Health, stamina and the parry* — but only creatures take it.)
- *(The bow **was** on this list. It is not any more — see above. The first
  person to join as Avtandil could not scratch anything, and the first answer
  was to grey the archer out of multiplayer. That was the wrong answer: barring
  characters to work around a missing feature does not scale to the four
  characters this is heading for, so the feature got built instead.)*
- Prediction, reconciliation, rollback, dedicated servers, matchmaking,
  anti-cheat, and a readiness handshake for joining mid-load.

### What the other windows see of a creature

Only the host thinks for creatures, so anything that happens in their thinking
has to be told to the others. The imp, puglin, orc and Arkdeva say what they are
doing through `act` / `act_serial`, and every peer plays it and sinks the
corpse in `_process`. The wolf predates that: its swipe was only ever played on
the host, and its fall and sink ran in `_physics_process`, which only the host
has — so in every other window it stood up to fight, did nothing while health
went down, and died standing. The swipe now goes out as `net_swipe()`, and the
other peers play the fall and the sink themselves once `is_dead` arrives.

    sh tools/two_peers_monsters.sh    # the client sees the wolf swipe, fall and sink; the others die and sink

### Testing it

`tests/multiplayer_test.gd` checks everything one process can: that bodies are
spawned rather than baked, that a second peer is built with *its* character,
that somebody else's body takes no physics ticks and steals no camera, that the
mirrors are on the wire, that the wolves are gated, and that two attackers in
one tick both land.

Two peers talking to each other cannot be tested in one process — one
`SceneTree`, one `multiplayer`. `tools/two_peers.sh` runs two Godots, one
hosting and one joining, and reads the two logs together. **Each side cuts its
own wolf**, and both report both:

The host plays the **knight** and cuts its wolf; the client plays the **archer**
and shoots its own, through the real input path — press, hold, release:

```
HOST   mywolf health 0 lost 4 dead true   theirwolf health 0 lost 0 dead true
CLIENT mywolf health 0 lost 0 dead true   theirwolf health 0 lost 4 dead true
HOST   saw them drawing for 449 frame(s)
```

The same wolves in the same state in both windows, each killed from the other
end — and the host saw the client's bow actually drawn rather than arrows
appearing out of a man standing at ease. The script fails if the two disagree,
**if either wolf comes through untouched**, or **if the draw never arrived**.
Those last two are the checks that were missing: the first version only had the
host attack with a sword, and a client archer who could not hurt anything walked
straight past it.

## Music

`scripts/music.gd`, autoloaded as `Music`: one track at a time, looped,
crossfaded over two seconds when a scene asks for another — the menu asks for
`menu` (`sounds/tower-music/safe_haven_mini.mp3`), the world for `world`
(`safe_haven.mp3`). Being an autoload it carries across the scene change, so
the menu's track fades into the world's rather than cutting off. The MP3s are
imported as they are; the loop is switched on in code, so a new file needs only
a line in `TRACKS`. (The files arrived as `Safe Haven.mp3` and `safe haven mini `
with no extension, which Godot would not import; renamed.)

**The menu's track in the level.** `World._play_music_in_village` compared
what it wanted with what it had last asked for, which starts empty; out in the
wild it wants nothing, so "nothing == nothing" and the menu's track, still on
from the menu, played on for the whole game. It now compares with
`Music.current_track()`. `marsh_test` starts the menu's track and checks it is
gone.

### The mere's song

`scripts/marsh_song.gd` (`MarshSong`, added by `World._add_marsh_song` under
the level): two passages of a woman's voice cut from the user's recording —
`sounds/moments/short-women-voice-1.mp3` (0:48–1:02) and `-2.mp3`
(1:41–1:55), each 14 s with a short fade in and out. When this peer's player
walks into the marsh round the misty village (the mere's ellipse widened by
8 m) the first plays; 5–10 s after it ends, the second; then nothing. Leaving
(20 m past the rim) fades it out; it can play again only after 30 s away. It
fades out too if the orcs' fight music starts. At -16 dB (the music is -10),
with a ±1 dB trim so the two passages sound alike — heard, not announced.
Local only; each peer hears his own. `marsh_test` checks the sequence.

### Sounds

`scripts/sfx.gd` (`Sfx`): a one-shot `AudioStreamPlayer3D` placed on whatever
made the sound and freed when it ends, the pitch nudged a few percent so a
repeat does not sound like a recording. The files the user added are trimmed
to single clips with ffmpeg: the sword pack's eight-second take cut at its
silences into `sounds/tariel/swing_1..7.wav`, the bowstring pull and release
cut to their first third of a second (`sounds/bow/draw.wav`, `release.wav`).
The knight's swing whooshes (one of the seven at random, from the sword's
socket, on every peer, since every peer plays the swing); the rogue's daggers
use the same air cut higher (`swing_pitch` 1.45); Avtandil's string sounds as
the draw starts and again as it goes. The world's music is now two tracks in
turn, `safe_haven.mp3` and `kind-of-year.mp3`.

## Graphics

One setting, three positions. `Graphics` applies it to the viewport and to
whatever scene is loaded, so it can be changed before a level exists and again
from inside one; `Game` remembers it in `user://settings.cfg`. The enum's values
are what is written there, so Medium went on the end (`LOW, HIGH, MEDIUM`) and
`Graphics.ORDER` is the order the menus show them in.

| | High | Medium | Low |
| --- | ---- | ------ | --- |
| sun's shadow | 2 cascades, 95 m | **1 cascade, 55 m** | **off** |
| render scale | 1.0 | **0.85**, FSR | **0.7**, FSR |
| edges | SMAA | FXAA | none |
| texture mipmap bias | 0 | 0 | **+1.0** — surfaces go soft |
| SSAO | on | off | off |
| glow, fog | on | on | off |
| grass: draw distance, LOD bias | 130 m, 0.06 | 95 m, 0.04 | 60 m, 0.02 |
| wood and meadow plants | as laid out | 80 % of the distance | 60 % |
| loose stones, people | 110 m, 80 m | 80 m, 60 m | 55 m, 45 m |

High was 2× MSAA until September 2026. Over the wood and the pier that cost 3.5–4
ms a frame on an M1 — most of the way from 60 fps to 50 — and SMAA gets the
edges nearly as clean for a fraction of that. Nothing else on High changed; the
figures are in "Performance, September 2026" below.

The grass reads its three knobs once as it is built, so `refresh_meshes()` is
what pushes them back down when the setting changes underneath it. The wood's
and the meadows' own draw distances are scaled from what they were built with,
kept on each node as `designed_range` metadata, so the setting can be changed
back and forth without them creeping.

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
- **Locomotion.** The legs are posed from **where the feet have to be**, not by
  swinging the joints and hoping the feet land somewhere. Each foot is given a
  path — planted, with the body travelling over it, then picked up, carried
  through and set back down — and hip, knee and ankle come out of the law of
  cosines on the model's own thigh and shin. That is what a stride is: the
  ground holds the foot still while the body moves past it. See
  [The stride](#the-stride) below for what falls out of that.
- **States.** Airborne swaps the stride for a tuck; dashing adds a hard forward
  lean. Both are what shows through wherever a clip is not playing.
- **Climbing.** A procedural pose, like the crouch and for the same reason: the
  library has a one-metre mantle and nothing else that touches a vertical face.
  Hands and feet work in diagonal pairs — the left hand reaches as the right
  knee comes up — paced by how much face the body has actually covered, so a
  slow haul reaches slowly and a body hanging still holds the grip it is on.

  The arms are **solved onto the wall**, not posed at it: the controller passes
  the distance to the face and `_reach_for_wall()` aims each wrist at a point on
  it, through the same two-bone solve the legs use. Angles picked by eye put the
  hands near the surface and then a forearm's length through it the moment
  anything about the fit changes — the torso leaning in, the body hanging
  further off — which is exactly what they did. The solve is done in the
  shoulder's own parent frame, because a target written in the model's frame
  adds the chest's lean to the reach.

  The sword and the shield go **over the shoulder** while climbing
  (`_sling_weapons()`), which is also what the `stow` button does. Both are
  carried in hands that a climb puts flat on the wall, and both are far wider
  than the hand holding them: a metre of blade in a fist on a wall is a metre of
  blade inside the wall. Neither is re-parented — both are *placed in the
  model's own frame*, behind the chest, and that placement is expressed in
  whatever frame the hand they hang off is in this frame. So they sit still on
  the back while the arms work, without a second attachment point to keep in
  step with the first, and every swing, block and stow the rest of the rig does
  still drives the same node it always did.

  Taking hold of a wall **cuts** whatever clip was playing rather than fading
  it. A wall caught in mid-jump has the take-off clip on the body at the moment
  it is caught, and a tenth of a second of it at full strength on top of the
  climb reads as the jump carrying on up the wall — and when it runs out it
  hands over to the falling loop, which comes back at full weight and rides up
  and down the building. `AnimRetarget.cut()` is that: stop, zero, forget.
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

## The animation library

`assets/anim/ual2.glb` is Quaternius' **Universal Animation Library 2
(Standard)** — a UE-style mannequin with 65 bones and 43 hand-authored clips,
CC0 (`assets/anim/LICENSE.txt`). `scripts/anim_retarget.gd` replays those clips
on Tariel, who has no skeleton at all.

### How the transfer works

Tariel is rigid parts on a joint hierarchy, so nothing can be skinned to the
mannequin's bones, and copying the mannequin's joint *positions* would tear the
parts apart — the two bodies are not the same proportions. **Only rotation is
transferred:** each joint takes the orientation its counterpart holds, expressed
in the model's own frame, which leaves every limb exactly as long as it was
authored.

The rest poses disagree — the mannequin ships T-posed, Tariel in a
sword-and-shield stance — so a constant per-joint correction is solved once at
load: swing each of Tariel's limbs onto the direction its counterpart points in
the mannequin's rest (that *is* Tariel's T-pose), and the correction is the gap
between that and the mannequin's own rest. Only the swing is solved, never the
twist, so the authored grip on the sword and the roll of the shoulders survive.
Nothing here is hand-tuned; the numbers come out of the two rest poses.

Sides are **crossed** on purpose. Tariel's `*_l` nodes sit on the model's -X
side, and with the model facing +Z that is the mannequin's *right*. Matching the
names instead of the anatomy would put the sword in the wrong hand.

Playing `A_TPose` is the calibration check: it is the pose the correction is
solved against, so if the arms do not come out level and the legs straight, the
mapping is wrong and nothing else is worth looking at.

    godot --path . --script res://tests/clip_shots.gd -- /tmp/shots A_TPose

### Blending, not switching

Clips and the procedural poses are blended **per joint**, and a joint is
resolved against the pose its *parent* was actually given — not the clip's — so
a half-faded clip never leaves the chain hinged in the middle. That is what lets
`Mask.UPPER` hand a sword swing to the arms while the legs keep striding, which
is what a swing thrown at a run uses.

### The stride

The procedural gait is described by two numbers that mean something — how much
of the cycle a foot spends on the ground (`walk_duty` 0.62, `run_duty` 0.34) and
how far it is picked up (`foot_lift`, `run_foot_lift`) — rather than by half a
dozen joint amplitudes that have to be balanced against each other by eye. Given
a foot path, `_solve_leg()` produces the angles, and the rest follows:

- **The knee folds on its own.** During the swing the ankle is carried nearer
  the hip than a straight leg would put it, and a two-bone solve has nowhere
  else to bend. Peak flexion comes out at ~55° at a walk and ~100° at a sprint,
  which is roughly what a person does, from no curve shaped by hand.
- **The hips bob because the legs pull them down.** `_hip_drop()` asks how far
  the pelvis has to come down before a straight leg could reach the foot, and
  the hips go down by exactly that. A walk therefore dips at its double support
  and a run rides high through its flight — neither animated, both a consequence
  of where the feet are. The stride blends *out* of the feet's way through the
  same number, so the planted foot stays where it was put instead of being
  dragged off the ground.
- **Stride length answers to the gait, not only the pace.** `_stride_span` is
  the ground one cycle covers; dawdling and creeping both shorten it, so the
  cadence rises to make up the difference instead of the feet sliding to cover
  ground the legs never crossed. A crouch-walk is the same stride, shorter and
  quicker.
- **A foot can only be planted as far out as the leg reaches.** Anything asked
  for beyond `leg × foot_reach` has to come out of the flight phase — which is
  how a run lengthens in the first place, and why each foot's time on the ground
  drops from ~40 % of the cycle at a walk to ~13 % at a sprint. A walker sets the foot down
  well in front and pushes off behind; a runner lands much closer to underneath
  and drives much further back.
- **The pelvis is not the ground.** The authored stance pitches the hips forward
  and the somersault turns them right over, so the foot targets are rotated back
  out of whatever the pelvis is doing before they are solved, and the sole's
  tilt has it taken off again. Without that the feet sink at one end of the
  stance and float at the other.

Measured on a treadmill (the body held still while the rig is driven at a given
speed), the procedural legs put the boots **0 mm** through the ground at a
sprint and hold the planted foot to within about a centimetre of the ground
right through the stance, travelling backwards at 4.6 m/s while the body goes
forwards at 4.5.

Two knobs were retuned when this went in: `run_stride_bonus` came down from 3.5
to 2.2, because a 5.5 m cycle at 9 m/s is a cadence no sprint has, and
`crouch_stride_scale` went from 0.45 to 0.55, because it now shortens the stride
itself rather than just the swing of the legs.

### The walk cycle, and why it is not simply played

The library's only forward cycle is `Walk_Carry`, and measuring it settles what
can be done with it: **1.34 m of ground per 2 s cycle**, an authored 0.67 m/s.
This game walks at 4.5 and runs at 9. Played at rate that is 6.7× and 13.4× —
the legs would blur — and slowed down to look right the feet would skate.

So the cycle is **seeked from the procedural stride phase** instead of played.
The phase is already one cycle per stride of ground covered, so the feet stay
planted at any speed, and the stride *lengthens* with pace rather than only
turning over faster. What the borrowed phase cannot fix is amplitude — the clip
swings a walk's legs and a sprint reaches much further — so the clip's share is
wound down as the pace rises (`walk_clip_sprint_share`, 25 % at a full sprint)
and the procedural stride takes the difference. Walking is mostly the clip;
sprinting is mostly procedural.

`AnimRetarget.measure_stride()` is what produces that 1.34 m, off the clip
itself: the feet are furthest apart at mid-stride, which is one step, and a
cycle is two of them, scaled by the ratio of Tariel's leg length to the
mannequin's. Drop a real run cycle into `walk_clip` and none of this needs
touching.

    godot --path . --headless --script res://tests/debug_retarget.gd

prints the measurement, and the retarget's per-limb error against the mannequin.

### What comes from where

The library ships **no idle, run or crouch**, so those stay procedural and the
clips cover the one-shots:

| In game                    | Clip                                        |
| -------------------------- | ------------------------------------------- |
| attack                     | `Sword_Regular_A` / `_B` / `_C`, in turn    |
| walk / run legs            | `Walk_Carry`, lower body, seeked by stride phase |
| take-off / fall / land     | `NinjaJump_Start` / `_Idle` / `_Land`       |
| double-tapped dodge        | `Sword_Dash`                                |
| slide (`crouch` at a run)  | `Slide_Start` → `Slide` → `Slide_Exit`      |
| crouch                     | *procedural — the pack has none*            |
| ledge climb (`jump`)       | `ClimbUp_1m`, stretched to `climb_duration` |
| wall climb                 | *procedural — the pack has none*            |
| `rig.hit()`                | `Hit_Knockback`                             |

Anything else in the library is reachable with `rig.play_clip(name)`;
`rig.clip_names()` lists all 43. Not covered by the pack, and therefore still
procedural: **idle, run, crouch, free climbing, block and the single-tap roll**.
There is no sword-draw clip in it at all.

Clips play on **two layers**, because a walk has to keep running underneath
whatever one-shot is over it and one mixer cannot do that. `Gait` holds the walk
cycle on the lower body; `Actions` holds the one-shots. Three sources stack in
`_apply_pose()`, weakest first — procedural, then gait, then action — each a
slerp, so a layer that is only half in leaves the one under it showing through.

The blade's cutting window is **measured** from each swing clip at load —
`AnimRetarget.measure_travel()` samples the sword hand and takes the span where
it is moving fastest — so retiming a swing or dropping a different clip in needs
no numbers changed anywhere.

Everything degrades cleanly: if the library fails to load, `AnimRetarget.setup()`
returns false and every pose falls back to the procedural one.

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
  `generate/physics`, which builds a `StaticBody3D` around the model. It was a
  trimesh (`physics/shape_type = 2`) until September 2026, when a capsule
  `test_move` against its 4 300 triangles was measured at 8 ms; it is now a
  convex decomposition of at most six 32-point hulls (see "Performance,
  September 2026"). The importer is the right tool for static level geometry —
  unlike the character, where the same mechanism
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

The grass is **not nodes**. The clumps arrive as one flat `PackedFloat32Array`
on the node — five numbers each, x/z/yaw/width/height — and `GrassField` turns
them at load into a couple of dozen `MultiMeshInstance3D`s on a 16 m grid. That
is the single largest thing that was costing frames: as instanced scenes the
field was seventeen hundred draw calls, and it is now about forty. It also took
the scene file from 5 600 lines to 500. The stones stay as instanced scenes —
there are thirty of them, they are solid, and they were never the problem.

The grid is deliberately tight. A multimesh is picked one level of detail at a
time, so a large chunk would hold the clumps at the player's feet back to the
detail of the ones at its far corner; and only a chunk something has actually
walked through gets re-uploaded, so bending costs a buffer write where the
player is and nothing anywhere else.

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
once it has passed. Rocks are left alone — they are children, and the grass is
not.

What each clump is currently drawn with is kept **on this side of the rendering
server** as well as in the multimesh. A multimesh is write-only without a
renderer behind it — `get_instance_transform` comes back as the identity in a
headless run — so anything that has to *read* a pose reads the mirror:
`clump_basis(i)`, which is what the smoke test checks the bend with, and the
blood, which tints clumps through `stain()` rather than hanging an overlay
material on a node that no longer exists.

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
most expensive thing in the scene. Drawing the field out of multimeshes is what
took the draw calls off it; the settings below are what hold the triangles down,
and they matter more than they look:

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
- `draw_chunk` trades culling against node count: smaller chunks cull and pick
  detail more finely, and cost a node each.

Drawing it out of multimeshes is what took the draw calls off it. Standing at the
spawn, looking out over the meadow into the treeline — the busiest view in the
level — the field went from **about 1 700 draw calls to 117**.

That is also why the level can now afford a wood, a hamlet and a skyline on top
of it. Measured by `tests/draw_budget.gd` from that same spot:

| | draw calls | triangles |
| --- | --- | --- |
| before any of this — greybox, meadows, six creatures | 2 235 | 1 670 000 |
| now — plus 1 000 plants, 38 buildings, a skyline, 17 creatures | **1 616** | **482 000** |

Where the 1 616 go: 894 of them are the sun's shadow map, 399 the creatures (a
rigid-part rig is forty-odd draw calls, and the sun draws every one of them again
per cascade), 359 the wood's canopy and 111 the grass.

The sun went from four shadow cascades over 175 m to **two over 95 m**, which is
most of the difference. Four cascades spread the same shadow map over twice the
ground when the map doubled, so they were both dimmer and dearer; two over a
shorter reach put the detail back where it is looked at and took 400 draw calls
off the frame.

`grass.glb` ships with a `Leaf` material but no texture, so it renders as white
cards out of the box. `assets/grass/leaf_material.tres` is wired in through the
import's `use_external` material override to make it plain green until the real
texture arrives — the clumps in `grass2.glb` are textured and need nothing.

### Meadows

The scatter's field has been replaced: `Meadows` (`scripts/meadows.gd`) grows
the grass for the whole map at load, seeded so every peer grows the same one,
and hands it to the same `GrassField` with `replace()`. It asks the ground what
a walker would:

* **drifts** on the open ground, from a slow noise field with a hard enough edge
  that the meadow lies in sweeps and bare patches rather than an even sprinkle,
  planted in knots of two to four clumps, taller in the middle of a drift;
* thick along the **edges** — the treeline and the shoulders of the tracks —
  and none on the tracks themselves;
* a band of **reeds** round the mere and along the bay's shore, just above the
  water, with bulrushes (the kit's `Cattail_*`) standing in them;
* only the odd tuft **under the trees**;
* **flowers** in patches of one kind at a time (daisies, violets, bellflowers,
  balloon flowers) inside the drifts;
* nothing where something solid stands, found with a ray.

Each clump is tinted (`GrassField.tints`, the multimesh's instance colour, which
blood is laid over): the kit's lime taken down to grass green, drier and more
golden where a second noise says the ground is dry, darker by the water and in
the wood. Over `budget` (9 000) the field is thinned evenly. The flowers and
bulrushes are multimeshes in 48 m squares, drawn out to 80 m. Growing it all
takes about a fifth of a second.

## The wood

`Forest` (`scripts/forest.gd`, at `Forest` in the world) grows about six hundred
trees, two hundred bushes and two hundred pieces of ground litter at load, out of
one seed, and plants ninety more along the hedgerows. None of it is in the scene
file.

The counts came down on purpose. Twelve hundred bushes read as moss rather than
as undergrowth, and at 3.9 m apart the crowns closed into a ceiling at head
height — from inside, the whole view was leaves and the trees stopped reading as
trees. Five metres apart with the crowns lifted is a wood you can walk through
and see across, which is what a wood is.

Three thousand plants cannot be three thousand nodes, so the wood is built the
other way round from the props beside it:

- **Drawn** by `MultiMeshInstance3D` — one per species per chunk, which is one
  draw call for every oak in a forty-metre square rather than one per oak.
- **Chunked** on a 64 m grid, so whole squares are culled behind the camera, and
  a species that does not grow in a square costs nothing there. The chunk size is
  a trade that was measured rather than guessed: smaller chunks cull more finely,
  larger ones are fewer draw calls, and every visible chunk costs one more per
  shadow cascade. At 44 m the level drew 300 more times for no gain anywhere.
- **Collided** through shape owners on static bodies laid out on a 22 m grid. A
  trunk needs a cylinder, not a node; a thousand nodes that never process are
  still a thousand nodes to build and tear down. The cylinders are pooled by
  radius to the nearest five centimetres, so a thousand trees share about seventy
  shapes between them.

  **Not one body for all of them**, which is what it was first. The broadphase
  culls by body: once a query touches a body at all, every shape that body owns
  is looked at — so seven hundred trunks on one body cost two milliseconds of
  physics a tick *standing on the open plain with no tree within eighty metres*.
  On a grid, a query looks at the twenty in one cell. It is the same trap the
  house's trimesh colliders were, one level up.
- **Placed** from a seeded `RandomNumberGenerator` and two noise fields, so
  every peer in a multiplayer game grows the identical wood without a byte of it
  crossing the network.

**The wood is one wood, on one side of the map.** It was a ring around the play
area to begin with, thinning outwards, and a ring reads as trees having been
sprinkled over the ground rather than as a forest — you are never in it and never
out of it. So the map is divided instead: everything past a line running
north-west to south-east is wood, everything before it is the settlement and its
fields. The line has a long-wavelength noise wobble on it, which is what gives a
treeline with bays and headlands in it rather than a ruled edge.

Glades inside it are *holes*, not a thinning. Multiplying the whole wood by a
noise field — the first version — made every tree a coin toss, so nowhere was
properly dense and nowhere was properly open. A threshold leaves the wood at full
density and takes distinct bites out of it.

Species are **regional**, not sprinkled. A low-frequency noise field decides
which conifer or which broadleaf grows where, so the wood has a pine end and an
oak end and stands of dead timber between them. That is a look, and it is also
what keeps the per-chunk draw call count down: a chunk holds two or three
species, not every species in the kit.

`min_trunk_gap` stops the wood becoming a wall: it drops any tree that lands
closer than 2.3 m to one already standing, since the jitter that keeps the wood
from looking planted will otherwise put two trunks a foot apart. `CLEARINGS` is
the list of places nothing grows whatever the treeline says — the greybox core,
the buildings standing in it, the settlement, and the glades the creatures are
met in. Each has a soft rim, so a glade has a ragged edge rather than a shaved
circle.

### Hedgerows

The open half would be bare, and filling it by loosening the treeline would put
the wood back where it had just been taken from. So the trees out there were
*planted*: `HEDGEROWS` is a set of polylines — field boundaries, a windbreak, the
lane down to the greybox core — walked at a fixed spacing with a little wander
off the line. A hedgerow says something a wood does not, which is that somebody
marked this field out, and it is what makes the east read as farmed rather than
as empty. It shares everything else with the wood: the same multimeshes, the same
pooled trunks, the same chunk grid.

`collider_shrink` is under 1 on purpose. A cylinder cut to the widest point of a
flared base catches the player a foot away from the bark; the radius itself is
measured off the mesh — the widest point of the bottom eighth of its vertices —
so swapping a species for another gets the right collider with no number changed
anywhere.

### The art

`assets/forest/` is a curated copy of the Quaternius Nature Kit: 115 `.obj`
models and their textures, lifted out of `assets/trees/` so Godot never has to
scan the whole pack (there is a `.gdignore` in the original). `.obj` is what is
wanted here — Godot imports it as a plain `ArrayMesh` rather than a
`PackedScene`, which is exactly what a `MultiMesh` takes. The kit's `.mtl`
files reference their textures with Windows separators (`textures\Bark Oak.png`),
which resolve to nothing on macOS or Linux; the copies have them fixed.

## The settlement

`Level/Village` is thirty-eight pieces of the HighLands Fantasy Buildings kit laid
out as a place somebody lives: a street running east with eight thatched huts
facing each other across it, a town centre at its head, a barracks, a watchtower,
a windmill out where the wind is, a walled gate at the western approach, crop
fields beyond the houses and the fences, barrels and crates of a working village.
Each piece is a `Node3D` running `scripts/building.gd` with the `.fbx` instanced
under it.

It is laid out on a street on purpose. Buildings dropped around a clearing read
as a camp; buildings facing each other across a line read as a village, and the
gate at one end of that line tells you which way in is.

That script exists because two of the kit's Unreal conventions do not survive
the import:

- **Textures.** The `.fbx` names a material — `M_Hut` — but not the files that
  dress it, so everything arrives flat off-white. The files are there, in a
  `TextureMaps` folder beside the model, named after the same material, so the
  material name is the whole of the lookup: `M_Hut` wants `T_Hut_diffuse.png`,
  `T_Hut_normal.png` and the rest. Nothing is wired by hand per building, and
  the materials are shared, so ten crates are one material.
- **Collision.** Unreal reads a mesh named `UCX_*` as the convex hull to collide
  against; Godot reads it as a second thing to draw. So the `UCX_` meshes are
  taken out of the drawing and put back as `ConvexPolygonShape3D`s on a
  `StaticBody3D`. That is both correct and the cheap way round — the
  alternative is the trimesh the importer would otherwise cut from the building
  itself, and `SimpleCollision` on the house in this same level already measured
  what that costs.

A building with no hull — the crop fields, the axe — gets `build_collision =
false` in the scene, since it is decoration and saying otherwise is a warning
every time the level loads.

Where a piece of the kit runs from its own origin rather than being centred on
it, the placement was **measured rather than reasoned about**: a wall span turns
out to run six and a half metres back along its local -Z and to sit 2.5 m to one
side of its origin, so the two spans of the gate were put where a print of their
world bounding boxes said they had to go to meet the towers. Two minutes with a
probe beat twenty of sign-flipping.

The windmill's sails hang off the mill rather than standing beside it, so moving
the mill moves them, and they turn: `scripts/spinner.gd` is a function of the
clock, which means every peer sees the same sails in the same place without a
word being said about it, and a dropped frame changes nothing.

## The skyline

`Horizon` (`scripts/horizon.gd`) rings the map with two offset rings of the
kit's mountains, standing well behind the boundary wall. The boundary is four
invisible boxes; walk up to one in an open field and the illusion is over. A
ridge behind it answers the question the player was about to ask — the map does
not end there, it just does not go any further.

Cheap on purpose, because none of it is ever reached: seventy-five triangles a
peak, drawn through one multimesh per model per ring, no collision at all, no
shadows (the sun's shadow map does not reach out there), and `lod_bias` low
enough that a ridge drops to its coarsest mesh immediately.

Since the marsh was added the map is longer than it is wide, so the rings are an
oval centred on the middle of the whole ground (`centre`, `stretch`) rather than
circles round the spawn, with a few more peaks to go round.


## The marsh and the misty village

The map grew by a strip 130 m deep south of the old south wall (which moved to
z = -250.5; the east and west walls were lengthened to match). In it is a
**mere** with the **misty village** standing on a C-shaped island in the
middle, set out as in the reference picture the model came with
(`assets/world/lasha-egutidze-lasha-egutidze-mist1.webp`): the C open to the
north, which is the side a player arrives from, so the first sight of it is the
picture.

**The ground** is `Marsh` (`scripts/marsh.gd`), built at load from a height
function like the wood is: flat at y = 0 where it meets the old box, dished down
a metre into the mere. Drawn as one grid mesh with the old ground's material
(darkened towards the water), collided as a `HeightMapShape3D` from the same
numbers. The water (`assets/world/water.gdshader`) is one plane 0.35 m below
the old ground: the bed is under it, so the mere is **waded**, not swum and not
walled off — about 0.65 m of it. Mist is a few dozen upright cards
(`assets/world/mist.gdshader`) turned to the camera, softened where they meet
anything and faded as the camera walks into them; volumetric fog would have been
a cost across the whole world for something wanted in one place.

**The wood** grows into the strip as well (`Forest.south_extent`), planted
*after* the old square so the square's wood comes out of the seed exactly as it
did before. A clearing keeps it back from the mere, and a smaller one on the
north shore is where the ride from the open ground comes out.

**The village** is `assets/world/mist_village.glb`, rebuilt from the model it
was delivered as (`assets/world/mist2.glb`) by `tools/mist_village.py` in the
art folder:

- **Transforms solved back.** Several houses in the delivered file had been
  parented to squashed objects in Blender — a whole house hangs off a pipe
  scaled 0.009 × 0.15 × 0.009 — and a glTF node cannot hold the shear a rotated
  child of such a parent has. The exporter dropped it and the shingles came out
  as shards tens of metres long. Each piece's world transform is solved for
  from what was written, and where more than one fits, the one that keeps the
  piece its own size wins.
- **Eight thousand pieces merged** into one mesh per material: twenty-odd draw
  calls, 115 k triangles.
- **Colours** for the materials that were procedural in the source and arrived
  white, picked off the picture; the shingles multiplied down to slate.
- **Scaled 2.2×**, which puts a barrel at hip height next to the characters and
  the tallest house at fourteen metres.
- **Collision by name**, which Godot's importer understands: the island's own
  ground is a trimesh (`island-colonly`), and everything else is hulls
  (`-convcolonly`) — a handful per house, clustered by k-means over its pieces,
  one per tree trunk, rock, barrel and step. About a hundred hulls in all. A
  trimesh per plank would be the house in the old level again.

`MistVillage` (`scripts/mist_village.gd`) does the rest at load: the grass
cards come in alpha-*blended* and are switched to alpha-scissor (sorts
correctly, costs less, and they are kept out of the shadow map).

`tests/marsh_test.gd` walks across where the old wall was, wades the mere,
stands on the island, runs into a house, and times a physics tick in the
village against one out on the plain. `tests/world_shots.gd` has four vantages
on it (`mere_*`), the first at the angle of the reference picture.


## The bay and the harbour

South of the marsh the map runs on another 205 m to a **bay** (the south wall
is at z = -455.5 now, and the mountains' oval is centred on the middle of the
whole length). It is a second [Marsh] node, `Bay`, with a much bigger body of
water — an ellipse centred beyond the south wall, so what the player sees is a
coast rather than a pond — a sandier shore, and a sea-coloured surface
(`assets/world/sea.tres`, the same shader as the mere). It is shallow enough to
wade, like the mere: the bed is 1.25 m down and the water 0.6 m.

Nothing else stands in it but a **pier**: `assets/place7/pier.glb`, modelled
in the art folder's `world/pier.blend` — a plank walkway 2.6 m wide and 32 m
long out from the end of the track, on to an 8 m landing stage, on posts, with a
rope rail, a couple of barrels and a crate. The planks are three weathered tones
and the waterline ones darker and wet. The walkway, the stage, the barrels and
the crate are hulls (`-convcolonly`). Old Baqaq fishes off the end of it.

The **orcs** stand in the water off the pier: their camp is at (0, -342), so
two of them wade the shallows either side of the walkway. (The harbour town
built from `mall1.glb` stood here before; it was too much for the place and has
gone.)

## Tracks and ruins

The old ground was a set of places dropped on a plain, each the same distance
from nowhere, with the greybox's grey and pink test boxes standing in the middle
of it. Two things change that:

* **Tracks** (`scripts/paths.gd`): worn dirt ribbons from the spawn to the
  settlement's gate and down its street, into the wood to the first glade, and
  south past Arkdeva's glade and the puglins to the mere, round it and on to the
  bay. Each is drawn soft-edged and a little uneven in width, follows the
  ground where it dips, and the wood keeps off it (`Forest.paths`), so a track
  through the trees is a way through them. They also tell a player where to go.
* **Ruins**: the stairs, ramp, platform, steep face and pillars keep every
  measurement the smoke test depends on, but are drawn in weathered stone
  (world-space triplanar, so a block's texture runs on across the next) and
  mossy stone, instead of flat beige and pink.

The kit's broadleaf trees were a flat lime that read as plastic beside anything
textured; `Forest.leaf_tone` takes their greens down to something a leaf could
be, leaving bark and the conifers alone. The oak and bush leaves carry their
lime in a texture under a white material, so they are found by the material's
name and toned harder, towards olive (`Forest.broadleaf_tone`).

## Quests

Three people with jobs, each with a mark over their head — a gold `!` for a job
on offer, a green `?` when it is done and waiting to be handed in:

| who | where | job |
| --- | --- | --- |
| Datvi the Woodcutter (the bear with the log) | the settlement's street | kill 4 wolves |
| Ali of the Embers (the fire spirit) | the mere's north shore, where the track comes out | kill 6 imps |
| Old Baqaq the Fisherman (the frog with the rod) | the end of the pier | kill Arkdeva |

Walk up to one and **F** (`interact`) talks; F again takes the job on, walking
away declines it. A taken job sits in the top-right corner with its count. Kills
are counted by watching the creatures (`QuestBook` polls the `enemy` group and
counts each new corpse by its scene's name), so any creature is a kind without
registering it, and in co-op a kill counts for everyone who has the job.
Players have no health or purse yet, so the reward is the giver's thanks and a
burst of warm light.

`scripts/quest_book.gd` is the book and the on-screen text; `scripts/quest_giver.gd`
is a person: the model scaled to a height, dropped on to whatever is under it,
breathing and turning to face whoever talks to them. `tests/quest_test.gd`
checks all of it.

## Creatures

`scenes/enemies/` holds four kinds and the level holds seventeen of them, all
under `Enemies`: the wolf and the golem that were always here, and two out of the
Bestiary kit that animate a different way — each of those in three colourways, so
seventeen creatures are four meshes.

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

**Imp and Puglin** (`monster.gd` + `skeleton_anim.gd`) — the opposite problem
from the wolf, and a much easier one. The Bestiary kit ships *rigged*: a real
`Skeleton3D`, skinned, built to the Unreal mannequin's bone names — `pelvis`,
`spine_01`, `upperarm_l`, `thigh_l`, `foot_l`, the lot. Which is also what the
Quaternius library the rest of the game animates from uses. So there is nothing
to solve and nothing to author. Every bone is matched by name and the pose is
carried across as a **delta from rest**:

```
target_pose = target_rest · (source_rest⁻¹ · source_pose)
```

Because it is relative to each rig's own rest, proportions survive: the Imp is
1.4 m tall and the Puglin 0.75 m against the mannequin's 1.6 m, and both walk
with their own legs rather than being stretched onto the mannequin's. The kit's
rigs are missing the pinky chain and the toe leaves; those are skipped, and a
bone with no counterpart keeps its rest pose, which for a finger nobody will
ever see is exactly right. Fingers are skipped on purpose as well — twenty bones
per creature per frame, below the size of a pixel at the distance these are
fought at.

This is the sibling of `AnimRetarget`, and the two exist for opposite reasons:
that one has to solve a correction per joint because Tariel has no skeleton at
all; this one has to solve nothing because the kit already agrees with the
library.

**Skins.** The Bestiary ships three base-colour maps per creature and one mesh,
which is the cheapest variety there is: a green imp and a grey one are two
creatures as far as anybody looking at them is concerned, and one mesh and one
skeleton as far as the engine is concerned. `Monster.skin` picks one, and the
file it wants is worked out from the material name — `MI_Imp` wants
`T_Imp_BaseColor_2.png` — so nothing is wired per scene and the materials are
shared between creatures wearing the same one.

**Which way they face.** Both arrived walking backwards, and it took two goes to
see it, because *eyeballing a render cannot answer this*: a camera standing in
front of a creature and a creature standing in front of a camera produce the same
picture. The answer is in the model. On any biped the ball of the foot is in
front of the ankle, and a creature in Godot travels down its own -Z, so
`monster_shots.gd` reads `ball_l` against `foot_l` and says which way the model
is actually built to face. With the check in place it was one line in each scene.

The wander is the golem's — pick a spot, walk to it, wait, pick another, out and
back along a line so it reads as patrolling rather than drifting. What is new is
that the legs are real, so the playback rate is tied to the ground speed: a
stride is measured off the clip at load (the feet are furthest apart at
mid-stride, which is one step, and a cycle is two of them, brought onto the
creature by leg length) and the cycle is retimed every frame. That is what keeps
the feet from skating.

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

Bodies do not stay. After `corpse_linger` seconds the body sinks into the ground
over `corpse_sink_time` and the node is freed. Sinking rather than blinking out
keeps the removal something that happens *in* the world, and it costs nothing:
the sink is written to the rig after `_collapse()` has run, so it wins over the
settling that is still going on. Left alone, corpses are both clutter and a
drain — every one of them keeps posing a rig every frame.

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

### The orc warrior

The orcs are twice Tariel's height (3.8 m; they were five) and fight with an
axe, with their own clips: Mixamo's axe set (idle, walk, run, a guard, the
horizontal, backhand and overhead blows, three combos, the spin, a kick, a
running leap, a battle cry, a death) plus Mixamo's orc idle and walk for when
they are only wandering. `tools/retarget_orc.py` in the art folder puts them on
the orc's rig. His rig carries Mixamo's bone names already but rests in an A
where the source rests in a T, so every limb is first swung into the source's
rest before the source's motion is laid on top; his trunk and head are left
alone, because they stand upright in both and his Head bone just happens to
point out of his face. The delivered mesh also had his fists modelled resting
against his belt, fused to it and skinned a little to each other, so any swing
pulled a web of belt after his hands; the script splits those vertices by
which side they mostly belong to and cuts the few faces that joined them.

The blows land where his right hand is moving fastest in each clip, measured
once; he opens with a roar the first time he sees somebody; a player beside or
behind him gets the spin; from further off he runs and leaps and comes down in
the overhead slam, which splits the ground in a run of spikes. His guard against
a drawn bow is the guard clip laid over his upper body while his legs keep
walking.

He runs with Mixamo's mutant run now — heavy, wide, arms loose — in place of
the axe set's jog, which looked like somebody late for a bus.

**The chains.** Besides Mixamo's combos he has three long ones of his own,
built in Blender by `tools/orc_chains.py`: his clips run together, each cut
short of the settle back to idle at its end (and past the wind-up at its
start), the seams cross-faded over six frames. The berserk is a combo into the
spin; the breaker is horizontal, backhand, overhead — and a chain whose last
blow is the overhead ends in the slam and the spikes; the brawler is a kick
into a combo. While a chain lasts he walks in behind it (`chain_advance`) and
turns more freely, so stepping back from the first blow does not end it. Their
blows are found like any clip's, where the right hand moves fastest, and, as a
combo's, only the whole chain landing floors a player.

**The great-axe orc.** Every second orc of a band (`World.ORC_MIX`) is the other
kind: `scenes/enemies/orc_greataxe.tscn`, the same script with `great_axe` on,
the model `assets/orc/orc_greataxe.glb`. He has a topknot, a mohawk of spikes
and a braid bound in iron rings (modelled on his head in Blender; the braid is
four bones on a `SpringBoneSimulator3D`), and a double-bitted axe in both
fists. His clips are Mixamo's great-sword set — idle, walk, run, guard, the
power, low, downward and combo slashes, the high spin, the jump attack, the spin
kick — with the mutant's roar and breathing idle, and three chains of his own
(fury: the combo slash into the high spin; crush: the power slash into the
downward, which slams; reaper: low slash, spin kick, downward). `GREAT_ACTS`
maps each act onto them.

Two hands on one haft is the part a retarget cannot do on its own: his
shoulders are twice as broad as the source's, so the copied arms leave his
fists apart and off any common line. `tools/great_axe.py` fixes it per frame.
The haft runs the way the source's two palms run on its sword grip, set in his
right fist, edge the way his knuckles face; his left fist goes to the point on
the haft nearest where the retarget had it, between one and three fists below
the right, by an analytic two-bone solve that keeps the elbow in the plane the
animation had it in and turns upper arm and forearm by the shortest arc only —
twist about a limb's own length is what tears the skin at elbow and wrist. The
axe is skinned wholly to a `weapon_axe` bone under the right hand, keyed to the
haft's frame, so it arrives with the rig and nothing places it in the game.

**His ground is the water.** An orc's leash is not a ring round his camp but
the whole mere his camp stands in (`holds_the_water`, `OrcWarrior._holds()`,
using the Marsh node's `in_mere()`): he follows anyone anywhere in the bay's
water and lets go of whoever climbs out onto the land, and walks home.
Left alone twenty seconds (`regen_after`, a Brute setting the orc scenes
turn on) he mends to full over a second and a half.

**Specials floor you.** Every creature's special blow is sent as a combo of
one (`Brute._floor()`), so landing clean it knocks the player down: the orc's
slam, spin, kick and leap, the spikes out of the ground (anyone's — the wave
does it, so Arkdeva's thorns too), and Arkdeva's stamp and chop. Blocked or
rolled, it still does nothing.

**The cut in the air.** Both kinds of axe carry a [BladeArc](#the-cut-in-the-air)
along their head, emitting while an attack has the head moving faster than
`arc_speed` (10 m/s). The world's creature culling leaves trails alone: their
bounds are world-space and would be measured from the middle of the map.

### Arkdeva's poison

`scripts/venom.gd` draws it, from modelled shapes (`assets/fx/venom.glb`, from
`fx/venom.blend`): a teardrop gob that flies nose first, wobbles, glows at its
rim and sheds drops that fall; a splash of droplets where it lands; and a pool
that lies on the ground as the ground lies (laid along the surface under it,
found with a ray), runs out from the middle with a ragged front, bubbles, and
dries from its edges inwards before it goes (`assets/fx/venom_pool.gdshader`).
It replaces a sphere and a flat, unlit green disc stamped at one height.

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

## Stutter, and where it actually comes from

`tests/perf_probe.gd` measures this, and it measures every configuration **in
one process, back to back** — separate runs on a laptop are not comparable,
because thermal state and whatever else the machine is doing move the numbers
further than the thing being measured does. It reports a distribution, never an
average: a stutter is a tail problem, and the mean is exactly the statistic that
hides it.

    godot --path . --script res://tests/perf_probe.gd    # not --headless

What it found:

- **Steady state is fine.** ~7.6 ms a frame with vsync off, which is 130 fps on
  an M1; the 60 Hz budget is 16.6 ms. Turning off the grass, the enemies, the
  player model, every shadow, or the whole shadow pass moves this **not at all**
  once the scene has settled. There is no bottleneck to find.
- **The stalls are first-time pipeline compilation.** Godot builds a render
  pipeline the first time it draws a given material in a given pass, and that
  costs anywhere from a few ms to most of a second. The frame times are spiky
  for the first stretch of play and flat afterwards, and the spikes track *new
  scenery entering the frustum*, not any subsystem. 58 distinct materials over
  2400 mesh instances is a lot of first times.

`scripts/pipeline_warmup.gd` pays that bill up front: nine vantage points that
between them see the whole level, two frames each, behind a black screen, before
the player gets control. Set `enabled = false` on the `PipelineWarmup` node to
measure without it.

### The stutter was the creatures, not the scenery

The one that actually made the game hitch, and the one the draw call count said
nothing about. Standing in the wood, a **physics tick cost 24 ms** — a guaranteed
dropped frame at 60 Hz, every frame, for as long as you were in the trees.

`tests/physics_budget.gd` found it by switching things off one at a time, and it
was not the trees: with their colliders disabled the tick still cost 22 ms. It
was the creatures. Two things were wrong at once.

- **Four of them were standing inside trees.** The wood had been re-laid out and
  their spawn points had not moved with it, so they spent every tick walking into
  a trunk — `move_and_slide` running out its iterations, `StepUp.climb` taking all
  ten of its probes and failing, sixty times a second, each. Creatures are placed
  in the glades now, and the glades are the same list the wood keeps out of.
- **All seventeen were thinking all the time.** On a 120 m map with six creatures
  that was free. On a 240 m map with seventeen it is a wander, a step-up probe
  and a `move_and_slide` per creature per tick for creatures nobody can see.
  `World.creature_think_distance` stops any of them thinking past seventy metres
  — well clear of the twenty at which a wolf notices anybody — and wakes them
  again on approach.

Together: **24 ms to 1.0 ms** in among the trees, 1.9 at the house and 2.6 out on
the open ground.

The probe that found it loads a **fresh level for every configuration it
measures**. The first version reused one, and its numbers were nonsense: walking
the knight into the wood to take a reading leaves eight wolves chasing him, and
everything measured afterwards is of a fight rather than of the thing being
measured. It also frees each level outright rather than queueing it, because a
queued free leaves a thousand static bodies in the physics server for another
frame and they pile up across runs.

### The warm-up was not running

Worth writing down, because it failed in the way that is hardest to notice: it
did all of its work and produced nothing, silently.

The node hung its camera off the level — `get_parent().add_child(_camera)` — and
`_ready()` runs while the level is still handing readiness down to its children.
A node in the middle of that refuses to take another one, so `add_child` failed
outright with *parent node is busy setting up children*. What was left was a
camera with no parent: it cannot be made current and it cannot be moved, so the
warm-up spent its eighteen frames drawing the ordinary view, compiled nothing,
and freed itself looking exactly as though it had worked. Every pipeline it was
there to build got built on the first frame the player saw instead.

The camera now hangs off the warm-up node itself, which is a plain `Node` and so
leaves the camera at the root of its own transform chain — the poses were always
in world space, so nothing else changed. Warming the level properly takes **7.1 s
on an M1**, which is the size of the bill that was previously being paid in front
of the player.

Its vantage points are worked out from the ground plane now rather than typed
in. The two numbers that placed them were sized for a 120 m map, and when the
ground doubled they went stale without complaint: the warm-up still ran, it
simply stopped seeing the outer half of the level.

> **The machine matters more than any of this.** While these numbers were being
> taken, `iCloudDriveCore` was sitting at 82 % of a core, the load average was
> 6.8, free memory was down to ~60 MB and the machine had swapped 16.7 million
> pages. Four *identical* runs produced between 0 and 29 hitches. Before
> concluding the game stutters, check `uptime` and Activity Monitor — a runaway
> background process will out-stutter anything in here.

### The stutter near the house was not the rendering

A second, unrelated one, found later and worth writing down because the shape of
the mistake repeats. Walking towards the house hitched, and the obvious suspects
— the 68 MB house model, its twelve materials — were all innocent.

Godot's GLB importer gives **every mesh in a model its own `StaticBody3D` with a
`ConcavePolygonShape3D` cut from that mesh**. What arrived was:

| | |
| --- | --- |
| the house | 43 bodies, 31,032 triangles of collision |
| the cart | **2 bodies, 13,416 triangles** |

The player's tick is a `move_and_slide()`, three `test_move()`s for the step-up
and a contact pass, and each of them has to ask that geometry whether a capsule
has touched it. Measured with the player walking past the house wall:

| | physics, a tick |
| --- | --- |
| as imported | **8.9 ms** |
| cart simplified | 3.1 ms |
| both simplified | **1.5 ms** |

8.9 ms is half a 60 Hz frame spent deciding whether a capsule has touched a
cart — and the cart was two thirds of it, for a prop you walk around.

**And the cost is not local.** That was the second thing learnt, later and the
hard way: with the trimesh colliders in place a tick cost ~10 ms out on the
*empty plain* as well, forty metres from the house. Forty-five concave bodies
are expensive to have in the world at all, not only to stand next to — which is
why `smoke_test.gd` measures both places and asserts an absolute figure rather
than a ratio between them. A ratio looked like the load-independent choice and
was worthless: 0.88 before the fix against 2.3 after it, the wrong way round.

The fix is
[`SimpleCollision`](scripts/simple_collision.gd) on the `House` and `Cart` nodes:
one convex hull per mesh instead of a trimesh. Hulls keep the shape of things
that have one — a box over a sloped roof is a block the player stands on in
mid-air — but QuickHull takes a second over forty-five meshes, so they are baked:

    godot --path . --headless --script res://tools/bake_colliders.gd

Run that again whenever one of the models is re-exported. Without a bake nothing
breaks: `SimpleCollision` falls back to per-mesh bounding boxes, which are wrong
in detail and right in kind. `smoke_test.gd` checks the shapes were replaced,
that the cart is still solid, and that a tick beside the house still costs less
than 6 ms — the three ways this can quietly come undone.

## Performance, September 2026

A pass over the whole map after the bay, the orcs and the heroes went in.
`tests/perf_tour.gd` is the tool it left behind: it walks the camera round six
places found from the level itself (spawn, the wood, the hamlet, the mist
village, the pier, the orc camp), and at each one reads the frame, the draw
calls, the sun's share of them and the primitives at every graphics setting,
then the physics tick with the knight walking.

    godot --path . --script res://tests/perf_tour.gd    # not --headless

Measured on the M1 (while `iCloudDriveCore` held most of a core — the numbers are
only comparable within one run), in ms a frame:

| place | High before | High after | Medium | Low |
| --- | --- | --- | --- | --- |
| spawn, looking into the wood | 19.5 | 16.2 | 10.8 | 8.3 |
| in the wood | 14.2 | 11.4 | 8.4 | 4.2 |
| the hamlet | 17.2 | 12.8 | 10.4 | 4.9 |
| the mist village | 17.5 | 14.0 | 10.4 | 5.6 |
| the pier | — | 11.8 | 8.7 | 3.9 |
| the orc camp | 15.6 | 11.3 | 8.4 | 4.0 |

(The pier has no "before": the first version of the tour looked at the pier's
origin, which is in the middle of the map.) The load, warm-up included, went
from 9.3 s to 2.5 s, video memory from 2.7 GB to 0.6 GB, and Low from 6.5–10 ms
to 4–8. The physics tick, knight walking, is 0.7–4 ms everywhere, 6.6 at worst
in a fight at the orc camp.

### Textures

62 textures had been imported **lossless and without mipmaps** — the village's
38 maps at 4096², the imps', the puglins', Arkdeva's, the tree's. They are set
up from script (`Building`, `Monster`, `Arkdeva` load them by name), so the
importer never saw them used in 3D and never switched them to VRAM compression
on its own. At 4 bytes a pixel that was ~1.9 GB of video memory, and with no
mips every distant wall read the whole 4K map — which is also why Low's mipmap
bias did nothing for them.

They are all VRAM-compressed with mipmaps now; normal maps use the importer's
normal-map mode; the village's diffuse and normal maps are limited to 2048 and
its roughness and metalness to 1024. The kit's `_alpha` maps are left alone
because nothing loads them. The small palette textures in `assets/forest` are
left alone too: mipmaps would bleed one swatch into the next.

### The stall in every fight

A blow that drew blood cost the physics step it landed in **10–25 ms, every
time**. `Blood._spray` made a new `GPUParticles3D` and a new
`ParticleProcessMaterial` per hit, and that was nearly all of it. The spray now
comes from a ring of six emitters kept in the level and restarted; they share
one process material that throws along the emitter's -Z, and the emitter is
turned to face the blow. `World._prewarm_effects()` makes the ring, the blood
splat and dust ring images (both worked out a pixel at a time in script) and the
ground wave's meshes while the level loads, and `Sfx.warm()` reads the swing and
bow sounds off the disk before the first swing rather than during it. A fight at
the orc camp went from a worst step of 23–26 ms to about 6.

Finding it took timing *bands*. `Performance.TIME_PHYSICS_PROCESS` is the worst
step of the last whole second, refreshed once a second, so it cannot say which
step was slow or whose it was; nodes at fixed `process_physics_priority` values
reading the clock between the knight, the creatures and everything else can.

### Colliders with hundreds of points

A creature walking into something runs `StepUp.climb`, which is up to ten
`test_move`s a tick, and each of those is as dear as the shape it is pressed
against. The importer's *Simple Convex* had given the loose stones hulls of up to
471 points and the big rocks 330, and the watchtower was a 4 300-triangle
trimesh. A golem leaning on a big rock cost 10–20 ms a tick; a capsule
`test_move` against the tower cost 8 ms.

The three imports now ask for a convex *decomposition* with a cap on the hull:
one hull of at most 24 points per stone, one of 32 per big rock, and up to six of
32 for the tower (a column and its roof, so it can still be climbed). The same
`test_move` is now 0.1–0.3 ms. `physics/shape_type` is 0 with
`decomposition/advanced` in each file's `_subresources`.

### What was looked at and left

- **The creatures' thinking.** In a windowed run the physics tick is 1–4 ms
  everywhere once the two things above were fixed; the 4–6 ms first read in
  headless runs was the once-a-second maximum, not the typical step.
- **Draw calls.** The dearest views are ~2 000 draw calls on High, ~40 % of them
  the sun's shadow, but switching whole groups' shadows off moved the frame by
  under a millisecond: High is bound by filling pixels, which is why MSAA and
  SSAO were the things worth touching.
- **The wolves' rigs** (68 pieces each) and the 8 256-triangle grass clump are
  still the biggest things left, and both are Blender work.

## Tariel, skinned

Tariel is now a real skinned character: `assets/tariel_rigged/tariel_rigged.glb`
holds one 36-bone skeleton (UE mannequin names — `pelvis`, `spine_01`,
`upperarm_l`, `thigh_r`…), the body bound to it with every armour plate rigid on
a single bone so nothing stretches, his own sword and shield on the `weapon_r`
and `shield_l` sockets, and 47 clips from Mixamo's Pro Sword and Shield pack
retargeted onto it in Blender. It is driven by `scripts/skinned_rig.gd`
(`SkinnedRig`), which extends `CharacterRig` and answers every call the
controller makes, so `player.gd` is unchanged. `tariel.tres` points at
`scenes/player/tariel_rigged_visuals.tscn`; pointing it back at
`tariel_visuals.tscn` restores the procedural knight, which Avtandil still uses.

| In game | Clip |
| --- | --- |
| idle / walk / run | `SS_Idle`, `SS_Walk`, `SS_Run`, rate matched to ground speed |
| backwards, strafing while locked on | `SS_Backward_*`, `SS_*_Strafe_Walk`, `SS_*_Run_Strafe` |
| flurry | `SS_High_Attack` → `SS_Cross_Slash` → `SS_Downward_Slash` |
| air / plunge | `SS_Downward_Slash` |
| block, blocked hit | `SS_Block_Idle`, `SS_Blocked_Impact` |
| walking behind the shield | `SS_Block_Walk`, `_Back`, `_Left`, `_Right` — legs from the walk, the guard from `SS_Block_Idle`, baked in Blender; blocking caps the pace at `walk_speed` |
| hit | `SS_Head_Impact` |
| dash / dodge | `Roll_Quick_To_Run` |
| knocked down / get up | `SS_Falling_Back_Death` (and back to front) |
| airborne | `SS_Running_Jump` |
| crouch, slide | `SS_Crouch_Block_Idle` — *stand-in, the pack has none* |

He does not climb walls (`can_climb = false` in `tariel.tres`): only the hunter
does. The cape (`cape_00`–`cape_06`) and the ponytail (`hair_00`–`hair_04`) are
`SpringBoneSimulator3D` chains built by the rig, kept off the legs and body by
capsules on the thighs, calves, pelvis, spine and head — `Cloth` in the
inspector for stiffness, drag and gravity.

The clips' travel sits on the `root` bone and is taken out as root motion
(`AnimationPlayer.root_motion_track`), so the controller still moves the body.
Each swing's cutting window was measured in Blender off the blade tip and is in
`SkinnedRig.CUT_WINDOW`. The Blender source, the Mixamo files and the retarget
scripts live outside the repo in `~/Desktop/vepxis-art/` (its `NOTES.md` says
how to redo any of it).

    godot --path . --script res://tests/skinned_rig_test.gd -- /tmp/shots

### The cut in the air

His blade's streak is a `BladeArc` (`scripts/blade_arc.gd`,
`assets/fx/blade_arc.gdshader`) rather than the [SwordTrail] ribbon the
procedural rig and the wolves' claws still use. The ribbon joined the blade's
position frame to frame with straight segments, and a fast swing turns a long
way between two frames, so its outline had corners. The arc keeps each sample
with the time it was taken, drops frames where the pose has not moved (the
pose only changes on physics ticks), blurs the samples lightly along their
length — the clips are keyed at 30 a second and the blade changes direction at
every key — and lays its rows along a Catmull-Rom curve through them at even
steps of *time*. Its inner edge draws in toward the outer as it ages, so it
reads as a crescent that sharpens behind the blade. The shader draws a bright
hairline where the tip went, a paler sheet behind it, wind streaks drifting
back along it, a slight warp of the air behind, and a tail that frays away.

## Avtandil, skinned

The hunter went the same way as the knight:
`assets/avtandil_rigged/avtandil_rigged.glb` is his model on a skeleton with
the same bone names, his bow on its own bones (`bow_l` grip, `bow_limb_u` /
`bow_limb_l` so the limbs can bend, `bow_tip_u` / `bow_tip_l` for the string
ends) and `draw_r` where the fingers hold the string — plus 75 clips: Mixamo's
Pro Longbow pack and seven climbing clips. `scripts/skinned_archer_rig.gd`
(`SkinnedArcherRig`) is `SkinnedRig` with his clip table, and the controller
reaches the bow through `aim_bow()` / `loose_bow()` by name, so either archer
rig answers.

| In game | Clip |
| --- | --- |
| idle / walk / run / full pace | `AV_Idle_01`, `AV_Walk_*`, `AV_Run_*`, `AV_Sprint_Forward` over 5.5 m/s |
| draw | `AV_Nock_Draw` — the back half of the pack's draw (the quiver reach dropped), bow arm held on the target throughout, baked in Blender |
| holding / walking drawn | `AV_Aim_Idle_01`, `AV_Aim_Walk_*` |
| loose | `AV_Shooting_Arrow`, the snap after the string goes |
| crouch | `AV_Crouch_Idle_01`, `AV_Crouch_Walk_*` |
| wall: up / down / sideways / still | `AV_Climbing_Up_Wall`, `AV_Climbing_Down_Wall`, `AV_Shimmy_*`, `AV_Hanging_Idle`, picked from the climb drive and rate-matched to it |
| over a ledge | `AV_Braced_Hang_To_Crouch` |
| dash / dodge | `AV_Dive_Forward`, `AV_Dodge_Forward` |

The bow itself is `scripts/bow_modifier.gd` (`BowModifier`), a
`SkeletonModifier3D` that runs after the clips: the chest tilts onto the aim
pitch, the limbs bend towards the string hand as the draw builds, the string
runs from each tip to the fingers (nodes `bow_string_u` / `bow_string_l`, as
the procedural bow had them), and an arrow sits on it while drawn.

    godot --path . --script res://tests/skinned_archer_test.gd -- /tmp/shots avtandil

## The mage and the rogue

Two more characters on the select screen, from block-built models the user
made (`assets/magic-person/mage1.glb`, `assets/dager-person/dager.glb`).

**Rigged and dressed in Blender** (`~/Desktop/vepxis-art/heroes/heroes.blend`):
`tools/hero_rig.py` turns each into one mesh rigidly skinned to a Tariel-style
skeleton (UE names, `weapon_l`/`weapon_r` sockets), turned to face -Y and
scaled to 1.8 m; the mage's sleeves are split at the elbow and his robe is
shared between hips and thighs so it follows the legs. `tools/hero_dress.py`
adds the house style as boxes bound to bones — for the rogue Avtandil's
leather: a baldric, bracers with gold bands, pauldrons, wrapped shins, thigh
sheaths, a cowl, a mask, eyes and brows; for the mage a leather belt with a
gold buckle, a gold hem and front band, gold cuffs, eyes and white brows, and
a glowing crystal in a gold ring on the staff. His book is gone. Clips are
Mixamo's (`mixamo_heroes/`: the magic pack, knife stabs, the dual combo,
ninja idle and run, flips, falling, floating) plus Avtandil's crouch set and
mantle, retargeted with `tools/retarget_mixamo.py`.

**The rogue** (`rogue.tres`, `SkinnedRogueRig`) is the knight's controller and
rig with his own table: three stabs in a flurry at `swing_rate` 2.1, the dual
combo as the heavy, the double stab off a jump, a backflip for the evade. Both
daggers cut the air (`SkinnedRig.off_hand_blade`; the blade length and its
rest direction are per character now). No shield: 6.8 m/s, the longest roll,
35% crits.

**The mage** (`mage.tres`, `SkinnedMageRig`) fights from afar. His weapon is
`CharacterProfile.Weapon.STAFF`, which the controller treats as it treats the
bow — hold to charge, let go to cast, a tap is a quick weaker cast — but the
profile's `projectile` is `scenes/fx/spell_bolt.tscn` (`SpellBolt`, an
`Arrow` with `projectile_drop` 0 that glows, trails gold and bursts where it
lands; the model is the user's `skill1.glb`). Charging holds the sustained
two-handed cast and brightens a light in the staff's crystal. He jumps 3.6 m
(`jump_height`) and, holding the jump on the way down, levitates (`levitation`
seconds sinking no faster than `levitate_fall`, 2.1 m/s), on Mixamo's float.

### The bolt

- **Thrown with the staff.** Letting go plays the staff's half of
  `MG_Cast_1H` (0.50–0.84 of it): drawn back over the shoulder and brought
  round to the front. The clip's free-hand push is not played. The rig's
  `cast_lead()` says how long the staff takes to come through (0.23 s), and the
  controller sends the cast (`net_cast`) at once and the bolt (`net_loose`)
  after that lead, from `spell_origin()`, the crystal.
- **Slow, then fast — over the whole flight.** It leaves the crystal at
  `start_share` (30 %) of its speed as a spark that swells to full size, and
  gathers pace with the distance it has covered, reaching full speed only near
  the end: over `ramp_share` (90 %) of the way to a locked quarry, or
  `ramp_distance` (16 m) thrown at nothing, kept between `ramp_min` and
  `ramp_max`. The pace follows the way through raised to `ramp_curve` (1.3), so
  most of it comes late. (It used to be at full speed half a second after
  leaving, whatever it was thrown at.)
- **Its tail** is its own, not the arrow's two flat bands: four
  [GlowTail](scripts/glow_tail.gd)s fed the head's position every tick — a wide
  soft glow, a hot white core that cools to gold down its length, and two fine
  strands wound round the line of flight (a helix, opening out as it speeds
  up) — plus embers shed along the way. A `GlowTail` is a strip through the
  points the head has passed, turned every frame to face the camera, tapering
  to nothing at the tail and soft across its width, so it has the same body
  seen from the side, from behind or end-on; points live `life` seconds, so the
  tail is short while the bolt is slow and long at full speed.
- **It hunts what is locked.** `net_loose` carries the locked target's path
  and the bolt `hunt()`s it, bending towards it no harder than `steer` (36 m/s²
  sideways). That is a tight curve just off the staff and a gentle one at full
  speed, so walking or running on across the line is followed and hit.
- **It can be dodged.** A quarry that says `is_evading()` (a player rolling or
  dashing, a Fighter dashing aside), or whose velocity breaks sideways off the
  bolt's line by more than `dodge_kick` (4 m/s) against its recent pace, shakes
  it off. From then on it flies straight, and it goes through a body rolling
  out of its way.
- **It does not come back.** Once it is past its quarry, hit or not, it fades
  out where it is. Unlocked, it flies straight and fades at `reach` (70 m).

`tests/heroes_test.gd` checks both: their rigs and clips, the charge, the bolt
leaving the crystal slowly and gathering pace, flying straight unlocked,
following a body walking across it, losing one that breaks sideways or rolls
and going out once past, the jump clip following the arc, the high jump and
the float, the stab cutting with both hands.

### The mage's jump

`MG_Jump` was keyed by hand in Blender (`heroes.blend`, on `mage_rig`, from
`MG_Idle`'s pose): the push off with one knee driven up, both knees up and the
staff raised on the way up, open at the top with the free arm out, legs
reaching down and the arm up for balance on the way down. It is not played at
its own pace. `SkinnedMageRig` seeks it every frame to `0.5 - 0.5 · vy / v0`
(`v0` the take-off speed), so rising at full speed is its start, the top of the
arc its middle and falling as fast again its end — the top of the clip is the
top of the jump however high it goes. Holding the jump on the way down still
floats him (`MG_Float`); `MG_Fall` is no longer used.

## Health, stamina and the parry

Every character has **health** and **stamina** (`max_health`, `max_stamina`
in the profile: Tariel 160, Avtandil 120, the mage 100, the rogue 110; stamina
100, the rogue's 110). `PlayerHud` (`scripts/player_hud.gd`) draws your own two
bars in the top-left, each as long as its pool, with the chunk a blow took
lingering pale for a beat before it drains, and the stamina bar dimmed while it
is spent.

**Stamina** pays for the roll (`roll_stamina`), stretching it into the dodge
(`dodge_stamina`), every attack — a swing, an arrow, a spell
(`attack_stamina`) — and every blow caught on the shield (`block_stamina` per
point of damage, 2.4). As in every Souls game what matters is that there is
*some* left: the last of it buys one more roll and the bar runs out under it;
at zero nothing that costs stamina can be done. It comes back at
`stamina_regen` (40/s, 12/s behind the shield) once `stamina_delay` (0.55 s)
has passed — `stamina_empty_delay` (1.1 s) if it was run all the way out — and
never mid-roll, mid-swing or while drawing.

**Blocking** (Tariel only) takes a blow on the shield for stamina instead of
health. A blow that lands on a shield with no stamina left **breaks the
guard**: he is held for `guard_break_time` and half the blow comes through.

**The parry.** A blow that arrives within `parry_window` (0.22 s) of the shield
going up is **thrown back**: it costs nothing, the shield punches out
(`SkinnedRig.parry()`, the guard's jolt played fast), sparks fly off it
([ParryFlash](scripts/parry_flash.gd): a star, a fan of sparks falling back
towards whoever struck, a lamp flaring) with a clang
(`sounds/parry/clang.wav`, made in code: the inharmonic ring of struck steel
over a thud), and whoever threw it is told on the host (`net_parried`) and
**reels** ([Recoil](scripts/recoil.gd)):

1. *The rebound* (0.3 s): its weapon goes back the way it came — the attack
   clip that threw it is run **backwards**, fast (the orc's AnimationPlayer at
   −2.4; `SkeletonAnim.rewind()` for the imps and puglins) — while the swinging
   arm is thrown up and back and the chest and head go back with it.
2. *The fold*: its force spent, the body doubles forward over itself, head
   down, and hangs there open.
3. *The recovery*, back to its guard, `Recoil.STAGGER` (1.6 s) after the parry.

Both are laid over whatever the clip says, bone by bone, as turns about the
creature's own side-to-side axis, so the same numbers read the same on the
orc's skeleton and the Bestiary's. Arkdeva, posed limb by limb, has its own
move for it (`Act.PARRIED`): up on its hind legs with both scythes flung high
and wide, then down low with them hanging. The rest of a parried combo is not
thrown, and while it reels a creature takes **half as much again**
(`Recoil.RIPOSTE`) from every blow. Only ordinary blows can be parried: a slam,
a stamp, a spin, the ground coming up — the blows that floor you (a combo of
one) — are only ever blocked.

**Falling.** At no health he goes down (`Reaction.DEATH`), "YOU HAVE FALLEN"
comes up across the screen, the creatures leave him be (`net_dead` is
replicated and `Brute._fallen()` is checked when they pick someone to fight
and when their blows land), and after `respawn_time` (4 s) he is back on his
feet, whole, where he first stood. Until there are potions and fires to rest
at, health also comes back slowly on its own (`mend_rate`, 4/s) once nothing
has hurt him for `mend_after` (10 s). `immortal` (health stops at 1) is for
tests that are about something else.

    godot --path . --headless --script res://tests/vitals_test.gd

## The second round of combat: balance, two shields, the perfect dodge

**What things hit for.** Creatures now hurt: an imp's blow is 40, a
puglin's 48, a wolf's swipe 38 — three or four of them fell anyone — and the
raid bosses (both orcs, Arkdeva) hit for 220, more than any character has, so
every blow of theirs is a kill unless it is rolled, blocked or parried. A blow
on a shield never costs more than 70 % of the stamina bar, so even a boss's can
be taken on it once.

**Wolves** fight now: `Wolf._land_swipe()` lands `swipe_lands_after` (0.32 s)
into a swipe on whoever is in reach and in front, as one blow of two (a flinch,
parryable — a parried wolf is knocked back and cannot swipe for
`parried_stagger`). They notice a player at 11 m (`sight_range`, was 20) and
give up at 18. All eight live in one den east of the settlement, round
(74, -16), each on its own spot 6 or 10.5 m from the middle and patrolling only
4 m of it (`prowl_radius`), so they are together but never in a heap.

**The parry, animated.** `SS_Parry` was keyed in Blender off `SS_Block_Idle`
(`tariel.blend`): a small wind-up, then the shield swept out across the blow to
his left with the body opening behind it and the sword drawn back for the
answer, held a moment, and back to the guard. `SkinnedRig.parry()` plays it.

**The inventory** (**I**, `scripts/inventory.gd`) holds the shields. Tariel has
two and carries one:

| | round shield | tower shield |
| --- | --- | --- |
| parry | yes | no |
| a blow on it costs | stamina × 1 | × `tower_block_share` (0.55) |
| guard | `SS_Block_Idle` | `SS_Tower_Block` — lower, knees bent, leaning into it |

Both are in `tariel_rigged.glb` (`tariel_shield`, `tariel_tower_shield`, the
tower one modelled in Blender: crimson, iron-rimmed, a gold Bolnisi-style
cross and boss, bound to `shield_l`); `SkinnedRig.set_shield()` shows one and
hides the other, and `Player.net_shield` tells the other peers. While a screen
of his own is open (`Player.menu_open`) the body stands still and takes no
buttons — the world is not paused, since the game may be online. Characters
with no shield see their weapon and a note that they carry none. 1 / 2 or a
click puts one on.

**The map** (`scripts/world_map.gd`). The level photographed once, from 300 m
straight up with an orthographic camera over its 240 × 575 m, when the map is
made (without the fog, which from up there turns everything grey). A small map
in the bottom-right corner turns with the camera — what is ahead on screen is up
— and shows 90 m of it; **M** opens the whole of it, north up. On both: you (a
gold arrow), the other players (blue), creatures (red; on the small map only
those within reach of it) and the people with work (gold).

**The perfect dodge.** A blow that arrives within `perfect_dodge_window`
(0.3 s) of a roll starting goes through a body that is already out of the way
**perfectly**: the roll's stamina comes back, and for a second the body sheds
copies of itself ([ShadowTrail](scripts/shadow_trail.gd)) — its own skeleton and
meshes duplicated with the pose they hold, cut loose from everything that moves
them, in a dark shadow rimmed with violet, each fading and sinking as it goes.
Every peer sees it (`Reaction.PERFECT_DODGE`).

**The mage in the air.** [MageWind](scripts/mage_wind.gd): two discs of
spiralling light turning opposite ways under his feet and a ring of wisps that
orbit and stream down off them, faded in when he leaves the ground and stronger
while he floats. **His bolt** no longer rolls (a spinning orb with a crackling
tail read as a thing tumbling), and is drawn between physics ticks
(`Engine.get_physics_interpolation_fraction()`), so at forty metres a second it
glides instead of stepping.

**New looks** (`~/Desktop/vepxis-art/tools/hero_style.py`, in `heroes.blend`).
The mage in Georgian dress: a burgundy chokha, rows of ivory gazyri with silver
caps across the chest, a black belt with silver plates and a khanjali, a black
papakha where the pointed hat was, and no scroll on his back. The rogue in
black, with dark leather, steel, and crimson at the bracers, the sheaths and a
sash. The models are UV'd onto a palette atlas; the script reads each face's
colour off it and moves the face to a flat material of its new colour, so the
atlas is left alone (`heroes_before_style.blend` is the file before).

## Swapping in the real models

Replace the scene under `Visuals` with the imported knight, keep the origin at
the feet, and either keep driving it with `TarielRig` (if the joints are named
the same — retarget the animation library onto them by editing `BONE_MAP` in
`anim_retarget.gd`, which is the only place the two rigs are tied together), or,
for a properly skinned model, retarget the library onto its `Skeleton3D` at
import time and feed an `AnimationTree` from the `state` enum plus the
`jumped` / `landed(impact_speed)` / `dash_started` / `attack_started` /
`slide_started` / `climb_started` signals. Resize the
`CollisionShape3D` to the model and keep `max_step_height` below the capsule
radius.

## Layout

```
project.godot            input map, physics layers, gravity
icon.svg
scripts/player.gd        the controller, and the target lock and bow it drives
scripts/game.gd          autoload: which character is being played, and settings
scripts/main_menu.gd     the front end, built in code
scripts/net.gd           autoload: the connection and who is in it
scripts/world.gd         the level, and spawning the bodies that stand in it
scripts/character_portrait.gd  the model on its card, lit and turning
scripts/graphics.gd      what low and high actually change
scripts/menu_style.gd    the widgets and the palette both menus are made of
scripts/pause_menu.gd    the in-game menu
scripts/target_marker.gd the sight over whatever is being fought
scripts/step_up.gd       walking up a step, for anything on legs
scripts/character_profile.gd  one playable character, as a resource
scripts/arrow.gd         an arrow in flight, swept rather than collided
scripts/archer_rig.gd    the bow: raise, draw, flex, loose
tools/build_avtandil.gd  writes assets/avtandil/avtandil.tscn
scripts/grass_field.gd   grass bending, wind, LOD and culling
scripts/sword_trail.gd   the streak a blade leaves, on a fixed vertex buffer
tools/build_scatter.py   generates the meadows in the world scene
scripts/character_rig.gd procedural animation, and the clip layers on top of it
scripts/anim_retarget.gd replays the animation library on the skeleton-less model
scripts/pipeline_warmup.gd draws the level once at startup so it need not stall later
scripts/dust_ring.gd         the dirt a blade throws up going into the ground
scripts/simple_collision.gd  swaps the scenery's trimesh colliders for hulls
scripts/collider_bake.gd     the hulls, worked out once and kept
scripts/forest.gd            grows the wood: multimeshes, pooled trunks, wind
scripts/horizon.gd           the mountains standing behind the boundary wall
scripts/marsh.gd             the marsh strip and the bay: ground, water, mist
scripts/paths.gd             the worn tracks between the places on the map
scripts/quest_book.gd        the quests: who gives what, counting, the on-screen text
scripts/quest_giver.gd       a person with a job: model, mark, breathing, facing
scripts/venom.gd             Arkdeva's poison: the gob, the splash, the pool
tests/quest_test.gd          headless checks: the givers, talking, counting, handing in
tests/venom_shots.gd         photographs the poison in flight, landing and drying
scripts/mist_village.gd      the misty village's materials, fixed up at load
tests/marsh_test.gd          headless checks: the marsh, the mere, the village
scripts/building.gd          gives a kit .fbx its textures and its UCX hull back
scripts/spinner.gd           turns whatever hangs off it, off the clock
scripts/monster.gd           a Bestiary creature, wandering its patch of wood
scripts/skeleton_anim.gd     replays the animation library on a skinned rig
tools/inspect_assets.gd      what an imported model actually contains
tools/inspect_skeletons.gd   whether a kit's rig can take the library's clips
tests/world_shots.gd         photographs the level from fixed vantage points
tests/monster_shots.gd       photographs each creature, walking
tests/draw_budget.gd         says where the draw calls go, one subsystem at a time
tests/physics_budget.gd      the same for the physics tick, on a fresh level each time
tools/bake_colliders.gd      writes those out; re-run when a model changes
assets/tariel/tariel.glb the Tariel model
assets/anim/ual2.glb     Quaternius Universal Animation Library 2, CC0
scenes/player/player.tscn
scenes/world/greybox_world.tscn
tests/smoke_test.gd      headless checks: movement, jump, dash, slide, climb, camera
tests/combat_test.gd     creature facing, arena bounds, blocking, dismemberment
tests/pose_shots.gd      renders one PNG per animation state
tests/clip_shots.gd      renders any library clip on Tariel; A_TPose is the check
tests/debug_retarget.gd  prints mannequin vs Tariel limb angles, and the walk stride
tests/crouch_shots.gd    renders just the crouch and the double-tapped dodge
tests/climb_shots.gd     renders the wall climb, and a stride sampled right round
tests/archer_test.gd     headless checks: the archer, the bow, the target lock
tests/multiplayer_test.gd  headless checks: who owns what, who is spawned
tests/net_host.gd        one half of the live two-process check
tests/net_client.gd      the other half
tools/two_peers.sh       runs both and reads the two logs together
tests/menu_test.gd       headless checks: the menu's pages and the graphics setting
tests/perf_probe.gd      frame-time distribution, one configuration at a time
tests/inspect_ual2.gd    dumps the library's bones, rests and clip list
tests/screenshot.gd      renders a single frame to a PNG
```

```
godot --script res://tests/pose_shots.gd -- /tmp/poses   # idle, walk, run, jump, attack
godot --script res://tests/clip_shots.gd -- /tmp/clips   # the library, on Tariel
godot --script res://tests/climb_shots.gd -- /tmp/climb  # the wall climb, and the stride
godot --headless --script res://tests/inspect_ual2.gd    # what the library contains
```

## The fourth round: the parry move, recoil, the bag, the village, the menus

**The parry is a move now.** Raising the round shield *is* the parry: the
guard goes up as `SS_Parry` (re-keyed in `tariel.blend`, stronger — a coil, the
shield swept out across the blow with the body behind it, a hold, and back) and
only then settles into `SS_Block_Idle`. A blow that lands within
`parry_window` (0.3 s) of that move is parried; later it is an ordinary block.
The move has its own cooldown (`parry_cooldown`, 0.7 s) so the guard cannot be
fluttered for a permanent parry. `Player.net_parry_move` plays it on every peer.

**Parried wolves recoil.** `Wolf.parried()` → `net_reel()` on every peer: for
`Recoil.STAGGER` the wolf rears back off its forelegs (`rig.rotation.x`) and is
jolted away, then eases back into its stance. Orcs, imps, puglins and the golem
already had their recoil; the wolf was the one that just stood there.

**The bag** (**I**, `scripts/inventory.gd`) is laid out like Elden Ring's:
tabs (Weapons, Shields, Goods; Q / E), a grid of slots with drawn icons, the
chosen item's name, kind, picture, attributes and effect in the middle, and the
character's status down the right (HP, stamina, attack, critical, run, roll,
what is equipped). Arrows / mouse to choose, Enter / 1 / 2 to put on.

**The big map** (**M**) is full-screen now, lit, with the photograph taken
without fog: the wheel zooms about the mouse, dragging moves it, C brings it
back to you, M or Escape closes it; a legend and the keys along the top.

**The assassin.** One knife, not two cleavers: both big blades removed from
`heroes.blend` and a long knife built on `weapon_r` (tapered blade, crimson guard
with silver ends, wrapped grip, silver pommel). Every stab of the combo is the
knife hand's (`DG_Stab_Lead_R` is `DG_Stab_Lead` mirrored), played at 2.5×. His
face boxes were moved onto the atlas's eyes. He runs at the hunter's 5.9 m/s,
and upright: `DG_Run` and its back / left / right were rebuilt from the ninja
run (kept in the blend as `DG_RunNinja*`) — the upper body rotated about the
pelvis to 8° off vertical, the head keeping its old facing, the legs their old
world pose, and the arms taken from the mage's run (the right one mirrored half
a cycle on).

**The mage** was brought to the others' proportions: hands, forearms, upper
arms, head and feet scaled down.

**The perfect dodge** leaves a shadow and a whoosh (`sounds/dodge/shadow.wav`)
only for the characters with `CharacterProfile.shadow_dodge` — the assassin and
Avtandil. Tariel's is still perfect (stamina back), just without the flourish.

**The village.** The music plays only inside it (`World._play_music_in_village`,
checked every 20 frames). The huts are 1.3× bigger and spread out along the
street; a wooden fence (the kit's `SM_WoodFence`, dressed by [Building], its own
box colliders) goes round `World.VILLAGE` with a gap for the gate on the west.
Seven villagers ([Villager], `assets/villager/villager.glb` — the mage's body in
everyday chokhas, black or white papakha, no staff) walk the street, stop,
fidget, and turn to watch a player who comes near. The test blocks (ramp,
stairs, steep face, platform, pillars) moved out of the world into
`scenes/world/test_course.tscn`, which the tests that climb bring in; the big
rocks are gone, the grass is thinner (`Meadows` spacing 3.4) and the daisies are
off (`Meadows.flowers`).

**The menus.** Behind every page is [MenuBackdrop]: dusk over three drifting
ranges, the moon, stars, sparks rising, the left sunk into shadow. The front is
a column on the left; the other pages are dark gold-edged cards. The hero
select is laid out the way the big games do it: the picked one large in the
middle in a pool of their own colour on a lit stone, a dossier on the right
(name, epithet, weapon, six bars against the best of the roster, what only
they can do, the blurb) and the roster along the bottom.

## The fifth round: any window size, the map photograph, Mixamo locomotion

**Any window.** `window/stretch/mode` is `canvas_items`: menus, HUD, map and
bag scale with the window from the 1600 × 900 they are laid out at. Settings
has a SCREEN row (`Game.set_display`, saved in `user://settings.cfg`): the
window as it opened, 1280 × 720, 1920 × 1080, 2560 × 1440 or full screen. The
hero-select stage keeps its size and stands in the middle of whatever room it
gets, with a soft shaft of light, a breathing glow, a lit stone and motes.

**The map photograph** is taken 2 s after the level loads, not on its first
frame, and taken again (up to eight times) while it comes out as nothing but
sky: on a first run the renderer is still compiling shaders and simply does not
draw what is not ready, which gave a map of pale blue.

**The mage's wind** shows only while he floats (the jump held), not on a
plain jump.

**The assassin's head.** The cowl was weighted to the chest and sat behind the
head, so the face box stuck out of it and every turn of the head left it
behind. It now follows the head, is deep enough to hold it, has an opening
for the face, and the eyes and mask sit on the face instead of in front of it.

**Mixamo locomotion.** The assassin's idle (a fight stance), walks and runs
(forward, back, left, right) and the mage's walks and runs are Mixamo's
(`vepxis-art/mixamo/assassin`, `.../mage`), retargeted with
`tools/retarget_mixamo.py` onto `dagger_rig` / `mage_rig` (same bone names as
Tariel's). The mage keeps his own staff arm, phase for phase, from his old
clips, and his old idle. `ground_speed` in both rigs is measured off the root
bone. The old clips stay in `heroes.blend` as `DGOld_*` / `MGOld_*` and are not
exported.

## The sixth round: the mage's full charge, the assassin's combo and flips, orc music, deaths, wolves

**The mage's full charge.** Held to its end (`draw_time`, 1.4 s) the spell is
a different thing: `SpellBolt.empower()` makes it nearly twice the size, blue-
violet instead of gold (orb, light, tail, strands and embers), with a wider
burst, and `CharacterProfile.full_charge_bonus` (1.8 for the mage) puts that
much more on its damage. While charging, the staff is drawn back as the charge
builds (the cast clip held at its wind-up, `WIND_FROM` → `CAST_FROM`) and the
magic gathers at the crystal as a ball of light that grows with it and turns
blue-violet when full — which is where the bolt leaves from.

**The assassin.** His combo is Mixamo's one-handed sword combo cut in Blender
into its five blows (`DG_Combo_1..5`), each starting where the last left the
blade, so clicking runs one flowing string; after a second without a click it
starts again from the first (`SkinnedRig.flurry_reset_after`). One tap of the
roll is a forward flip (`DG_Run_Flip`), two quick taps a twisting flip
(`DG_Twist_Flip2`) — both carry him the way he is going. (Two taps used to be a
*backflip* played while the body flew forwards, which is what looked mad.)

**Orc music.** `sounds/fight/orc_fight.mp3` plays (`Music` track `orc_fight`)
while an orc within 35 m is chasing or fighting this peer's player, and for 5 s
after; otherwise the village's music inside the fence and nothing outside.

**Deaths.** Imps and puglins no longer end in their knock-back clip: the
clip stops a moment in and the body goes over backwards onto the ground,
lands with a small rock and lies there (`Fighter._topple`). Wolves go down on
all fours and over onto their side (`Wolf._collapse`) instead of being pitched
nose-up into the air.

**Wolves.** Spread out across the den (1.8× further apart), a little quicker
(`prowl_speed` 2.2, `charge_speed` 8.3). Hurt from any distance — an arrow from
beyond their sight — a wolf comes for whoever hurt it and keeps coming for
`provoked_time` (14 s) however far; every wolf within `pack_call` (14 m) of it
comes too (`Wolf.provoke()`).

## The seventh round: a quicker assassin, the mage's pace and strike, holding costs breath

**The assassin's blows** are cut tight in Blender, so the knife is moving from
the first frame, and played quicker (`swing_rate` 2.1). The combo is eight
blows long and turns: the five of the one-handed sword combo, a spinning cut
(`DG_Spin_Cut`) and a backhand (`DG_Backhand_Cut`) from Mixamo's axe set, and
a last big blow off its three-hit combo (`DG_Finisher`).

**His flips** are only their jump — the run-up and the getting up cut off
(`DG_Flip`, `DG_Twist`) — and have more time: the roll 0.6 s, the double-tap
dodge 1.1 s, so the twisting flip is no longer a blur.

**The mage** runs at 5.4 m/s with a quicker cadence (`MG_Run` taken as 2.7 m/s
of ground a cycle).

**Holding costs breath.** `CharacterProfile.draw_stamina`: the mage's charge
takes 14 stamina a second, Avtandil's draw 9; run dry and the shot goes as it
is.

**The bolt's strike** is lightning letting go instead of a ball swelling: a
white-hot spark gone in a tenth of a second, a thin ring of light running
out, forks of lightning cracking from the point, a crown of sparks thrown out
and falling, and the lamp flaring — in the bolt's colours, all bigger for a
full charge (`SpellBolt._burst`).

## The eighth round: the assassin's evade and climbing, the wolf's tell

**The assassin's evade** (superseded by *Evades in a row* below; was `hold_to_flip`):
a tap of the dash is a quick step — Mixamo's standing dodges, the same the
archer's double tap uses, forward, back, left or right as the body sees it
(`SkinnedRogueRig.step_dodge`); with an enemy locked he keeps facing it, so it
is a step to the side or back. Held past `hold_flip_after` (0.16 s) the step
becomes the twisting flip; two quick taps do the same. Pushed away from what is
locked, it is a backflip straight off, still facing it
(`SkinnedRogueRig.backflip`). Everything costs him less: a step 7, the flip 3
more, a blow 7.

**He climbs**: `can_climb` on, and Mixamo's wall climbs, shimmies, hang and
hang-to-crouch retargeted onto his rig (`DG_Climb_Up/Down`, `DG_Shimmy_*`,
`DG_Hang`, `DG_Hang_To_Crouch` as his mantle), their vertical travel on the
root so the body's own movement is not doubled.

**The wolf's tell**: the swipe winds up for longer and plainer (`swipe_windup`,
55 % of a 0.85 s swipe: the arm high and back, the chest rearing) with a red
glint gathering on the claws about to come through, then goes fast; the claws
land 0.58 s in (`swipe_lands_after`), a swipe every 1.5 s.

## The ninth round: the backward flip, the wolf that loses its limbs

**Locked and dodging back** the assassin now does the same twisting flip a held
dash gives, even on the quickest tap (`Player._press_dash_flipper`).

**Wolves run like Tariel** (`charge_speed` 5.6, `flee_speed` 4.5). A cut-off
arm no longer swipes (`WolfRig.swipe` picks the arm that is left); with both
legs cut the wolf drops to the ground, chest low (`WolfRig.is_legless`,
`State.DOWN`). A new attack, the pounce (`WolfRig.lunge`, a 0.35 chance while
it has both arms): it gathers low, both claws glinting red, then springs
forward and brings both arms through, reaching 1.6 m further than a swipe.

**Footsteps** (`Footsteps`, on every hero's rig): ten footfalls cut from
`sounds/persons/run/run.wav` (`step_1..10.wav`). Each foot bone's height is
watched; a foot that has been lifted and comes back to the ground plays one, so
the sound lands with the foot at any pace and on any clip. Quieter walking,
silent standing, in the air, dashing or climbing.

## Evades in a row

Every hero can evade again and again (`Player._press_dash`, `_start_evade`,
`_end_dash`): a press of the dash while an evade is going is kept and the next
starts the moment it ends; a press within `chain_grace` (0.25 s) after one
ends follows on without the cooldown. Each hero's evade is his own — the
knight's and the mage's roll, the hunter's dive. For them a second tap inside
`double_tap_time` still turns the roll in progress into the longer dodge; a
press later in the roll is the next roll. `SkinnedRig._play_action` now starts
a clip over when it is asked for the one already playing (a roll straight
after a roll would otherwise carry on from the end).

The assassin (`CharacterProfile.step_then_flip`, was `hold_to_flip`)
alternates: a step, then the twisting flip if another press follows, then a
step again, and so on (`_evade_chain` even = step, odd = flip). Holding the
button no longer does anything. Locked on, his steps keep facing the target —
backward too: backing off is a step back, and a second press is the flip.
`heroes_test` checks the step–flip–step run, the locked back-step then flip,
and the chaining for Tariel, the mage and Avtandil.

## Sounds of the fight

The user's recordings, cut with ffmpeg into single mono clips with a few
milliseconds' fade at either end (the sources stay where they were dropped:
`sounds/sword-sound/`, `sounds/dager-sound/`, `sounds/all/*-sound1.wav`,
`sounds/orc/orc-aggressive-sound1.wav`, `sounds/assassin/feel-hit-sound1.wav`):

| Clip | Cut from | Heard when |
|---|---|---|
| `tariel/air_1..6` | `sword-air-effect.wav` (six of its seven) | Tariel swings (`SkinnedRig.swing_sounds`) |
| `tariel/hit_1` | `sword-hit-sound1.wav` | his blade goes into a creature |
| `assassin/swing_1..4` | `combo.wav` (three) + `single-hit-dager.wav` | the assassin's knife cuts |
| `assassin/hit_1..3` | `monster-hit-sound1.wav` | his knife goes in |
| `assassin/hurt_1` | `feel-hit-sound1.wav` | he is hurt |
| `all/hurt_1` | `take-damage-sound1.wav` | anyone else is hurt |
| `all/fall_1` | `dropped-person-sound1.wav` | a hero is knocked down or dies (0.45 s after) |
| `all/block_1` | `hit-mount.wav` | a blow lands on a raised shield (`Reaction.BLOCK`) |
| `all/loot_1` | `drop-item.wav` | a creature dies (something falls from it) |
| `orc/roar_1` | `orc-aggressive-sound1.wav` | an orc is roused (`Brute.net_roar`, at most every 8 s) |

The mage and the hunter keep the old, lighter `swing_1..7` (`LIGHT_SWINGS`).
The blade landing is decided on the host, in the creature (`Wolf`, `Brute`,
`Fighter`), which tells the player's every copy through
`Player.net_blade_landed`; hurt, fall and block ride on `net_react`.
Levels, by the user's ask: footsteps low (`Footsteps.volume_db` -16), swings
and hits in the middle (about -30 dB mean once played), the rest under them.

## The assassin's new body, and landing where he lands

**His look** (`assets/rogue_rigged/rogue_rigged.glb`, built by
`vepxis-art/tools/r4_build.py` into `heroes.blend` as `rogue_v4` on
`dagger_rig`): the same box-built man as before, the same proportions, the
boxes' edges softly rounded as Tariel's are, and a good deal more to him — a
hood with a brim and a fallen point, eyes with pupils, a crimson scarf with its
tails down the back, a short cape, a leather vest in three plates, a strap of
throwing knives, a sash and a buckled belt, pouches, flaps, a layered left
pauldron, studded bracers, fingers (the right hand a fist round the knife, the
left open), knee pads, cuffed boots and a better knife. Seventeen flat
materials, no textures; every piece rigid on one bone.

**No slide after an evade** (`CharacterProfile.dash_land_at`,
`dodge_land_at`): where in the evade the clip puts his feet down (0.72 of the
step, 0.66 of the flip for the assassin) the travel brakes to nothing, and
the evade hands on no leftover speed, so a flip lands where it lands. The other
heroes keep 1.0, the old glide.

**Evades chain with no pause** (`Player._evade_landed`): once the clip has put
his feet down, what is left of the evade is only the getting up, so a press
from then on — or one kept from earlier — starts the next evade at once
instead of waiting the recovery out. Pressed over and over: step, flip, step,
flip, not a frame stood still between them.

## Jumps, landings and evades are heard

`Player.MoveSound` (JUMP, LAND, ROLL, STEP, FLIP), cut in Python from the
user's recordings into mono clips with short fades, the sources left where
they were dropped:

| Clip | Cut from | Heard when |
|---|---|---|
| `all/jump` | `jumpup-drop.wav` 0.38–0.78 s (the push off) | a jump (`_do_jump`), or a push off a climbed face |
| `all/land` | `jumpup-drop.wav` 0.77–1.45 s (the feet coming down) | a landing from 3.2 m/s of fall up (`land_sound_speed`), louder by 7 dB towards `hard_landing_speed` |
| `dodge/roll` | `tariel-avtandil/dodge.wav` from 0.5 s, so its thump falls in the roll | Tariel's, Avtandil's and the mage's roll, and rolling out after a knockdown |
| `assassin/step` | `dager-sound/normal-dodge.wav` | the assassin's step |
| `assassin/flip` | `dager-sound/flip-dodge.wav` | his twisting flip |

The moves run only on the body's own peer; `_move_sound` sends the sound to
every peer through `net_move_sound` (dropped if it comes from anyone but the
body's owner). Levels (`MOVE_VOLUME`) put a jump a little over a footfall
and the evades with the fight's other sounds, under the blades. A double-tap
that turns Tariel's roll into the long dodge adds nothing — the roll's sound
is already playing. `heroes_test` jumps and evades each hero and counts
`move_sounds_heard`.
