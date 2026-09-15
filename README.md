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
scenes/world/greybox_world.tscn` is that level: 120 × 120 m of flat
ground walled in at the edges, a 15° ramp, a 55° face that cannot be stood on, a
6-step staircase up to a platform, pillars to test camera collision, and a
watchtower, a medieval house and cart, boulders, meadows of grass and stone
clusters, and a handful of creatures wandering about.

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
| run | 9 m/s | 10.4 m/s |
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
- **A draw stops at the face.** The string comes back to the jaw — `0.62 m` from
  grip to hand on this model. Past that is not a longer draw, it is an arm
  coming out of its socket, and it was the other half of why the pose looked
  wrong. `archer_test.gd` measures the draw length and where the elbow ends up.
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

| | |
| --- | --- |
| `attacks_commit` | the rule itself, so it can be turned off to measure against |
| `commit_speed_scale` | 0.18 — what is left of the run, **for the cuts after the first** |
| `chain_window` | 0.5 s — how long a flurry is still running, after which the next cut is a first one again |
| `loose_recovery` | 0.34 s — the archer's equivalent, after the string goes |
| `attack_buffer_time` | 0.22 s — a press during a swing is *remembered*, not eaten, so a flurry is one press per cut at the player's own rhythm rather than a timing test |

**An attack off a jump comes down from over the head.** `AttackStyle.OVERHEAD`,
forced rather than taken in turn: a horizontal cut thrown off a jump is a man
swinging at the air he is passing through.

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

**Multiplayer is on the screen and is not wired up.** More than one player needs
per-device input routing and either a split viewport or a network, none of which
exists. Choosing it says so on the character screen and starts a solo game,
rather than pretending.

`scripts/pause_menu.gd` is the same widgets again, in the level rather than in
front of it: resume, settings, or out to the main menu. It runs while the tree
is paused — it is the one thing that has to — and unpauses on the way out, or
the front menu would load paused and nothing on it could be clicked.

## Graphics

One setting, two positions, because a greybox does not need twelve. `Graphics`
applies it to the viewport and to whatever scene is loaded, so it can be changed
before a level exists and again from inside one; `Game` remembers it in
`user://settings.cfg`.

| | High | Low |
| --- | ---- | --- |
| shadows | on | **off** — the single most expensive thing in the scene |
| render scale | 1.0 | **0.7** — roughly half the pixels |
| texture mipmap bias | 0 | **+1.0** — a smaller mip than the distance calls for, so surfaces go soft |
| MSAA | 2× | off |
| SSAO, glow, fog | on | off |
| grass draw distance | 130 m | 60 m |

The grass reads its three knobs once as it is built, so `refresh_meshes()` is
what pushes them back down when the setting changes underneath it.

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
the player gets control. About 0.3 s of startup. Set `enabled = false` on the
`PipelineWarmup` node to measure without it.

> **The machine matters more than any of this.** While these numbers were being
> taken, `iCloudDriveCore` was sitting at 82 % of a core, the load average was
> 6.8, free memory was down to ~60 MB and the machine had swapped 16.7 million
> pages. Four *identical* runs produced between 0 and 29 hitches. Before
> concluding the game stutters, check `uptime` and Activity Monitor — a runaway
> background process will out-stutter anything in here.

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
