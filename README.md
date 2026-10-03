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
godot --path . --headless --script res://tests/fighter_test.gd     # imps and puglins: bands, rousing, blows, the whole-combo knockdown, dying, the leash
godot --path . --headless --script res://tests/imp_test.gd         # the imp: size, own clips, circling, leap, evade, thrown by a cut, two at a time
godot --path . --headless --script res://tests/puglin_test.gd      # the puglin: a band as one, balls, mud in the eyes, the three-cut combo, scatter and gather
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
button is pressed again. When it dies the lock goes straight on to whichever
enemy stood nearest *it* (not nearest him), if one is within `lock_range`, so a
fight with a pack does not need the lock taken again after every kill.

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
| sun's shadow | 2 cascades, 95 m | **1 cascade, 55 m**, 2048 map | **off** |
| shadow filter | soft low | soft very low | hard |
| render scale | 1.0 | **0.85**, FSR | **0.7**, FSR |
| at most this many pixels drawn (then FSR) | 2.4 M | 1.6 M | 1.0 M |
| edges | SMAA | FXAA | none |
| texture mipmap bias | 0 | 0 | **+1.0** — surfaces go soft |
| SSAO | on | off | off |
| glow | on | on | off |
| fog | on | on | on |
| how far anything in the lands is drawn (`REACH`) | 240 m | 180 m | 130 m |
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

**Wolf** (`wolf.gd` + `wolf_rig.gd`) — *now the wolf-man with a skeleton and
Mixamo's clips: see "The wolf-man" at the end. What follows is how the first
one, joint by joint in code, was made.* The model is the same kind of thing as
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

`scripts/blood.gd` is built entirely in code, in **blocks like the world it
falls in** (the user's call, after a round of wet, lit, realistic blood that
did not fit): flat unshaded red, cubes and faceted pools.

`Blood.splatter(world, point, direction, on = null, strength = 1)`, where
`direction` is the way the blow was going (see *Blows that are felt*):

* **The spray** — two pooled emitters restarted per blow (`SPRAY_POOL` sets,
  made at load; a new `GPUParticles3D` per hit once cost 10–25 ms): a stream of
  36 small bright cubes thrown along the blow in a narrow fan (`THROW_SPREAD`
  17°, `THROW_SPEED` 2.2–6.2 m/s), tumbling as they fly and fall; and the gush,
  12 bigger, darker cubes that burst out of the cut and shrink away as they
  come down.
* **The ground** — a pool under the wound after a moment, `DROPS` (14) stains
  where the spray was going (each worked out as one drop of the same fan,
  followed down its parabola, laid when it would have got there, stretched the
  way it was moving), and a wider splash where most of them came down. Where
  the ray finds no ground (the rolling land is not always a body it can hit)
  the land's own height is used: before, a stain on a hillside went under the
  hill. One image for all of them: a faceted blob (nine straight-sided lobes),
  darker in the middle, with square drops thrown round it.
* **The body** — with `on`, the creature takes a cut where the blade went in
  (`Blood.wound`): a `Decal` laid along the blow, carried by the part of the
  body nearest, projecting only onto the creature's own meshes (`WOUND_LAYER`,
  1 << 18) and only on the side the cut is on. At most `MAX_WOUNDS` (7).
* The grass and props where most of it comes down are tinted strongly (0.8,
  over 1.9 m): in a meadow the stains lie under the grass.

The blade darkens as it works, a third per cut.

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

## Performance, October 2026

The September pass was made on the 240 × 575 m core. Since then the lands went
round it (600 × 890 m, `Lands`, `LandsPlaces`: five villages, sixteen camps,
forty-nine landmarks, Gulansharo), and the game had got slow on High and
Medium: low frame rates and a judder when running and turning the camera.

    godot --path . --script res://tests/perf_tour.gd    # not --headless

| place | High before | High after | Medium before | after | Low before | after |
| --- | --- | --- | --- | --- | --- | --- |
| spawn, to the wood | 15.8 ms, 6 112 draws | 16.0, 3 452 | 14.3, 5 365 | 12.8, 2 871 | 6.6, 1 933 | 8.1, 888 |
| in the wood | 39.5, 3 790 | 13.2, 2 166 | 27.4, 3 336 | 9.9, 1 619 | 16.0, 1 593 | 7.1, 772 |
| the hamlet | 42.9, 4 296 | 14.9, 2 797 | 28.7, 3 848 | 12.0, 2 235 | 16.5, 994 | 6.6, 555 |
| the mist village | 43.2, 2 204 | 15.3, 1 809 | 30.8, 1 941 | 10.7, 1 456 | 19.8, 924 | 7.4, 513 |
| the pier | 35.3, 963 | 11.2, 836 | 24.4, 614 | 8.4, 478 | 13.9, 283 | 5.3, 208 |
| the orc camp | 48.8, 4 095 | 16.0, 2 562 | 32.6, 3 367 | 12.0, 1 947 | 20.1, 897 | 7.2, 368 |

Video memory 1.49 GB → 1.02 GB. The frame times of the "before" run are high
partly because the machine was busy (see *Measuring* below); the draw calls
are exact.

What was done:

- **The lands' places batched** (`StaticBatch`). The city, the villages, the
  camps and the landmarks are boxes, cylinders and props, 1 329 of them, each
  its own draw call and its own again in each shadow cascade: about 4 000 of
  the spawn's 6 000 draws, drawn whether they could be seen or not. At load
  they are copied into ~600 meshes, one per square of the map × material ×
  size × shadow (small pieces on 32 m squares, middling on 64, large on 96),
  and freed. Pieces under 1.6 m cast no shadow. Left alone: anything with
  children or a script (the land gate), anything see-through, the kit's
  buildings (scenes).
- **Everything in the lands has a reach** (`Graphics.REACH`: 240 / 180 / 130 m)
  and the fog hides where it stops. Small pieces 70 m, middling 150 m (before
  the setting's scale), the big ones the setting's reach, fading into the fog
  over its last 12 %; the wood's trees are capped at it too. The ground, the
  water and the far mountains, which cost little, go on to the horizon. The
  fog is thicker to match (`Looks`: 0.0042 → 0.0052, Low 0.0032 → 0.0058) and
  is on for Low as well, which had none.
- **Occlusion culling** (`Occluders`, `rendering/occlusion_culling`). The
  ground of the lands is a flat grid lifted in its shader, so the CPU never
  knew a hill was there: an 8 m grid of it is now an occluder, each corner at
  the lowest ground within a step of it and 3 m under that, so it is
  everywhere below the drawn ground and never hides what stands on it. The
  big solid boxes of the lands' places (walls, towers, houses:
  `LandsPlaces.occluder_boxes`) and each kit `Building`, shrunk into its own
  outline, are the other occluder. Looking north from the spawn: 2 795 →
  1 583 draws. Checked against pictures with it off (no difference past the
  frame-to-frame noise of the grass and the air).
- **A pixel budget** (`Graphics.PIXEL_BUDGET`). A Retina Mac's full screen is
  3360 × 2100, five times the 1600 × 900 window everything above is measured
  in; High drew all of it. Now no setting draws more than 2.4 / 1.6 / 1.0
  million pixels and FSR brings it up, re-worked whenever the window changes
  size (F11, the display setting).
- **Shadows one step cheaper**: the filter soft-low on High, very-low on
  Medium (from the project's soft-medium), and Medium's single cascade on a
  2048 map.
- **The run's judder** (`VisualSmoother`, on the hero). The body moves sixty
  times a second and the screen is drawn at whatever rate it manages, so at
  45 fps one frame had no step in it and the next two, and a camera smoothly
  following a body that jumps makes the whole world judder round it when it
  turns. The model is now drawn where the body was the fraction of a tick ago
  the frame is drawn at, and the camera follows that. Only *drawn* there: the
  offset goes on after every other `_process` and comes off before any other
  `_process` or `_physics_process`, so the collider, the blows, the IK and the
  skills that move the model (`LevelBeam`) never see it. Godot's own physics
  interpolation was not used: everything moved from `_process` (the camera
  rig, the blade arcs, the bars over heads, the cloth) would have been drawn a
  tick late. The creatures still step at 60 Hz: their own scripts set their
  `Visuals` (a corpse sinking, the golem's stomp), and they are seen from
  further off.

### Measuring

- **Frame times from a script-driven window are only as good as the window.**
  A visible window waits for the display (1/3 of the main thread was in
  `IOSurfaceSharedEvent waitUntilSignaledValue`, sampled with `sample`), an
  occluded one does not, so one run can read 17 ms and the next 5 ms for the
  same frame. Metal gives Godot no GPU timestamps. Draw calls, primitives
  and objects are exact; read those first.
- `_shots_tmp/` probes used this round (not kept): a gameplay probe (stand,
  run, run and turn, swing, all of it, with the spikes and the physics ticks
  in each frame), one that switches each thing off in turn at four spots, one
  that times every script's `_process` by hand (all of them together are
  under 2.5 ms; the orcs are most of it at their camp), occlusion on/off with
  picture differences.
- At the spawn on High the frame is ~16 ms and GPU-bound, right at a 60 Hz
  display's 16.7: a frame just over it waits a whole refresh, which reads as
  a hitch about once a second. Medium (~10–13 ms) has room to spare.
- **iCloud.** The project is on the Desktop, which iCloud syncs: `bird` held
  75 % of a core through every run of this pass, and every import and every
  screenshot is uploaded. Moving the project out of iCloud's folders (or
  turning Desktop & Documents off) gives that back to the game.
- LODs: every heavy .glb already imports with `generate_lods`; nothing to do.

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

**A neck for the assassin**: his head sat down on his shoulders, the hood
reaching to them. Now the head rides 6 cm higher (`HEAD_LIFT` in
`vepxis-art/tools/r4_build.py`) on a neck wrapped in the mask's dark cloth, the
hood stops short above the shoulders and the crimson scarf is a low collar
round the base of the neck — as Avtandil's head stands on his.

## The mage's new body

`assets/mage_rigged/mage_rigged.glb`, built by `vepxis-art/tools/m5_build.py`
into `heroes.blend` as `mage_v5` on `mage_rig`, in the assassin's manner:
box-built, the edges softly rounded, every piece rigid on one bone, flat
materials and no textures (24, `m5_*`; the old atlas is gone). Still the old
Georgian wizard, with more to him: a black fur papakha in ridges with a gold
badge and a glowing stone, a long white beard in steps, a drooping moustache
and bushy brows, eyes with pupils; a wine chokha with gazyri, gold lapels, a
high collar behind the head, a mantle and a back cape with runes at the hem;
bell sleeves rimmed in gold; a belt of silver plaques and a khanjali; a
grimoire on the right hip and two glowing vials on the left; a fist round the
staff and an open hand for the spells; soft boots. The skirt is in two: the
top on the pelvis, a panel on each thigh, so the legs walk under it.

The staff is new too: gnarled, leather at the grip, three prongs curling up
round an ice-blue crystal with motes about it. `SkinnedMageRig.CRYSTAL_UP` is
0.83 m (the crystal sits lower than the old one's), and the crystal's light at
rest is its own blue (`CRYSTAL_LIGHT`); the charge still gathers gold and
turns violet when full, as before. The same 31 `MG_` clips.

## The land rolls (branch `terrain`)

The old square is no longer one flat box (`scripts/terrain.gd`, on
`Level/Ground`). One function, `Terrain.height_at`, answers for all of it on
every peer: a slow roll of a couple of metres, a handful of hills and hollows
placed by hand (`features` — the tallest about 10 m), the land rising towards
the north, east and west walls to meet the mountains, and fading to nothing
before the marsh strip's seam so the two meet at y = 0. Wherever something was
put down on the old box it stays dead level — every mesh in `Level`, the spawn
marks, the people, the creatures, the camps, the wood's clearings — and a worn
track keeps only a fifth of the roll. The drawn ground is a one-metre grid in
8 × 8 chunks; the floor is a `HeightMapShape3D` on the same grid.

Trees, their trunks' colliders, the grass, the tracks and the settlement's fence
are put down at `Terrain.height`/`height_under` instead of 0.

**Two looks for the ground**, one shader (`shaders/terrain_ground.gdshader`),
blending grass, hay-coloured dry patches, bare earth on tracks and steep banks,
rock on steeper ground and mud where the marsh darkens it: `styles[0]` the house
style, painted in flat colours over the old ground's noise; `styles[1]` from
CC0 photographs (`assets/terrain_real/SOURCES.md`). **F8** swaps them in play;
`-- ground_b` starts in the second. `tests/terrain_test.gd` checks the relief,
the flat places, that the floor is what is drawn, the tracks' gradient, the
seam, the trunks and a walk up the tallest open hill.

## Looks: F8, the forest floor and the light grass

**F8** in play steps through the world's looks (`Looks`, `scripts/looks.gd`, a
child of the ground that `Terrain` makes), with the look's name at the top of
the screen for a moment. The level starts in the new one (it is put on as the
ground is built, and again once the meadows have grown); `-- look_N` starts in
another.

| F8 | ground | grass |
| --- | --- | --- |
| 1 **new** (default) | the forest floor, the dark grade | `grass_light.glb`, 364 triangles, and the low sward |
| 2 **old** | the house ground | `grass2.glb`, 8 256 triangles |
| 3 | the house ground | `grass_light.glb` |
| 4 | the photographed ground (`styles[1]`) | `grass_light.glb` |
| 5 | the forest floor | `assets/grass2/gras2.glb`, 6 672 triangles |

A look changes the ground's material (`Terrain.set_style`, the marsh strips
too) and the clump every chunk of the grass is drawn with
(`GrassField.set_clump_scene`) — the same clumps where they stand, not a field
grown again. `tests/looks_test.gd` checks the default, the swap, the mask and
the round back.

**The forest floor** (`shaders/terrain_forest.gdshader`, `Terrain.styles[2]`) is
six photographed CC0 grounds (`assets/terrain_real/SOURCES.md`): fallen leaves,
twigs and moss under the trees; grassy ground under the meadows; bare earth
with sprigs and the odd leaf on the rest of the open ground, so ground with no
grass on it reads as ground; worn earth on the tracks and banks, rock on the
steep, mud by the water. Where two meet they are blended by height — the
brighter photograph takes the edge — so leaves lie over the earth in drifts
rather than fading into it. It is cheap on purpose: each pixel reads only the
grounds that are there (two or three), once each, the relief only within 40 m;
repetition is broken by a slow wash of brightness and hue from the old noise
texture rather than by sampling everything twice. Reads inside those branches
use `textureGrad` with the derivatives taken outside them, or the mip level
would be wrong at the edges.

Where the trees and the grass are is **the ground mask** (`Looks.ground_mask()`):
a 120 × 318 picture of the map, two metres a pixel, red where trunks stand
(`Forest.trunk_positions()`, 5.5 m round each, softened twice so a lone tree
stands in a smudge of leaves rather than on a disc) and green where the meadows
planted clumps. It is made the first time the look is worn (about 130 ms) and
again when `Meadows` grows (`Meadows.grown`). It is the same picture a hand-
painted mask would be, when the ground comes to be painted.

**The dark grade** (the new look only; `Looks._grade`): for a fight that feels
brutal rather than a fairy tale (Lineage 2 and Elden Ring were the brief).
ACES, the sky and its haze grey and heavy, the fog thicker, contrast up and
colour drained (`DARK_ENV`, `DARK_SKY`), a warmer, weaker sun (`DARK_SUN`),
and every material of the wood multiplied down (`DARK_WOOD`). The level's own
values are kept on first change and put back by the other looks.

It has two settings, by the graphics level (`Graphics.current`, which
`Graphics.apply` sets and then has every `Looks` regrade): **Medium and High**
wear the grade above as it was first made (`DARK_*`: ACES, exposure 0.95,
ambient 1.6, sun 1.05 with shadows 0.74, saturation 0.74, the whole wood at
`DARK_WOOD`); **Low** has its own (`LOW_*`). The first try had been judged on
Low, where there is no ambient occlusion, glow or fog and the textures are
blurred, and there it went murky — the wood black, the hero in shadow unread
— so it was lifted twice (AgX, which keeps the shadows open; exposure 1.2,
brightness 1.14, ambient 2.4, shadows 0.56, SSAO 0.55), the green taken down
harder than the other channels instead so it reads a deep olive — the leaves
only (`Looks._is_leaf`, `LOW_WOOD`), the grass clumps and the sward
(`LOW_GRASS`) and the grassy ground (`LOW_GROUND_GRASS`, the forest floor's
`tone_grass`) — and the bark lifted rather than darkened (`LOW_BARK`). Seen on
High that was too light, and the user wanted the first grade back there; so
each keeps its own. `tests/looks_test.gd` switches the setting and checks the
grade follows. The sward sways no more (a hand-high sward barely moves, and
swaying thousands of clumps a frame cost the physics tick at the house).

**The low sward** (the new look only): a second `GrassField`, `Level/Sward`,
grown the first time the look is worn and hidden and stopped when it is not.
`Meadows` plans it with the meadows (`Meadows.sward`, its own dice, so the
meadows come out exactly as before): six short clumps within 1.8 m of every
meadow and edge clump, up to 32 000. The clump (`grass_short.glb`,
`vepxis-art/tools/grass_short.py`) is 60 blades of 0.2–0.4 m, 180 triangles;
its blade texture is the kit's blade turned light grey
(`grass_blade_grey.jpg`) and each blade carries its own colour — fresh and deep
green, grey-green, yellow-green, straw, and the odd dead brown one — darker at
the root; the tint only pulls a patch towards hay where the meadow is dry. It
is drawn to 30% of the grass's distance (`GrassField.draw_distance_scale`,
which the graphics setting leaves alone). With it on, `perf_tour` still draws
fewer primitives in the new look than in the old (spawn 607 000 against
674 000).

**The light clump** (`assets/grass/grass_light.glb`, built by
`vepxis-art/tools/grass_light.py`): 52 curved blades of five sections, 0.4–0.7 m, the same
leaf texture as `grass2`, darker at the root through the vertex colour, normals
bent towards the sky so both faces take the light, opaque rather than
alpha-dithered. 364 triangles against 8 256.

**The photographed ground stuttered** because its twelve textures had been
imported lossless and without mipmaps (the same thing "Textures" above found
in the village): every distant pixel of the whole ground read the full 1K map,
twelve of them twice. They are VRAM-compressed with mipmaps now, normals in the
normal-map mode, as are the forest floor's.

What it costs — `perf_tour` on the M1, primitives drawn on High (exact; the
frame times of these runs moved by 50% between two runs of the same look, as
Blender was rendering alongside, so they are not given):

| place | old | new |
| --- | --- | --- |
| spawn, to the wood | 665 000 | 603 000 |
| in the wood | 575 000 | 536 000 |
| the hamlet | 403 000 | 343 000 |
| mist village | 439 000 | 373 000 |
| orc camp | 328 000 | 324 000 |

So the grass was already not the dear part: `lod_bias` 0.06 had most of its
triangles gone at any distance. The light clump takes 10–15% of what is drawn
off where there are meadows, and the forest floor costs about what the house
ground does. The frame is now mostly the sun's shadow (560 of 1 500 draw calls
at the spawn) and the wood.

## Tariel's new body, and capes of cloth

**Tariel** (`assets/tariel_rigged/tariel_rigged.glb`, built by
`vepxis-art/tools/t6_build.py` into `tariel.blend` as `tariel_v6` on
`tariel_rig`) is now box-built like the assassin and the mage: the edges
softly rounded, every piece rigid on one bone, flat materials (17, `t6_*`).
The knight in the panther's skin: a steel cuirass with a ridge and gold edges
over a crimson tunic, lames at the belly, a gorget, a tiger's head on the right
shoulder looking forward with its hide and paws down the arm, a sash of the
skin across the chest, three steel plates on the left shoulder, vambraces with
gold bands, fists round the sword's and the shield's grips, a belt with gold
studs, leather straps (the front ones on the thighs, so they walk), knee cops,
greaves and tall boots; a gold diadem with a ruby, black hair in a tail with a
gold band (on the `hair_` spring bones as before), a curled moustache and a
short beard. The trunk's pieces lean with his spine. The sword and both
shields are the old ones. Same 58 clips.

**Capes are cloth** (`ClothCape`, `scripts/cloth_cape.gd`): a sheet of points
hung from a bone that swings with the body, streams back on a run, is kicked by
the legs and ripples in a light wind. Verlet at a fixed 60 steps a second with
the sheet's lengths put back six times a step (along, across, the diagonals and
every other point down), capsules round the trunk and the legs pushing it out,
and each point drawn a little towards where it hangs at rest — strongly at the
top, not at all at the hem — so it keeps its drape and never flies apart. The
rest shape curves round the back (`wrap`), so from the side it is not a flat
board. Drawn as one double-sided sheet in world space, its colours from a
small texture (ground, hem, trim; a tiger's stripes or a row of runes).

Each rig names its capes in `_configure()` (`SkinnedRig.capes`, specs in the
Blender model's coordinates): Tariel his tiger's skin off the fur across his
shoulders, the mage his long wine cape with gold runes at the hem, the assassin
a short dark cape with a crimson hem and the two tails of his scarf. The rigid
capes are gone from the models (`CLOTH` in `r4_build.py`/`m5_build.py`), and
Tariel's cape spring bones are left alone when he has cloth. Purely for show:
every peer hangs its own. `heroes_test` checks each has his cloth, that it
hangs behind him standing and trails behind on a run.

## Avtandil's new body and bow

`assets/avtandil_rigged/avtandil_rigged.glb`, built by
`vepxis-art/tools/a7_build.py` into `avtandil.blend` as `avtandil_v7` on
`avtandil_rig`, in the manner of the others (22 flat materials, `a7_*`; the
old body and bow stay in the file, unexported). Still the hunter in green: a
hood up and open at the face with a point down the back, its cowl on the
shoulders cut into leaves, a laced leather jerkin over the tunic, the quiver's
strap across the chest and the quiver on his back with its arrows over the
right shoulder, a long guard on the bow arm and a glove on the drawing hand, a
hunting knife on the right hip and a horn and a pouch on the left, a split
skirt with a light hem, the calves wound in linen, soft boots with the tops
turned down. His head sits down on his shoulders as Tariel's now does.

His head, picked by the user from a set of trials (`HEADWEAR`, `FACE` and
`FACE_LOOKS` in the build script keep them all): the hood thrown back and
lying round his neck with its point down his back, brown hair out, swept to
one side; and the first Avtandil's plain face — two light eyes on a flat face
— with a little more to it: a hunter's squint with dark pupils and a lid
line, angled brows, a small nose and mouth, stubble along the jaw and a scar
on the right cheek.

The bow is a horn-and-wood recurve: a wrapped grip and a riser with gold at
its ends on `bow_l`, each limb tapered and bowed a little away from him, a
horn belly on the string side and a gold band, the ears turned forward at the
tips — all on the `bow_limb_` bones, so `BowModifier` bends them as before
(the `bow_tip_` bones are only where the string is tied). Same 77 clips.

## Skills, the skill bar, and the evade's key

**The bar.** Four squares at the bottom centre of the screen (`PlayerHud`,
`Player.SKILL_SLOTS`), keys **1, 2, 3, 4** (`skill_1`..`skill_4`): the skill's picture, its key in the
corner, a shade over it that drains down with the seconds left while it comes
back, a flash when it is ready again, and its name over the bar for a moment
when it is used. An empty slot is a dark square. Which skill sits in which slot
is the hero's profile (`CharacterProfile.skills`, ids from `Player.SKILLS`,
each with its name, stamina and cooldown). Skills are used from the ground,
never mid-swing; there is no mana yet, so they cost stamina.

**Rain of Arrows** (Avtandil, key 1; 25 stamina, 12 s): he shoots into the sky
(`AV_Sky_Shot`, built in Blender from Mixamo's Shooting Arrow: a hand to the
quiver, the arrow nocked, the body leaning back until the bow points some 60°
up, the string drawn and let go, upright again after; played at double speed,
the string goes 1.5 s in and he is held still until just after). The arrow
goes up, and 0.75 s later 36 arrows come down for 1.3 s (`ArrowRain`) on what he
has locked if it is within 18 m — following it while they fall — or 9 m ahead
of him. Nothing is drawn on the ground. They come slanted from his side, each
worth 35% of a full draw (crits as his shots do). They are ordinary `Arrow`s,
and only the host's copies count for damage — every peer builds the same rain
from the same seed (`net_arrow_rain`). A third of them come down on the bodies
standing where it falls, the locked one first; spread evenly, a volley over a
wolf would mostly miss it. `tests/skills_test.gd`.

**The evade's key** (`Controls`, applied by `Game` at start): **Command** on a
Mac, **Control** everywhere else; walking goes to Shift off a Mac (on a Mac it
stays on Control). The gamepad is untouched. Command-Q during play does not
quit (Q puts the weapons away, and is pressed while evading); any other way of
closing the window does.


## Arrows stay in what they hit; blood dries; the corner map

**Arrows** (`Arrow._stick_in`) go into the bone of the body's skeleton nearest
where they hit (a `BoneAttachment3D` per bone, shared by every arrow in it), so
they move with the leg or the head they are in and go down with the body; a
body with no skeleton (the wolves) takes them in the piece of it they hit.
After `linger` they fade out (`GeometryInstance3D.transparency`) rather than
sinking.

**Blood** (`Blood`) lies 30 to 40 s — the ground patches, the grass it darkened
(`GrassField.unstain`) and the props it wetted — and then fades over 4 s and is
freed, so a long fight does not leave a field of patches behind it.

**The corner map** is now in the top-right, round (a `Panel` with a rounded
style that clips the map drawn inside it, and a gilt rim), at 78% opacity.

## The mage's charge and throw

Holding the button, he swings the staff round — down, back behind him and up
(`MG_Charge_In`, cut from Mixamo's Two Hand Spell Casting, frames 1–43) — and
then holds it high for as long as the button is (`MG_Charge_Hold`, 43–67,
looped), the magic gathering at the crystal as before. Let go, he throws it
(`MG_Cast_Throw`, Standing 2H Magic Attack 01, 19–64): swung back behind him and
brought through, and the bolt leaves the crystal as it comes past his shoulder
(frame 19 of 46, measured on the crystal), with a burst of sparks there and the
stone flaring. Downloaded without anyone pressing Save: the page's own API
(export, monitor, the job's URL), and curl on the Mac.

## Hunter's Mark, the Piercing Arrow, the Fire Arrow, the Poisoned Blade

Four skills more on the bar, each with the creature's answer to it. What stays
on a creature (the mark, burning, poison) is an `Afflictions` node under it
(`scripts/afflictions.gd`): it keeps the timers, draws the look, and — on the
host only — ticks damage every 0.5 s through the creature's `take_dot` (which
ignores half the armour). `Afflictions.factor(creature)` is what a blow's
damage is multiplied by. Flashes, rings, sparks and flames are built by
`SkillFx` (`scripts/skill_fx.gd`). The effects were shown first as Blender
videos (vepxis-art `skills/videos/`) and then built here to match.

**Hunter's Mark** (Avtandil, key 2; 12 stamina, 14 s): he points at what he has
locked, or the best thing in front within 32 m (`AV_Point_Charge`, from
Mixamo, frames 36–132 at 1.4×). For 10 s it wears a red outline and a turning
sigil over its head, and every blow on it does more: 5% from a bow, 2% from
anyone else (see below). If there
is nothing to mark, the skill does not go and costs nothing.

**Piercing Arrow** (key 3; 30 stamina, 10 s): a full draw with wind and light
gathering at the arrowhead (`BowCharge`), then a shot that goes on through
everything on its line for 40 m (`PiercingShot`, a sweep through the
creatures' layer that leaves out what it already went through), hurting each
and throwing it back and down.

**Fire Arrow** (key 4; 25 stamina, 12 s): the head catches while he draws; the
arrow flies in an arc to where he aims (`FireShot`) and where it lands the
ground burns for 5 s (`FireZone`: flames, embers, smoke, a glow and a scorch
mark that stays a while). Whatever stands in it burns, and goes on burning
1.5 s after it steps out. The flames are alpha-blended, not added — added over
the bright meadow they washed out to cream.

**Poisoned Blade** (the Assassin, key 1; 15 stamina, 18 s): he takes a vial
out, pours it along the blade and tosses it away (`DG_Poison_Coat`, baked in
Blender with IK — Mixamo had nothing for it). For 10 s the blade is green and
drips (`VenomBlade`), and each cut adds a stack of poison, three at most, each
ticking on its own; the poisoned body's veins show green.

**What the creatures do** (`react(kind, from, push)`, called on the host and
replicated as an act): the orcs flinch and roar when marked (`RX_Flinch`,
`OR_Mutant_Roar`), fall and get up when the piercing arrow hits them
(`RX_Falling_Down`, `RX_Getting_Up` — open to blows while down), swat at the
fire (`RX_Swat_Bugs`, `RX_Agony_Head`) and stumble with poison
(`RX_Injured_Stumble`) — Mixamo clips retargeted onto both orc glbs. Imps and
the other fighters are knocked back, scratch at the flames and sway; wolves
reel and are shoved. `tests/new_skills_test.gd`.

## The mark only over the head; skill shots drawn like any shot, wind after

**The mark's numbers** (`Afflictions.factor(creature, from)`): a marked
creature takes `MARK_BOW` (×1.05) from anyone fighting with a bow — the
ordinary arrows, the skill shots, the fire they leave (`take_dot` carries who
lit it) — and `MARK_OTHER` (×1.02) from everyone else. `Afflictions.is_bow()`
reads the striker's `CharacterProfile.weapon`. Wolves, brutes (orcs, Arkdeva)
and fighters (imps and the rest) all pass `from` in.

**The mark's look**: the sigil over the head and nothing else — the red outline
round the body and the ring on the ground are gone, on every creature. It sits
over the creature's head bone (`Afflictions._over_head()`: the first bone
called `head`, else anything with "head" in it, else `bar_height`), so it rides
a stooping orc or a spider's rider.

**Piercing and Fire Arrow are drawn as an ordinary shot is.**
`SkinnedArcherRig.charged_shot(hold, pitch)` plays the ordinary draw
(`AV_Nock_Draw` over the profile's `draw_time`), brings the string back with
it, and holds at full (the draw's last frames slowed right down — the aim idle
drops the bow) until `loose_skill_shot()`, which is the ordinary release. The
shot leaves from `arrow_tip()`, the head of the drawn arrow. Nothing gathers on
the arrow while it is held (`BowCharge` is no longer used): what the skill is
shows once it has gone. From the press to the release he does not walk
(`Player._root_timer`; turning is unchanged).

**Where the wind's weight is** (a pass against the reference, side by side):
the reference puts the mass of the blast *at the archer* — a big, soft bell of
air bursting off the bow that fills half the frame and then thins — where ours
had been small, far off and drawn in thin wire-like lines. So: `WindBlast.cone`
at the release (an open bell of air, 9 m, opening to 2.6 m in a fifth of a
second, with two broad soft swirls round its mouth); every ribbon soft across
its width (`_soft_quad`: clear at both edges, brightest down the middle); a
field-of-view kick (`WindBlast.kick`, +7°) with the shake; the recoil 7 m/s;
the braced draw a quarter slower, the whirl at the head tightening and
quickening as the release comes and a glint on the head just before it; the
streak behind the arrow 4 m and faint.

**The Piercing Arrow is a great shot of wind** (key 4), after Ironeye's
Single Shot in Elden Ring Nightreign (`PiercingShot`, the pieces in
`WindBlast`): at the release white shards burst off the bow, he is shoved back
a step (`pierce_recoil`, 5 m/s) with dust off his feet and the camera jolts
(`WindBlast.shake`, `h_offset`/`v_offset` only); the arrow goes as a white
streak with speed lines racing beside it; bands of air (a ribbon partway round
the line, `WindBlast.band`) open round it now and then, inside a tornado laid
down stretch by stretch behind the arrow (`WindBlast.twister`: two ribbons
wound loosely round the line, in 3 m gusts with 1.2–3.4 m gaps between them, fading when
seen down the line (`WindBlast.end_on`) so from behind it is no target of rings, spinning, the funnel widening with distance), and a thin mist is left hanging along the first 30 m
(`WindBlast.mist`, alpha 0.03 — thicker reads as cotton wool). While it is
held he braces — hips down, knees bent, leaning on from the waist while the
chest keeps the aim (`BowModifier.crouch`, `charged_shot(..., brace)`) — and a
whirl of air turns at the arrowhead (`AirSwirl`: four white
bands round the head and a few motes drawn in, following `arrow_tip()`). Its wind is wide: anything within
`BLAST_RADIUS` (1.1 m) of the line is struck and thrown down, not only what
the arrow goes through (a capsule query per step on the creatures' layer).
Nothing is blue and nothing lights anything. The Fire Arrow is unchanged in
flight (`FireShot`).

!! `SkillFx.swell(grow)` puts the size peak at `grow` of the life: above 1 the
peak is past the end and the particles stay near nothing — that is why the
first mist could not be seen.

The Rain of Arrows is as it was (`AV_Sky_Shot`, `ArrowRain`) — a round that
changed it was undone at the user's word. Avtandil's bar: **1** the mark,
**2** the fire arrow, **3** the rain, **4** the piercing arrow; four slots. `new_skills_test` checks he stands
still through the draw and that the string is drawn with the arrow on it.

## Seven fixes after play: the head, fast arrows, planted skills, the lock, the evades

1. **Avtandil ran looking at the sky.** The sprint clip, straightened up 28° in
   Blender, left the head thrown back ~20° (measured: head −17° from upright
   running, +11° standing). `BowModifier.head_level` brings the head to
   `head_lean` (6°) forward of upright while he runs and is not aiming; the rig
   eases it on and off (`SkinnedArcherRig`). The skeleton's own forward is +Z —
   the first try measured against −Z and threw the head further back.
   (Modifier results only show in `Skeleton3D.skeleton_updated`; a probe that
   reads bone poses anywhere else sees the pose without them.)
2. **Arrows fly at 72 m/s** at full draw (46 off a snap), up from 34/21: at
   twenty metres the arrow is there in under a third of a second, so the evade
   has to go as the string does.
3. **The skills are taken standing.** `Player._root(seconds)` stops him dead
   (velocity zeroed, then no walking) for the mark's point, and for the fire and
   piercing draws — the mark no longer slides out of a run.
4. **The Fire Arrow is quick:** drawn at twice the pace (`FIRE_QUICK`) and held
   0.25 s (`FIRE_HOLD`).
5. **The Piercing Arrow follows what it was drawn at.** Through the draw
   `_track_pierce` turns him on the quarry (fast, not a snap), so the lock
   camera goes with it; the aim is settled at the release by the body's owner
   (`net_pierce_loose`, sent to every peer) — at the quarry wherever it has got
   to, even behind him.
6. **No blow lands through an evade**, even one cut short by running into a
   body or a wall: `_safe_until` covers the whole roll or dodge from its start.
7. **A perfect dodge with a shadow** (the assassin, Avtandil) covers him while
   the shadow is shed: `ShadowTrail.GUARD` (1.2 s). `tests/evade_guard_test.gd`
   checks both, for Tariel, Avtandil and the assassin.

**The mark on the run.** No lunge (`AV_Point_Charge` is no longer played) and
no stop: the legs go on with whatever they were doing and only the string arm
is flung out at the prey — `BowModifier.point`/`point_at` swing the upper arm
and forearm round to it (up 0.09 s, held 0.14, down 0.2); the glint goes as the
arm comes up. Not committed, not rooted; a draw under way is let down (that
hand is busy).

**Hit mid-skill, the skill stops.** A flinch, a knock-down or death
(`net_react`, every peer) calls `Player._interrupt_skill()`: `_skill_serial`
moves on, and every skill's steps (`net_arrow_rain`, `net_hunters_mark`,
`net_piercing`, `net_fire_arrow`) check it after each wait and stop — no
shot, no glint, no rain; the string and the brace let go
(`SkinnedArcherRig.cancel_skill_shot`), the whirl at the head goes.

**The hunter's evades.** Locked on and pushing left or right, the dodge key
gives the long dodge at once (`_sideways_on_lock`, then `_upgrade_to_dodge`);
any other way, or not locked, a roll. He has no double tap any more. The
others keep theirs.

**The mark's glint** is a comet now — a bright head, a 0.6 m tail, sparks
twinkling out behind — with no line left hanging from where he threw it
(thrown on the run, that line stretched back to where he had been).

**The user's own sounds, in.** Cut with ffmpeg (mono, a few ms of fade):
`unverified/sounds/bow/draw_2.wav` (the first second of `pulling-bow/pulling-bow-sound3.wav`)
and `release_2.wav` (`shot-arrow/shot-arrow-sound1.wav`) are the bow's draw and
release now; `arrow_hit_1..5` (from `damaged-arrow/`) play where an arrow goes
into a body (`Arrow.HITS`); `unverified/sounds/tariel/slash_1..4` (the four
swings in `sword-sound/last-sword-sound.wav`) are Tariel's swings. The
Piercing Arrow has the ones recorded for it in `sounds/bow/`: `ult_cast.wav`
(`bow-ult-cast.mp4`, which is a wav, trimmed) as the draw starts, `ult.wav` through the
hold, `ult-shoot-1.wav` at the release with `last-ult.wav` under it for the wind.
`full.wav` is not used.

**The mark's glint flies straight**, like a shot, at `mark_speed` (75 m/s),
no arc. **Footsteps** start louder: the ramp with speed goes from −3 dB, not
−9, so the first steps of a run are heard.

**The draw's creak stops with the draw.** `Sfx.play` returns the player it
made; the bow keeps the draw's (`Player._draw_sound`) and `Sfx.stop` fades it
out (60 ms) the frame the draw ends, however it ends — so a quick loose is the
release alone, not the release over the rest of the creak.

**A swing is heard with the cut.** The slashes are short, so `_whoosh` waits
for the clip's cut window (less 60 ms) rather than sounding at the start of
the wind-up, where one was over before the blade moved — and only if it is
still that swing. (`fighter_test` waits longer for an imp's two blows: the
sound's pitch draws on the global RNG, and so moved the dice the imp's choices
come from.)

**Three of the four slashes were silent.** The first cut put `-ss` after `-i`,
so the fade-out, timed from zero, landed before the clip's sound began; only
`slash_1` (cut from 0.04 s) had any. Re-cut with `-ss` before `-i` (the arrow
hits too); `heroes_test` now checks no swing, hit, draw or release clip is
silent. Levels brought down: the draw −12 dB, the release −8, the arrow going
in −14, Tariel's swing −18, the Piercing Arrow's cast and swell −11, its shot
−7 and wind −14.


## Blows that have to land

A creature's blow used to be a patch of ground: at one moment of the clip,
everyone within a reach of its middle and inside a cone in front of it was
hit — the orc's 4.6 m and ±72°, whether the axe got there or not, and anyone
within 0.8 m of him whatever way he faced; Arkdeva's scythes a four-metre ring
round where they were meant to come down; the wolf's claws 2.9 m. So a blow
that visibly missed still hurt.

**Now the weapon is followed** (`scripts/weapon_sweep.gd`, `WeaponSweep`).
While a blow is live, a few stretches of the weapon or limb — each a capsule,
end to end and so thick — are read off the pose every frame, and a player is
struck only if one of them passes through his body (an upright capsule, 0.3 m
round, 0.12–1.78 m up, plus 8 cm of graze) on the way from the last frame. The
step between two frames is cut small enough that a fast swing cannot skip over
him, and a stretch whose end moves slower than `min_speed` is only being carried
(an axe held up, a scythe settling) and hurts nobody. Each sweep meets a player
once; a parry or a knock that ends the act takes its sweeps with it.

* **The orc**: the haft and the bit of his axe (`Hit0..2` marks on the axe, on
  the great axe's bone), live from 0.16 s before to 0.12 s after each moment his
  hand moves fastest (the spin ±0.35, the overhead from 0.28 before); the kick is
  his shins and feet. His clips were made for a man's height, and twice that his
  flat swings sailed over a man's head — so he **stoops into them**
  (`stoop`, 17° at the waist, easing in and out round each blow). He opens from
  `reach` (4 m) but **steps in** (`close_speed`) until whoever he is after is
  `strike_reach` (2.9 m) off by the time the blow comes. The overhead's stones
  burst up only 0.9 m round where the axe hits; the spikes are still their own
  hit.
* **Arkdeva**: each scythe from its last joint round the blade's curve to its
  point (read off its mesh: `_find_blades`), the front legs knee to foot in the
  stamp, live only while they come down. Its body collider is 1.5 m round now
  (was 3.0; 1.5 now): a player can get in under the front of it, where the scythes land.
  It closes to 2.2 m before a scythe, 2.0 before the chop, 3.6 before a stamp, and opens from 4.4 m
  (`melee_range`, was 8.6).
* **The wolf**: forearms, paws and claws, and the jaws in a pounce; it steps into
  a swipe until the claws reach (`claw_reach`).
* **The imp and puglin**: forearms and fists out to the fingertips; they step in
  to `fist_reach`.

`WeaponSweep.show = true` draws every live stretch in red, for looking at blows
in the game. `tests/sweep_test.gd` throws each blow once with nobody near,
records where its weapon went and prints a map of where it can land; then a
player stood where it went is struck, and one just past its furthest reach is
not — even where the old reach-and-cone would have hit him.

## The wolf-man

`assets/wolf/wolf_beast.glb` replaces the old joint-by-joint wolf. Built in
Blender by script (vepxis-art `tools/wolf_build.py`): metaball blobs turned to
low-poly meshes — a barrel chest and a hump of shoulders over a lean waist, a
long muzzle, tall ears, amber eyes, big clawed hands, heavy thighs over raised
heels, a bushy tail — and locks of fur raked back along it, darker in the mane.
One mesh per bone, each **parented to its bone whole** (a `BoneAttachment3D` in
Godot), so a limb the blade takes is hidden and dropped as a piece of its own.

The skeleton is Tariel's naming plus a jaw and four tail bones, so Mixamo's
X Bot clips go on through `tools/retarget_mixamo.py` (vepxis-art
`tools/wolf_export.py` does model, clips and export in one go). The clips
(`mixamo_wolf/`): **Running Crawl** (running on all fours — its chase), Mutant
Walking (prowl and fighting steps), Mutant Breathing Idle, **Mutant Swiping**
(and mirrored, for the other paw), Mutant Jump Attack (the pounce), Zombie
Reaction Hit Stumble Back (a swipe thrown back), Zombie Crawl (dragging itself
on its belly once both legs are gone), Mutant Dying; Roar, Hit, Punch, Crawl
Walk and the upright Mutant Run are in the file unused.

`WolfRig` keeps the old API for `Wolf`: `animate()` picks the clip from speed
and stance and paces it to the ground; `swipe()`/`lunge()` play the attack so
its fastest moment arrives when the old timings said the claws land; `reel()`,
`fall()`. Over the clips: the jaws open as it strikes, the tail swings, and the
red glint gathers on the claws about to come through.

### How the wolf fights: intellect

`scripts/wolf_mind.gd` (`WolfMind`) is its fighting mind; `Wolf` carries out
what it decides. Once it is within 4.5 m it is always doing one of five things:
**close** (in to its claws' reach), **strike** (a combo, one move after the
other), **circle** (side-stepping round him face on, drifting towards his back),
**retreat** (backing off, often with a hop back first) and **wait** (holding out
of reach a moment). From the circle or the wait it comes again — straight in, or
from out of reach in a sudden **pounce**. It never runs away for good.

Whatever it is doing it **watches his blade**: when a swing starts within reach
it may throw itself aside (Dodging Right, and mirrored) or hop back (Jumping
Backwards Dodge); for the moment it is getting away the blade goes through air
(`_evading`). A cunning one breaks off its own windup to do it, and goes in
while he is still coming out of a swing that found nothing.

**Intellect** is 0 to 1, each wolf its own (drawn between `wit_range` unless set):

| | dull (0.2) | middling (0.5) | cunning (0.9) |
|---|---|---|---|
| sees a swing coming | 0.38 s | 0.26 s | 0.14 s |
| gets out of one | 1 in 4 | 1 in 2 | 3 in 4 |
| longest combo | 1 | 2 | 3 |
| circles, feints, flanks | no | some | often |
| backs off after a combo | 1 in 3 | 1 in 2 | 3 in 4 |
| punishes a miss | no | yes | yes, at once |
| waits its turn in a pack | no | yes | yes |

Hurt, it grows careful: it backs off and dodges more — and comes back. A pack
takes turns: no more than two wolves with the wit to wait go in at one player at
once (`PACK_ATTACKERS`); the rest circle.

**Combos**, from what it has left: *rake* (a swipe), *double rake* (left,
right), *rake and leap* (left, right, pounce), *feint* (a hop back and the pounce
straight after); with one arm a swipe or a swipe and a bite; with none the
*bite* (Vampiric Bite: a lunge with its jaws). **A leg cut off puts it down**:
it drags itself on its belly at him (Zombie Crawl) and its attack is the
*ground lunge* — thrown forward, claws and jaws. It cannot dodge any more.

New clips (mixamo_wolf/): Dodging Right (+ mirrored), Jumping Backwards Dodge,
Walking Backwards, Strafe Walking left and right, Vampiric Bite.

**Cut limbs land on the ground.** A severed piece used to stop at a height of
zero: under the rolling land it sank out of sight, over the bay it hung in the
air. It now finds the ground by a ray straight down and stops when its lowest
mesh, not its joint, reaches it.

`tests/wolf_mind_test.gd`: the table; a cunning wolf getting out of most of a
dozen swings and a dull one out of fewer; blows landing; backing off and coming
again; a clever pack never more than two in at once; a wolf with a leg off
crawling in, lunging and getting him, the leg lying on the ground; one with no
arms biting.

### Wolves as they go about: coats, gaits, a tell, missiles

**Coats.** Each wolf is born with one (`WolfRig.COATS`, from its name so every
peer agrees): black, dark grey, grey-brown, pale grey, russet — the fur
materials swapped for the coat's colours, one set of copies per coat.

**Four legs or two.** Also from its name: half go about on all fours (a slow
crawl on their beat, Running Crawl after you, and standing they hold the crawl's
pose low on four feet), half upright (the brutal walk, the upright Mutant Run).
Everyone rises to fight. Its beat is walked slower (`prowl_speed` 1.1, three
quarters of that on all fours), and where it gets to — and now and then on the
way — it stops a while (`linger`, 3–8 s) and **looks about**: the head turned
slowly one way and the other, now and then down to the ground at a scent.

**The tell before a pounce** is longer (`lunge_duration` 1.35, gathering for
0.8 s): down low on its haunches (`crouch`), trembling, its eyes flaring, the
claws glinting red, and a growl.

**Missiles.** Arrows, the mage's bolts, fire and the piercing shot are in the
group `missile` and say where they are going (`flight()`). A wolf that is after
somebody judges each one once, when it is seen on a line through it: loosed
from out of reach (10 m and more) it gets out of the way of most — about
seven in eight (`missile_dodge_far`) — and close in of about one in two
(`missile_dodge_near`), a little more or less by its wit; one dodge no sooner
over than it may throw itself out of the way of the next; on its beat, unaware,
of none. The same for the mage's bolts (a `SpellBolt` is an `Arrow`): and a
bolt hunting a wolf that gets out of its way is shaken off (`Wolf.is_evading()`)
and flies on straight. Out of the line, for a moment its body is not there to be struck.

**Down on its belly it lies still.** The crawl let the body down by measuring
the parts hanging off the bones, which follow a frame late — and the body bobbed
up and down against its own measure. Now it is measured from the bones as posed,
and eased. **Cut pieces** stop on the ground by their true lowest point (points
on their surface, not the box round them, which reached lower when turned and
left them a hand over the ground).


### The claw wave

Now and then — not always — a wolf **cuts the air with its claws and throws the
cut at you**: three sickle blades of torn air side by side, the marks of three
claws, flying at 15 m/s for 17 m, leaving the air they tore hanging behind them
in fraying slashes (`scripts/claw_wave.gd`, `ClawWave`). The swing itself is
`scripts/wolf_claw.gd` (`WolfClaw`), hung on the rig as `WolfRig.claw`.

**The tell comes first, and it is long.** It rears up, a paw raised over its
head and held there, trembling, while its claws gather a red glow and embers
are drawn in to them, its eyes flare, its jaws open and it growls — 0.55 to
0.85 s of it (shorter for a clever one), over a second from the start to the
first wave. Then the paw comes down and the wave leaves it.

A clever wolf follows on (its combo length is `WolfMind.combo_max()`):

| blow | the swing (Mixamo) | the wave | get out of it by |
|---|---|---|---|
| **rake** (always first) | Standing Melee Combo Attack Ver. 2, the raised paw brought down | slanting | a step aside or a roll |
| **sweep** | Standing Melee Attack Horizontal: arms wide, raked across | flat, the blades one over another from knee to head | a roll through it |
| **slam** | Zombie Attack: both paws overhead, held, brought down to the ground | on end, bigger, three furrows torn in the ground, the camera jolted | a step aside |

A rake or sweep that lands staggers (a blow of two: a round shield met with it
at the last moment turns it and shatters it); the slam's knocks you down. A
shield held towards it catches it; a roll or a dodge goes through it; a wall
breaks it. It strikes by where its blades go (`WeaponSweep`), each player once.

**When.** Only with both arms and both legs, from 3.2 to 11 m, and then
`claw_cooldown` (9–15 s, less for a clever wolf) before the next; the first no
sooner than 2.5–5 s after it is born. Chasing somebody who keeps out of reach
(an archer) it stops and throws it; in a fight it comes out of the circle or
the wait now and then as the claw wave instead of coming in.

**How the swing is played.** Each blow is four beats of its clip — rise, hold
(the tell), strike, recovery — each over a time of its own
(`WolfClaw.BLOWS`), so the hold can be stretched without the swing going slack.
The clip is driven to where it should be each frame by its speed, so the
crossfades between blows still blend. The paw raised in each blow is found from
the clip itself.

**Blender.** A file of its own, `vepxis-art/wolf/wolf_claw.blend` (wolf.blend is
left alone), built and exported by `tools/wolf_claw.py` in a background Blender:
`build` (the rig appended from wolf.blend, `mixamo_wolf_claw/*.fbx` laid on it),
`cut` (WFC_Rake, WFC_Sweep, WFC_Slam cut from the takes), `wave` (the blades:
three sickles side by side, the tips swept back, UV along and across →
`assets/fx/claw_wave.glb`), `export` (the rig with only the WFC_ clips →
`assets/wolf/wolf_claw_anims.glb`, taken into the wolf's AnimationPlayer as the
library `claw`), `shots` (contact sheets of clips).

Multiplayer: the host decides and throws the wave that hurts; `net_claw` has
every other peer play the same swing, and their waves are its likeness.

`tests/claw_wave_test.gd`: the clips are there; the tell is over 0.9 s, with the
paw over its head, the claws burning and the eyes flaring; a cunning wolf
throws three waves and they land on a knight standing there; rolled through as
each comes, none lands; a step aside gets out of the rake and the slam; a
shield catches it; a wall breaks it; kept at a distance for 30 s it throws it
one to three times; with an arm gone, never. `tests/claw_wave_shots.gd` takes
pictures of it.

### Running you down, and the leap at the end of it

On all fours after somebody a wolf runs fast — `charge_speed_on_fours` 8.5 m/s
(upright 6.4), the Running Crawl sped up to match — and a run that brings it to
within 3–6.5 m of him (`run_leap_range`) ends in **a leap**: a snarl and a flash
of its claws as it gathers for a fifth of a second, then straight on at him
through the air, half a metre up, for 0.65 s, thrown far enough to land on him,
claws raking as it lands (Mutant Jump Attack); then it fights. Once in 4 s at
most (`run_leap_cooldown`). A roll or a step aside as it leaves the ground gets
out of it; a shield takes it.

**The leap is the wolf's, not its hips'.** `WF_Pounce` (the Mutant Jump
Attack) carries its own throw: the root a metre and eight on, the hips a
metre and three quarters up. The rig pins the root, so the clip stood still,
and the hips flew while the body stayed on the ground — and the pounce then
shoved the body on at 9 m/s along the ground under them: a wolf that slid at
you with its hips in the air. Now `WolfRig._carry_out` takes the throw out of
the clip once, at load (the rise above standing out of the hips' track; the
root's travel kept as the curve), and `Wolf._fly` carries the body along that
curve while the clip is off the ground: the curve's distance stretched to
land `LAND_SHORT` (0.9 m) short of whoever it leaps at, its height cut to
`LEAP_HEIGHT` (45%: a wolf leaps low and long, a mutant high), the ground's
rise or fall eased in by the landing — motion warping, the way a souls-like
lands a lunge on you. The clip is played from its own start
(`_strike(..., whole)`), sped up to arrive on time, so the crouch before it
leaves the ground is seen: the pounce's tell is that crouch, a quarter of a
second, then 0.45 s in the air. Both the pounce and the run's leap go this
way; the old shove and `_leap_off` are gone.

### Hand to hand, souls-like

The wolf used to spend a fight mostly off the ground — hopping back, dodging,
pouncing, leaping in again after every third cut. It fights hand to hand now:

* **Bigger** — the rig at 1.65 (was 1.1; 1.4 first, then bigger still at the
  user's word, so its moves read), the capsule 0.62 × 2.35, the claws'
  reach and its fighting distances, the bar and the clips' paces
  (`WolfRig.*_pace`) all scaled with it, so its moves read from the
  camera.
* **Its moves** (`Wolf.MELEE`, clips from Mixamo laid on in
  `vepxis-art/tools/_wolf_add_clips.py`): `punch` a quick jab, `rake` a
  zombie's raking swipe, `combo2` and `combo3` a two- and a three-blow
  combo, `slam` an overhead two-handed smash — with the swipes,
  the bite and the pounce. Each is a clip, the clip times its blows land
  (`hits`, measured as the hands' fastest moments), what strikes (claws or
  jaws), how hard (of `swipe_damage`), how fast and which stretch of the
  clip. Every blow is its own `WeaponSweep`, live ±`HIT_HALF` round its moment.
* **Chains** (`WolfMind._choose_combo`): every wolf throws two to four
  blows at a time — swipe-swipe, jab-swipe, rake-grab, the three-blow
  combo, the smash, swipe-bite; a cunning one also swipe-swipe-smash,
  jab-combo, combo-smash, rake-swipe-swipe and the old rake-and-leap. The
  blows of a chain share one combo on the hero (`begin_chain`): caught by all
  of them he goes down, and a round shield can still throw the first aside.
  The smash is one heavy blow: never parried, and down he goes if it lands.
  In a chain a swipe is 0.72 of a lone one.
* **Commit** — it turns after him through a windup and stops `COMMIT`
  (0.24 s) before the blow: from there it goes where it was aimed, and a step
  aside gets out of it (`Wolf.tracking`).
* **The delayed blow** — now and then (more often the cleverer it is, and
  the smash most of all) it holds the top of its windup still for 0.25–0.6 s
  before the blow comes (`WolfRig.melee`'s hold), so rolling on reflex is
  punished.
* **Every blow is seen coming** — through the last half second before any
  hand-to-hand blow lands the claws flare and the jaws open (held, they stay
  lit); the jab is played slower so it has a windup at all. The grab and
  headbutt was taken out: it did not read as a blow.
* **The bite** reaches down: at its size the jaws passed over a man's
  shoulders, so a bite's reach runs from the jaws down towards his chest.
* **A leap is committed**: it is aimed as it leaves the ground and not turned
  in the air, nor while it gathers itself after landing — stepped out of, it
  comes down where it was going, stops dead (no sliding on) and only turns
  once it is up again (`Wolf.tracking`, `Wolf._land`).
* **Hit-stop** — a blow landing, its on him or his on it, all but stops its
  clip for a few hundredths of a second.
* **Poise** — `max_poise` 150, taken off by every blow's damage (less through
  a heavy move's windup: `armour`), back at 45 a second once it is let
  alone; at nothing it staggers for 1.15 s, open, and cuts into it bite deeper
  (`Recoil.RIPOSTE`).
* **Less leaping** — dodges `0.06 + 0.42 × intellect` (was 0.12 + 0.68), a
  hop in one dodge of five, retreats and hops after combos far rarer, the
  pounce and the claw wave from range less often, circling shorter. Cut three
  times running, two times in three it trades — straight back at him with a
  jab and a rake, armoured — instead of hopping out.

`_shots_tmp/fight_film2.gd` (a throwaway) films a wolf against a hero who
stands and takes it. `wolf_mind_test`'s dodge thresholds and `archer_test`'s
mark height follow the brawler and the bigger body.

`tests/wolf_run_test.gd`: arrows and the mage's bolts, from 12 m and from 3.5 m,
most got out of from far and many close in; a bolt it gets out of misses; on
all fours faster than 7.5 m/s, the run ending in a leap from over 2.5 m off,
off the ground, its claws landing.

## Balance: p.atk, m.atk, p.def, m.def, crit

Two kinds of attack and two of defence, for heroes and creatures alike
(`scripts/defence.gd`): a blow is taken as `damage × 100 / (100 + def)` — 25
takes 80 % of it, 100 half.

* **p.atk / p.def** — blades, claws, fists, arrows. A hero's p.atk is his
  profile's `damage`, and it is what his cut is worth on *every* creature (an
  imp, a puglin, an orc and Arkdeva used to take a flat 25 from any blade, so
  the knife did as much as the sword there).
* **m.atk / m.def** — the mage's bolt (`CharacterProfile.m_atk`,
  `shot_power()`), fire, poison, the wolf's claw wave (torn air) and Arkdeva's
  venom and its pools. `take_hit(..., magic)` and `receive_blow(..., magic)`
  carry which it is.
* **Crit** — now on the blade too (`Player.cut_worth()`, `CharacterProfile.cut()`);
  it used to be only on shots. A critical is counted once: the shooter makes the
  damage a critical one, and the imp and the orc no longer multiply it by 1.5
  again. The orc's and Arkdeva's `armour` (0.75 off everything) is gone for
  p.def and m.def.

**The heroes.** Tariel is the slowest to kill and the slowest to die; the
mage's bolt is the heaviest single hit, then the hunter's arrow and the
assassin's knife.

| | HP | p.atk | m.atk | p.def | m.def | crit | ×crit | stamina / a strike |
|---|---|---|---|---|---|---|---|---|
| Tariel | 180 | 16 | – | 40 | 20 | 5 % | 1.5 | 100 / 18 |
| Avtandil | 120 | 30 | – | 15 | 15 | 15 % | 1.8 | 100 / 12 |
| the Assassin | 110 | 18 | – | 20 | 15 | 25 % | 1.8 | 110 / 9 |
| the Mage | 105 | – | 44 (×1.8 full charge) | 12 | 40 | 12 % | 1.6 | 110 / 15 |

Fire (14 a second) and poison (2.5 a stack) are magic and go through m.def.

**The creatures.**

| | HP | p.def | m.def | its blows |
|---|---|---|---|---|
| imp | 90 | 20 | 10 | 40 |
| puglin | 150 | 25 | 10 | 48 |
| wolf | 160 | 40 | 10 | 110; claw waves 70 / 70 / 90 (magic) |
| orc | 320 | 120 | 40 | swing, combo, kick 115; heavy, slam, spin 170; leap, wave 190 |
| Arkdeva | 420 | 150 | 60 | strike 130; both, stamp, chop 180; thorns 150; venom 90 and pools 30 (magic) |

**What that makes of a fight** (measured with a probe holding attack for 20 s:
Tariel 1.05 swings a second, the Assassin 1.4, Avtandil about 0.57 full draws,
the mage about 0.24 full charges — everyone's stamina runs dry):

| on a wolf, every blow landing | one hit | a wolf dead in | wolf blows to fall |
|---|---|---|---|
| Tariel | 11.4 | ~13 s | 3 |
| Avtandil | 21.4 | ~12 s (from far off it dodges 65 %) | 2 |
| the Assassin | 12.9 | ~7.5 s + poison | 2 |
| the Mage | 72 (full bolt) | ~9 s (it dodges bolts too) | 2 |

An orc takes 22–25 s from the Assassin and the mage, ~37 s from Avtandil (his
arm up against arrows) and ~40 s from Tariel; its ordinary blows leave every
hero standing, its heavy ones are the end of anyone but Tariel.

**A wolf is whole until it is down to half its health** (`sever_below`): till
then the blade wounds it — blood, the damage through its p.def, a shove — and
only after that do limbs come off.

`tests/balance_test.gd`.


## The village grown, and the wolves' hill behind it

**The village** (`World._dress_village`) is spread over a bigger lot — out from
the gate towers to the east (`SPREAD` 1.12) and away from the street north and
south (1.4) — and everything in it grows with it, taller than it is wider
(`GROWTH`): the huts 1.5 across and 1.9 up (two storeys against a man), the
barracks, the town centre, the windmill, the towers and the walls. Only the
model inside a building is scaled; its hulls are scaled point by point to match
(`_grow_building`), so no body is ever scaled unevenly. The fence runs round the
bigger lot (`VILLAGE`, 96 × 72 m) and the ground is kept level over all of it.
The puglins that farmed the north moved out onto the east fields (82, −14), the
wolves' old ground.

**Behind it, to the north, the wolves' hill**: a broad rise from the village's
north fence to the north wall, highest to the north-east (about 12 m), gentle
enough to climb all the way (`Terrain.features`). **A wood grows up it**
(`Forest.GROVE`), pines and oaks from a ragged foot a little past the fence to
the wall — planted after the rest of the map's wood so that comes out of its
seed exactly as it did — with two glades in it (`GROVE_GLADES`), **the wolves'
dens**, four wolves in each. A hedgerow runs along the foot of it. Wolves are
not flattened into the ground any more: each is stood on its hill where it was
put.

**The mountains** north and east used to stand with their feet in the land
(one on the village's east side, two over where the hill is); those are pushed
back out along their line (`Horizon._clear_of_the_land`) until they clear it,
so the hill and its wood stand in front of the range.

`tests/village_shots.gd -- <dir> <tag>` takes pictures of it.

**The wood on the hill, thinned out** (`Forest.HILL_FIRS`): firs only (two
pines and a cedar), nothing under them — no bushes, no litter — and no hedgerow
at its foot. Each is stretched up by 1.45–1.85 on its height alone, so the
trunks stand bare well over a man's head, and they grow on a 6.8 m lattice with
no glades cut from it: some forty of them, a wood you can see through and fight
in between the stems. **Twelve wolves** now, spread over the whole hill — no
two nearer than about thirteen metres — with a little room kept round each
(`GROVE_GLADES`), so a pack is met a wolf or two at a time.


## Harder wolves, a gentler poison, over the fence, a bigger fir wood

**A wolf is harder to kill** — above all for the Assassin, whose quick cuts
used to take it apart:

* **Each hero's cut is his own**: a blade takes off the hero's own `damage`
  (Tariel 26, the Assassin 17), through the wolf's p.def — no longer a flat 26
  from anyone.
* **More of it**: 160 health (was 100).
* **Limbs are not a way to finish it**: below half its health a cut takes a
  limb only one time in three (`sever_chance`); the rest wound it.
* **It breaks out of a combo**: cut three times inside two seconds while it is
  fighting (`combo_break_cuts`, `combo_window`), it hops back out of it and
  comes straight back in with a leap (`WolfMind.come_back_leaping`). A string
  of quick cuts is answered, not just taken.

| to kill a wolf (cuts, no crits) | before | now |
|---|---|---|
| Tariel | about 5–6 | about 9 |
| the Assassin | about 5–6 | about 13, broken out of every third |

**The Poisoned Blade** (`venom_dps` 7 → 2.5): three stacks are 7.5 a second —
a help to the blade, not the whole of the kill.

**Over the fence.** A hero who ran at the village fence and jumped was pulled up
onto its rail — a 25 cm top with nothing to stand on beyond it — and stood on it
or dropped off it. The ledge is now felt for at the face and further in (the
top of something thin is found, not only the ground past it), and a top with
nothing under the landing is **vaulted**: over in an arc clear of the rail, down
onto the ground on the far side (`_vault_peak`). `tests/fence_vault_test.gd`:
every hero, both ways, lands on his feet on the far side (on the old code three
of the four stood on the rail).

**The fir wood, bigger and older**: it runs on west past the village down to
the great wood (`Forest.GROVE_WEST`, the hill's shoulder with it), and has an
age to it — tall old firs (the three biggest pines of the kit, trunks bare over
a man's head) about seven metres apart, young firs of every height among them
(`HILL_YOUNG`), a few open places for the light to come down into, nothing under
them. Sixteen wolves on it, spread out, four of them in the west part. The oak
line west of the village is gone (it is inside the wood now).

## The land north of the village longer, giant firs, the mountains further off

**The world is 60 m longer to the north** (`Terrain.north_extra`; the ground,
its collider, the walls, the meadows and the map all follow — `Terrain.contains`
and `north_edge` say where it ends). The mountains on the horizon are pushed
back to clear the whole of it with a margin (`Horizon._clear_of_the_land`, now
on every side).

**The wood starts away from the village and comes on gradually.** Past the north
fence there is open meadow first (nothing planted within 12 m of the village);
then young firs, few at first and more further in (`GROVE_RAMP`, 26 m), then the
old wood. The hill is lower and wider and further back (its top at about
z 160), so the wood climbs slowly.

**Giant firs** (`HILL_GIANTS`, `assets/forest/GiantFir_{A,B,C}.obj`, built by
`vepxis-art/tools/giant_fir.py`): bare trunks with a root flare, crowns from
about 12 m up to 35 m, 9–10 m apart. Walking in is walking among columns. Each
is about 300 triangles. The main wood's canopy, undergrowth and litter carry on
over the new strip outside the wolves' wood.

**The stutter in the wood was the wolves, not the trees.** Measured standing in
the wood: the trees cost little (68–330 triangles each), but sixteen wolves each
posing a full rig every frame gave the spikes. A wolf prowling with no one near
(`pose_far`, 30 m) now poses every third frame on the gathered time. Frame times
there: p99 30.8 → 27.0 ms, worst 37 → 27.

Sixteen wolves, moved to the new wood.


## Levels

Every hero starts at **level 1**. What he kills is experience; enough of it is
a level (`scripts/leveling.gd`, class `Leveling`, hung under each player by
`World._build_player` as `Leveling`, on every peer).

**Experience is a share of the level, 0 to 100 %.** A wolf is worth a whole
level shared among `level + 2` of them, so each level asks one wolf more than
the last and a wolf is worth less and less:

| level | wolves to the next | a wolf gives |
|---|---|---|
| 1 | 3 | 33.33 % |
| 2 | 4 | 25 % |
| 3 | 5 | 20 % |
| 4 | 6 | 16.67 % |
| … 9 | 11 | 9.09 % |

Other creatures are worth so many wolves (`Leveling.WEIGHT`): an imp 0.6, a
puglin 0.8, an orc 3, Arkdeva 12, anything else 0.5. What is left over from a
level carries into the next, counted in wolves. Every hero within 35 m of a
creature when it dies gets it whole — alone, that is simply the one who killed
it. The host hands it out (`World._on_creature_died` → `Leveling.share`) and
tells every peer the new level and experience (`net_progress`).

Level 10 is the top for now.

**What a level gives**, each hero along his own line — about 8 % of where he
starts, Tariel's in health and armour and least in his blade, the Mage's in his
spells and m.def, Avtandil's in his arrows, the Assassin's in critical hits
(no crit chance grows past 40 %). A level also makes him whole again: health
and stamina full.

| each level | HP | p.atk | m.atk | p.def | m.def | crit | stamina |
|---|---|---|---|---|---|---|---|
| Tariel | +15 | +1 | – | +3 | +2 | – | +3 |
| Avtandil | +9 | +2.4 | – | +1.2 | +1.2 | +1 % | +2 |
| Assassin | +8 | +1.5 | – | +1.5 | +1.2 | +1.5 % | +3 |
| Mage | +7 | – | +3.5 | +0.8 | +3 | +0.5 % | +3 |

So at level 4 Tariel has 225 health, p.def 49, p.atk 19; the Mage m.atk 54.5
and m.def 49. The growth goes onto the hero's own copy of his profile (the
`.tres` every body of that hero shares is never touched) and onto the
controller's `max_health`, `p_def`, `m_def`, `max_stamina`, which a respawn
keeps.

**Where it shows.** A gilt shield at the head of the health and stamina bars
with the level in it, the hero's name over the bars; the experience a gold
line along the whole bottom edge of the screen, cut in tenths, with "EXP
33.33%" over its left end and what a kill brought rising off it ("+33.33%"); a new level is "LEVEL UP" at the top of the screen, and the
shield throws out light. The bars stop growing at 480 px, however high the
level.

**Taken up into the light** (`scripts/level_beam.gd`, `LevelBeam.on(hero)`),
3.7 seconds, the way a ship's beam lifts someone off the ground: high overhead
a light opens and a cone of pale light spreads down from it round him, wide at
the foot, a haze through it brighter at its edges, rings running up it
(0–0.8 s); his body is lifted off the ground most of a metre, turning a
little, and hangs there while motes are drawn up round him into the beam and
a deep chord swells under a rising rush of air (to 2.6 s); then he is set
back on his feet with a deep, soft boom rolling away, the glow round him goes
out, and the HUD's "LEVEL UP" comes up (at 2.95 s); the cone narrows and
closes into the sky. The sound is grave, not bright: open fifths on D from a
soft dark wavetable, two voices a hair apart on each note, the air, the boom
falling in pitch into a dark tail of noise — made in code on a worker thread
when a hero is spawned (`LevelBeam.warm`), ready long before the first level. Only his body (`Visuals`) is lifted, never
his collider. Nothing is drawn on the ground (a circle with a star in it, a
pool of light, a column from the sky with ribbons round him, a golden burst
out of him on landing and bells were tried before and taken out). All made in code; every
peer makes its own from `Leveling.net_progress`, nothing replicated.

`tests/leveling_test.gd`: level 1 to start; a wolf far off is nothing; a wolf
a third at level 1 and a quarter at 2; 3, 4 and 5 wolves are levels 2, 3 and
4, each healing and each with its light; an orc at level 4 half a level; Tariel grown by his line;
the shared profile untouched; what an imp and an orc are worth in wolves.

## Over the creatures: level and damage

`scripts/combat_text.gd` (class `CombatText`, under the World as
`CombatText`):

* **Their level**, "Lv 3  Wolf", over the health bar of every creature within
  24 m, coloured against the hero's own level: grey 3 or more below, green
  below, white the same, yellow 1–2 above, red 3 or more above. Levels are
  `Leveling.LEVEL_OF`: imp 1, puglin 2, wolf 3, orc 6, Arkdeva 10.
* **What each blow took**, a number that jumps up off the creature, pops,
  slows and fades in a second: white, or for a critical larger, gold and with a
  "!". It is read, not told: every frame each creature's `health` is compared
  with last frame's, so every weapon, spell, fire and poison shows without any
  of them knowing, and on a client too (where `health` arrives replicated). A
  critical is noted by the creature as it takes the blow
  (`CombatText.mark_critical`, in `take_hit` and the blade's cut in
  `Wolf`, `Fighter`, `Brute`) — on the host; a client shows its numbers plain.
* The words are on their own render layer (`CombatText.LAYER`), which the map's
  photograph from above leaves out.

`tests/combat_text_test.gd`: a wolf near shows "Lv 3  Wolf" in yellow, one far
off nothing, an imp "Lv 1  Imp" in white; a blow puts up what it took, a
critical with a "!", gone after a second; and a new level lifts the hero up in
the light and sets him down where he was.


## The wolf that no longer skates, and runs you down

Four fixes after play, and the wolf's run made a thing to fear.

**The Hunter's Mark is only laid on.** It used to stagger what it marked — a
wolf at a run then stumbled on in the stagger clip at running speed, skating
across the grass. Now `react(&"mark")` only provokes: on the wolf, the fighter
and the orc it does nothing else. The sigil over the head is smaller again
(`Afflictions.SIGIL_SCALE` 0.7), and so is the lock's dot (`TargetMarker.size`
0.021, `grow_with_range` 0.0016).

**The lock goes on after a kill** (see *Target lock*): to the enemy that stood
nearest the dead one.

**Nothing a wolf does skates.** A probe (`_shots_tmp/skate_probe2.gd`, thrown
away after) ran both kinds of wolf, at each wit, through standing, being swung
at, being circled, being backed away from, knocks, parries and marks, and a
prowl, and measured every frame how far the body went against how far the
clip's feet say it should. What skated, and what it does now:

- *A stagger at a run* (4.8 m/s of skating, the worst): the chase kept driving
  it on through the reel. And *a claw wave thrown in the chase* went on at
  6.4 m/s. Both are the one rule below now.
- *Every move* — a swipe, a combo, the smash, a bite, a dodge, a hop, a stagger —
  now carries the body exactly as far as the clip's own root goes
  (`WolfRig.ride()`, from `_travels`: each clip's root path worked out once, in
  the body's own frame, while the root itself stays pinned). A move that stays
  put stays put; a stagger stumbles back; a combo steps in. The old step-in
  under a blow, which dragged the body at up to the charge speed while the clip
  stood still, is gone. A move's steps towards him are cut short so it stops
  chest to chest (`Wolf.CONTACT`) rather than treading on the spot against him.
- *The run and the walks* were clamped to paces their feet could not keep
  (a run clip played at 0.7 while slowing to a fight, a crawl-walk held at 1.6
  while going faster). The clamps are wide now, and a wolf running inside a
  fight runs rather than playing its walk at double speed.

After: every clip's mean error under 0.4 m/s, the loops and the stagger under
0.1 (the rest is the first frames of a blend and contact with him).

**The run builds, and ends in a blow.** Off the mark at `run_start_speed` (4.8),
flat out after `run_build` (2.2 s) at `sprint_speed` 10 (on all fours 12.5),
the clips' paces following. Fast enough (`run_strike_speed` 5) and at the
right distance, it strikes out of the run — whichever fits the gap:

- **the spinning rake** (`WF_RunSpin`, Mixamo *Great Sword High Spin Attack From
  Run*): both claws round in two blows, the path stretched (0.6–1.6×) to bring
  the first onto him; two rakes do not put him down;
- **the leaping smash** (`WF_RunAxe`, *Running Jump With Attack With Axe*): off
  the run into the air, carried along the clip's throw like the pounce and
  warped to come down on him, two-handed; it puts him down;
- **the pounce**, as before.

Its fight has a new tactic, **RUN_UP**: now and then it turns its back and walks
off to 8 m, then turns and comes at a run. And closing from more than a couple
of steps it runs, building, instead of walking.

## Blows that are felt

What says a cut went *in*, the way it does in a souls-like:

* **It goes the way the blade was going.** Every blow used to be thrown along
  the blade itself, hilt to point, whichever way the swing went.
  `CharacterRig.swing_direction()` reads where a point two thirds up the blade
  is against where it was two or three ticks ago (seen whenever a creature asks
  for the cutting edge, which every one in reach does every tick of a swing),
  and that is the blow now: cut from its right, a creature is shoved, bent and
  bled to its left.
* **The body is thrown over.** `scripts/hit_react.gd` (`HitReact`): a spring
  laid over whatever the clips are playing. On a skeleton the spine is bent a
  share at each joint from the hips up (the wolf: pelvis to head,
  `WolfRig.BENDS`); a body with no bones of its own is tipped over its feet
  (the fighters and orcs, their `Visuals`). A little under-damped, so it goes
  over, a touch past upright on the way back, and still; blows on a body still
  thrown over add to it, so a flurry rocks it. It runs on the real clock, so the
  jolt goes through even while the hitstop holds the clip.
* **Its move is broken off — unless it has armour.** `Wolf._flinch`: a blow
  landing while the wolf is in an ordinary move (the punch, the rake, the
  swipes) breaks it off — the claws never land, the start of the stagger (or
  `WF_Hit_F/L/R`, once those clips are in) plays for `FLINCH` 0.42 s, and it can
  do nothing else until that is over. So in the middle of his combo its plain
  blows never reach him. What has armour goes through: the heavy moves (`slam`,
  `combo3`, `combo2` — `armour` below 1 in `MELEE`), a leap, a claw wave, and
  the counter it turns on him when it has had too many cuts too fast
  (`_count_cut`; `COUNTER_ARMOUR` 1.6 s, long enough for the counter to come
  in): then the body only gives a little (`FLINCH_ARMOURED`), it is barely
  moved, and the blow lands on him anyway. `net_flinch` shows it on every peer.
* **The swing catches, and so does what it bit** (`scripts/hit_feel.gd`,
  `HitFeel`, October 2026). Both are held all but still for the same beat,
  longer the heavier the blow (`HitFeel.stop_for(cut_weight)`): the dash's cut
  0.04 s, a light cut 0.07, the end of a string ~0.1, a heavy blow up to 0.14.
  His side: `SkinnedRig.hitstop`, the swing's clock held with it; while it
  holds (`Player._bitten`) he does not glide on (`BITE_GLIDE`), and his
  commitment and any cut asked for meanwhile wait for it. The creature's side
  goes out to every peer (`Player.net_bite`, from `blade_hit`): the wolf's own
  `WolfRig.hitstop`; creatures that step their clips themselves (fighters,
  imps, orcs) step them at `HitFeel.pace()`; any other clip player is held by
  its process mode. All on the real clock.
* **The body lit**: for 0.1 s the creature is lit faintly at its edges, a warm
  white fading out (`HitFeel.flash`, an additive overlay; meshes already wearing an
  overlay, an affliction or the blood, are left alone). Brighter for a heavier
  blow.
* **Blood out of the cut, not a streak of light**: the red streak laid along
  the swing where it bit is gone (it read as a laser); the gush above is the
  mark of the blow.
* **The view is knocked and shaken, every cut** (`ImpactFx.knock`, one tween
  for both so they never fight over the offsets; his own camera only): knocked
  the way the blade went, 3 cm for the dash's cut, ~4 for a light one, up to
  6.6 for a heavy blow, then shaken (3.5–9 cm, dying away over 0.18–0.3 s).
* **It is heard**: under the ring of the steel, a short deep thump with a wet
  tear over it (`ImpactFx.thud`, made in code at load).

Fighters and orcs get the direction, the wound, the streak, the tipping over,
the hold and the light; breaking off their moves is still the wolf's alone.

**Leaning into the run** (`Player._lean`): the model (not the capsule) is
leant over its feet into a turn, the faster and tighter the more
(`turn_lean_rate`, at most `turn_lean_max` 0.2 rad), forward as a run picks up
and back as it pulls up (`pace_lean_*`), eased in at `lean_follow`; forward and back it is a spring a little
under-damped (`pace_sway_*`), so pulled up he rocks back and a touch forward
past upright before he is still. Pulled up hard out of a run, or thrown back the
other way, the feet kick up a little dust (`skid_*`, a small `DustRing`). Worked out
from the turning and the replicated velocity, so every peer sees it; none in
the air, in a swing or a dodge. `tests/hit_feel_test.gd` checks the lean and
the bite.

## Cuts in the air

Every blade and claw draws its cut with `BladeArc` (`assets/fx/blade_arc.gdshader`):
a hot hairline where the tip went, a soft halo round it in the glow colour, a
thin sheet behind it thinning to nothing at the hilt (`sheet`), wind streaks
running back along it, the air behind it bent, and a tail that frays away —
added to what is behind it, light rather than paint, so it never covers the
wood as a flat grey crescent. `strands` draws more than one line side by side.

* Tariel's sword and the assassin's two blades: one line, a pale sheet, a cool
  white-blue halo (`intensity` 1.15).
* The wolf's claws: no longer the plain additive `SwordTrail` (a faint white
  strip), but three lines side by side — the marks of its claws — ash-white in
  a dull red halo over hardly any sheet, lasting 0.26 s (`WolfRig._make_trail`).
* The orc's axe keeps its own grey arc.


## Tariel's colours: F9

Tariel's colours are a wardrobe in `SkinnedRig.TARIEL_WARDROBE`, not baked into
the model: each dress is a set of colours for the model's materials (by their
names from Blender, `t6_crimson`, `t6_tiger`, `t6_gold`, … in Blender's linear
values) and for his cloth cape. `_put_on_dress()` gives each named surface a
copy of its material in the new colour (`set_surface_override_material`) and
recolours the cape (`ClothCape.recolour`) — the same meshes and the same number
of materials, so a dress costs nothing. **F9** steps through them in the game
and says which is on; `SkinnedRig.dress` is the one worn (the static default
is the one he starts in). The other heroes have no wardrobe.

* **crimson** — as the model was made: crimson, bright gold, an orange tiger.
* **panther** — oxblood, a tawny panther skin, old bronze, darker steel.
* **black** — black and steel, a dark amber skin.
* **indigo** — deep indigo cloth, tawny skin, muted gold.
* **hunter** — olive and leather, of a piece with Avtandil.

## Tariel v8: dressed in cloth

`vepxis-art/tools/t8_build.py` (`t8_build()` in `tariel.blend`, collection
`t8`, object `tariel_v8`; the glb written by `tools/export_tariel.py`): the
same box-built face and body style as v6 — a new face (heavy brows, a hooked
nose, a scar, a full beard, long hair and a braid, a leather band) — but the
clothes are **cloth**, not boxes: one smooth surface for the chokha from the
shoulders to below the knee, open down the front over a mail shirt, folds
deepening and flaring to a bronze-braided hem; its skirt weighted from the
hips down into each leg (and shared between the legs at the back), so it
hangs and swings; soft sleeves flaring to a turned cuff; a soft collar. Leather,
bronze, the pelt over the shoulders, the pauldrons and the boots stay built
from boxes. Gazyri on the chest, a belt with bronze plates and a khanjali.
Black for now (`HEX` in the script). The model is scaled 1.08 in
`tariel_rigged_visuals.tscn`: taller. The wardrobe (F9) now only recolours the
cape; it starts on `black`.

The long coat (`t8_build("long")`) is the one in the game: to the ankle, heavier
folds, slit up the back, the calves taking part of its hem.

## Avtandil v8: two outfits, one in the bag

`vepxis-art/tools/a8_build.py` (`a8_build(outfit)` in `avtandil.blend`) dresses
v7's Avtandil — his face, hands, boots, quiver and bow are v7's
(`a7_build.py`, run first) — in cloth the way Tariel v8 is: a tunic from the
neck to the hem with its own thickness, folds deepening to the hem, the skirt
weighted into the legs; soft sleeves; hoods, a mantle, a sash as cloth. Four
outfits were drawn (`OUTFITS`: hunter, ranger, khevsur, wanderer); two are in
the game, **each its own mesh on the one skeleton** in
`avtandil_rigged.glb` (written by `vepxis-art/_a8_export.py`):

* `avtandil_ranger` — **Ranger's Mantle**, worn: a grey-green tunic to
  mid-thigh under a long moss mantle, its hood up.
* `avtandil_wanderer` — **Wanderer's Kaftan**, in the bag: an olive kaftan to
  mid-calf wrapped across the chest, a crimson sash, a deep brown cowl.

`SkinnedRig.garbs` names the outfit meshes a rig carries (set in
`_configure()`; empty for a hero with one) and `set_garb(i)` shows one and
hides the rest. `Player.set_garb(i)` puts one on; `net_garb` carries it to the
other peers, as `net_shield` does the shield. The bag (**I**) has an
**Attire** tab listing them (`Inventory.GARBS`: the name, a line and a drawn
icon per mesh name); Enter or a click puts one on, and the status column says
which is worn. Only one is drawn at a time, so the second costs memory, not
frames (about 36k triangles each).

## The assassin's and the mage's outfits

Both are dressed in cloth the same way (`vepxis-art/tools/d8_build.py`,
`m8_build.py`, written to their glbs by `vepxis-art/_garb_export.py`), each
version its own mesh, chosen in the bag's Attire tab. The assassin: the black
coat edged in red (worn), Nightblade, the Crimson Hood, the black coat edged
in ivory, the Sandstrider. The mage: Storm (worn), Ember, Sage, Wine. A hood
is round cloth whose rim covers the corners of the square face; the black
coats' hood falls back over the nape. `SkinnedRig.garb_capes` hangs each
outfit's cloth capes its own way (colour, length, none); `ClothCape` takes a
`point`, so a hem can be cut to a point at the back (the worn coat's short
cape).

### The mage's bolt always arrives

A locked bolt now bends as hard as it has to: at least as fast as the line to
its quarry swings round at that pace and distance, so however the mage was
moving or facing when he let go it comes round and hits. Only a real dodge
(`is_evading()` — a roll, a dash) shakes it off; a creature merely turning or
breaking into a run is followed (`dodge_by_swerve`, off). A bolt still hunting
never fades for having gone past; one shaken off still does.

### The assassin coats his blade on the move

The Poisoned Blade no longer slides him along in a standing pose: while the
coat plays he is slowed to a walk and can steer, and the legs walk under the
arms (`SkinnedRig.walk_under`, the same stride the swings use). The coat
clip's right forearm no longer spins round at the flick (`DG_Poison_Coat`
eased from frame 49 to 70 in heroes.blend).

Tariel stands taller: his model is scaled 1.2 (was 1.08).

## Tariel v12: a warrior, in Avtandil's style

`vepxis-art/tools/t12_build.py` builds Tariel from Avtandil's own pieces
(`a7_build.py` / `a8_build.py`: the classic face, with a full beard; the
cloth tunic) and carries every vertex onto Tariel's skeleton bone by bone
(`AV` / `TA` bone tables; a little broader across, `BROAD`), so the two heroes
are of one world. `_t12_export.py` writes the glb. Three dresses
(`SkinnedRig.garbs`, the bag's Attire tab), all a warrior's: a sleeveless
tunic to above the knee, the arms bare and bound in white linen from the elbow
to the knuckles, the shins bound too, a leather guard on the left shoulder, a
baldric — in earth red (worn), in slate edged in crimson, and in the panther's
hide. No cape. The round shield is new: boards of wood side by side, an iron
rim and boss, rivets (`shield12("wood")`); v8's is kept in tariel.blend as
`tariel_shield_v8`.

Tariel now starts as a **berserker** (a Norse look on the same square head:
clearer eyes with a blue-grey iris, longer hair in locks at the sides and down
to the nape, thin braids at the temples, no beard): bare-chested under a
leather jerkin open to the belt, a bear's fur over the shoulders, gold rings on
the bare arms, the shins bound. In the bag: a Norse wool tunic with a woven
band and a grey fur mantle, a mail shirt, and the three warrior's tunics, all
with the same head (`VERSIONS12` vk_* in `t12_build.py`).

**His hair is picked on the hero select.** The hair is its own mesh now, one
per style, worn over whichever outfit is on: each laid lock by lock —
tapering, slightly twisted ribbons in three browns, combed back from the brow
over the crown (`hair2(style)` in `t12_build.py`), over a dark close cap, the
shaved sides and nape in stubble darkening upward. Six, the first the one he
starts in: a long mohawk falling to the nape; the sides shaved, the top tied
into a tail; into a braid ringed in gold; into a knot on the crown; all of it
long and swept back; and the old shoulder-length hair (`classic`).
`_t12_export.py` builds the garbs bare-headed (`hair_split`) and each hair as
`tariel_hair_<style>`. `SkinnedRig.hairs` / `hair_names` / `set_hair(i)` show
one; `Player.set_hair(i)`, replicated in `net_hair`; `Game.hair(id)` /
`set_hair(id, i)` hold the choice (remembered in settings.cfg, section `hair`),
and the local player puts it on when he spawns. On the character page, under
the stage, `<  HAIR  NAME  n / 6  >` steps through them on the turning model
(faded out for a hero with no choice).

**And his face.** The head itself is a mesh of its own now too, one per face,
worn over any garb and picked on the hero select the same way (a `FACE` row
over the `HAIR` one): the face he has always had (the square head), and six
sculpted ones — Norse and low-poly, flat-shaded, with a long braided beard or
with stubble (V3, V2); a painted-adventure one, smooth, the features pushed,
bearded (S3); and three clean ones as in the older fantasy MMOs and anime —
an oval face, a small straight nose, large almond eyes lined dark along the
top, thin brows, a quiet mouth (A2 finer and elvish, A4 stern, A1 plain). The
sculpted heads are signed distance fields (smooth unions of ellipsoids,
capsules, rounded boxes; the clean ones lofted from a profile) meshed with
marching cubes and painted face by face (`vepxis-art/tools/heads/sot_sdf.py`
→ `heads/<key>.json`), brought in and cut down by `sot_head()` in
`t12_build.py`; the hair grows from the sculpted skull's surface and keeps
off it, and the scalp under it is painted, not boxed. Hair is fitted to the
skull it grows on, so there is a set of the six styles per kind of skull
(`box`, `sot`, `anime`: `tariel_hair_<skull>_<style>`; on a sculpted skull
the block hair is a long parted hair instead). `SkinnedRig.faces` /
`face_names` / `face_skulls` / `set_face(i)` (the hair follows onto the new
skull: `hair_mesh()`), `Player.set_face` / `net_face`, `Game.face(id)` /
`set_face(id, i)` (settings.cfg, section `face`).

The one on the stage stands still now; dragging across the stage (mouse, or a
finger) turns them (`CharacterPortrait.spin`, `_on_stage_input`).

## The wolf: cuts, the ground, the fall

**The limb the blade went through.** A cut that takes a limb takes the one the
edge passed nearest (`WolfRig.sever_along_edge` → `_limb_gap`), no longer one
drawn at random; two about as near (within 12 cm), either. The piece is thrown
along the blade and a little out from the body, and turns end over end about
the line the blade cut across (`SeveredLimb.launch(away, blow)`), slowed by the
air. Both cut ends are raw: a flattened ball of wet red flesh on the piece and
on the body (`_stump_cap`, hung on the nearest part above the joint so it moves
with it), and the stump bleeds in five pulses, thinner each time
(`WolfRig._bleed`). A piece fades out over its last second instead of blinking
out.

**Down, it can be cut.** On its belly its back is under half a metre high, and
a cut swung at a standing man's height went clean over it: nothing was ever
struck. Now a wolf that is down meets the blade where it lies — the edge is let
down to the height of its back (`Wolf._within_reach`, `DOWN_BACK`) before it is
asked what it reached; how near along the ground is still the blade's own.

**It dies where it lies.** Killed on its belly it no longer gets up to play the
standing death clip: it goes limp where it is — blended over half a second into
the crawl's pose with its head and chest on the ground (`WF_Limp`, one moment of
the crawl made a clip of its own by `_still_of`) and rolled a little onto its
side. Killed standing, the death clip starts where it begins to give (its still
first half second is gone, 0.55 s) and runs a little faster (1.2). Either way
the body **strikes the ground**: dust where it lands and the sound of a weight
dropping (`WolfRig.landed` → `Wolf._body_lands`), the hips and then the
shoulders. The tail goes slack.

**It fades, it does not sink.** After `corpse_linger` the body fades out where
it lies over `corpse_fade_time` (1.2 s; `WolfRig.fade`, each mesh's
`transparency`, its shadow off past half) — let down through the ground it read
as the ground eating it.

`tests/wolf_mind_test.gd`: a wolf with both legs off is cut where it lies, and
killed there it goes limp with its head low.

## The map to come: five bosses

A plan, not yet built: the land grows from 240 × 635 m to 600 × 890 m (x −300…300,
z −470…420), the present land untouched in the middle and five regions round it,
each with one gate, a ridge, cliff or river between it and the next, and its boss
in a closed arena at the far end: **Mamberi's wood** (the lord of the wolves; the
wood carried on to the east), **Ochopintre's beeches** (south-east, across the
Black River), **the Devis' mountain** (south-west, the orcs of the bay their
vanguard), and two regions not yet given a boss — **the northern upland** beyond
the wolves' hill, and **the western plain** beyond the village.

## The assassin: the knife goes where he cuts

**Aimed cuts** (`scripts/strike_aim.gd`, `StrikeAim`, a `SkeletonModifier3D`
after the stride). A cut has something it is thrown at: the locked target if it
is near enough, or else the nearest enemy within 3.2 m and 70° of where he is
pushed or faces (`Player._strike_candidate`). He is turned to it, every peer
is told what it is (`net_strike_at`, since the host's copy of the swing is the
one that cuts), and:

- **he steps in to it** — further than `strike_close` (0.42 m from his middle
  to its near side) the cut first carries him in, over 0.13 s and no more than
  1.8 m (`_step_in`);
- **the swing bends down to it** — the knees give (the hips let down, the legs
  folded so the feet stay), then the trunk leans in over the hips, the head
  held up, and the waist turns a little to it if it has moved: as far as the
  gap between where the swing cuts on its own (`strike_natural` 1.25 m; the low
  thrust 0.8, the finisher 0.7, `strike_heights`) and the middle of the thing
  (`Player.strike_point`: its `strike_point()` — a wolf's chest, or its back
  down on its belly — or half its `body_height`). Eased in over 0.07 s as the
  cut starts, out over 0.2 s;
- **the edge gives a little** (`SkinnedRig.get_cutting_edge`): the knife is
  20 cm longer for the hit than it looks (`strike_reach`), and a cut aimed at
  something is let down to it by up to 30 cm past what the bend made up
  (`strike_pull`) — a short knife moving fast is past a body between two
  physics ticks as often as in it.

Only the assassin (`SkinnedRogueRig`: `strike_aim`). At a puglin a pace and a
half off, a little aside, six of his seven blows now reach it (two of eight
did); at a wolf on its belly the knife goes down to 0.26 m.

**His string** is a knife's now: the slash down and back up, a low thrust in
(the reverse-grip stab of his knife-fighting set, only its thrust:
`flurry_part` plays part of a clip), the spin, the backhand, a quick jab (the
lead stab's), and the big blow down to the ground to end it. The sword combo's
overhead cuts (3 to 5) are gone — they went over anything shorter than a man.

**He stands square** (`DG_Stand`, built in Blender by
`vepxis-art/tools/dg9_build.py`, not retargeted: Mixamo's standing idles are
all side-on): both feet under him a little apart, knees soft, arms down, the
knife low with its point ahead, three seconds of breathing, the head turning a
little. The fighter's side-on guard (`DG_Idle`) is no longer his idle.

**The Poisoned Blade** is a new coat (`DG_Poison_Coat`, the same builder,
2-bone IK solved per frame over the standing pose): the knife brought up
before his chest, two fingers of the other hand run along it from the guard to
the point, then the excess flicked off with a snap of the wrist. `VenomBlade`
follows it: the blade greens behind the fingers as they go, a green breath off
the fingertips, and its light is small and faint (the old one turned his whole
body green). The vial is gone (`DG_Poison_Coat_Vial` kept in heroes.blend).

`tests/rogue_strike_test.gd`.

### The assassin's heavy blows and a quicker string

**Two buttons.** He has no shield to raise, so the block button (right mouse)
is his **heavy blow** (`Player._attack(true)`, `SkinnedRig.heavy`, thrown as
`attack(HEAVY + i)` on every peer). Which one depends on what the light string
(left mouse) has come to (`Player._heavy_blow`, from `flurry_position()`):

| before it | the heavy blow | clip (part) |
|---|---|---|
| nothing (the string left a second) | a lunge in with the point and a slash back out — two cuts, stepping in up to 3 m | `DG_Thrust_Slash` |
| nothing, at a run | a flying front flip, the knife coming down as he lands, the flip landing where it is thrown | `DG_Big_Flip` |
| one or two cuts | a spinning leap and kick, the knife coming down after it — two cuts | `DG_Spin_Flip_Kick` |
| three or four | three great cuts, the last from over his head to the ground | `DG_Axe_Three` |
| five or more | the whirling combo, round and through — three cuts, carried forward | `DG_Dual_Combo` |

A heavy blow ends the string, costs 1.6 light cuts' stamina, is worth
1.4–1.8 of one (`cut_weight`, multiplied in `Player.cut_worth`), bites longer
(the hitstop ×1.8) and shakes the view when it lands. The light string's last
cut is worth 1.35.

**Blows that cut more than once** (`cut_windows`): each window is its own blow
— a new `attack_serial`, so what it lands on takes it afresh, and its own
whoosh.

**Blows that carry him** (`carried`): a flip, a leap, the whirling combo move
him by their own clip's travel (the root motion, `carry_velocity`), scaled so
he lands where what he is thrown at stands (`carry_scale`, from the blow's
`travel`).

**The light string** (Mixamo's, all the assassin's own) is six cuts, in an
order where each starts where the last left the knife (matched by the knife's
tip at each end, measured in Blender): the slash down and back up, the spin,
the backhand, the long sweep from high right to low left (`DG_Axe_R2L`), and
the blow down to the ground. No cut is played faster than 0.36 s, the last
than 0.46 s (`flurry_min_time`, `finisher_min_time`): at his pace the tightest
of them had been a 0.2 s blur.

**Heavy blows play their recovery.** The spinning leap ends on the ground and
he rolls up: it was cut before the getting up, and he sprang from the ground to
his feet. Now each heavy blow plays on past its last cut (to `part.y`), the
commitment is held to the end of the getting up where there is one (`hold`),
and from `rise` on an evade may take him out of the rest (`in_recovery`).

**Flexible**: a light cut whose cut has done its work can be broken off by
an evade (`SkinnedRig.in_recovery`): the follow-through is his to give up. A
heavy blow plays out.

New clips (`vepxis-art/tools/dg10_export.py`, retargeted from
`mixamo/assassin/`): `DG_Slash_Out`, `DG_Axe_R2L`, `DG_Thrust_Slash`,
`DG_Axe_Three`, `DG_Big_Flip`. `tests/rogue_strike_test.gd` checks the choice
of heavy blow, the double cut, and the evade out of a follow-through.

## Tariel after Ashen: two looks

Tariel is now one of two on the hero select — the `LOOK` row under the stage
(the rig's `faces`, relabelled): **AS HE WAS**, the square-headed Tariel in
the berserker's harness with the long mohawk, and **THE WARRIOR**, the
figure after Ashen — a slim flat-shaded body lofted in few-sided rings, a
carved bone half-mask with cut eye holes over a bare jaw, the sides of the
head shaved under a crest of hair braided down the back, a wrap-over wool
tunic (the lapped edge bound in a woven band, a bronze brooch, gathered
under the belt, two flaps slit at the hips with a zigzag hem), short breeches
with turned-up leather cuffs, bare arms in gold rings and linen wraps, a fur
mantle, a leather guard on the left shoulder, wound calves and furred boots
(`vepxis-art/tools/t14_body.py`, `t14_dress.py`, look `warrior_earth`;
exported by `vepxis-art/_t16_export.py`). He is one mesh, body and head and
dress together (`tariel_face_ashen`), so `SkinnedRig.whole_faces` lists him:
while he is on, `wearing_whole()` hides the outfit and the hair. The other
faces, hairs and outfits have left the glb (they stay in `tariel.blend`);
`garbs` is the berserker's alone and `hairs` the long mohawk alone, so
neither row is offered. The glb went from 13.6 MB to 4.8 MB.

**Now the wanderer.** The second look is Tariel after Ashen's own hero
(`THE WANDERER`, look `a_ashen` in `vepxis-art/tools/t14_dress.py`): a blank
pale mask lying close over the whole face — a smooth sheet curving across it
(`mask_flat`, the face pressed back behind it, a faint ridge down the nose),
no eyes cut, a rim you can see; short curly fair hair; an olive wool tunic
with long sleeves, a stand-up collar and toggles down the chest, big leather
cuffs, a short capelet of leather cut ragged over the shoulders; slim brown
breeches tucked into shaped boots (a turned-down cuff, a strap and buckle
over the instep), the shins bound crosswise over them; a hero's build (the
shoulders broader, the neck thicker, the head a size up) and hands with
fingers. The warrior, the hooded and masked versions and two knights (after
Elden Ring's Wylder and Dark Souls' Soul of Cinder) stay in the art tools as
looks (`warrior_*`, `h_*`, `k_wylder`, `k_cinder`). `vepxis-art/_t16_export.py`
builds whichever look `T16_LOOK` names (default `a_ashen`).

**His cloak.** The wanderer's capelet hangs as cloth now (look `a_soft`):
folds that deepen towards the hem, longer at the back, the hem in shallow
uneven scallops with its lining and thickness showing, its sides weighted
partly to the shoulders so the sleeves no longer show through it. Under it he
wears a real cloak of plain brown wool from the back of the shoulders to the
calf, simulated like Tariel's old tiger skin: `SkinnedRig.whole_capes` hangs
capes for a whole figure the way `garb_capes` does for an outfit.

## The wolf in a fight: no back turned, no wild leaps, quicker blows

- **Drawing off to come again** (`WolfMind.Tactic.RUN_UP`) no longer turns
  its back and walks off: it draws off slantwise at a trot, face on, watching
  him (`Wolf.withdraw()`, `withdraw_speed` 3 m/s), to 6.2 m or 1–1.8 s, and
  then comes at a run that builds. The old one read as the wolf giving up in
  the middle of a fight — and a hop back thrown while its back was turned
  went *towards* him. wolf_mind_test checks it never turns its back.
- **A leap forward is aimed at him however it was turned** (`_take_off`): a
  pounce or a leap out of a run was aimed only if he stood within ~70° of the
  way it faced; otherwise it leapt off the way it faced. A hop back still keeps
  to its own facing.
- **Quicker blows.** The hand-to-hand clips (Mixamo's, human speed) played
  slow — the jab at 0.72 — so a chain dragged: now jab 1.05, rake 1.5, three
  blows 1.45, two blows 1.4, smash 1.25. The blow held at the top of its
  windup (to catch a roll) is rarer and shorter (0.15–0.35 s) and no longer a
  freeze: it creeps on at an eighth of its pace, coiled.

## The wolf's fight, read and punished

- **Every blow told.** Each chain opens on a sound — a short snarl, a growl
  for the long three-blow combo, a deep roar for the smash — and as a blow
  comes its claws glow and its eyes flare. The smash, which no shield turns,
  has its own tell: the claws burn a deep red and larger and the eyes blaze
  (`WolfRig._melee_heavy`, `_melee_glint`, `_glint`, `_tell`).
- **An opening after the big ones.** The smash comes down and its claws stay
  in the ground 0.7 s (`open_after_slam`); a pounce or a leap out of a run
  that finds nobody lands it off balance, staggering 0.85 s
  (`open_after_miss`, `_stumble()`, `net_stumble`). Either way it takes the
  riposte's half again (`Recoil.RIPOSTE`), as when a parry throws it back.
- **No stutter under a string of cuts.** The beat of stillness when it is hit
  is 0.03 s for an ordinary cut (0.09 for a critical), and its own blows
  landing 0.05 s — a long combo no longer judders it.
- **The claws' cut** is as big as the wolf that throws it (`_size()`, the
  scale of its `Visuals`), leaves from as high as its paw, and is thrown at his
  chest: up at a man on a ledge, down at one below (no steeper than ~35°; the
  slam's ground wave stays on the ground). One thrown into the ground breaks
  there. claw_wave_test: "up on a ledge".
- **Two on one man.** Now and then one of the two stands off at 6–8.5 m and
  throws the claws' cut at him every 3 s or so while the other brawls
  (`WolfMind.Tactic.SHOOT`); after 6–9 s they change places — the thrower
  comes in, the brawler draws off to throw (`_swap_shot`, `take_shot`). Never
  both at once. wolf_mind_test: `_pair()`.
- **It reads him.** A shield held up at it and kept there (0.5–1.1 s, the
  cleverer the sooner) is answered once per spell of guard: it runs round him
  past the shield and strikes from his side or back (`WolfMind.Tactic.FLANK`),
  or — the block being frontal and paid in stamina — it batters it with the
  blows that cost a shield most (the smash, or the long combo into the smash)
  to break the guard. Nothing here leans on the parry. A man under a quarter
  of his stamina is pressed: no drawing off after a chain, blows closer
  together, a chain one longer (`_winded`). A man with a bow is come at
  weaving, not down the line of his arrow (`_ranged`). wolf_mind_test:
  `_guard()`.

## The imp grown, with clips and a fight of its own

The small ones were too small: the imp stood 1.68 m to the top of its hair
against Tariel's ~2 m, the puglin 1.06 m (most of a cut goes over its head —
next), the golem 1.9 m and never fights. The imp is first.

- **2.1 m, hair and all** (`visual_scale` 1.25). The collider is the body at
  that size (capsule r 0.375, h 2.0; `body_radius`/`body_height` scaled by
  `visual_scale` for the blade), the bar over its head with it. Its walk and
  run are retimed off its own stride *at its drawn size* (the Monster's
  retime ignored `visual_scale`, so a scaled creature skated).
- **Its own clips, on its own rig.** Mixamo's, retargeted in Blender onto the
  Bestiary Imp's skeleton (vepxis-art `tools/imp_build.py`: `build` → imp.blend,
  `clips` → 33 `IP_*` actions, `export` → `assets/monsters/imp/imp_anims.glb`,
  the rig and a speck of mesh so Godot builds the Skeleton3D). Most came from
  the wolf-man's set already on disk (claws, the leap, dodges, strafes, hits,
  death), the flips and the run from the assassin's, the fall and getting up
  from the reactions. `SkeletonAnim.setup(target, source)` now takes the file
  its clips come from (`Monster.clip_source`, `loop_clips`), so the model is
  still the kit's and keeps its colourways, and the delta from rest is exact
  (the round trip through Blender moves no rest by more than 0.04°).
- **Its body goes where its clips go.** How far each clip carries the hips
  was measured in Blender (`imp_clip_meta.json`); the clips are exported in
  place and the body is driven along that path, scaled to its size, by
  `move_and_slide` — into walls and bodies like any walk. A leap is stretched
  or cut so the head of the mace, not the imp, comes down on him
  (`land_off` 1.5 m); a blow on foot is stepped in under to `strike_off`. The
  sidesteps and the backflip, in place in their clips, are carried by hand, fast
  off the mark and easing out (`dodge_distance` 2.6 m).
- **How it fights** (`scripts/imp.gd`, `Imp extends Fighter`):
  - *It circles.* Roused, it runs to a ring round him (3.4–5.4 m) and strafes
    there face on, working round towards his back, backing out quickly when it
    finds itself inside the ring and keeping off its own band.
  - *Two go in at a time* (`Imp.PACK`); the rest circle, and now and then one
    stops and flexes at him.
  - *It hits and gets out.* From the ring it leaps in with the mace overhead
    (`POUNCE`, floors) or flips in feet first (`FLIP`); close in it rakes with the
    claws (`SWIPE`), swings the mace (`MACE`), runs the two together (`COMBO`,
    no knockdown) or brings the mace down two-handed (`SLAM`, floors). Then,
    three times in four, it hops or flips back out of reach.
  - *It does not block* (`block_chance` 0): a cut coming, it sidesteps either
    way or, right on top of him, flips or hops back — untouchable for the first
    `evade_iframes` (0.5 s, long enough for Tariel's blade to pass) — and a cut
    that met nothing is answered at once (`_counter`).
  - *A cut throws it the way the blade went*: its hit clip for that side
    (`IP_Hit_F/L/R`), a stagger for a blow worth more than a fifth of its health,
    each carrying the body as it carries the hips. Only coming down out of a
    leap does it not stop.
  - The blows are its limbs, not a circle round it: the mace from the fist to the
    spikes (`MACE_TIP`, measured off the mesh), the claws from the forearm to the
    fingertips, the feet in the flip. Each lands where that limb moves fastest in
    its clip.
  - It dies by its own clip (`Fighter.dies_by_clip`) instead of being tipped
    over.
- fighter_test's block / break / dash / combo checks are on a puglin now (held
  to the numbers they were written for); imp_test checks the imp.


## The pack's leader, and a bow that can bring a wolf down

- **Every pack has a leader.** Wolves whose homes lie within `pack_span`
  (22 m) of one another, one to the next, are one pack (`Wolf.pack()`); of a
  pack of two or more, one leads (`_find_leader`, the same on every peer —
  by its path): 15% bigger, 60% more health, no duller than 0.8.
- **Its fall shakes them.** Brought down, every one of its pack staggers where
  it stands (and is open for that moment) with a growl, and then each either
  **breaks and runs** to the nearest other pack (`desert_chance` 35%; it goes
  there at a run and becomes one of that pack — unless it is cut on the way,
  when it turns and fights) or **stays, enraged** (`_enrage`): no leader, so
  no taking turns — they all go at him at once — no drawing off, no standing
  back to throw, no flanking; it hits 30% harder and moves 15% faster, dodges
  his swings half as often, gets out of no arrow's way at all, and its eyes
  burn brighter. wolf_mind_test `_leader()`.
- **A bow or a staff can bring it down.** It got out of the way of most
  arrows and bolts from far off (85%): now of some — 45% far, 30% close — and
  after a dodge it wants 2 s before it can dodge another
  (`missile_dodge_rest`); enraged, none. wolf_run_test and wolf_mind_test
  expect some dodged, never most.

## No parry; wolves see further; blood styles

- **The parry is gone.** Raising the shield no longer flings it out first
  (`SS_Parry`) and a blow met the moment it comes up is simply blocked, paid
  in stamina like any other; there is no `parry_window`, `parry_cooldown` or
  `_parry()` on the player any more, and the inventory no longer lists it. The
  creatures keep their `parried()` (a thrown-back reel) for anything else that
  knocks them back. vitals_test and skinned_rig_test check the block only.
- **Wolves come out from further off:** they notice him at 17 m (was 11) and
  follow to 28 m (was 18).
- **Blood can be drawn four ways** (`Blood.style`, `Blood.use_style()`),
  shown side by side by `_shots_tmp/blood_styles.gd`: `cubes` (as it was),
  `gloss` (round glossy drops and wet pools that catch the light), `trail` (a
  thin fast streak and one red brush-stroke laid the way the blade went, a few
  drops; 18–24 s) and `mist` (a soft red mist that hangs and thins, small soft
  stains that go in 8–12 s). The game still uses `cubes` until one is chosen.

### Blood: the mist, and a clear mark on the ground
- **The game now bleeds `mist`** (`Blood.style` defaults to it): a red mist
  that hangs and thins where the blow landed. What it leaves on the ground is
  no longer a few faint soft spots but a clear deep-red pool under the wound,
  two or three splashes the way the blow was going and a spatter of small
  drops round them; it lies 14–18 s, then fades. The other styles stay
  (`Blood.use_style()`).

## The puglin: a band that rolls

The puglin stays small (1.1 m, as it was) — its strength is that it never
comes alone. `scripts/puglin.gd` (`Puglin extends ClipFighter`), its model and
clips `assets/monsters/puglin/puglin.glb` (vepxis-art `tools/puglin_build.py`:
the kit's Puglin, its stick swapped for a short sword skinned to the right
hand, 25 Mixamo clips `PG_*` on its own rig; the colourways still the kit's,
`skin_dir`, and only `MI_*` materials are recoloured).

- **A band is one thing.** Roused, the band walks at him slowly (`bunch_speed`
  1.3 m/s), bunched round one point that stops `stand_off` 3 m short of him, each
  in its place round it (`bunch_radius`), faces all on him (`Puglin._bands`, kept
  by the band's first member).
- **They roll.** Curled into a ball (the roll clip held on its most curled
  frame) it comes at him at up to 9 m/s, the body turned over about the middle
  of the ball as fast as the ground goes by (`_lay_ball`, every peer, from the
  replicated velocity), off walls. Past him it rolls on, swings round in an arc
  (`roll_turn`) and comes again — two or three passes; finding him, it bounces
  back off and swings round. It comes fast (10 m/s) and steers after him while
  he is ahead of it (`roll_home` 1.8 rad/s), letting go of him only in the last
  `roll_commit` 2.2 m, so a man standing or walking across it is found on the
  first pass (puglin_test, four of four) and a late sidestep still works. A
  rolling ball meets only the world: balls of a volley pass through one another
  (they used to knock each other off their line, which was most of their
  misses), and one he rolls clear of (dodging, rolling, untouchable) goes on
  through him — he is neither hit nor carried along on it — and comes again. Bunched, the whole band rolls at once every 7–11 s;
  when every ball of such a volley finds him he goes down (a combo of one on the
  last ball), a single ball only flinches him. Steel glances off a ball (a puff,
  no blood); magic gets in and knocks it out of its ball. Uncurled it stands
  dizzy a second — the opening.
- **Mud** (`MudBall`, `ScreenMud`), made to be
  seen coming and to blind: it scoops a lump and holds it in its fist through the
  wind-up; the lump flies lumpy, spinning and wet-shining with a pale rim that
  stands it off the earth behind it, shedding drops, with a dark spot on the
  ground under it that says where the arc will come down; it lands with a slap,
  a spray of drops and a patch that dries. What it hits takes a little and,
  unless he rolled away from it or met it on a shield, gets mud in his eyes, on
  *his* screen only (the host tells his peer, `net_mudded`): one big slap where
  it hit and eight or so round it and off the edges (under the bars, the bag
  and the menus — `ScreenMud.LAYER` 3 — never over the settings), thick and wet in the middle,
  running in drips, round drops thrown off, a brown film over the lot; it holds
  2.6 s and thins away over 4. Every splat is a picture made once (eight shapes,
  `ScreenMud._bake`, 0.6 s, in the level's warm-up) laid on the screen as a plain
  textured rectangle: it had been one full-screen shader working every splat out
  for every pixel and blurring the view under it, which on a Retina screen took a
  frame from 28 ms to 93 ms for as long as the mud was on. A band's timers all run on one clock (the physics
  frames), not each member's own. The throw is only the throw: the clip's arm
  drawn back from 0.55, flung at 0.70 (where the hand goes forward fastest,
  measured), held to 0.80 — before 0.55 it waved the hand back and forth once
  for nothing. The mud's splat pictures, lump, drops and patch are made once behind the
  level's warm-up black ([PipelineWarmup]) — the first lump to hit used to stall
  the frame while they were built.
- **One combo, three cuts**: three of the sword-and-shield set's slashes run
  together (across, back the other way, a heavy one down into the ground),
  counted as one combo — all three floor him. `ClipFighter._chain_blow /
  _chain_serial` let several acts be one combo. The moments are where the point
  sweeps across in front of it (measured 1.0–1.3 m out; the orc's axe combo tried
  first swung mostly behind a body this shape).
- **A big blow breaks it up**: a cut worth 1.35× the hero's ordinary one (a heavy
  cut, the last of a string, a critical), one knocking it down, or one swing
  through two of them — they hop off from him every way at once, come at him from
  all sides for 6.5–9 s each on its own (circling slowly, its own ball, its own
  mud, its sword), then one of them shouts and they bunch again.
- **Hard to cut** (p.def 80: a 26 cut takes 14), easy to burn (m.def 5); an
  ordinary cut does not stop its stroke or its throw — only one worth a fifth of
  its health staggers it.
- **Tariel's cuts reach down to it**: his rig bends his swing to what it is aimed
  at, as the assassin's does ([StrikeAim]; `strike_natural` 1.3, `strike_pull`
  0.25). Before, most of his cuts went over a puglin's head.

**Up close it fights.** Near him (`close_in` 4.2 m) it walks in and cuts rather
than throw mud from there. A ball that finds him stops against him, uncurls
there (`BUMP`) and goes straight into its three cuts; only a roll that never
found him ends in the dizzy moment. About half of them (`leaper_share`, fixed
per puglin by its name) are leapers: rolling straight at him and 2.8–4.8 m off,
one springs out of its ball (`LEAP`, the sword-and-shield set's jump attack,
`PG_JumpAttack`), the body carried up over the clip's own hop (`leap_lift`) and
the leap stretched so the sword comes down on him — a blow that floors him if
he does not get out of the way. Balls roll at 10 m/s (13 was too fast in play).

`ClipFighter` (`scripts/clip_fighter.gd`) is what the imp and the puglin share:
moves as clips, the body carried along each clip's measured path, blows by limb
(explicit moments and thresholds where the measure runs two swings together;
`blow_window`, `blow_min_speed` for smaller arms), the step in under a blow, and
walking picked by direction and retimed to the stride at the drawn size.


## The lands round the core (the v4 map in the game)

The world is 600 × 890 m (x −300…300, z −470…420): the old level in its middle,
untouched, and the five lands of the v4 map round it — the west's golden fields
and vineyards, the northern upland with its tarn and ruined fortress, Mamberi's
misty spruce wood, Ochopintre's autumn beeches beyond the Black River, the devs'
mountains with the glacier lake and the ravine. The map is drawn and baked
outside the game (`vepxis-art/map/v4`: `design.py` → `raster.py` →
`export_game.py`), which writes `assets/world/lands/`: the height of every metre,
the water's level and which way it runs, twelve cover layers, each land's green,
the grass clumps, the lists of trees, stones and flowers, and all of
`world_v4.json` (regions with their routes, camps, arenas and moods; landmarks,
settlements, fires, zones, the city). Change the map there and export again;
nothing of it is worked out in the game.

- **Ground** (`Lands`, `scripts/lands.gd`). Chunks of one flat grid lifted in the
  shader from a float texture of the heights (`shaders/lands_ground.gdshader`):
  a metre a cell near, five metres far, skirts so the two never crack; the whole
  build is ~0.3 s. The cover is the map's twelve layers (grass, needles, beech
  litter, heather, rock, scree, snow, dirt, gravel, mud, crops, flowers); grass
  is painted as the core's house style paints it, in each land's own green. Four
  `HeightMapShape3D`s round the core are the floor. Where the lands meet the
  core the lands' edge is eased onto the core's ground (`_meet_the_core`), so
  there is no step. `Terrain.height_at` answers from the lands outside its square.
- **Water.** One surface over every wet metre at its own level — down the rivers
  and down the four falls as sheets — flowing along the river (two phases of the
  ripple maps slid along a flow map), turquoise where glacial, foam on the falls
  and rapids, the sky at a grazing look (`shaders/lands_water.gdshader`). The
  bay's plane is cut at the rim.
- **No swimming.** Deeper than 1.3 m, the floor rises 2.5 m out of the water: a
  deep river holds a body on its bank. It is crossed at the fords (their bed
  brought up to a wade), on the stepping stones and over the bridges.
- **Crossings** (`Lands.crossings`). The map says where a bridge is, not how long:
  each is worked out at load as the shortest way over the water near it, bank to
  bank, and the barrier is let through along it. `LandsPlaces` builds them: plank
  bridges with rails, the log bridge, the arched stone bridge, the rope bridge,
  stepping stones, the ferry's jetty.
- **The rim.** Walls round it, and land running on out under the mountains
  (`Beyond`); the old four walls round the core are gone and the `Horizon`'s rings
  stand out past the new rim.
- **Roads** (`Paths.roads`): each land's way from its gate to its boss, the spurs
  to its villages and the city's streets, drawn like the tracks and kept clear of
  trees, not flattened into the core.
- **Trees, stones, flowers** (`Forest.plant`): 3153 trees where the map put them
  (spruce as the giant firs and cedars, pine, oak, beech in autumn gold, red
  maple, yellow birch, dark alder, pale willow, orchard trees, juniper, the great
  plane, bushes; a model can carry its own colour), 904 stones, 2400 flowers and
  sunflowers, drawn and collided as the grown wood is; nothing on a bridge's line.
  21 000 grass clumps on a `GrassField` of the lands' own.
- **Places** (`LandsPlaces`, `scripts/lands_places.gd`), from the kit and from
  boxes, as the greybox was — stand-ins where the map put them, at the size it
  asked: five villages (houses round a square, fences, stone walls or towers by
  style), the camps (fire, tents, logs; a palisade round the orcs'), the rest
  fire before each boss with a cairn and a banner, a ring of standing stones
  round each boss arena, two tall stones at each land's gate, and the landmarks —
  kurgans, idol, wayside cross, hill-fort, stone circles and pillars, cairns,
  ruined towers and the northern fortress, the orc lookout, quarry, the devs' cave,
  the glacier, rock gate and crag, falls' spray, the fallen oak, the giant beeches,
  maple, hollow oak and plane, light shafts, the glowing mushroom ring, the fern
  ravine, shrines, huts, the watermill, ruined and burnt farms, treehouses,
  haystacks.
- **Gulansharo**, the city on the bay's north shore (in the core, from the map):
  its wall with crenels, eleven towers, three gates, streets, the market with its
  stalls, twelve named houses each with its sign (the merchants' guild, temple,
  smith, armourer, bowyer, apothecary, tailor, inn, store, stables, barracks,
  harbour house), the moles and lighthouse, three ships. **The land gate is shut**
  until the orcs in the mist village are dead (`LandsPlaces.open_land_gate`).
- **The orcs' den.** The mist village is the orcs' now — two with great axes in
  its yard, four on guard (`World.CAMPS`, `orc_guard`); they no longer wade in
  the bay. **Two Arkdevas**, each in its own lair cut into the wood: the web
  ravine (−104, −118) and the marsh lair (−80, −216); the old glade at (5, −50)
  is wood again.
- **Travelling fires** (`Waystones`): 21 rings of stones round a fire, in every
  village, at the ways and before every boss. F lights a cold one (it stays
  lit); at a lit one F opens the list of the other lit fires, ↑ ↓ pick, F goes.
  The village square's is lit from the start.
- **Each land's air** (`LandsMood`): the map's mood for each land mixed by how
  much of it lies round the hero and eased in — the fog's colour and thickness,
  the sun's height, bearing and colour — on top of whatever `Looks` and the
  graphics setting put there (anything they write is the new base; the core is
  the base itself). And what drifts in the air: dust in the west, motes in the
  north, mist in Mamberi, falling leaves in Ochopintre, snow in the devs' land.
- **The spawn** is the village square (62, 44).

`tests/lands_test.gd`: the lands are there and meet the core without a step, the
floor is the drawn ground, a hero walks out of the core, a deep river holds him
but every ford and bridge takes him over, the fires light and carry him, the
city's gate is shut until opened, the air knows the lands.


## The village dressed: a market, a smithy, gardens and a cobbled square

The village the hero starts in was huts on bare grass. It has a life now
(`scripts/village_props.gd`, [VillageProps], put up by `World._dress_village`):

* **The square is cobbled** round the spawn, between the stalls — one flat sheet
  (`shaders/village_plaza.gdshader`) with Poly Haven's *Cobblestone Large 01*
  (1k, 4 m a tile), its edge following the stones rather than a straight line,
  cut in the opaque pass. Grass keeps off it (`VillageProps.in_plaza` in
  `Meadows._site`).
* **A market** on both sides of the square: stalls and a stall-cart with crates
  of apples and carrots, barrels, sacks, a vase and a pot, a table with stools.
* **A smithy and a training yard** in front of the barracks: anvil on its log,
  weapon stand, workbench, cauldron, two straw dummies.
* **Tables with stools** in front of the town centre and a barrel rack.
* **The windmill**: a wagon and flour sacks; **the gate**: a wagon come in on
  the track, crates off it, a banner on each gate tower.
* **At every hut's door** a bench, barrels, a bucket, crates or a vase; bushes
  at its corners, flowers by the door, a fern and stepping stones out to the
  street. Bushes and flowers along the town centre, the gate and the fence
  corners.

167 props from three free Quaternius kits (Fantasy Props, Medieval Village,
Stylized Nature — all CC0; `assets/village/SOURCES.txt`), cut down in
`vepxis-art/village/village_props.blend` (the heaviest decimated, one material
per texture sheet, textures at 1024) into one `assets/village/village_props.glb`.

**What it costs.** Every placed prop is baked at load into one mesh per
material for each 48 m cell (`SurfaceTool.append_from`), so 167 props are some
seventy meshes, most of them culled from any one view; only the big things cast a shadow (`SHADOWED`: stalls, wagons,
tables, bushes), small ones are not drawn beyond 70 m and the rest beyond
110 m. Solid ones (stalls, barrels, crates, tables, wagons, dummies...) get a
box each in one `StaticBody3D`. Textures are VRAM-compressed with mipmaps
(normal maps in normal-map mode). Measured in the village, four views, props
on and off, interleaved runs on the M1:

| | props off | props on |
|---|---|---|
| draw calls (High) | 3250–7520 | +60 to +130 (about 2%) |
| primitives (High) | 0.75–1.44 M | +0.2 M (134 k triangles, drawn in the prepass and main pass) |
| frame time | — | no difference above the run-to-run noise (±5 ms on this machine) |
| video memory | 943 MB | 970 MB (+27) |
| load | — | +90 ms |

The layout is data at the top of the script (`PLACED`, `GREENERY`, and per hut
`AT_DOOR` / `GREEN` mirrored for the north row), each model's front facing +z at
yaw 0. `VillageProps.enabled = false` leaves them out (for measuring).
`tests/village_props_test.gd`: every model in the layout is in the kit, few
meshes, nothing solid on the villagers' street, the spawn, the gate, a door or a
quest giver, the square cobbled and grass-free.


## The ground of the core: ferns in the woods, grass out in the open

**The open ground greener.** The low sward (the short clumps of the new look)
grew only round the meadows' clumps; it now grows over the open ground too
(`Meadows._open_sward`): in broad patches — most of the open, gaps where the
earth shows — everywhere that is not wood (a clearing cut in one counts as
open), water, a track, the square's cobbles or, in the village, under
something standing. A grid 2.1 m fine, two clumps a point, 12 000 clumps
(`open_sward_spacing`, `open_sward_budget`; the sward's budget went from 32 000
to 72 000 to hold both). The forest floor lays its grassy ground under the
sward as well (`Looks._build_mask` adds it to the mask's green), so a patch of
it stands on grass rather than earth; a lone tree's smudge of leaves is a
little lighter (0.45 a trunk, was 0.55), so the parkland between the woods
reads as grass with leaves under the trees rather than as bare litter. The
shader lets a little more of the open ground be grassy (`open_grass` 0.95,
the patches' edge 0.14–0.44).

**What lies on the floor** (`scripts/ground_cover.gd`, [GroundCover], laid by
`World._ready` once the wood has grown): knots of ferns and a broad-leaved plant
on the floor of the wolves' firs and the great wood, mushrooms in rings and
knots, the odd mossy stone and small stump, fallen logs in the great wood
only; in the open, stones lying in the fields with a smaller one or two by
them, low leaves, pebbles at the edges of the tracks, and at the woods' edges
small patches of bellflowers and violets (still no daisies). About 3 800
things, planted through `Forest.plant` so they are drawn as the wood is (a
multimesh per model per chunk, graded by `Looks` with the wood, no shadows,
gone past 46 m on the floor and 70 m in the open). Only the 30 logs are solid,
and there are none on the wolves' hill: it stays open ground to fight on. The
ferns and plants are the Stylized Nature kit's (CC0), saved out of
`village_props.glb` as meshes in `assets/village/cover/`, their spring lime
taken down to the wood's deep green; the rest is the wood's own kit. The same
on every peer (a fixed seed over a fixed grid).

Tried and dropped: roots at every trunk's foot, twigs, the kit's grass tufts —
in the dark grade the roots and twigs read as black spikes and the tufts as
bright green sprouts.

**What it costs** — `perf_tour` with two more places (the wolves' wood, the
south fields), everything on and off (`GroundCover.enabled = false`, no open
sward), two runs of each, interleaved, on the M1: draw calls +0 to +130 at a
place (the most at the orc camp and in the wolves' wood), primitives within
±5%, frame times and the physics tick inside the run-to-run noise (which on
this machine was ±10 ms at High), video memory about the same (1051–1082 MB
off, 1082 on), load +0.4 s (GroundCover 0.25–0.5 s, the open sward ~0.15 s).
`tests/ground_cover_test.gd`: it grows, every instance drawn, no shadows and a
draw distance on the litter, nothing in the village, no log on the wolves'
hill, the open sward there and off the square and the tracks' middles.


## Tariel's string, after Dragonwilds

The user filmed the combos he wanted from *RuneScape: Dragonwilds* (two short
phone videos, one blade and two): every cut from a different side, a step in
under each, about half a second a cut, a wide pale crescent behind the blade,
a whole turn of the body to end the string, and a leap brought down into the
ground. Tariel's string is that now (`SkinnedRig._configure`):

| press | clip | what it is |
| --- | --- | --- |
| 1 | `TR_Axe_R2L` | a hard cut from his right to his left, stepping into it |
| 2 | `TR_Inward` | the backhand, low and in |
| 3 | `TR_Axe_Spin_A` | a sweep up out of a crouch |
| 4 | `TR_Axe_Rising` | the finisher: a whole turn low on his feet, the blade coming round and up with him; worth 1.6 |
| shield up + attack | `TR_GS_JumpSlam` | the heavy blow: a leap, the sword brought down two-handed into the ground, carried to what it is thrown at |

The first finisher was the great sword's running spin (`TR_GS_RunSpin`, still in
the glb): with two hands on the hilt through his shield and a lean back it
read as a man falling round, and two more things made it worse — a clip that
carries him moved the body, so the run was laid under his legs
(`swing_strides`), and the waist was bent back toward the target all through
the turn (`StrikeAim`). Neither happens now under a clip that carries him or
a cut of the string that does.

Seven clips from Mixamo (X Bot, retargeted onto `tariel_rig` with
`retarget_mixamo.py`, in `tariel.blend`; the FBX in `vepxis-art/mixamo_tariel/`),
five of them used. Each cut is played from a part of its clip (`flurry_part`),
~0.5 s at `swing_rate`; the string starts over after 1.1 s without a click.
The windows were measured in Blender from the sword's tip: past 55% of its top
speed it cuts (`cut_window`), past 30% the arc is drawn (`trail_window`, new)
— so the crescent covers the whole sweep while only the fast part of it hurts.

**The heavy blow out of the guard.** A hero with a shield has no second
attack button (the block button is his guard), so `Player._guard_heavy()`
throws his heavy blow when attack is pressed *while the shield is up*; the
shield comes down for as long as the blow lasts. A press during a swing with
the shield held is buffered as a heavy one. The slam's spec has a `slam`
share: when the clip reaches it the rig emits `slammed(at, heft)` once, and
`Player._on_slammed` throws up dust (`DustRing`), a small eruption and a wave
of broken ground running on the way he faces (`GroundFx`), the hard thud and
a camera shake — on every peer, since every peer plays the swing. The wave is
a look only: what the slam hurts is still what its blade passes through.

**The arc** (`BladeArc`) has a second look, `smear` (in `blade_arc.gdshader`):
where the orc's axe and the wolf's claws leave a glowing hairline, the heroes'
blades leave what the video's do — a broad pale sheet from the hilt to past
the tip, brushed with fine streaks along the swing, crisp at the edge the tip
swept, fraying at its far end and going to a grey-blue smoke as it ages (0.26
s). A spin draws a whole ring. Properties set after the arc is made are only
pushed to the shader by `restyle()` (the first cut of this set its style
after `_ready` and the shader never saw it). The assassin's rings are drawn
wider than his short knives (`tip_overshoot` 0.6), and his string now ends in
the same whirl as Tariel's (`DG_Whirl`, the axe's turn retargeted onto
`dagger_rig`, `tools/dg11_export.py`); the blow down to the ground it replaced
is still among his heavy ones.

The arc is styled per hero from `arc_style` (life,
intensity, sheet, taper) and brightened, widened and lengthened by
`arc_heavy_boost` on any blow worth more than 1.2 of a cut (the finisher, the
heavy blows). The assassin's two knives use it too, a little finer.

Checked with `_shots_tmp/tariel_look.gd` (the string and the slam at a
puglin, filmed from the side): four cuts in ~2.6 s, an arc on each, the slam
landing ~3 m on with its dust and wave.


## The assassin made real

The user asked for the assassin out of boxes: the old one is a figure of
rigid boxes, each on one bone, so every joint bends like a hinge between two
bricks — it moves in pieces. A first try lofted a body by hand
(`tools/dg12_body.py`) and was rightly thrown out: it looked worse than the
boxes. What he wears now is professional work: **Quaternius' Ranger**
(*Modular Character Outfits – Fantasy*, CC0) with the head, eyes, brows and
hair of his *Universal Base Characters* (CC0), both in `vepxis-art/new-persons`,
fitted onto `dagger_rig` by `vepxis-art/tools/dg14_ranger.py`:

- The Ranger keeps his own shape. `dagger_rig` is a box skeleton — hips 14 cm
  apart, a straight spine, a 5 cm neck — and laying the Ranger's bones onto it
  (the first fit, `dg13`) spread his legs wide and bent his head down. Now
  only the arms are laid onto `dagger_rig`'s (each bone's head on its
  partner's, stretched to the next, so the knives sit where its hands are);
  body, legs, neck and head stay as Quaternius made them, at a scale of 0.95
  where the two skeletons' joints lie within a few cm of each other. The
  weights are renamed onto `dagger_rig` (`spine_02` → `spine_01`, `spine_03`
  → `spine_02`, `Head` → `head`, every finger → its hand), so the one
  animation set drives every look.
- Filled out (`THICK`): Quaternius drew him slight, so each bone's flesh is
  widened round its own length — the chest 12–14 %, the arms 26–34 % (they
  were a boy's under a man's legs), the legs barely (2–4 %) — without his
  growing taller or a joint moving.
- The clips have no fingers, so the hands are baked into fists, and the fist
  is a real one now: every finger closed the same way (the left hand's were
  bent backwards before), the thumb laid over the index finger's middle
  joint (found by search in Blender), and the knife's grip put through the
  ring the fingers draw, cut to a hand's width, the guard against the index
  finger.
- Out of the green, which is Avtandil's: the Ranger's own painting recoloured
  by `vepxis-art/tools/dg17_recolour.py` (greens and browns moved apart, the
  shading kept) — charcoal cloth and oxblood leather for THE BLADE, crimson
  cloth and near-black leather for THE SHADE; textures cut to 2k in
  `new-persons/mco_2k`.
- A knife in each fist, Quaternius' *Medieval Weapons* dagger (CC0), lying
  forward out of the thumb's side, in dark oiled steel with a bright honed
  edge, a dark bronze guard and a leather-wrapped grip.

Two looks, picked on the hero select (`faces`), both whole figures with a
cloak of cloth (`whole_capes`), and neither shows a face: **THE BLADE**, the
hood up and nothing in it but shadow, chestnut hair falling out of it at the
sides; **THE SHADE**, the hood off, long chestnut hair round a face wrapped
smooth in black cloth, a black cloak with a crimson hem. The one of boxes
stays as **AS HE WAS**, with the outfits in the bag. `rogue_rigged.glb` is
27 MB with them (it was 10).

### Two knives, not a sword and a shield

His string began with the one-handed sword's cuts, whose left hand is tucked
to the chest as if it held a shield: only the right knife moved, and a man
with two knives flailing one of them looked aimless. It is a knife-fighter's
string now, both hands at work in every blow: both knives thrown out wide
(`DG_Slash_Out`), both brought back in across him (`DG_Slash_In`), then
Mixamo's dual-blade combo cut into its three blows — left then right, both at
once, both again the other way (`DG_Dual_A/B/C`, copies of `DG_Dual_Combo`,
each blow found from the hands' speed in Blender) — and the whirl to end it.
Each has its cut and its trail window where both hands are fastest.

## Avtandil in the green

Avtandil wears the same outfit (`vepxis-art/tools/dg16_avtandil.py`): the
Ranger fitted onto `avtandil_rig` the same way, with his own bow and quiver
lifted off his old ranger's outfit. His rig is a bigger man than the
assassin's (head at 1.97 m, not 1.8), so the fit is done with the rig shrunk
to the assassin's size (every measure holds) and the result grown back onto
it. His arms are drawn in by a few cm so the left fist closes exactly on the
bow's grip — the bow cannot move, its string and limbs are the
`BowModifier`'s bones. Three looks on the hero select: **THE RANGER** (hood
up, only shadow in it), **THE HUNTER** (hood off, long hair, the face
wrapped), and **AS HE WAS**, in his two old outfits. `avtandil_rigged.glb` is
23 MB with them (it was 5).

**The knife was the wrong way up.** Both knives stood up out of the back of
the fist in the T. Every Mixamo blow is made for a blade out of the thumb's
side, lying forward in the T as Tariel's sword does, so as the wrist turned
to cut the knife turned over into a reverse grip — and the cut in the air
with it. All the looks hold it forward now (the old outfits' knife turned 90°
on the fist in Blender; `blade_rest_dir` forward). The second knife draws its
ring too (`off_hand_whole_only`) but does not cut. His blows are eased into
one another over 0.14 s (`action_blend`).

**Swinging on the run.** The first cut out of a run kept the whole run under
it, and the run's legs were laid under a body that was swinging and turning
to its target: legs thrashing. Now that run is eased down to the swing's pace
over 0.3 s (`Player.free_swing_ease`) — a lunge, not a glide — and the run is
laid under a swing only while he is really going somewhere
(`SkinnedRig.swing_stride_from`, 1.6 m/s); at a swing's own pace the clip's
feet are his. For Tariel too.

Not changed: while he coats his blade (`DG_Poison_Coat`, made for the old
empty left hand) the left knife stays in that hand.


## Tariel the warrior in the iron helm

A third look for Tariel on the hero select, **THE WARRIOR**: leather and a
scaled coat, an iron helm with his face in its shadow, his own copper-red
sword and no shield. `shieldless_faces` hides both shields and
`own_sword_faces` hides Tariel's sword while he is worn. The model is
".Fuse Warrior" by Leonardo Carvalho (Sketchfab, CC BY 4.0). The credit is in
`assets/tariel_rigged/SOURCES.txt` and must stay with the game.

It is a real rigged character: a Mixamo skeleton with fingers, with the
helmet, sword and shield as meshes of their own. So nothing is weighted by
us. `vepxis-art/tools/fw_fit.py` poses its skeleton onto `tariel_rig`:

- The arms and legs are laid on (`COPY_LOCATION` + `STRETCH_TO`).
- The spine, neck and head are only turned, to lean as the rig does. The feet
  keep their own lie.
- The fingers close as his own clip holds them.

Every mesh is baked in that pose and its weights are renamed onto
`tariel_rig`'s bones: `Hips` → `pelvis`, `Spine` → `spine_01`,
`Spine1/2` → `spine_02`, every finger → its hand, and so on. His sword is
turned about its grip to lie forward out of the fist, as the clips expect.
`tools/fw_export.py` writes the glb.

A first try with an AI-made model (Kingslayer, one fused surface with no
skeleton, weighted by bone heat: `tools/ks_fit.py`) bent like rubber and was
thrown out.


## Tariel as the squire and the knight, on a skeleton of their own

Two more looks for Tariel on the hero select, **THE SQUIRE** (bearded,
bareheaded, in the starter's leather vest and breeches) and **THE KNIGHT**
(the plate set and its helm, the hair under it). Both are Blink's low poly
man, "FREE Low Poly Human – RPG Character" (Unity Asset Store, Standard
EULA; `assets/tariel_blink/SOURCES.txt`). They carry Tariel's sword and his
round or tower shield, whichever he holds.

**This figure is not fitted to `tariel_rig`.** The warrior and the wanderer
were posed onto the rig and their weights renamed onto its bones, so they
took the rig's proportions. This model keeps its own skeleton (Advanced
Skeleton names: `Root_M`, `Shoulder_R`…), its own proportions (6 cm
taller, shoulders further back) and its own weights. It is a second model,
`assets/tariel_blink/tariel_blink.glb`, loaded beside Tariel's
(`SkinnedRig.figures`, see below). Its skeleton is moved by his:

- `FigureFollower` (`scripts/figure_follower.gd`) waits for
  `skeleton_updated` on the rig's skeleton, when the pose is final (clip,
  stride, strike aim, every modifier).
- It then turns every mapped bone of the figure in the world as its partner
  has turned from its rest: `global = (pose · rest⁻¹) · figure_rest`.
  The map is `SkinnedRig.figure_map` (`Root_M` ← `pelvis`, `Chest_M` ←
  `spine_02`, `Shoulder_R` ← `upperarm_r`, `Knee_L` ← `calf_l`, …).
- Bones not in the map ride their parent as they rest (`Spine2_M`, the
  fingers, the face).
- The hips are also moved, by the rig's hips' travel × the figure's hip
  height ÷ the rig's, so his longer legs still reach the ground.

This needs both rests to point the limbs the same way. `vepxis-art/tools/bl_blink.py` turns the
model's rest (arms, forearms, thighs, calves, hands) onto the rig's bone
directions, closes the fingers into fists and applies that as the rest. The
mesh is only turned about its own joints by its own weights. The script
also adds `weapon_r` (under `Wrist_R`) and `shield_l` (under `Elbow_L`) with
the rig's rest orientation, set off from the figure's joints as the rig's are
from its own. The grip is moved out into the fist and the shield down onto the
slimmer arm (`NUDGE`). The rig's sword and shields are copied onto them.

While one of these looks is on:

- The figure shows. It is in `whole_faces`, `shieldless_faces` and
  `own_sword_faces`, so none of the rig's meshes do.
- `figure_faces` says which figure a face is worn on and which of its meshes
  show: a list of name prefixes shown and hidden.
- The blade's markers are moved onto a `BoneAttachment3D` on the figure's
  `weapon_r`, so the cut in the air leaves his sword. The sparks and sounds
  follow the same mount.

Hits and the camera still go by the rig's skeleton, whose hand is up to 20 cm
from his. The feet land within 2–5 cm of the rig's.

The package came through Unity (Hub + an empty project in `~/UnityBlink`,
Package Manager → My Assets → Download). The `.unitypackage` is a tar of
GUID folders (`asset` + `pathname`) and is unpacked without Unity
(`vepxis-art/blink/pkg`). Its 33 own clips on its own skeleton are not used.


## Synty's Sidekick: four more looks on a third skeleton

Four more looks for Tariel on the hero select, from Synty's "Sidekick Modular
Characters" FREE Starter Pack (Unity Asset Store;
`assets/tariel_sidekick/SOURCES.txt`):

- **THE PALADIN**: Synty's Starter_01, the plumed helm, the knight's plate and
  the wolf pelt on his back.
- **THE HOODED**: Starter_03, the hood, and the plate mixed with the other
  kit's pieces.
- **THE SWORN**: a mix of the same parts. The knight's plate without helm,
  mask or pelt, one of the human heads with hair and a full beard, and a
  heavier body.
- **THE IRON KNIGHT**: the helmed knight in Starter_03's steel-and-blue colour
  map, more muscled.

Every Sidekick part (157 of them) carries the same 88-bone skeleton. It uses
the mannequin's names, as `tariel_rig` does, plus fingers, twist bones and
attach points. A look is a list of parts (Synty's `.sk` recipe or our own),
a colour map and the body blend shapes (`defaultBuff`, `defaultHeavy`,
`defaultSkinny`, `masculineFeminine`, from the recipe's `MuscleValue`,
`BodySizeValue` and `BodyTypeValue`).

`vepxis-art/tools/sk_build.py`:

- Imports each part once, bakes the shapes at each look's values and joins
  each look into one mesh (`sk_<look>`) on the one armature.
- Turns the rest onto the rig's limbs and closes the fists, as `bl_blink.py`
  does.
- Adds `weapon_r` / `shield_l` for Tariel's sword and shields.

The skeleton stays Sidekick's own.

`SkinnedRig.figures` now holds any number of such models by id, each with
its scene, mesh prefix, bone map and hips. Blink's is `blink`, Sidekick's is
`sidekick`: its `spine_03` follows the rig's `spine_02`, and `spine_02`
rides `spine_01`. `figure_faces[face].figure` says which one a face wears.
Every figure is loaded once, hidden, with its own `FigureFollower` and its
own sword-hand mount. The one worn shows (`_figure`), and the blade's cut
moves to its hand.

The pack came through Unity, the same way as Blink's (Package Manager → My
Assets → Download). Its `.unitypackage` is unpacked without Unity into
`vepxis-art/sidekick/pkg`.


## Figures for the assassin and Avtandil, with their own arms

These figures run on the same machinery as Tariel's, and every hero keeps his
own looks:

- **The assassin** gets two Synty Sidekick looks.
  - **THE FOX MASK**: the fox mask and its hood, the wanderer's coat in
    Starter_02's reds, a sword at the hip for show.
  - **THE HOOD**: the deep hood and a cloth over the mouth, the same coat in
    dark steel and blue.
- **Avtandil** gets two looks.
  - **THE HUNTSMAN**: Blink's man in the starter's leathers.
  - **THE FOX HUNTER**: Sidekick in the brown hood, bearded, with two black
    foxes on his shoulders.

Each hero's arms come from his own model (`vepxis-art/tools/fig_hero.py`).
Both builders take the hero's joints (to turn the figure's rest onto his limbs)
and his arm bones off his glb. `VX_HERO=tariel|rogue|avtandil` picks the hero
for `tools/bl_blink.py` and `tools/sk_build.py`.

- **Knives:** cut out of the assassin's model by material and side (the left
  one is weighted to the hand), each put on the figure's added
  `weapon_r` / `weapon_l`.
- **Bow:** cut out of Avtandil's by its `bow_*` bones, whole chain and all.
  `draw_r` comes along too.
- **Offsets:** each added bone is set off from the figure's joint as the
  hero's is from his. Only its head matters: its parts turn rigidly about it.

In the game:

- **The assassin's off-hand cut** (his left knife's ring) moves to a mount
  on the figure's `weapon_l`, as the main hand's does.
- **The bow's string and arrow** are placed from the figure's bow.
  `FigureFollower` emits `followed` once it has posed the figure.
  `SkinnedRig._on_figure_followed()` is a hook for that. The archer uses it
  to call `BowModifier.place_string_on(figure_skeleton)`, which reads the
  figure's own `bow_tip_u/l`, `draw_r` and `bow_l` by name.
- **Arms shown:** `<prefix>_arm_*` meshes always show on the worn figure, and
  the sword and shields follow `shield_kind` (`_show_figure_arms()`).
- **Bone maps:** `SkinnedRig.blink_map(extra)` and
  `SkinnedRig.sidekick_map(extra)` build a figure's map with the hero's arm
  bones added.

Sidekick parts can bring dynamic bones of their own (the pelt's `abac_dyn_*`,
the plume's `ahed_dyn_*`, hair and beards). They are added to the figure's
skeleton and ride their parents; left out, their vertices stretched.
`CIVL_10_26AHPB`, a long tail of cloth behind the hips that only Synty's
physics hangs down, is left out.

`tests/figures_test.gd` (headless) puts every figure look on every hero and
checks:

- the figure shows and the hero's meshes don't;
- the look and its arms show;
- the hands are within 40 cm;
- the cut comes off the figure's hands, both hands for the assassin;
- the string sits on the figure's bow tip;
- every figure is put away again for the hero's own look.


## The assassin's Sidekick looks hold one knife

Sidekick's men are made for one blade: the fox mask carries a single sword,
at his hip. So THE FOX MASK and THE HOOD hold one knife, in the right fist.
They fight with the one-handed string the assassin had before his two-knife
one:

1. `DG_Combo_1` and `DG_Combo_2`: Mixamo's one-handed sword combo, the left
   hand tucked to the chest.
2. `DG_Spin_Cut`: the spinning cut.
3. `DG_Backhand_Cut`: the backhand.
4. `DG_Axe_R2L`: the axe's cut from right to left.
5. `DG_Whirl`: the whirl to end it.

The two-knife heavy blow (`DG_Dual_Combo`) gives way to the one-handed
combo's last big blow (`DG_Finisher`). No ring is drawn off the empty hand.
THE BLADE, THE SHADE and AS HE WAS keep both knives and the two-knife string.

`SkinnedRig.face_moves` holds this, by face:

- `flurry`, `flurry_part` and `heavy` are laid over the rig's own moves.
  `_configure()` leaves those, and `_own_moves` keeps them.
- `off_hand: false` draws no ring off the off hand.
- `hide_arms` lists the figure's `arm_*` meshes the look doesn't carry.

`set_face()` applies them (`_apply_moves()`). `figures_test` checks that
every clip of such a string is in the model and that the hidden knife stays
hidden. `heroes_test` and `rogue_strike_test` expect the string and heavy
blow of whichever look is saved.

## The test arena, and creatures and bosses on skeletons of their own

**TEST ARENA** on the ride page (next to ALONE and WITH COMPANIONS) starts a
solo game on an empty floor (`scenes/world/test_arena.tscn`): the same
`World`, with `raise_camps = false`, so no camp is raised. `F1` shows the
board (`ArenaPanel`, `scripts/arena_panel.gd`):

- At the start, one of every kind already stands on the floor, facing the
  middle: the creatures on a ring 11 m round, the bosses on one 30 m round
  (`_populate`). With **Wait for my blow** on, none of them moves until the
  hero strikes it.
- **Creatures** and **Bosses**: every kind the game has is a button. Pressed,
  one is called up a few paces in front of the hero, facing him, with a patch
  of ground of its own there, so it fights at once.
- **Look**: the arrows step through the hero's looks on the spot (`set_face`,
  remembered as the menu's pick would be).
- **Heal**, **Hold still** (every creature stops thinking and walking) and
  **Clear**.
- **Wait for my blow** (on by default): a creature called up stays blind
  (`sight_range` 0) until the first blow that hurts it. Then it gets its sight
  back and turns on the hero.
- **Can't be hurt** (on by default): the hero is kept at full health.

New creatures and bosses, each on the skeleton it came with. No bone is
renamed or moved. `vepxis-art/tools/mon_build.py` builds each one:

- **Its own clips**, where it came with some: the minotaur (17), the centaur
  (20) and the four dragons (16 to 18 each).
- **Mixamo's clips**, where it did not: the frog marauder, the one-eyed ogre
  and the Knight of darkness. The demon borrows the minotaur's own clips: both
  skeletons use the mannequin's names, and a beast's stance suits its
  digitigrade legs. The clips are carried onto the creature's bones by where each
  bone points: the Mixamo T-pose is laid onto the creature's limbs first, so an
  A-posed arm swings the way the Mixamo arm does.

Every clip is made in place at 30 fps and named with the creature's prefix.
How far the hips travel in each clip goes to `<name>_clip_meta.json`. Out:
`assets/monsters/<name>/<name>.glb`.

| Scene | What | Clips |
|---|---|---|
| `frog.tscn` | frog marauder with an axe | Mixamo (orc axe set) |
| `demon.tscn` | horned demon with a sword | the minotaur's |
| `ogre.tscn` | one-eyed ogre, fists | Mixamo (mutant, brawl) |
| `minotaur.tscn` | boss, great axe | its own |
| `centaur.tscn` | boss, lance | its own |
| `dark_knight.tscn` | boss, the Knight of darkness with a great sword | Mixamo (sword and shield set) |
| `dragon_terror.tscn`, `dragon_nightmare.tscn`, `dragon_usurper.tscn`, `dragon_souleater.tscn` | bosses | their own |

`Brawler` (`scripts/brawler.gd`, a `ClipFighter`) reads the scene for:

- its attacks (clip, rate, the part of the clip played);
- the big attacks it saves for when the hero is further off;
- the bone it strikes with (`weapon_bone`, `weapon_tip`, `weapon_radius`);
- the bones whose speed marks the blow;
- its hit, death and roar clips.

`tools/make_brawlers.py` writes the ten scenes from one table.

`Monster.hips_bone` and `foot_bones` name the hips and feet of a skeleton that
isn't the mannequin's (`SkeletonAnim.hips_name` and `feet`).

`tests/arena_test.gd` checks the arena:

- no camp is raised;
- every entry is called up and stands on the floor;
- each creature, alone with the hero, has its clips and comes at him and swings;
- Hold still, Clear and the look arrows work.

## THE NINJA: the assassin on a skeleton made for it

BlenderKit's sci-fi ninja is a sixth look for the assassin, with his two
knives. The model came built for animating in Blender: its Mixamo bones hang
under control and helper bones. `vepxis-art/tools/bl_mixfig.py` (with
`clean_rig`) makes it a skeleton of its own, of the Mixamo bones alone, each
under its nearest Mixamo ancestor. The weights were the Mixamo bones' already.
Then it follows the assassin's skeleton like any figure
(`SkinnedRig.mixamo_map()`). Out: `assets/rogue_ninja/rogue_ninja.glb`.

## THE DARK KNIGHT: Tariel in the Knight of darkness

Anton Puzanov's Knight of darkness 2 (Unity Asset Store) is a tenth look for
Tariel, on its own mannequin-named skeleton, with his sword and shield. It is
built by `bl_mixfig.py` (`VX_HERO=tariel VX_FIG=darkknight`). Out:
`assets/tariel_darkknight/tariel_darkknight.glb`. The same knight also fights
as a boss (`dark_knight.tscn`).

## The elf: a second archer on the hero select

**THE ELF** is a fifth hero, beside Avtandil, who stays as he was. She is his
archer: his rig, his clips, his bow and his skills (`scenes/player/elf.tres`,
`SkinnedElfRig`). She is worn as **THE DARK ELF**: blend-swap's animated dark
elf on its mocap (CMU-named) skeleton, which follows his. Her own bow, arrow
and quiver are left out for his bow.

`bl_mixfig.py` (`shape: elf`) works her figure at rest, each change by a soft
falloff round a landmark taken off her own bones, so her clothes move with her:

- a much fuller bust (the dress pushed out a little further, so no skin
  shows through it);
- a narrow waist;
- wide, round hips;
- a slightly finer jaw;
- a smaller forehead: brow to crown pressed down by a quarter.

Her hair is silver-white. The painted lines of her skin map are half blurred,
and the whole skin is turned a dark elf's: slate with a blue-violet cast, its
shading kept (`skin_tinted`).

**Her weights over the hips and belly are made again** (`reweight_hips`). The
model came with the whole seat weighted to the lower back and none of it to the
thighs, so every stride pulled the thigh out of the buttock (spikes) and every
bend folded the belly along one line. Across that band each vertex is now
weighted by how near it is to the pelvis, the spine and the thigh on its side,
smoothed along the mesh and blended into the old weights at the band's edges.
Her skeleton stays her own (the blend's mocap skeleton), following Avtandil's.

**The bow sits in her hand**: the grip is set back into the palm (`nudge`) and
her fingers are closed round it (`grip`).

She has three outfits in the bag (Attire). Each is a whole body of the figure;
`SkinnedElfRig.set_garb` shows the one put on.

- **Sylvan Leathers**: the green she came in.
- **Shadow Weave**: the same cut dyed black-violet, with silver for gold
  (`noir_garb`, mesh `de_noir`).
- **Night Harness**: black leather straps on the bare skin (`harness_garb`,
  mesh `de_harness`). The bodice, kilt, belt and pouch are taken off. The
  sleeve, pauldron, collar, bracers and boots stay, dyed black and silver (the
  model has no skin under them). Every strap is cut out of her own skin between
  two planes, so it follows the body and keeps its weights:
  - triangle cups, with halter straps up to the collar;
  - a band under the bust and a strap down the middle;
  - a cross over the belly and a low belt;
  - thigh-high wraps, with crossed straps on the thighs;
  - a long glove on the bare arm.

  The briefs painted on the skin are turned black leather.

## THE NIGHT ELF: a realistic woman on her own skeleton

Two more looks for the elf, **THE NIGHT ELF** and **THE NIGHT ELF, BARE**, both
on **Anna Ipati (animated)** by Jungle Jim (Sketchfab, CC Attribution 4.0;
credit kept in `assets/avtandil_anna/SOURCES.txt`). She is a realistic
Character Creator woman, kept on her own Character Creator skeleton
(`CC_Base_*`), which follows Avtandil's like every figure. Her twist bones
ride their limbs.

`vepxis-art/tools/anna_prep.py` gets her ready:

- lighter: the face's 350 shape keys cleared, the hair cards decimated, the
  textures at 1024 (378k triangles down to 118k, 253 MB down to 31 MB);
- a dark elf: the skin slate blue-violet, the hair silver-white, the ears drawn
  up and back into points;
- the briefs cut down to a thong;
- her meshes grouped as `body`, `hair`, `bra` and `thong`, so a look can show
  or hide each one.

`bl_mixfig.py VX_FIG=anna` builds the figure (`assets/avtandil_anna`):

- the bones' numbered suffixes taken off;
- the limbs' main bones, which the export left at the origin, put back at their
  joints (`fix_zero_bones`);
- Avtandil's bow in her closed left hand.

THE NIGHT ELF shows everything. THE NIGHT ELF, BARE leaves off the bra.

The thong: its front is a smaller triangle cut from her briefs. The string round
the hips and the strip behind are cut out of her own skin between planes, so
their edges are clean.

`FigureFollower` takes two refinements for her (figure spec `damp`, `mids`):

- She stands taller than his hunter's crouch: her hips and spine turn only
  about half the way his do.
- Her middle spine bone, which he has no partner for, turns halfway between
  his two. Her waist bends instead of creasing, and her chest no longer swings
  off to one side.

### Three outfits and a softer roll

Three more looks on the same body, chosen with the LOOK arrows like the others:
**THE NIGHT ELF: HARNESS** (leather cups on halters, a strapped harness over the
belly, a choker, thigh-high boots with straps, long gloves), **THE NIGHT ELF:
CORSET** (a laced leather corset with silver trim, knee-high boots, bracers) and
**THE NIGHT ELF: SILK** (sheer cups, garter belt, stockings with straps, long
gloves). All three keep the thong. They are cut straight from the skin in
`vepxis-art/tools/anna_prep.py` (`VX_FITS`), so they carry the body's own weights
and bend with it; the cups are aimed from the breast bones. Each is a mesh of its
own in the glb (`an_fit_harness`, `an_fit_corset`, `an_fit_garter`) and
`figure_faces` shows the right one.

The dodge roll is no longer the elf's own dive: `SkinnedElfRig.borrow_clip()`
takes Tariel's tucked `Roll_Quick_To_Run`, converts every rotation onto the elf's
skeleton (q_dst = q_src * r_src^-1 * r_dst) and scales the pelvis path by the hip
heights. The torso damping that keeps her run upright now eases off between 35 and
80 degrees of bend (`FigureFollower._damp_at`), so the tuck curls fully instead of
diving flat.

### Three more outfits, and her colours on the hero select

Three more looks: **THE NIGHT ELF: GOLD** (gold armour: cups, a V over the
thong, fine chains on the hips, armlets, bracers and greaves over short boots),
**THE NIGHT ELF: CATSUIT** (glossy from the throat to the toes, a plunge to below
the bust and the back open to the waist, cut in pieces along straight planes so
the edges stay clean) and **THE NIGHT ELF: HUNTRESS** (a leather tube top, hot
pants with a silver belt, knee boots with silver cuffs, bracers, a strap round
one thigh).

Under LOOK on the hero select there is now a **COLOUR** row: BLACK, CRIMSON,
VIOLET, EMERALD, MIDNIGHT, WHITE or GOLD. It dyes her leather and silk, her bra
and thong too (`SkinnedElfRig.set_tint`, `TINTS`), by a dyed copy of each
material set as the surface's override. The gold armour takes the colour too but
stays metal (white turns it silver). The silver trim and her skin are never dyed.
The pick is
remembered (`Game.tint`/`set_tint`, the `[tint]` section of the settings) and
reaches the other players through `Player.net_tint`.

### THE DARK ELF retired; her leathers on THE NIGHT ELF

The old dark elf (blend-swap's model, its own mocap skeleton) is gone from the
game: her figure, her looks and her three outfits in the bag. What stays is
her clothing. **THE NIGHT ELF: SYLVAN**, now the elf's first look, wears her
green bodice with one sleeve and the carved pauldron, the leaf kilt with its
belt and pouch, the thigh wrap, and the boots and bracers trimmed in gold.
`anna_prep.py` (fit_sylvan) does the transfer:

1. It takes the cloth faces off her model.
2. It moves each vertex by the bones that moved it on her skeleton onto the
   same bones of this one. A limb is turned from her joint to this one's and
   stretched to its length; the body is scaled by height. Her mocap foot
   joint sits at the sole, so her ankle is placed at the same share of the
   way from knee to floor as here.
3. It pushes the cloth 11 mm out of the skin where it sinks in.
4. It turns every face to look away from the skin, because her cloth was
   two-sided.
5. It weights the cloth from the skin under it.

Of all the looks, only two stay in the game: **SYLVAN** and **HUNTRESS**. The
plain, bare, harness, corset, silk, gold and catsuit looks were dropped at the
user's pick. `anna_prep.py` still knows how to cut the dropped outfits, but it
throws them away unless they are named in `VX_FIT_KEEP` (by default
`fit_huntress,fit_sylvan`). All the clothes are matte now: the leather has
roughness 0.85 and the metal 0.6.

The COLOUR row dyes it as well. Each colour has its own picture
(`assets/avtandil_anna/sylvan_t<n>.jpg`): the green dyed, the gold kept
(silver for WHITE), the brown leather left brown. EMERALD is the leathers
as they were.

## Smaug, to look at only

A fan model of a dragon from free3d (`free3d.com/dragon`) is built by
`mon_build.py smaug_preview` into `assets/monsters/smaug_preview/`. It is
called up in the arena as **Smaug (look only)**: it stands, with no clips, and
does not fight. It is a fan model of a copyrighted character, so its model and
scene are kept out of the history (`.gitignore`). The arena skips the entry
where the scene isn't there.

## THE WARRIOR: two hands on a great sword, a hero of his own

THE DARK KNIGHT is no longer one of Tariel's looks. Its sword was never really
in its hand: it followed Tariel's skeleton, and his sword and grip, bone by
bone. The knight is now **THE WARRIOR**, a sixth hero on the hero select
(`scenes/player/warrior.tres`, `SkinnedWarriorRig`), with his own skeleton,
his own clips, a great sword in both hands and no shield.

**The model** (`vepxis-art/tools/wr_build.py`, out: `assets/warrior/warrior.glb`):

- Anton Puzanov's Knight of darkness 2 (Unity Asset Store), skin 2: red cloak
  and gold boots. The boss in the arena wears skin 1.
- He keeps the skeleton he came with (the mannequin's names, 1.95 m). Added:
  a `root` bone for the root-motion track, and `weapon_r` in the right fist.
- His finger bones did not lie in his gloves' fingers (the gloves were bound in
  another pose). Each is laid along the part of the glove weighted to it. Both
  fists are then closed round a grip, and the mesh is baked into that as the
  new rest.
- His own sword is the great sword: scaled up 1.12, with its grip stretched to
  0.26 m (two fists), the right fist just under the guard.

**The grip.** In every clip, per frame:

1. The blade runs the way the Mixamo man's two palms run on his grip (right
   palm minus left).
2. The right hand is turned so its grip runs that way.
3. The left fist is brought onto the hilt, 0.1 to 0.2 m under the right, by a
   two-bone solve with shortest arcs only (after `great_axe.py`).

Where the Mixamo man lets go with his left hand (the palms more than 0.46 m
apart), the left hand is left free; between 0.26 and 0.46 m it is eased.

**The clips.** Mixamo's Great Sword pack, 28 clips (`WR_*`), carried by
`mon_build.carry`. `GA_*` came from `mixamo_orc/`; the rest were downloaded into
`vepxis-art/mixamo_warrior/`:

- walk, run, backwards and strafes;
- jump, crouch, hits;
- the combo, downward, low, power and high-spin slashes;
- the jump attack, the slide attack, a kick and the hilt;
- a death onto one knee and a roll (not from the pack: the sword stays in the
  right hand).

Cut windows, trails and ground speeds were measured in Blender
(`tools/wr_measure.py`, off the blade tip and the planted foot).

**How he fights:**

- **Attack** is his string. The combo's three blows are one clip under three
  names (`WR_Combo_A/B/C`, added at load), and the high spin ends it. Each blow
  is 0.5 s at the least and the last 0.75 s; `swing_rate` is 1.25.
- **The other button** (no shield to raise) throws his heavy blows, picked by
  where the string is (`Player._heavy_blow`):
  - out of nothing: the power slash;
  - early in the string: the leap and the blade into the ground (it shakes);
  - later: the cut down into the ground;
  - at the end of the string: the low sweep;
  - at a run: the slide in under it.
- Off a jump, the jump attack.

**His weight.** `CharacterProfile` has a Weight group that overrides the
controller's own values:

| | Warrior | the controller's |
|---|---|---|
| ground acceleration | 26 | 60 |
| deceleration | 32 | 75 |
| turn | 7 | 12 |
| turn standing | 12 | 22 |
| carried by his swing | 0.08 | 0.18 |
| shove | 0.14 | 0.28 |
| stagger | 0.016 | 0.03 |

His other numbers:

- run 5.0, walk 2.1;
- a shorter, heavier roll;
- jump 0.8;
- 210 health, p.def 45, damage 27;
- 24 stamina a blow.

Tariel's fuse look is called THE IRON HELM now, so that no look of his is
also called THE WARRIOR. `SkinnedRig.sword_mesh_name` names the blade mesh a
rig's blood goes on.

`tests/warrior_test.gd` checks:

- he is on his own rig and skeleton, with every clip his tables name;
- the sword is in his fist and there is no shield;
- he is heavier than Tariel;
- both hands are on the hilt standing, walking and through a cut;
- attack throws his string and the other button a heavy blow.

## THE WARRIOR, second round: the sword on his shoulder, a cloak of cloth, blows with weight

- **Out of a fight** he carries the great sword on his right shoulder, in one
  hand: the blade's flat over the shoulder and pointing back, his fist before
  it (`WR_Rest` on Mixamo's standing idle with an axe, and `WR_RestWalk` on
  its swagger walk). The arm is laid there in Blender
  (`wr_build.shoulder_pass`): the fist and the blade's line are set in
  spine_03's frame, so they ride the body, and the arm is solved to them
  with its elbow out and down.
- He goes back to both hands on the hilt with a blow, a blow taken or a
  target locked on (`SkinnedWarriorRig.in_fight`). After 4 s of quiet the
  sword goes back on the shoulder. The run keeps the pack's run.
- **The cloak is cloth.** His own textured cloak, below the shoulders, is
  weighted to a grid of 9 × 9 bones (`clk_<row>_<col>`), laid round him on
  the cloak's own surface by angle and height (`wr_build.cloak_bones`). It is
  wholly the grid's under 1.38 m and its own above 1.5 m. `ClothBones` (a
  SkeletonModifier3D, `scripts/cloth_bones.gd`) hangs that grid as one sheet:
  - [ClothCape]'s Verlet cloth, with the lengths along, across, the diagonals
    and every other point kept;
  - capsules round the trunk, the legs and the arms;
  - the top row sewn to spine_03, and a drape held strongly at the top and
    hardly at the hem;
  - each bone set where its point is, turned as the sheet round it has
    turned.
- **Blows with weight.** Every attack clip now keeps its travel on the root
  bone, and his blows are `carried`: the step the man in the clip took goes
  into the body with the cut. That covers the combo's three, the high spin,
  the power slash, the second combo, the leap and the slide.
- **A second string.** Started while moving, the string is Mixamo's
  two-handed sword combo instead (`WR_Combo2_A/B/C`, one clip under three
  names), with the high spin to end it.
- **A new heavy blow.** At the end of the string, the heavy button throws the
  great swing round and into the ground (`WR_HeavySwing`, Mixamo's two-handed
  heavy weapon swing, slam at 0.55). It replaces the low sweep.
- Blows ease into one another a little quicker (`action_blend` 0.12) and come
  a little faster (`swing_rate` 1.3).

`warrior_test` also checks:

- the shoulder stance out of a fight;
- the cloak is cloth: its hem travels, and its bones hang below their tops;
- a cut carries him forward and puts him in the fighting stance with both
  hands on the hilt;
- moving, he throws the second string.


## The roster trimmed (2026-10-02)

The art is heading to stylized low poly, starting with Polysplit's Heroes pack
(see `ASSET_WISHLIST.md`). The hero select now offers only these looks:

- **Tariel**: every look, as before.
- **Avtandil**: **AS HE WAS** only, the one of boxes, with his two outfits.
  THE RANGER, THE HUNTER, THE HUNTSMAN and THE FOX HUNTER were taken off
  (`SkinnedArcherRig`: no figures).
- **The assassin**: **THE FOX MASK** only, on Sidekick.
  THE BLADE, THE SHADE, AS HE WAS, THE HOOD and THE NINJA were taken off
  (`SkinnedRogueRig`: the Sidekick figure alone, no capes).
- **The mage** and **THE WARRIOR**: unchanged.
- **The elf** is off the roster. `elf.tres`, its visuals scene and
  `skinned_elf_rig.gd` are gone.

The sections above still describe the looks that were taken off. Their asset
folders were left in place:
- `assets/avtandil_anna`
- `assets/avtandil_blink`
- `assets/avtandil_sidekick`
- `assets/rogue_ninja`

Nothing loads them now, so they can go whenever their history is no longer
wanted.


## Polysplit's Swordsman, and two animation packs side by side (2026-10-02)

**THE SWORDSMAN** is one more look for Tariel, the first from Polysplit's
"Low-Poly Medieval Fantasy Heroes – Basic Pack" (`assets/tariel_polysplit/`).
He wears the pack's M_Swordsman as Polysplit dressed him: the blue gambeson,
the skull cap over a mail coif and the scabbard on his back, in the pack's
pre-coloured textures (body colour 1, objects colour 1).

The pack's heroes (`BasicHeroes/M_<Class>.fbx`) each carry the whole male base
(every hair, face and beard) and the class's outfit, on one 98-bone skeleton:
`pelvis_joint`, `waist_joint`, `chest_joint`, `L_`/`R_` arm and finger joints,
and hair, cape and coat-tail chains. `vepxis-art/tools/ps_build.py` builds the
figure as `sk_build.py` does for Sidekick:

- It joins the look's parts into one mesh (`ps_swordsman`).
- It turns the rest onto the rig's limbs and closes the fists.
- It adds `weapon_r` / `shield_l` with Tariel's shields.
- It puts the pack's own sword where Tariel's is: grip in the fist, blade and
  flat turned to his.

Two gotchas:
- The face's eyes, brows and mouth are cut-out decals on quads. The
  material's alpha goes through a "greater than 0.5" node, so the glTF comes
  out `alphaMode: MASK`. Without it the face is a red and white block.
- The parts' UV maps do not share a name. Each part is left one layer, named
  `UVMap`, before the join.

`SkinnedRig.polysplit_map()` maps the waist to `spine_01` and the chest to
`spine_02`. Hair, cape and coat-tail chains ride their parents. The figure is
6% taller than the rig; `FigureFollower` scales the hips' travel to match.

### Kevin Iglesias and UAL 2 on tariel_rig

The aim is to choose which paid animation pack to buy. The free versions of
both are retargeted onto `tariel_rig` by `vepxis-art/tools/kv_retarget.py`,
into `assets/anim/compare/melee_compare.glb`. That file has no mesh, only the
clips:

- `KV_*`: Kevin Iglesias' Human Melee Animations FREE.
- `UQ_*`: the UAL 2 Standard clips that are already in `ual2.glb`.

Each mapped bone takes the turn its partner has made from rest, in the world,
corrected by the small difference between the two T-poses' limb directions.
Limb lengths stay the rig's, and the hips travel by the ratio of hip heights.
Every clip is sampled at 30 fps by time. The paid Kevin pack uses the same
skeleton (`B-hips`, `B-spine`, `B-chest`, `B-upperArm.L`, ...), so the same
script brings it over by adding its files to `CLIPS`.

What the free packs lack:
- Kevin FREE has no jump.
- UAL 2 Standard has no ordinary run (only `Sword_Dash`) and no plain
  sword-hand idle.

The comparison scene is kept outside the repo, in `vepxis-art/polysplit/cmp.gd`; to run it, copy it to `_shots_tmp/`. It shows three
Swordsmen following three rigs, one each for Kevin, UAL 2 and the Mixamo
clips Tariel uses now, through IDLE, COMBAT IDLE, RUN, SWORD, SWORD COMBO
and JUMP. It writes a movie with `--write-movie`, and Blender's sequencer
turns the frames into an mp4.


## The maker: YOUR OWN, out of every part of Polysplit's heroes (2026-10-02)

On the hero select, every hero now has one more look, the last one:
**YOUR OWN**. With it on, the dossier makes way for the maker. The maker has
four tabs, and each row has an arrow either side:

| Tab | What it sets |
| --- | --- |
| CLASS | the class, and the body (man or woman) |
| FACE | eyes, brows, mouth, beard, hair and skin colour; the stage's camera moves in on the head while this tab is open |
| GEAR | top, legs, MORE (capes, scabbards, pauldrons… each put on or taken off), hat and cloth colour |
| ARMS | the weapon, and what is in the other hand |

The class is picked first. It dresses him in its clothes, hat and arms, and
changing it leaves the face as it is. Every change is worn on the stage at
once and remembered (`Game.look()`, the `[look]` section of `settings.cfg`).
The look goes to the other peers as a JSON string (`Player.net_look`).
The plan behind it is `CHARACTER_CREATOR.md`. Parts 1–6 are done here; the
animations (part 7) come next.

What was decided with the user:

- **Both genders, every hero.**
- **The old looks stay.** YOUR OWN is added after them. It took the place of
  THE SWORDSMAN, the one Polysplit look Tariel had: its index is the same, so
  a saved pick carries over.
- **Any hero can wear any class.** His own come first:

  | Hero | His own classes |
  | --- | --- |
  | Tariel | swordsman, fighter, knight |
  | the warrior | knight |
  | the assassin | rogue |
  | Avtandil | archer, hunter |
  | the mage | mage, sorcerer, warlock, witch |

- **The pack's colours are enough:** 8 body colours (skin, hair, eyes) and
  14 object colours (cloth, arms), each a texture swapped in
  (`assets/polysplit/colors/`).
- **The mage holds a sword.** A staff can go in his other hand.

### The figures

The figures are `assets/polysplit/<hero>_<m|f>.glb`: one per hero and gender,
ten in all, about 6 MB each. They are written by
`vepxis-art/tools/ps_creator.py` (background Blender, about 40 s each).

Each holds the pack's figure on its own 98-bone skeleton. The rest is turned
onto that hero's limbs and the fists are closed, as `ps_build.py` did for
the one Swordsman. Every part is a mesh of its own, all hidden but those the
look shows. A part's kind is in its name:

| Mesh | What it is |
| --- | --- |
| `ps_head`, `ps_topbody`, `ps_bottombody` | the bare body |
| `ps_eyes_<0-4>`, `ps_brows_<0-4>`, `ps_mouth_<0-4>` | the face's decals |
| `ps_beard_<1-8>` | the beards (men only) |
| `ps_hair_<n>` | a hairstyle with no hat (1–14) |
| `ps_hairb_<n>`, `ps_hairb_<n>_<part>` | the same style cut for a hat: the pack's "b" cut, with its bun or bangs and without its top |
| `ps_top_<class>`, `ps_bottom_<class>` | a class's clothes |
| `ps_x_<class>_<part>` | what else a class wears |
| `ps_hat_<id>` | the 18 hats; the ones with no bones of their own are put on `head_joint` |
| `ps_w_<id>` | a weapon in the sword hand: `sword_a`, `sword_b`, `greatsword`, `dagger`, `staff_a`, `staff_b`, `bow` |
| `ps_o_<id>` | one in the other hand: `shield`, `dagger`, `staff_a`, `staff_b` |
| `ps_shield`, `ps_tower_shield`, `ps_arm_bow` | the hero's own arms |

The weapons ride the hero's own weapon bones, which `fig_hero.py` adds to the
figure. Mage and warrior entries were added there. Each weapon is placed
where the hero holds his own:

- Tariel's sword sets the blades.
- The warrior's great sword sets his.
- The assassin's knives set the daggers.
- Avtandil's bow sets the hunter's bow, turned tip onto tip, because his own
  is straight at rest. Its string rides `draw_r`.
- The mage has none of his own, so he holds the weapons as the pack does.

A weapon is left out of a hero's file if he has no bone for it.

`sword_b`, `staff_b` and the woman's great sword come from the pack's loose
weapon files. They are set where the class's own sword or staff is held. No
woman's class has a great sword.

### In the game

- **`PolysplitLook`** (`scripts/polysplit_look.gd`) is the look: one
  Dictionary.
  - It also holds the class sets, the hats (how much hair shows under each,
    and whether the beard and face do), each hero's arms, and the names.
  - `dress()` puts a class on a look.
  - `regendered()` changes the body.
  - `normalized()` mends a look read from disk or the wire.
  - `apply()` shows the figure's parts and swaps the two textures. The
    materials are duplicated per figure, so one hero's dye stays his.
- **`SkinnedRig`** adds the face `CUSTOM` when `_configure()` sets
  `polysplit_hero` (`_add_maker()`).
  - **Figures:** two figures (`psm`, `psf`) are loaded only the first time
    they are worn, so the hero select's five stages stay light.
  - **Bones:** `polysplit_map()` maps them. Where the rig has a third spine
    bone, as the warrior does, the chest rides it instead.
  - **Hiding the hero's own model:** while YOUR OWN is worn, his meshes are
    put away. The warrior's meshes are not named for him, so they are put
    back afterwards by `_hide_own()`.
  - **The cut:** its markers are measured off the blade in hand (`_reach()`
    on the mesh's bind pose), so a dagger cuts short and a great sword long.
    The other hand's ring is drawn only for a blade.
  - **The look:** `set_look()` / `get_look()`.
- **`CharacterPortrait.frame_close()`** follows the head for the FACE tab.

Gotchas:

- !! **Hidden parts and stale matrices.** The pack hides most variants: the
  bare body, and all but one hair. Hidden, Blender neither selects them nor
  applies them. Their `matrix_world` is also stale (scale 1, not the fbx's
  0.01) until they are shown and the view layer updated. Without that, the
  bare body and the hairs come out a hundred times too big.
- !! **The male Archer.** Blender cannot import `M_Archer.fbx` (`KeyError:
  rootSkeleton`). Godot's own fbx reader can.
  - `_shots_tmp/fbx2glb.gd` turned it into `polysplit/conv/M_Archer.glb`
    (kept in vepxis-art).
  - Its parts match the fbx imports exactly.
  - Its hat is the Tyrolean.
- The woman's all-in-one file (`BasicHero_F.fbx`) holds three swords, one per
  class. Only one of them is taken.

### Tests

`tests/maker_test.gd` (new) covers every hero, in both genders and every
class the pack has for him. It checks that:

- the figure of the look's gender is worn and the hero's own meshes are put
  away;
- every part the look names is a mesh and is shown, and nothing else is;
- the hair is the hat's cut;
- the figure's hand is within 0.35 m of his;
- the weapon is in hand, and the cut comes off the figure's hand and is the
  blade's length;
- the colours are swapped in;
- the look survives the wire;
- his own look comes back afterwards.

`menu_test` checks the maker on the page.

`assets/tariel_polysplit/` (THE SWORDSMAN) is no longer worn. It is kept
because `vepxis-art/polysplit/cmp.gd`, the animation comparison for part 7,
still stands on it.

A face index saved when a hero had more looks now falls back to his first
look, not his last (`SkinnedRig.set_face()`). Without this, Avtandil and the
assassin would have come up in YOUR OWN.

### Every hero his own clothes; hats and arms free (2026-10-02, later)

The maker now offers a hero **only his own classes**
(`PolysplitLook.HERO_CLASSES`). His top, legs and MORE come from those
classes alone, so a swordsman no longer wears the rogue's legs.
`normalized()` mends any other class's clothes on a saved or sent look back
to his own.

Hats are free for everyone. So are the arms: any blade the hero's figure has
a bone for.

| Hero | Sword hand | Other hand |
| --- | --- | --- |
| Tariel | arming sword, broad sword, great sword, dagger | his shield, round shield, none |
| the warrior | great sword, the two swords, dagger | — |
| the assassin | dagger, the two swords | dagger, none |
| the mage | the two swords, great sword, dagger | staff, crooked staff, dagger, none |
| Avtandil | his own bow, the hunter's bow | — |

Every hero still starts with his class's own weapon.

The idea of clothes that fit whoever picks them up, and of weapons dropped
by bosses, is noted in `CHARACTER_CREATOR.md` §8.


## The animation lab: Kevin Iglesias | UAL 2 | what the heroes play now (2026-10-02)

`scenes/tools/anim_lab.tscn` (`scripts/anim_lab.gd`) shows the two packs we
bought side by side with what the heroes play now, one move at a time. Each
column is a figure in Polysplit's clothes, holding the set's arms:

1. **Kevin Iglesias**, Human Melee Animations (119 male in-place clips), on
   Quaternius' UAL 2 mannequin.
2. **Quaternius UAL 2**, on its own mannequin, exactly as made.
3. **Now:** the set's hero on his own rig with his Mixamo clips, in YOUR OWN.

The moves are grouped into sets by what is held:

| Set | Hero in column 3 |
| --- | --- |
| MOVING | Tariel |
| SWORD AND SHIELD | Tariel |
| TWO HANDS | the warrior |
| TWO KNIVES | the assassin |
| BOW | Avtandil |
| SPEAR | the mage (a staff stands in for the spear for now) |

A pack with nothing for a move says so: NOT IN THIS PACK.

**Keys:**

| Key | What it does |
| --- | --- |
| ← → | another move |
| ↑ ↓ | another set |
| 1 / 2 / 3 | pick that column's clips for the move |
| space | pause |
| - / = | slower / faster |
| R | play the move again |

Picks are kept in `assets/anim/lab/picks.json`. Launched with
`--write-movie <f>.avi --fixed-fps 30 -- movie <set>`, the lab walks through
one set and quits.

**Why the mannequin.** UAL 2's skeleton is the UE mannequin: three spine
bones and every finger. Our `tariel_rig` has two spine bones and no fingers,
and the Mixamo clips reach the figure through two retargets: Mixamo →
`tariel_rig` → Polysplit. On the mannequin, UAL 2 plays with no retarget at
all, and Kevin goes through one, fingers included.
`assets/polysplit/mannequin_m.glb` is the maker's figure built onto the
mannequin's limbs (`ps_creator.py mannequin m`). It holds the pack's arms
the way the pack holds them, the shield on the forearm.

**How Kevin's clips got onto the mannequin:**

- !! Blender's fbx reader brings Kevin's skeleton in lying down, with the
  clips standing and in centimetres. A retarget from that throws the figure
  off the stage.
- Godot's own fbx reader (ufbx) reads them right. `vepxis-art/tools/fbx2glb.gd`
  turned every clip, and Kevin's skinned man `HumanM_Model.fbx` (whose bind
  is the T-pose), into glb (`kevin_melee/glb/`).
- `vepxis-art/tools/kv_godot.gd` retargets them in Godot into
  `assets/anim/lab/kevin_lib.res`, an AnimationLibrary of `KV_*` clips. Each
  bone takes the turn its partner made from the T-pose, in the world, with
  the limbs' rest difference corrected. The hips travel by the ratio of hip
  heights. It takes a few seconds.
- The converted clips are bare node hierarchies (no mesh, so no skeleton),
  and spaces in the names come out as `_-_`.
- Godot's glb import takes `_Loop` off UAL 2's clip names and loops them.
  The lab looks for both spellings.

`assets/anim/lab/ual2_mannequin.glb` is UAL 2 Source's `UAL2.glb` as bought.

### The user's picks (2026-10-02)

The user's picks are in `assets/anim/lab/picks.json`: for each move, the main
column, and under "also" the others kept beside it to vary the blows. The
lab stars the main one.

| Set | Picks |
| --- | --- |
| MOVING | Kevin: standing, walk, run, sprint, strafe, run back, hit, death. Dodge: Kevin, ours kept too. Jump and climb: UAL 2, ours kept too. |
| SWORD AND SHIELD | Guard, the three cuts, combo and heavy blow: UAL 2, Kevin's kept too. Block: Kevin. Blocked hit: UAL 2. Shield bash and drawing the sword: Kevin. |
| TWO HANDS | Guard and cuts 1-3: Kevin. Cut 4: both, Kevin and UAL 2's one-handed blow from above into the ground. Parry and slam: UAL 2. |
| TWO KNIVES | Guard: Kevin. Every stab, combo, parry and the one knife: UAL 2, for its range of blows. |
| BOW | UAL 2. |
| SPEAR | Kevin, the only pack that has it. |

Still to do: the shield sits wrong in the hand on the mannequin's figure.

(Done since: see the next section.)

## The heroes on the mannequin with the picked moves (2026-10-02)

ANIMATION_MIGRATION.md, part 3. YOUR OWN, every hero's, is worn on
Quaternius' UAL 2 mannequin, the UE skeleton (three spine bones, every
finger), and fights with the clips the user picked in the lab. The other
looks (AS HE WAS and the rest) stay on the hero's own rig and Mixamo clips
until the user says otherwise.

### How a rig wears the mannequin (`SkinnedRig`, region "YOUR OWN on the mannequin")
- The first time YOUR OWN is worn, `_build_mannequin()` loads
  `assets/anim/lab/ual2_mannequin.glb` beside the model (its own mesh hidden)
  and gives its player one library of its own: UAL 2's clips, Kevin's
  (`kevin_lib.res`), the hero's own clips carried onto the mannequin
  (`assets/anim/heroes/<hero>_mannequin.res`, vepxis-art `tools/h2m.gd`, the
  same world-delta retarget as kv_godot.gd) and any clip another hero lends
  (`mq_borrow`: the mage's spell is Tariel's `SS_Spell_Casting`).
- `_use_mannequin(on)` swaps what the rig drives: `_anim`, `_skel`, the
  stride and strike modifiers; the model is hidden whole and its player
  stopped. Back on another look, the hero's own tables come back
  (`_own_tables`).
- !! Every clip has every bone keyed (`Moveset.complete()`): UAL 2's clips
  leave out the bones they do not move, Kevin's the middle spine bone, and a
  bone no clip keys stays wherever the last one that did left it (the same
  clip measured two ways depending on what played before it).
- The figure is the maker's built on the mannequin's limbs
  (`assets/polysplit/mannequin_m.glb`, `mannequin_f.glb`: `ps_creator.py
  mannequin m|f`), following the mannequin (chest on `spine_03`, head on
  `Head`). It carries the pack's arms and Tariel's two shields (HIS SHIELD);
  "HIS OWN BOW" shows the pack's bow (his own bends on bones of his rig's).

### The moves (`scripts/moveset.gd`, `Moveset`)
- `kind_of(look)`: the set by what the look holds: a sword -> SWORD AND
  SHIELD, the great sword -> TWO HANDS, a dagger -> TWO KNIVES, a bow -> BOW,
  a staff -> SPEAR. MOVING under every one.
- `build(kind, own)`: the tables laid over the hero's own. MOVING's picks are
  the clip table's idle/walk/run/sprint/strafe/back/roll/mantle/hit/down;
  Kevin's walk and run the other ways go with them; the jump is UAL 2's start,
  air and landing. "also" picks are played at random in the main one's place
  (`_alt()`): the hero's own roll, air and climb; Kevin's guard; the heavy
  blow's other.
- Strings: the cuts one after the other, each with its `_Rec` played after it
  if no blow follows and he stands; the combo clip cut at its cuts into a
  string of its own (`<clip>#1`, `#2`...); Kevin's cuts as another. A new
  string is picked at random. The picked blows play at `MQ_SWING_RATE` (1.1),
  not the Mixamo clips' 1.6.
- In a fight (a blow, a hit or the guard in the last 4 s, or something locked
  on) he stands in the picked guard, else Kevin's standing. The block is a
  standing clip: the legs walk under it (`StrideModifier`) as he moves.
- Cut and trail windows, ground speeds, the shield's turn and the bow's
  release are measured off the clips (vepxis-art `tools/clip_meta.gd` ->
  `assets/anim/lab/clip_meta.json`): the tip past 55 % of its top speed
  cuts, past 30 % draws the arc; the standing foot's median speed is a
  cycle's pace (on the figure, times the rig's scale).

### The arms
- The shield rides a bone of its own on the left forearm (`shield_l`). One
  shield on the forearm cannot face the blow both in UAL 2's guard and in
  Kevin's block (they hold the forearm ~70° apart), so `_turn_shield()` turns
  it about the forearm onto each clip's measured `shield_turn` (the guard's
  for a clip with none), 540°/s.
- Every weapon of the mannequin's figure goes through the middle of its fist
  (`ps_creator.py mannequin_grips()`: the line between a blade's or a staff's
  ends, a bow's grip). The pack's straight bow string is taken out; the game
  draws the string to the right fist (`BowModifier.place_string_at()`).
- Two hands on one grip: the figure's arms are their own length, so its left
  fist lands off the hilt where the mannequin's is on it. `hilt_hand()` puts
  it back (as far along the handle as the mannequin's, scaled; two-bone IK,
  the elbow kept in its plane), unless the clip itself lets go of the hilt.
- Avtandil on the mannequin draws with UAL 2's `Bow_Notch` (0..0.4), aims
  with `Bow_Aim_Neutral`, looses with `Bow_Shoot`; his own aim walks, climbs
  and skills are his clips carried over. The mage cuts with the picked sword
  moves and casts with Tariel's spell, the legs walking under it.

### Tests
- `tests/grip_test.gd` (new): every picked clip, frame by frame, on the
  figure: each grip in its fist (a failure), the left fist on a two-handed
  grip, the blade in the body (torso, head, thighs); the shield's face ahead.
  All pass, no clip warned. Worst seen: the left knife touches the hips (up
  to 9 cm, 2-7 % of frames) in `Sword_Light_Combo` and `Sword_Light_C`;
  `KV_AttackPolearm03` sweeps through the hips 16 % of its frames.
- The one-handed blows picked for TWO HANDS (`Sword_Heavy_D`, `Sword_Block`,
  `Sword_GroundPound`) let go of the hilt: the great sword is held in one
  hand there.
- The tests that check a hero's own look (heroes, archer, warrior,
  rogue_strike, skinned_rig) put face 0 on first: the settings may have YOUR
  OWN on. `skinned_rig_test` checks YOUR OWN on the mannequin too.
  `Footsteps` asks the rig which skeleton moves (`skeleton_now()`).

### Seen in the game (hero reels, 2026-10-02)
- Kevin's STANDING (`KV_Idle01`) is an unarmed idle: the weapon sticks out
  sideways from the loose hand. The guard is held for 4 s after a fight.
- The mage's attack button charges and casts (the bow's interface): his
  sword moves are in his tables but nothing throws them yet.

### Tariel's run and evade, set right (2026-10-02, later)
- The run played was Kevin's sprint: it took over past halfway from the run's
  pace to the sprint's, and the controller has no sprint gear, so at his run
  (5.6 m/s) he always sprinted, legs flung wide. The sprint now plays only
  past the hero's own `run_speed` (x1.1).
- Kevin's DODGE is a hop back that comes back (hips 0.53 m behind at 0.4 of
  it, then home); the dash turns the body to the way it goes, so on the run he
  hopped back while the body went forward, and slid. `_mq_roll()`: the hop is
  played (to its farthest, `hop_peak`) only when the dash goes the way it hops;
  any other way the pick's "also", the hero's own roll.
- Paces: measured as a foot's speed while down flat (the lower foot frame by
  frame read a run as 3.4 m/s for 4.9). In the game the feet still slid at
  that pace; at 0.833 of it they stand, the same for every hero tried
  (`Moveset.PACE_FIX`). The walk changes to the run halfway between their
  paces on the mannequin.
- `tests/stride_test.gd -- <hero>` (new): in the world, the game's inputs,
  the foot down flat must slide under 0.45 m/s walking and running, and the
  evade on the run must go ahead. All five pass (0.15-0.44 m/s).

### One speed for every hero; the guard walked without the feet in the ground (2026-10-02, later)
- Every hero now has Tariel's speeds, the user's word, to begin with: walk 2.4,
  run 5.6, dash 11 m/s for 0.45 s, dodge 8.5 m/s for 0.7 s (they were:
  warrior 2.1/5.0/8.5x0.55/7x0.75, assassin 3.0/5.9/9.5x0.5/8x1.1, Avtandil
  4.0/5.9/13.5x0.5/11x0.72, the mage 2.6/5.4/10x0.45/8x0.7). The warrior keeps
  his slower start, stop and turn.
- Walking behind the shield, the walk's legs were laid under Kevin's block,
  whose hips are low and turned square to the guard: the legs went into the
  ground and stepped sideways while he went ahead. `StrideModifier` now takes
  the hips' height and turn from the cycle too, the trunk above kept as the
  clip has it. stride_test checks the guarded walk (slides 0.23 m/s, the
  ankles 3 cm higher than walking, not lower).


### Tariel's sword and shield: one author, one design (2026-10-02, later)
- Everything Tariel does with the sword on the mannequin is UAL 2's, played
  whole and near its own pace (`scripts/swordsman.gd`, laid over what
  `Moveset.build` makes of the picks for the sword):
  - the string is UAL 2's own chain, `Sword_Regular_A -> B -> C`, the same
    every time (each blow ends in the pose the next starts in). No string or
    clip of another pack is picked at random any more (`alts` emptied);
    A and B left alone are brought back by their own `_Rec`;
  - the evade is `Sword_Dash`: low and forward with the blade drawn across on
    the way, a light cut (x0.6). At x1.3 its lunge and cut fill the 0.45 s
    dash (travel stops at 0.7 of it, `dash_land_at`); the low hold and the
    rising after it are its recovery, given up as soon as he moves off. There
    is no longer evade to turn it into: a second press is the next evade
    (`_upgrade_to_dodge()` now says whether it could);
  - the jump attack is `Sword_GroundPound`, which starts in UAL 2's aerial
    pose: in the air it plays to the blade over the head and holds it there;
    landing, it plays on at x1.2 to its end, the blade into the ground. Only
    the chop cuts.
- Why: the deformation seen in the roll and the jump attack was the clips and
  how they were played (the Mixamo roll squeezed into the dash at ~1.8x, the
  jump attack played in pieces and held), not the mannequin: the old rig and
  the figure on the mannequin showed the same poses. UAL 2's clips on Tariel
  match the bare mannequin pose for pose.
- `tests/swordsman_test.gd` (new): the string twice A, B, C; the evade cuts,
  goes 1.5-4 m ahead, is let go when he moves off; the jump attack holds in
  the air, plays on at near its pace landing, to its end.

### Locked on, he turns and runs; the jump attack cuts; feet flat crouched; three runs to try (2026-10-02, later)
- Locked on, backing off turned into a backpedal at a run. Now he turns and
  runs whichever way he goes, the camera still on the target; only the bow,
  the raised guard, the walk key or the assassin's step-then-flip keep him
  facing it while backing off (`Player._watches_backing_off()`).
- The jump attack's chop lands after the feet do, in the PLUNGE role, which
  never cut: PLUNGE now cuts (and draws its arc) inside the clip's window.
- Crouched, the hero's own Mixamo clips carried onto the mannequin pointed the
  feet down and curled the toes under. `FootFlat` (a SkeletonModifier3D last
  on the mannequin) lays each foot as it stands at rest, turned only about
  the vertical, and the toes flat, wholly up to 0.16 m of ankle height and
  not at all past 0.32; only while one of those clips plays.
- Three runs to try in the game, F6 going to the next and remembered
  (user://trial.cfg): Kevin's `KV_Run01_Forward`, Tariel's own `SS_Run` (at
  4.3 m/s) and UAL 2's `Sprint_Shield` (5.6 m/s), `Swordsman.RUNS` /
  `RUN_PACE` (paces found in the game: clip_meta cannot read a run whose feet
  are both off the ground between steps). `stride_test -- tariel <run>`.
- swordsman_test: each run plays when picked; crouched, the toes lie no lower
  than standing.
- More to try (2026-10-02, later): Kevin's only other forward run,
  `KV_Sprint01_Forward` (his pack has Run01, Sprint01 and the strafes, no
  other), and `Sprint_Swing`, made at load by `Swordsman.bake()`: UAL 2's
  shield sprint's legs and trunk with Kevin's run's arms swinging, in step
  (each clip's left foot farthest ahead lined up). F7 / F8 lengthen or shorten
  the run's steps at the same speed (its pace x1.07 either way, kept per run),
  F9 leans him forward from the hips while running, 0/5/10/15 degrees
  (`RunLean`). All kept in user://trial.cfg.
- Picked (2026-10-02, later): Tariel runs with Kevin's sprint,
  `KV_Sprint01_Forward` (`Swordsman.RUN`), at its own pace: his `run_speed` is
  now 7.4 m/s, the clip's pace over the ground (at 5.6 it played at x0.76 and
  he went slower than his legs; now x1.01, the feet sliding 0.36 m/s). The
  others to try are gone: F6-F9, `trial.cfg`, `Sprint_Swing` and its bake,
  `RunLean`. Tariel is now faster on the run than the other heroes (5.6).

### Feet on the ground on slopes; the hero select's face close-up and layout (2026-10-02, later)
- Running across a hillside the uphill foot went under the ground: every clip
  is made on flat ground. `FootGround` (last on the mannequin's skeleton, every
  hero on it) looks for the ground under each ankle (a ray down, the body
  left out), keeps the foot as high over it as the clip holds it over flat
  ground, brings the hips down by what the lower foot needs (eased), bends
  each leg to its foot by two-bone IK in its knee's plane, and lays a foot
  near the ground along it (to 32 degrees). Only on the floor. Across a 30
  degree hillside the ankle went 0.21 m under; now 0.02 (15-20 degrees: 0.06
  -> 0.05-0.08 at worst). Past 40 degrees, where he cannot stand, it still
  goes 0.15 under.
- The hero select: FACE brought the camera to the belly on YOUR OWN, because
  `bone_position("head")` looked on the mannequin, whose bone is "Head":
  it now looks on the figure on it first (`head_joint`). The page fits 900
  high (the stage 500, the roster tiles 116x132; at 540 the roster and BACK
  went off the bottom); the look/colour/hair rows are hidden when there is
  nothing to pick, their room kept; "drag the hero to turn him" under the
  stage; the maker says whose it is ("TARIEL · YOUR OWN"), what it is for and
  that FACE comes close; a numbered part reads "4 / 5", not "4".
- Kevin's pack beyond the 01s: AttackShield02, CombatDamage02, Death02,
  CombatDeath01-04, CombatIdle01 (seen in a reel; none put in yet).

### A death for each class; strings and heavy blows to try in the game (2026-10-03)
- Each class (the look's `cls`) dies its own death on the mannequin
  (`Moveset.DEATHS`, the user's picks): swordsman `KV_Death01`, knight
  `KV_CombatDeath04`, rogue `KV_CombatDeath03`, hunter `KV_CombatDeath02`;
  the rest shared out (archer and sorcerer `KV_CombatDeath01`, fighter and
  mage `KV_Death02`, warlock `CombatDeath04`, witch `CombatDeath03`).
  `SkinnedRig.die()` (the player's DEATH reaction); being knocked down keeps
  its own fall, which the getting up plays backwards.
- To try in the game, Tariel on the mannequin: F6 the next string
  (`Swordsman.STRINGS`: UAL 2 Regular A-B-C, Light A-B-C-D, Heavy A-B-C,
  Kevin's 1H 01-04), F7 the next heavy blow (`HEAVIES`: UAL 2 Heavy Combo,
  Heavy D, UpperCut, Kevin's 1H 05); a line at the top says which; kept in
  user://trial.cfg. Every clip of them is measured (clip_meta) and played
  whole, with its own `_Rec` where it has one.
- The animation catalogue: ~/Desktop/vepxis_animations (Kevin's and UAL 2's
  clips on Tariel, a page a kind, `_shots_tmp/catalog/catalog.gd`).
- stride_test's run slide reads 0.36-0.44 m/s alone and up to 1.0 when the
  machine is busy with other tests (the sprint's feet are both off the ground
  between steps): run it alone.
- Picked (2026-10-03): Tariel dies `KV_Death01` whatever class he wears
  (`Moveset.HERO_DEATHS`). Two strings only, F6 going from one to the other:
  UAL 2 Regular A-B-C (the one worn at first) and UAL 2 Heavy A-B-C; the
  other strings and the heavy blows to try (F7) are gone, the heavy blow is
  UAL 2's Heavy Combo as before.


## The heroes brought down to a man's height (2026-10-03)

Tariel's visuals were scaled 1.2, so on the Polysplit figure he stood about
2.35 m with his helmet: a giant at the spawn, beside the village's doors, barrels
and stalls. Every hero is now near a man's height, and each has a height of
their own. Only the visuals node is scaled. The capsule (1.85 m) and the blow
and step distances are the same for all of them.

| hero | visuals scale | to the top of the head |
| --- | ---: | ---: |
| Tariel | 1.02 (was 1.2) | ≈ 1.95 m |
| the warrior | 1.1 (was 1.02, before that 1.0) | ≈ 2.1 m |
| Avtandil | 0.985 (was 1.0) | ≈ 1.88 m |
| the mage | 0.97 (was 1.0) | ≈ 1.85 m |
| the assassin | 0.94 (was 1.0) | ≈ 1.80 m |

**The warrior, the big and slow one (2026-10-03, later).** The knight's
outfit is his alone now (`PolysplitLook.HERO_CLASSES`: Tariel keeps the
swordsman's and the fighter's), and he is the biggest of them: visuals x1.1
(~2.1 m), running 4.6 m/s (Kevin's run at its own pace, x1.01) and walking
2.2, and his blows on the mannequin at 0.82 of the others' pace
(`SkinnedRig.mq_swing_scale`, heavy blows' own rates too). His slow start and
stop and slow turning were already his (`warrior.tres`).

**OUTFIT, not CLASS.** On the hero select the first tab of the maker and its
row are called OUTFIT: Polysplit's classes are only clothes, a hat, the extras
and the arms they start with; nothing in the game reads them.

On the Polysplit figure at scale 1, `head_joint` stands at 1.706 m in the idle,
and the top of the head is about 0.2 m above it.

- **Tariel runs at 6.3 m/s (was 7.4).** At the smaller size, Kevin's sprint at
  7.4 m/s needed x1.19, and the standing foot slid 0.76 m/s
  (`stride_test`; 0.45 is the limit). 6.3 m/s keeps the sprint at its own pace
  (x1.01; slides 0.35–0.39 m/s). He is still the fastest; the others run
  5.6 m/s. `archer_test`'s "as fast as the knight" (5.6 vs 6.3) was already
  failing at 7.4.
- **Moveset ground speeds follow the scale** (`SkinnedRig._wear_moves`, `pace :=
  scale.y`), so the walks and runs of every hero retime themselves.
- **...and the figure's legs (fixed later the same day).** The figure's limbs
  are turned as the mannequin's are, so its stride is longer by its legs: its
  hips stand higher than the mannequin's (`FigureFollower._scale`). Left out,
  every walk and run played too fast for the ground covered and the standing
  foot slid back 17-25 % of the pace. `SkinnedRig._scale_ground()` multiplies
  the paces by both, worked out again whenever a figure is put on. Tariel's
  sprint now plays x0.88 at 6.3 m/s (its own pace on his figure is ~7.2 m/s);
  every hero's walk and run slides 0.16-0.28 m/s.
- **`stride_test` measured noise before.** Headless, frames ran free of the
  physics ticks, so a tick with no frame (the pose not moved on while the body
  had) or two read as sliding, a different amount each run: the earlier
  0.35-0.39 at x1.01 was luck. It now draws one frame a tick
  (`Engine.max_fps`) and reads the body where it is, not where the smoother
  draws it, and gives the same numbers every run.
- **The blade reaches less far.** The cut markers are measured off the blade in
  hand, so they follow. `multiplayer_test` stood the two knights 1.3 m from
  the wolf; that is now 1.1 m.
- The monsters' sizes are planned against these heights
  (`CREATURES_PACK.md` §6).


## The sword in its scabbard (2026-10-03)

A hero on the mannequin in a look that wears a scabbard (YOUR OWN: Tariel as
the swordsman, across his back; as the fighter, at his left hip) puts his
sword away in it and draws it from it (`SkinnedRig`, region "The scabbard";
`scripts/sheath.gd`).

* **No new bones.** Every Polysplit scabbard is already rigid on one bone of
  the figure (the swordsman's on `cape_joint1`, the fighter's on
  `L_coatTail_joint1`). Where the sword lies in it, its socket, is worked out
  off the two meshes when the look is put on (`Sheath.blade`, `Sheath.socket`):
  the blade's line, its guard (where the mesh is widest across the line) and
  which way the guard runs; the scabbard's line, its mouth (the end higher at
  rest), its length and its width. The sword's bone, `weapon_r`, is laid there
  once the figure is posed (`_hold_sheathed`, after the follower), so its mesh
  and the cut's markers go with it. Of the scabbards worn, the one nearest the
  blade's length is used.
* **The pack's swordsman wears his hilt over his left shoulder.** A right hand
  draws over the right, so a back scabbard with its mouth on the left is
  mirrored across the figure's middle once, when it is first fitted
  (`Sheath.put_mouth_over_sword_shoulder`). A hip scabbard is left as it is
  (the fighter's is drawn across the body).
* **Kevin's clips** put it away and draw it: `KV_SheatheBack01_R` /
  `KV_UnsheatheBack01_R` for a back scabbard, `..Hips01_R` for a hip one
  (`SHEATH_CLIPS`). The sword goes over from the scabbard to the hand (or back)
  in 0.08 s at the moment the hand is at the hilt (`grab`: 0.57 of the back
  draw, 0.45 of the back sheathe, 0.52 / 0.59 at the hip; the hand's path
  sampled), with the legs walking under it (`walk_under`). Anything that breaks
  the clip off leaves the sword where it was asked to be.
* **Out of the fight it goes away by itself**: `Player.sheathe_after` 2 s after
  the rig is off guard (no blow, hit or guard for `EASE_AFTER` 4 s, no target),
  standing or walking with nothing else going on. The stow key still puts it
  away or draws it by hand.
* **One press draws it and cuts**: attack with the sword away plays the draw
  (to 0.8 of the clip at x1.5, ~0.4 s) and the press is kept while it plays
  (`Player._rig_drawing`), so the first cut goes as it comes out. Off the
  ground, or for an evade that cuts (Tariel's dash), the sword is simply in
  the hand at once; a hit taken leaves it where it is. The shield is on the arm all the while, so the guard is
  never late. Other peers see it through `net_stowed`.
* Not for a look with a blade in the other hand too (the rogue's two daggers),
  nor for a look with no scabbard: those keep the sword in hand.
* **The blade lies in the scabbard, not beside it** (fixed the same day). Each
  mesh's line is its own principal axis (Jacobi on the covariance,
  `Sheath._axes`), the guard is the widest slice across it, the mouth the
  middle of the scabbard's last 4 cm: the first try took the line from the
  sword's bone to its point, and the bone sits in the grip 11° and some
  centimetres off the blade's line, so the blade stood out of the scabbard.
  Every Polysplit blade now lies inside its scabbard but for the guard at the
  mouth (`_shots_tmp/fit_probe.gd` counted it).
* **On the run only the sword arm is the clip's.** Kevin's clips are a man
  standing; laid over a run they straightened his back mid-stride. While one
  plays, the stride under it ([StrideModifier] `upper`) gives the trunk, the
  head and the shield arm the run's pose too, so he keeps leaning into it.
* **The steps go on under it.** [Footsteps] read the feet later in the frame,
  when a modifier's pose is gone again: under a clip standing still with a
  stride laid on its legs (this, and the cuts on the run) the feet never seemed
  to lift. It now takes them as the skeleton is posed (`skeleton_updated`).
* `tests/sheath_test.gd` (the run's steps and lean while it is put away too).

## Tariel: the shield charge, the running cut, the cut that misses (2026-10-03, TARIEL_POLISH.md session 2)
* **The shield charge.** With the shield up, the dash is no evade but a charge
  behind it: UAL 2's `Shield_Dash` (1.1 s, played whole over `bash_time`
  0.85 s). He turns to what he is locked on or what is in front, the guard
  comes down, and he drives in at `bash_speed` 8 m/s for `bash_travel` 0.38 s
  (~3 m at nothing). Whatever is in front of the shield (`bash_reach` 0.55 m
  body to body, `bash_cone` 55°) is shoved (`bash_push`), takes
  `bash_damage` 0.35 of a cut, and reels: `react(&"knock")`, the reel every
  creature already had for a guard broken ([Recoil], blows on it bite x1.5).
  The charge stops dead on it with a clang, dust and a step back
  (`net_bash_landed`). Stamina: `bash_stamina` 1.3 evades. Every peer plays
  the charge (`net_shield_bash`), the host decides what it hits
  (`_tick_bash`), as the creatures decide what a cut hits. Only for a rig with
  the clip (`SkinnedRig.can_shield_bash`): Tariel on the mannequin.
  Kevin's `KV_AttackShield01` (the lab's "SHIELD BASH", the rig's `parry`
  slot) was never thrown by anything and stays so.
* **The running cut.** The first cut thrown at more than `run_cut_pace` 0.75
  of `run_speed` is UAL 2's `Sword_Light_D` (`Swordsman.RUN_ATTACK`, x1.1,
  weight 1.25): a wide sweep out of a lunge, the cut at 0.14-0.26 s. The run
  is kept under it to its cut and a step past (see "the run kept to the cut"
  below), 1.25 cuts' stamina. The string goes on from B after it (the rig's string slot is set
  to A). Style `SkinnedRig.RUN_CUT` over the wire, like the heavy blows.
* **The cut that misses.** A cut of the string (or the running cut) whose
  cut has passed with nothing landed (`Player._judge_whiff`: no
  `net_blade_landed` since the swing's first `attack_serial`) drags: its
  follow-through is played at `whiff_slow` x0.5 until `whiff_recovery` 0.22 s
  is lost (`SkinnedRig.overreach`), he is held that much longer, and the evade
  cannot break it off until it is over (it can break off a cut that landed,
  as before). Heavy blows, the jump attack and the evade's cut are not
  judged. In the test a missed A holds him 38 frames, a landed one 29.
* `tests/tariel_moves_test.gd` (new): the charge (clip, travel, the orc
  taken, reeling and hurt; the dash without the shield still the evade), the
  running cut and B after it, the miss (signal, longer, the evade refused).
* `clip_meta.json`: `Shield_Dash` measured (`Swordsman.CLIPS`), nothing else
  changed (a full rerun of `clip_meta.gd` drops `Sword_Light_C_Rec` and
  `Sword_UpperCut`, which no pick asks for any more: merged by hand).


## The Advanced Weapons in the heroes' hands (2026-10-03)

Polysplit's Advanced Weapons (`WEAPONS_PACK.md`) are held by every hero in
YOUR OWN, and picked on the hero select's maker, ARMS tab:

| Row | What it sets |
| --- | --- |
| WEAPON | the sword hand's: what the outfit's class holds, "3/16" says how far along |
| OTHER HAND | a shield, a second weapon or nothing |
| STYLE | NORMAL, ORNATE, OBSIDIAN or BONE: every Advanced Weapon in hand changes to it |

**What each class holds** (`PolysplitLook.CLASS_ARMS`, the user's word: a
class its own arms; **no bow for the swordsman**):

| Class | Sword hand | Other hand |
| --- | --- | --- |
| swordsman | swords (arming, broad, long, short, curved, rapier), great swords, knives, axe, mace, hammer, morning star, flail | his shield, round shield, buckler, kite, tower, knife, short sword |
| fighter | axe, mace, hammer, morning star, flail, swords, great sword, great axe, great hammer, spear, poleaxe, knives | his shield, round shield, buckler, kite, axe, mace, hammer, knife |
| knight (the warrior) | great swords, great axe, great hammer, poleaxe, spear, swords, mace, morning star, dagger | none, kite, tower, buckler |
| archer, hunter (Avtandil) | his own bow, the hunter's bow, short bow, long bow | — |
| rogue | knives, short sword, curved sword, rapier, swords | knives, short sword |
| mage, sorcerer, warlock, witch | swords, wand, short and long sword, mace, great sword, knives | staffs, quarterstaff, wand, knives |

The Heroes pack's own arms (`ARMS`, per hero) are still offered where the
hero had them. A great sword, a spear or a bow leaves no shield in the other
hand (`PolysplitLook.both_hands()`): the shield gives way to an empty hand.

**On the figure.** `vepxis-art/tools/ps_creator.py mannequin m|f` now puts
every Advanced Weapon in every style into `mannequin_<g>.glb` (108 meshes and
12 shields; 6 → 15 MB, the four styles' pre-coloured textures in it):

- `ps_w_aw_<name>_<style>` in the sword hand (`weapon_r`; a bow's on the
  left fist, `weapon_l`), `ps_o_aw_<name>_<style>` in the other (`weapon_l`,
  a shield on `shield_l`).
- **Held as the pack holds its own.** Every Advanced file has its pivot on the
  grip and its blade along the pack's -Y, like the Heroes pack's loose
  weapons, and the Heroes classes hold those only moved onto `R_equip_joint`
  (the left hand's turned half round the blade; measured: the class sword and
  staff are the loose ones moved, nothing turned). So they go there, and then
  through the same rest-setting and fists as the pack's sword. The bows are
  laid as the classes' bow (fitted off `BowBasic`), their string taken out
  (the game draws its own). Each is then moved into the middle of its fist as
  the long sword is (the knife in the other hand).
- **Shields** on the forearm as the pack's round one (`mannequin_shields`),
  their back as far off the arm as its back. !! The Advanced shields face
  the other way to `ShieldBasic` in their files (the straps came out in
  front): half a turn about each one's long way. The tower shield is x0.85
  (at 1.61 m it stood over his helmet in the guard).
- Materials `aw_<style>`; `PolysplitLook.dye()` leaves them alone (the cloth
  colour is for the Heroes pack's arms).

**In the game.** A weapon id is `aw_<name>_<style>` (`PolysplitLook.AW`,
`styled()`, `aw_name()`), so everything that looks for `ps_w_<id>` finds it.
`PolysplitLook.kind()` says which moves it is fought with
(`Moveset.kind_of`): a great sword, great axe or great hammer TWO HANDS, a
spear, poleaxe or quarterstaff SPEAR, a knife TWO KNIVES, a bow BOW, the rest
SWORD AND SHIELD. `cuts()` (the cut measured off the mesh: a spear cuts far,
a knife short; not a shield, a bow or a wand) and `sheathes()` (only swords
and knives go into a scabbard) replace `BLADES` in `SkinnedRig`. Avtandil's
string goes on whichever bow he holds; the mage's crystal on the
quarterstaff in his other hand.

Not in yet: the crossbow (no moves for it), the caestus and the claw (worn on
the fist, not held), the quivers, and the flail's chain (its bones are not
kept: it hangs stiff). The idle the hero select plays is Kevin's unarmed one,
so a weapon sticks out ahead of the hand there (as the pack's sword did).

Tests: `maker_test` holds every arm of every class in every style (a mesh,
shown, and the cut as far as it reaches); `menu_test` the ARMS tab's three
rows and the style worn on the weapon in hand. Sheets of every class's arms:
`vepxis-art/tools/aw_shots.gd -- <hero> <style> [guard] [names]` (windowed).

### Shields the right way round, each sword its own scabbard, the pack's shader (2026-10-03, later)

- **Shields.** The Heroes pack's round shield (ROUND SHIELD) and the Advanced
  ones were worn back to front: the handles out. !! In the files every shield
  faces +Z as imported (the handles on -Z) and its top is +Y; the -Y "front"
  `mannequin_shields()` was given lies in the shield's face, so which way it
  turned was luck. Now set from the files (looked at, not guessed from the
  shape): the face out, the top up in the guard. !! The top is the file's
  -Y: with +Y up the bone shields' skulls and the ornate crests stood on
  their heads (the user saw it; `vepxis-art/aw/probe5` draws every shield
  flat with its texture).
- **Scabbards.** A sword or knife of the Advanced pack brings its own
  scabbard: worn where the class's scabbard was (the swordsman's on his back,
  the fighter's at his hip, the knight's great one, the rogue's sheaths), the
  class's put away, in the weapon's style. `ps_creator.py aw_scabbards()`
  lays the pack's scabbard mouth on mouth along the class's (80 meshes a
  figure, `ps_x_aw_<scabbard>__<name>_<style>`); `PolysplitLook.extra_key()`
  says which is worn, and the sword is put away into that one (`Sheath`).
- **The pack's shader.** The Advanced Weapons are drawn the way the pack
  draws them in Unity (`shaders/aw_weapon.gdshader`, after
  `RGBRecolor_AdvancedWeapons.shadergraph`): metal and gloss by the RGB
  mask's channels (`assets/polysplit/aw_mask.png`), with each style's values
  (`PolysplitLook.STYLE_LOOKS`, from its `.mat`), and for ORNATE and
  OBSIDIAN the "imbue" glow, a rim and slow noise moving over the weapon in
  the style's colour. The flat look before was the pre-coloured texture
  alone, rough and with no metal. The figures are now 18.5-19.3 MB.
- **BLACK OBSIDIAN** (the user's word: the new and the old both): a fifth
  STYLE, the obsidian models drawn as they were first worn, the texture
  alone, black and dull, no glow. Its weapons' ids are the obsidian ones
  (`PolysplitLook.STYLE_MODELS`); `wear_style()` gives their meshes the plain
  material, OBSIDIAN keeps the pack's shader.

### Tariel's skill 1, the Rising Cut; the running cut held wound up (2026-10-03, later)
* **Skill 1 (key 1): the Rising Cut** (`Player._rising_cut`, `Swordsman.RISING_CUT`,
  the user's pick from a reel of ten run cuts). From standing or running, he
  draws the sword back low (UAL 2's `Sword_UpperCut` held at 0.06 of the clip)
  and runs at what is ahead within `rising_seek` 14 m (or what he is locked
  on), turning with it, at 1.12 of his run. `strike_gap` 1.1 m off its body
  (its own `body_radius`, not the drawn size: the orc is drawn x2.24) the
  blade comes up through it (weight 1.7). With nothing to run at, 0.45 s of
  strides the way he faces and the cut; held at most 1.6 s. 22 stamina, 8 s
  cooldown, its picture on the bar (`PlayerHud._icon`). The string starts at A
  after it.
* **A held cut** (`SkinnedRig.holding_cut` / `release_cut`, Player
  `_tick_charge`): a cut spec with `hold` plays to that share and is frozen
  there (no arc drawn), the run's legs under it (the stride under a swing),
  until the controller lets it go (`net_release_cut` to every peer). A blow
  that takes the clip off him breaks it off. Timed on the body's own clock
  (`Player._game_t`): the wall clock `_now()` runs ahead of the game in a
  recording (`--write-movie`) and under `Engine.time_scale`.
* **The run kept to the cut**: a running cut keeps the whole run until its
  blade starts to cut (`_ease_delay`, from `SkinnedRig.time_to_cut`), then
  eases down over `run_cut_ease` 0.35 s, a step through the swing. It steps
  in no more by a step of its own (`run_cut_reach` gone).
* Kept for the swords to come (`Swordsman.RUN_CUTS_KEPT`): `KV_Attack1H05_R`
  held wound up (a lunge and thrust) and `Sword_Heavy_D` unheld with the step
  (a heavy chop out of a run). The reel: `_shots_tmp/runcut_reel.gd` (not kept;
  ten clips as the running cut, each at speed and at x0.35).
* `tests/tariel_moves_test.gd`: the Rising Cut at an orc 8 m off (runs in,
  cuts, hurts it, cooldown) and at nothing.
