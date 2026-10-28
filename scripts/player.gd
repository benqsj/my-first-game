class_name Player
extends CharacterBody3D

## Placeholder third-person controller for greyboxing.
##
## Camera-relative WASD movement, gravity, jump (with coyote time + input
## buffering) and a dash / dodge roll with i-frames and a cooldown.
## The capsule mesh is a stand-in for the Blender knight models.

signal jumped
signal landed(impact_speed: float)
signal dash_started(direction: Vector3)
signal dash_ended
signal dodge_started(direction: Vector3)
signal dodge_ended
signal attack_started
signal block_changed(raised: bool)
signal slide_started
signal slide_ended
signal climb_started(ledge: Vector3)
signal wall_grabbed(normal: Vector3)
signal wall_released
signal weapons_stowed_changed(away: bool)
signal target_locked(who: Node3D)
## His guard broken under a heavy blow with too little stamina ([method _crumple]).
signal guard_broken
signal target_lost
signal arrow_loosed(power: float, damage: float, critical: bool)
## One of his arrows went into something living, on his own peer only: where,
## whether at the head, whether let go at the moment (for a blood effect to
## come; the HUD's mark there was taken off, 2026-10-05).
signal arrow_hit_felt(where: Vector3, head: bool, perfect: bool)
signal blade_planted(where: Vector3)
## A cut of the string went through nothing: its follow-through drags ([member whiff_recovery]).
signal whiffed
## The shield went into something on a charge ([method _shield_bash]).
signal bashed(who: Node3D)
## A creature's blow reached this body: what it was worth, and whether the
## shield caught it. (There is no parry: a shield only ever blocks.)
signal struck(damage: float, blocked: bool)
signal died
signal respawned
## A blow went through the roll in its first moments ([member perfect_dodge_window]).
signal perfect_dodged

enum State { GROUNDED, AIRBORNE, DASHING, DODGING, SLIDING, CLIMBING, WALLCLIMB, DOWNED }

#region Exported tuning
@export_group("Movement")
## Speed while the walk modifier is held.
@export var walk_speed: float = 3.6
## His run with no modifier held (the user's word, 2026-10-23: the pace
## Shift used to give, as his plain run, Kevin's sprint for its legs, and
## free); with Shift held he goes faster still (`sprint_share` of it), paid
## for in stamina (`sprint_stamina`).
@export var run_speed: float = 7.2
## The plain pace as a share of `run_speed` (1: the whole run; it was a jog
## at 0.66 till 2026-10-23).
@export_range(0.3, 1.0) var jog_share: float = 1.0
## Shift: this much faster than the run.
@export var sprint_share: float = 1.3
## Stamina a second the sprint costs while he is really going at it, in a
## fight or out of it. Run dry and he is winded: he runs (no faster) until it
## has come back past a fifth.
@export var sprint_stamina: float = 14.0
## The plain pace, m/s (`run_speed` x `jog_share`; kept up each tick, so a
## blessing that quickens his run quickens it).
var jog_speed: float = 4.75
## Going at a sprint this tick (the key held, moving, the stamina there).
var sprinting: bool = false
## How hard the character can change its ground velocity. High values are what
## keep a fast run from sliding on through a turn or a release.
@export var ground_acceleration: float = 60.0
@export var ground_deceleration: float = 75.0
## How much control the player keeps mid-air (0 = none, 1 = full).
@export_range(0.0, 1.0) var air_control: float = 0.35
## How fast a jump bleeds off with no stick input, in m/s². Much gentler than
## the ground figure: a jump should carry you, not stop dead in mid-air.
@export var air_drag: float = 3.0
## How fast the body turns to face its movement direction at a full run.
@export var turn_speed: float = 12.0
## Turn rate while barely moving. Higher than `turn_speed` so a standing turn
## is crisp while a sprinting one still has to carve.
@export var turn_speed_still: float = 22.0
## Tallest ledge the player walks up without jumping. CharacterBody3D has no
## built-in stair stepping, so this is resolved manually in _step_up().
@export var max_step_height: float = 0.4
## How far ahead the step-up sweep reaches. Must exceed the capsule radius or
## the sweep lands on the ledge's edge instead of its top face.
@export var step_forward_probe: float = 0.55

@export_group("Slopes")
## Speed lost running straight up a slope at the steepest walkable angle.
@export_range(0.0, 0.9) var slope_climb_penalty: float = 0.35
## Speed gained running straight down one. Kept small so downhills do not turn
## into a luge run.
@export_range(0.0, 0.9) var slope_descend_bonus: float = 0.15
## Pull down a surface too steep to stand on, in m/s². This is what stops the
## player from parking on the side of a boulder.
@export var slide_acceleration: float = 26.0
## Drag along that surface while sliding, so the slide reaches a terminal speed.
@export var slide_friction: float = 1.5

@export_group("Jump")
## Apex height in metres, converted to an impulse using the project gravity.
@export var jump_height: float = 1.05
## Gravity is multiplied by this while falling, for a snappier arc.
@export var fall_gravity_multiplier: float = 1.5
## Gravity multiplier applied while the jump button is released early.
@export var low_jump_multiplier: float = 2.0
## Grace period after walking off a ledge during which jumping still works.
@export var coyote_time: float = 0.12
## How long a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12
## Terminal velocity. Without it a long drop builds up enough speed to tunnel
## through thin floors.
@export var max_fall_speed: float = 34.0
## Landing faster than this counts as a heavy landing.
@export var hard_landing_speed: float = 14.0
## Fraction of the run that survives a heavy landing, so a big drop costs you
## some momentum instead of letting you sprint straight out of it.
@export_range(0.0, 1.0) var hard_landing_grip: float = 0.55

@export_group("Dash")
@export var dash_speed: float = 11.0
@export var dash_duration: float = 0.45
@export var dash_cooldown: float = 0.22
## Invulnerability window measured from the start of the dash.
@export var dash_iframes: float = 0.35
## Dashes are ignored while airborne when false.
@export var allow_air_dash: bool = false
## Cut the roll short when it runs into a wall rather than grinding along it.
@export var dash_cancels_on_wall: bool = true
## A second tap inside this window turns the roll into the library's dodge —
## slower, wider, and animated rather than tumbled.
@export var double_tap_time: float = 0.28
@export var dodge_duration: float = 0.7
@export var dodge_speed: float = 8.5
## Invulnerability window measured from the start of the dodge. Longer than the
## roll's, because the dodge is the deliberate, committed one.
@export var dodge_iframes: float = 0.45
## (the user's word, 2026-10-12: Elden Ring's) the evade is untouchable only
## for its first `dash_iframes` / `dodge_iframes`: what is left of it is a
## recovery a blow finds him in — a roll thrown too early is punished.
## No way pushed, the dodge button steps him back (`backstep_*`): short, a
## little untouchable, cheaper, still facing what he faced.
@export var backstep_time: float = 0.42
@export var backstep_speed: float = 6.5
@export var backstep_iframes: float = 0.2
@export var backstep_stamina: float = 12.0
## Attacking within this long of an evade's end (or pressed during it) throws
## the roll's own attack ([constant SkinnedRig.ROLL_ATTACK]): a quick thrust.
@export var roll_attack_window: float = 0.35
## An evade pressed while a blow has him reeling is kept and thrown the moment
## he has his feet again (the user's word 2026-10-13, as Souls does): if it
## comes no later than this after the reel.
@export var reel_dodge_keep: float = 0.3
## Off the ground, a blow this low (m over his feet) passes under him: his
## legs are up (Elden Ring's jump over a sweep).
@export var jump_clear_low: float = 0.55
var _backstepping: bool = false
## (the user's word, 2026-10-12: he rolled through the club, and then the
## stone it broke out of the ground caught him — no one roll could clear
## both) a blow rolled through covers the ground-shock that same creature
## breaks with it for `dodge_shock_cover` s: [method untouchable_now].
@export var dodge_shock_cover: float = 0.8
var _dodged_from: String = ""
var _dodged_at: float = -INF
var _roll_cut_asked: bool = false
## Till when a blow has him reeling (an evade pressed in it is kept).
var _reel_until: float = -INF
var _reel_dodge_asked: bool = false

@export_group("Crouch")
## Speed while crouched. Creeping is the point of it.
@export var crouch_speed: float = 1.9
## Height of the capsule while crouched.
@export var crouch_height: float = 1.15

@export_group("Slide")
## A slide has to be launched off a run; below this it would just be a squat.
@export var slide_min_speed: float = 5.0
## How much of the entry speed the slide starts with. Above 1 it is a burst.
@export var slide_boost: float = 1.12
@export var slide_duration: float = 0.85
## How fast the slide bleeds off, in m/s².
@export var slide_drag: float = 8.0
## Height of the capsule while sliding, which is what lets the player under a
## low gap. Standing back up waits until there is room again.
@export var slide_height: float = 0.9
@export var slide_cooldown: float = 0.3

@export_group("Climb")
## Ledges this far above the feet and no higher can be pulled up onto. The
## floor of the band sits above max_step_height, so anything that can simply be
## walked up is not turned into a climb.
@export var climb_min_height: float = 0.55
@export var climb_max_height: float = 1.7
## How far in front of the body the ledge is felt for.
@export var climb_reach: float = 0.75
## How long the pull-up takes. The clip is stretched to match.
@export var climb_duration: float = 0.55
## Vertical room the top of the ledge needs before it counts as somewhere to
## stand rather than a slot to be wedged into.
@export var climb_headroom: float = 1.9
## Over a thin top (a fence) rather than onto it: the height the arc clears,
## or -INF for an ordinary pull-up.
var _vault_peak: float = -INF

@export_group("Wall climb")
## Free climbing on faces too tall to be mantled — a house wall, a tower, the
## side of a boulder. Off leaves only the low pull-up.
@export var wall_climb_enabled: bool = true
## Faces steeper than this, measured from the horizontal, can be gripped. It has
## to sit above `floor_max_angle` or a walkable slope would be climbed rather
## than run up.
@export_range(0.0, 89.0) var wall_min_angle: float = 60.0
## How far in front of the chest a face is felt for.
@export var wall_grip_reach: float = 0.9
## Gap left between the capsule and the face it is hanging off. It is not just
## clearance: the body is narrow but what it carries is not, and a sword and a
## shield held against a wall go through it. The arms are solved onto the face,
## so hanging further off it costs nothing — the hands still land on the stone.
@export var wall_gap: float = 0.18
## Climbing pace up and down a face.
@export var wall_climb_speed: float = 2.1
## Pace sideways along one, which is quicker: a climber shuffles faster than
## they haul themselves upwards.
@export var wall_shimmy_speed: float = 2.4
## How fast the body swings round and settles against a face as it changes.
@export var wall_settle_speed: float = 14.0
## Push-off away from the face when jumping off it.
@export var wall_jump_back: float = 5.0
@export var wall_jump_up: float = 6.0
## How much wall there has to be above the grip before climbing is worth
## starting. Anything shorter is a mantle, and mantling is always tried first.
@export var wall_min_face: float = 1.0
## How long after letting go the face is ignored, so a jump off it is not
## caught by the same wall on the way past.
@export var wall_regrab_delay: float = 0.35

@export_group("PvP")
## His side in PvP: heroes of the same side never hurt each other; 0 is a side
## of his own (against everyone).
@export var team: int = 0
## What his blow on another hero is worth, as a share of what it is worth on a
## creature: a hero's numbers are made for orcs and wolves, and whole they would
## end a duel in two cuts.
@export_range(0.05, 2.0, 0.05) var pvp_damage_scale: float = 0.5
## Whether heroes may hurt each other at all (the whole game's; `-- --pvp` on
## the command line turns it on).
static var pvp_mode: bool = false

@export_group("Target lock")
## How far off a target can be taken.
@export var lock_range: float = 26.0
## And how far round from where the camera is looking, in degrees. Wide, because
## the point of the button is not having to aim it.
@export_range(0.0, 180.0) var lock_cone: float = 70.0
## How much further than `lock_range` a target may get before it is let go. The
## gap between the two is what stops a lock flickering at the edge of its reach.
@export var lock_break_range: float = 34.0
## How fast the camera swings round onto a target and then keeps it there.
@export var lock_camera_speed: float = 6.0
## How far the mouse has to be swept sideways to change target, in pixels. Big
## enough that aiming never does it by accident.
@export var target_switch_flick: float = 240.0
## How far above the target the camera rides while locked, in degrees. Looking
## *down* on a fight is what shows the ground between the two of you; aimed flat
## at a target, that ground is a sliver and everything reads as a silhouette.
@export_range(0.0, 60.0) var lock_camera_tilt: float = 14.0
## Locked, the camera kept at least this high over his feet (m), however
## high the point it looks at.
@export var lock_camera_floor: float = 0.7
## How fast the body turns to face one. Quicker than a running turn: facing the
## thing you are fighting is not something to carve into.
@export var lock_turn_speed: float = 16.0
## Whether running while locked turns the body the way it is going, instead of
## strafing round the target. Backing straight off still watches the target —
## walking away from something is not the same as breaking off from it.
@export var lock_run_turns: bool = true

@export_group("Commitment")
## Once a swing or a shot is thrown, nothing else runs until it is finished: no
## dodge, no jump, no second attack, no cancelling out of it. This is the whole
## of what makes a fight a series of decisions rather than a mash — an attack
## that can be called off mid-swing costs nothing to start.
@export var attacks_commit: bool = true
## How much of the run survives the commitment. Not zero: a swing that nails the
## feet to the floor reads as a cutscene. Elden Ring lets the step-through carry
## you, and no more than that.
@export_range(0.0, 1.0) var commit_speed_scale: float = 0.18
## How long after the string goes before anything else may be done, in seconds —
## the archer's equivalent of a swing's recovery.
@export var loose_recovery: float = 0.34
## How long an attack pressed during one already running is remembered for, so
## the next swing comes out the moment this one ends rather than being eaten.
@export var attack_buffer_time: float = 0.22
## How long the blade stays in the ground at the end of a jumping attack, in
## seconds. This is the price of the move: a plunge that ends with the character
## on his feet and ready costs nothing, so there would be no reason ever to
## throw anything else — and nothing for an opponent to punish.
@export var plunge_recovery: float = 0.85
## How far in front of the feet the blade goes in, in metres, and how wide the
## dirt it throws up is.
@export var plunge_reach: float = 0.36
@export var plunge_dust: float = 1.0
## How long after the last cut a flurry is still running, in seconds. Inside it
## the next swing is a follow-up and is slowed; outside it the next swing is a
## first one again and keeps its run.
@export var chain_window: float = 0.5

@export_group("Bow")
## How much of the run survives while the string is being held. An archer at a
## full sprint cannot aim, and being able to would make every other approach
## pointless.
@export_range(0.1, 1.0) var draw_speed_scale: float = 0.55
## Where the arrow leaves from, measured up the body, when the rig has no
## arrow on the string to say where it is.
@export var arrow_height: float = 1.35
## A string let go in the moment after the full draw has settled (the rig's
## `release_grade()` 1) is worth this much more; held past it, the bow shakes and
## the shot wanders up to `release_spread` degrees either way, by how hard.
@export var perfect_release_bonus: float = 1.6
@export var release_spread: float = 5.0
## Where the camera settles while the string is held, in degrees below level.
##
## The running camera sits twenty degrees above the player looking down, which
## puts the middle of the screen — the crosshair — on the ground a few metres
## ahead. Shot from there an arrow noses straight into the dirt at your feet,
## which reads as no arrow at all. Aiming brings the view towards level; the
## mouse still moves it from there.
@export_range(-40.0, 40.0) var aim_camera_pitch: float = -4.0
## How fast it comes up, and back down again once the string is loosed.
@export var aim_camera_speed: float = 6.0
## The view closes in as the string comes back (AVTANDIL_POLISH 5): this many
## degrees off the field of view at full draw, eased in and back out.
@export var draw_zoom_degrees: float = 7.0
@export var draw_zoom_speed: float = 5.0
var _fov_rest: float = -1.0
var _draw_zoom_now: float = 0.0
## Ground closer than this under the crosshair is not what the player is
## shooting at — it is the ground they are standing on.
@export var aim_min_range: float = 6.0
## How far a shot drops, as a share of the world's gravity. Arrows are fast and
## an arc the player cannot read is not a skill shot, it is a guess.
@export_range(0.0, 1.0) var arrow_drop: float = 0.35
@export var arrow_scene: PackedScene

@export_group("Vitals")
## Stamina won back a second, once `stamina_delay` has passed since any was
## spent. Holding the shield up slows it to `stamina_regen_guarded`.
@export var stamina_regen: float = 40.0
@export var stamina_regen_guarded: float = 12.0
@export var stamina_delay: float = 0.55
## Run it all the way out and it waits this long instead before it starts back.
@export var stamina_empty_delay: float = 1.1
## Stamina a blow caught on the shield costs, per point of the blow's damage.
@export var block_stamina: float = 2.4
## What a blow on the tower shield costs, as a share of what the round one pays.
@export_range(0.1, 1.0) var tower_block_share: float = 0.55
## Held this long when a blow breaks the guard (the shield taken with no
## stamina left to hold it).
@export var guard_break_time: float = 0.9
## How long the body lies there after falling before it is back on its feet at
## the start, in seconds.
@export var respawn_time: float = 4.0
## A blow that arrives within this long of a roll starting is dodged
## **perfectly**: the body leaves a shadow trail for a second
## ([ShadowTrail]) and the roll's stamina comes back.
@export var perfect_dodge_window: float = 0.3
## The critical (the user's pick, 2026-10-10, Elden Ring's): one of the big
## ones down on its knee within `crit_reach` m (at the ogre's size) in front
## of it, the attack is the critical — he is put before it and leaps, driving
## the blade down into it (the whole jump attack, `crit_time` s; the blade in
## at `crit_hit_at` of it), worth `crit_power` of a cut on top of its own
## `stance_crit`. Nothing lands on him through it.
@export var crit_reach: float = 3.2
@export var crit_time: float = 1.25
@export var crit_hit_at: float = 0.62
@export var crit_power: float = 1.5
@export_group("Flasks")
## The flasks he carries into a fight (the user's word, 2026-10-12: a fight
## that is hard to die in needs something to manage — Elden Ring's flask):
## `flask_count` of them, each mending `flask_heal` of his whole health. The
## drink (`Consume`, `flask_rate`) roots him to a walk and cannot be rolled
## out of; the health comes at `flask_heal_at` of it, and a blow that lands
## before that spills it — the flask is gone all the same. All of them
## again when he gets up after a death ([method _respawn]).
@export var flask_count: int = 4
@export var flask_heal: float = 0.4
@export var flask_rate: float = 1.0
@export var flask_heal_at: float = 0.65
const FLASK_CLIP := &"Consume"
## The flasks he has left.
var flasks_left: int = 4
## On the clock `_now()` reads: while he drinks, and when the health comes
## (below 0: none coming).
var _drink_until: float = -100.0
var _drink_heal_at: float = -1.0
@export_group("Vitals")
## Until there are potions and a fire to rest at, health comes back slowly on
## its own once nothing has hurt him for `mend_after` seconds.
@export var mend_after: float = 10.0
@export var mend_rate: float = 4.0
## Hurt but never killed: health stops at 1. For tests that are about
## something other than dying.
@export var immortal: bool = false
## Nothing in his hands (the story's start, until Datvi gives him arms,
## [Intro]): he runs, jumps, evades and crouches, but has nothing to cut,
## shoot or raise, and no skills.
var unarmed: bool = false
## Physical and magical defence (p.def, m.def), from the profile ([Defence]).
var p_def: float = 0.0
## What the dungeon's blessings make of his cuts and of the blows he takes
## ([Boons]): shares, 1 for none.
var dealt_scale: float = 1.0
var taken_scale: float = 1.0
var m_def: float = 0.0

@export_group("Physics")
## Impulse scale applied to loose rigid bodies the capsule walks into. Zero
## makes the player pass them by without disturbing them.
@export var push_force: float = 2.5

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false
@export_range(-89.0, 0.0) var min_pitch_deg: float = -60.0
@export_range(0.0, 89.0) var max_pitch_deg: float = 60.0
## Height of the camera pivot above the player's feet.
@export var camera_height: float = 1.5
## Higher values make the camera stick to the player more rigidly.
@export var camera_follow_speed: float = 22.0
## How far the view stands off him, and how much further on a great foe (one
## locked on, or a boss roused near him), so the whole of it is in the view
## (the user's word, 2026-10-22: a wider view on a boss).
@export var camera_reach: float = 4.5
@export var camera_reach_big: float = 2.6
## Pulled in by a wall it comes in at once; past it, it eases back out at
## this pace (m/s) rather than jumping.
@export var camera_out_speed: float = 3.5
## The arm is a ball of this radius swept out from him, not a thin ray: the
## view never comes so near a wall that it sees through it.
@export var camera_probe: float = 0.35
var _arm_len: float = 4.5
var _big_view: float = 0.0
var _big_seen_at: float = -10.0
var _big_near: bool = false
#endregion

@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
## The model and its procedural animation, built in _ready() from whichever
## character is being played. Not `@onready`, because there is nothing under
## Visuals until the profile says what should be: the controller is the same
## code for all of them and the character is the thing that varies.
var rig: CharacterRig
## Draws the model between physics ticks, so a run does not judder ([VisualSmoother]).
var _smoother: VisualSmoother
## Footfall sounds off the rig's feet (`Footsteps`); null on a rig with no skeleton.
var footsteps: Footsteps
## How deep he stands in water, 0 (dry) to 1 (to the knee): set each frame by
## whatever the water is ([SwampWade]); it slows him.
var wade: float = 0.0
## His pace at the deepest wade, as a share of what it would be.
@export_range(0.2, 1.0) var wade_speed_scale: float = 0.62
## Who is being played. Taken from the Game autoload on spawn unless something
## has set it first, which is what the tests do.
var profile: CharacterProfile
@onready var _collider: CollisionShape3D = $CollisionShape3D

var state: State = State.AIRBORNE
var is_invulnerable: bool = false
## Until when (in [method _now] seconds) no blow lands: the whole length of an
## evade — even one cut short by running into a wall or a body. (A perfect
## dodge's shadow no longer stretches it, 2026-10-10.)
var _safe_until: float = 0.0
## Health and stamina, taken from the profile on spawn. Everything that hurts or
## tires the body goes through [method _take_damage] and [method _spend].
var health: float = 120.0
var max_health: float = 120.0
## Every skill's cooldown times this (a dungeon's reward makes it shorter).
var skill_haste: float = 1.0
var stamina: float = 100.0
var max_stamina: float = 100.0
## Fallen, and waiting to be put back at the start.
var is_dead: bool = false
var _stamina_wait: float = 0.0
var _winded: bool = false
var _since_hurt: float = 0.0
var _respawn_left: float = 0.0
var _spawn_point: Vector3 = Vector3.ZERO
var _spawn_known: bool = false
## When the shield last came up, in seconds of engine time.
var _guard_raised_at: float = -100.0
## When the current roll started, and whether it has already been perfect.
var _evade_started_at: float = -100.0
var _evade_was_perfect: bool = false
## The critical under way: on whom, how long it has left, whether the blade
## has gone in, and where he was put to deal it.
var _crit_on: Node3D = null
## In a creature's grip (the ogre's, 2026-10-11): who holds him, how long
## still (s), where he was caught from; how many times (for a test).
var _held_by: Node3D = null
var _held_left: float = 0.0
var _held_from: Vector3 = Vector3.ZERO
var _held_time: float = 0.0
var grabbed_count: int = 0
var _crit_left: float = 0.0
var _crit_struck: bool = false
var _crit_from := Vector3.ZERO
var crits_dealt: int = 0
var _hud: PlayerHud
var _inventory: Inventory
## Which shield is carried ([enum Inventory.Shields]). Only the round one
## parries; the tower one blocks for less stamina.
var shield_kind: int = Inventory.Shields.ROUND
## Which of his outfits he wears: an index into the rig's `garbs` (0 for a
## hero who has only the one).
var garb: int = 0
## Which of the rig's hair he wears (see `set_hair()`), picked on the hero select.
var hair: int = 0
## And which of its faces (see `set_face()`).
var face: int = 0
## And the colour its clothes are dyed (see `set_tint()`).
var tint: int = 0
## And the look made on the hero select, worn with the face YOUR OWN (see
## `set_look()`, [PolysplitLook]).
var look: Dictionary = {}
## True while a screen of his own (the inventory, the big map) is open: the
## body stands still and takes no buttons.
var menu_open: bool = false
## True while the block button is held and the shield is up.
var is_blocking: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _jump_velocity: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _was_on_floor: bool = true
## Until when a landing makes no sound of its own (the knight's leap comes
## down with his blade, which has its own: not the body's thump and then the
## blade's, the user's word 2026-10-06).
var _quiet_landing_until: float = -100.0
## Fastest the player may travel horizontally while airborne: whatever it left
## the ground with. Air control steers the jump, it does not accelerate it.
var _air_speed_cap: float = 0.0
## Downward speed going into the last move, kept so the landing knows how hard
## it was — move_and_slide() has already flattened velocity by then.
var _impact_speed: float = 0.0
## Normal of the steepest un-standable surface touched last tick, if any.
var _steep_normal: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
## When the dash button was last pressed, so a second tap can be told from a
## first one.
var _last_dash_press: float = -100.0
## A press of the dash while an evade is still going: the next one, started
## the moment this one ends.
var _evade_queued: bool = false
## How many evades in a row so far (0 for the first). The assassin steps on the
## even ones and flips on the odd.
var _evade_chain: int = 0
## Until when a fresh press still counts as following on from the last evade,
## rather than starting a new run of them after the cooldown.
var _chain_open_until: float = -100.0
## After an evade ends, how long a press still chains on from it.
@export var chain_grace: float = 0.25
var _crouching: bool = false
var _slide_timer: float = 0.0
var _slide_cooldown_timer: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0
## Standing height of the capsule and where its centre sits, so the slide can
## put both back when there is room again.
var _stand_height: float = 0.0
var _stand_centre: float = 0.0
## Radius of the capsule, which is what decides how far off a face the body
## hangs while climbing it.
var _stand_radius: float = 0.4
var _climb_timer: float = 0.0
var _climb_from: Vector3 = Vector3.ZERO
var _climb_to: Vector3 = Vector3.ZERO
## Outward normal of the face being climbed, and the point on it the chest is
## holding onto.
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_point: Vector3 = Vector3.ZERO
## Smoothed climbing input, so the reaches do not snap when the stick does.
var _wall_drive: Vector2 = Vector2.ZERO
var _wall_cooldown_timer: float = 0.0
## What is being fought, if anything. Everyone can hold a target; what they do
## with it is the difference between a sword and a bow.
var target: Node3D = null
## The dot over whatever is being fought.
var _marker: TargetMarker
## Mouse travel banked towards changing target.
var _flick: float = 0.0
var _flick_up: float = 0.0
## Which part of the target the lock is on, lowest first (see [TargetPoints]).
var target_part: int = 0
## How long the string has been held, and whether it is being held at all.
var _draw_timer: float = 0.0
var _drawing: bool = false
const DRAW_SOUND := "res://unverified/sounds/bow/draw_2.wav"
const RELEASE_SOUND := "res://unverified/sounds/bow/release_2.wav"
## The other string's snap, a little louder as recorded (AVTANDIL_POLISH 5):
## the two taken in turn at random, so shot after shot is not one recording.
const RELEASE_SOUND_2 := "res://unverified/sounds/bow/release.wav"
## The Piercing Arrow's own (the user's recordings in sounds/bow): the cast as
## the draw starts, the swell through the hold, the shot, and the wind after.
const ULT_CAST := "res://sounds/bow/ult_cast.wav"
const ULT_CHARGE := "res://sounds/bow/ult.wav"
const ULT_SHOT := "res://sounds/bow/ult-shoot-1.wav"
const ULT_WIND := "res://sounds/bow/last-ult.wav"
## Levitation left in this jump, in seconds, and whether it is being used now.
var _levitate_left: float = 0.0
var _levitating: bool = false
var _shot_timer: float = 0.0
var _shot_rng := RandomNumberGenerator.new()

## Mirrors of internal state, published for the synchronizer.
##
## Written by the authority at the end of its own frame and read by everyone
## else, because a body somebody else is driving takes no physics ticks here and
## so knows none of this first hand. Public and plainly named on purpose: the
## replication list in `player.tscn` has to be readable, and `_crouching` and
## `state` are this class's own business.
var net_state: int = 0
var net_blocking: bool = false
## How many skills he has used (carried to every peer, so the host's
## creatures see a cast: the ogre punishes it, 2026-10-11).
var net_casts: int = 0
var net_crouching: bool = false
var net_airborne: bool = false
var net_stowed: bool = false
## How far the string is back and where it is pointed. Without these a remote
## archer stands with his bow down and an arrow simply appears — the draw is
## worked out in `_tick_bow()`, which is physics, which a body somebody else is
## driving never runs.
var net_draw: float = 0.0
var net_aim: float = 0.0
## Health as a share of the whole, and whether he is down for good: creatures
## on the host leave a fallen player alone.
var net_health: float = 1.0
var net_dead: bool = false
var net_shield: int = 0
## Which of the rig's outfits is on (see `set_garb()`), for the other peers.
var net_garb: int = 0
## Which of the rig's hair is on, for the other peers.
var net_hair: int = 0
## Which of its faces, for the other peers.
var net_face: int = 0
## And the dye on its clothes.
var net_tint: int = 0
## And the look made on the hero select, as [method PolysplitLook.to_wire]
## writes it ("" for none).
var net_look: String = ""
## The `net_look` last put on the rig, so it is only worn again when it changes.
var _net_look_worn: String = ""
## The state last shown of somebody else's body, for the moves that start on a
## change of it (taking hold of a wall, a pull-up): see `_show_net_climb()`.
var _net_state_shown: int = -1
## How long is left of the attack currently being committed to, and an attack
## pressed while it runs, waiting for it to end.
var _commit_timer: float = 0.0
## Until when the blade is being coated: he walks through it (see `_poison_blade()`).
var _coat_until: float = -100.0
## Until when a spell's gesture holds him to a walk, legs walking under it
## (the elf's Frost Spears: [MageSkills]), on the clock `_now()` reads.
var cast_walk_until: float = -100.0
## While above 0 he stands where he is (a skill shot being drawn and loosed).
var _root_timer: float = 0.0
## The draw's creak while the string comes back: cut off the moment the draw
## ends, however it ends (loosed, let down, rolled out of, hit).
var _draw_sound: AudioStreamPlayer3D = null
## What the Piercing Arrow was drawn at: he turns with it until the release.
var _pierce_quarry: Node3D = null
## Bumped whenever a skill under way is cut short: each skill's steps (on every
## peer) check it after every wait and stop if it has moved on.
var _skill_serial: int = 0
var _air_swirl: Node3D = null
var _attack_buffer: float = 0.0
## A heavy blow asked for during a swing, as `_attack_buffer` is for a cut.
var _heavy_buffer: float = 0.0
## The buffered cut is from the other string (the block button, no shield in
## hand: [method _other_string_ready]).
var _buffer_other: bool = false
## How many cuts into the current flurry, and whether *this* one keeps its run.
## The first swing does; the ones chained off it do not.
var _swing_chain: int = 0
var _free_swing: bool = false
## When the swing in hand was thrown, and how long the run a first cut is
## thrown out of lasts under it before it is down to the swing's pace.
var _swing_t0: float = -100.0
## Game seconds, ticked with the body ([member _swing_t0] and the wound-up
## cut are timed on it: what is timed against what the clip and the body do).
var _game_t: float = 0.0
@export var free_swing_ease: float = 0.3
## The ease of the swing in hand: `free_swing_ease`, or `run_cut_ease` for a cut out of a run.
var _free_ease: float = 0.3
## True while a cut thrown in the air still owes the ground its landing.
var _plunging: bool = false
## How long is left before a flurry is considered over and the next swing counts
## as a first one again.
var _chain_timer: float = 0.0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--pvp"):
		pvp_mode = true
	_spawn_character()
	# The bow's two sounds, read off the disk now rather than on the first draw.
	Sfx.warm([DRAW_SOUND, RELEASE_SOUND, PARRY_SOUND, SHADOW_SOUND, ULT_CAST, ULT_CHARGE, ULT_SHOT,
			ULT_WIND] + MOVE_SOUNDS + Arrow.HITS)
	# The level has just loaded, so this is the moment the graphics setting has
	# something to be applied to. The world knows nothing about settings; the
	# thing that spawns into it asks for them.
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.call_deferred("apply_graphics")
	_jump_velocity = sqrt(2.0 * _gravity * jump_height)
	_air_speed_cap = run_speed

	# The capsule is resized by the slide, so it must not be shared with anything
	# else that happens to instance this scene.
	var capsule := _collider.shape as CapsuleShape3D
	if capsule != null:
		_collider.shape = capsule.duplicate()
		_stand_height = capsule.height
		_stand_centre = _collider.position.y
		_stand_radius = capsule.radius

	# Snap far enough to hug the stairs on the way down, matching the step-up.
	floor_snap_length = maxf(floor_snap_length, max_step_height)
	# Hold the run speed while climbing or descending a ramp instead of letting
	# the solver trade it for height, then layer our own slope cost on top.
	floor_constant_speed = true
	# Stop a wall from acting as a ramp when it is hit at a shallow angle, and
	# keep glancing hits sliding instead of catching.
	floor_block_on_wall = true
	wall_min_slide_angle = deg_to_rad(12.0)
	slide_on_ceiling = true
	# Room for a few contacts: floor plus wall plus a step edge in one tick.
	max_slides = 6
	safe_margin = 0.002
	# Leaving a moving platform hands its velocity over, but only upwards, so
	# riding one sideways does not fling the player.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY

	# The camera rig lives in world space so that rotating the body never
	# drags the camera with it. It is re-positioned every frame in _process().
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3.UP * camera_height

	# Stop the spring arm from colliding with our own capsule.
	spring_arm.add_excluded_object(get_rid())
	# a ball, not a ray, swept out along it
	var probe := SphereShape3D.new()
	probe.radius = camera_probe
	spring_arm.shape = probe
	spring_arm.margin = 0.12
	_arm_len = camera_reach
	spring_arm.spring_length = camera_reach

	# Whose body is this?
	#
	# Every peer builds every player, so all four of these exist in all four
	# windows — but only one of them in each is *driven*. Turning the physics
	# callback off is what makes the other three inert, and it is the whole of
	# it: every `Input.` call in this file is reached from `_physics_process`,
	# so none of them runs for a body that is not yours. One line, and nothing
	# to forget at the twentieth call site.
	#
	# `_process` stays on for everyone — that is what animates the others.
	var mine := is_multiplayer_authority()
	camera.current = mine
	set_physics_process(mine)
	set_process_unhandled_input(mine)
	if mine:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_hud = PlayerHud.new()
		_hud.name = "Hud"
		_hud.player = self
		add_child(_hud)
		_inventory = Inventory.new()
		_inventory.name = "Inventory"
		_inventory.player = self
		add_child(_inventory)
		var chart := WorldMap.new()
		chart.name = "Map"
		chart.player = self
		add_child(chart)
		var book := SkillBook.new()
		book.name = "SkillBook"
		book.player = self
		add_child(book)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Locked on, the camera belongs to the target and the mouse is free to
		# say *which* target: a flick to one side takes the next enemy that way.
		# Accumulated rather than read per event, so it takes a deliberate sweep
		# and not the twitch of aiming.
		if target != null:
			_flick += motion.relative.x
			if absf(_flick) > target_switch_flick:
				_switch_target(signf(_flick))
				_flick = 0.0
				_flick_up = 0.0
			# Up and down moves the lock along a big creature: legs, belly, head.
			_flick_up -= motion.relative.y
			if absf(_flick_up) > target_switch_flick * 0.6:
				_switch_part(int(signf(_flick_up)))
				_flick_up = 0.0
			return
		camera_rig.rotate_y(-motion.relative.x * mouse_sensitivity)
		camera_rig.rotation.y = wrapf(camera_rig.rotation.y, -PI, PI)

		var pitch_delta := -motion.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x + (pitch_delta if not invert_y else -pitch_delta),
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		return

	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	# The string (Tariel's): F6 goes to the other.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F6 \
			and rig != null and rig.has_method(&"cycle_string"):
		var named: String = rig.call(&"cycle_string")
		if named != "":
			_toast("სერია:  %s   (F6 შეცვლა)" % named)


var _toast_label: Label


## A line of text at the top of the screen for a couple of seconds.
func _toast(text: String) -> void:
	if _toast_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_toast_label = Label.new()
		_toast_label.add_theme_font_size_override("font_size", 28)
		_toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_toast_label.add_theme_constant_override("outline_size", 8)
		_toast_label.position = Vector2(40, 90)
		layer.add_child(_toast_label)
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(2.5)
	fade.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


## Split in two: the camera is only your own body's business, the animation is
## everybody's. A knight standing in someone else's window has no physics ticks
## of its own — its position and velocity arrive over the wire — so the rig is
## driven from the replicated mirrors rather than from anything it works out
## for itself.
func _process(delta: float) -> void:
	if _held_by != null and is_multiplayer_authority():
		_hang()
	var mine := is_multiplayer_authority()
	if mine:
		# Smooth follow keeps the camera stable even though the body only moves
		# on physics ticks. Framerate-independent exponential damping.
		# Following where the body is *drawn*: the body itself only moves on
		# physics ticks, and a camera chasing those steps makes the world judder.
		var at := _smoother.drawn_at() if _smoother != null else global_position
		var follow := at + Vector3.UP * camera_height
		var follow_speed := camera_follow_speed
		if _now() < _glide_until:
			# a skill that moved him at once (the Shadow Step): the view glides
			# after him and swings round behind him, not a cut
			follow_speed = minf(follow_speed, glide_follow_speed)
			camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, _glide_yaw,
					1.0 - exp(-glide_turn_speed * delta))
		var weight := 1.0 - exp(-follow_speed * delta)
		camera_rig.global_position = camera_rig.global_position.lerp(follow, weight)
		_tend_arm(delta)
		_publish_net_state()

	# Somebody else's charge, as his body comes over the wire (his own is
	# ticked on the body's own clock, in `_physics_process`).
	if not mine:
		_tick_bash(delta)
		_tick_kick(delta)
	if rig == null:
		return
	if not mine and rig.has_method(&"set_shield") and int(rig.get(&"shield_kind")) != net_shield:
		rig.call(&"set_shield", net_shield)
	if not mine and rig.has_method(&"set_garb") and int(rig.get(&"garb")) != net_garb:
		rig.call(&"set_garb", net_garb)
	if not mine and rig.has_method(&"set_face") and int(rig.get(&"face")) != net_face:
		rig.call(&"set_face", net_face)
	if not mine and rig.weapons_stowed() != net_stowed:
		rig.stow_weapons(net_stowed)
	if not mine and rig.has_method(&"set_hair") and int(rig.get(&"hair")) != net_hair:
		rig.call(&"set_hair", net_hair)
	if not mine and rig.has_method(&"set_tint") and int(rig.get(&"tint")) != net_tint:
		rig.call(&"set_tint", net_tint)
	if not mine and rig.has_method(&"set_look") and net_look != _net_look_worn:
		_net_look_worn = net_look
		rig.call(&"set_look", PolysplitLook.from_wire(net_look))
	if state == State.WALLCLIMB:
		rig.climb_drive(_wall_drive, velocity.length(), _wall_hold_distance())
	if not mine:
		_show_net_climb()
	# `velocity` is replicated, so the pace is right for everyone. `is_on_floor()`
	# is not: it is the answer from a physics tick this body never took.
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var airborne := not is_on_floor() if mine else net_airborne
	var dashing := (state if mine else net_state) == State.DASHING
	# Somebody else's archer draws from the replicated numbers. His own
	# `_tick_bow()` is physics and never runs here.
	if not mine:
		# Either archer rig — the procedural one or the skinned one — takes this.
		if rig.has_method(&"aim_bow"):
			rig.call(&"aim_bow", net_draw, net_aim)
	_aim_strike()
	_lean(delta, planar, airborne or (state if mine else net_state) != State.GROUNDED)
	rig.animate(delta, planar, planar / maxf(walk_speed, 0.01), airborne,
			dashing, velocity.y, is_blocking if mine else net_blocking)
	if footsteps != null:
		var climbing := (state if mine else net_state) == State.WALLCLIMB
		footsteps.tick(delta, planar, not airborne and not dashing and not climbing, self)


## The body leant into what it is doing, over its feet: into a turn the
## faster and tighter it carves, forward as a run picks up, back as it pulls
## up. Laid on the model's own transform (the capsule stays upright), worked
## out from the turning and the replicated velocity, so every peer sees it.
func _lean(delta: float, planar: float, off_ground: bool) -> void:
	PlayerMove._lean(self, delta, planar, off_ground)


## Launched head over heels ([method net_tumble], the troll's tree, the
## user's word 2026-10-25: thrown back and turned over in the air): the model
## turned over backwards about his middle while he is off the ground, the
## turn finished quickly as he comes down; on every peer.
var _tumble_on: bool = false
var _tumble_angle: float = 0.0
var _tumble_rest_pos: Vector3 = Vector3.ZERO
var _tumble_rest_got: bool = false
const TUMBLE_SPEED := 7.5
const TUMBLE_PIVOT := Vector3(0.0, 0.95, 0.0)


@rpc("authority", "call_local", "reliable")
func net_tumble(on: bool) -> void:
	_tumble_on = on
	_tumble_angle = 0.0


@export_group("Lean")
## Radians of lean into a turn per (radian a second of turning × metre a
## second of pace), and the most it leans.
@export var turn_lean_rate: float = 0.0085
@export var turn_lean_max: float = 0.2
## Radians of lean per m/s² of picking up (forward) or pulling up (back).
@export var pace_lean_rate: float = 0.0032
@export var pace_lean_max: float = 0.1
@export var pace_lean_back: float = 0.13
## How fast the lean follows what it is asked for (1/s).
@export var lean_follow: float = 9.0
## The forward-and-back lean's spring: how hard it is pulled to what it is
## asked for, and how much the rocking is damped (under 2·√stiffness rocks).
@export var pace_sway_stiffness: float = 110.0
@export var pace_sway_damping: float = 13.0
## Pace (m/s) a stop or a turn back must come out of to kick up dust, how hard
## it must brake (m/s²), and the size of the puff.
@export var skid_pace: float = 4.5
@export var skid_brake: float = 35.0
@export var skid_dust: float = 0.45
@export_group("")

var _lean_ready := false
var _lean_rest := Basis.IDENTITY
var _lean_yaw := 0.0
var _lean_vel := Vector3.ZERO
var _lean_roll := 0.0
var _lean_pitch := 0.0
var _lean_pitch_speed := 0.0
var _lean_prev_flat := Vector3.ZERO
var _lean_prev_dir := Vector3.FORWARD
var _skid_at := -100000


## Somebody else's climb, as he climbs it (the user's word, 2026-10-22: the
## other player did not see the wall climb). His own wall_climb()/climb() are
## called from his physics, which runs only on his machine; here they follow
## the replicated state, and the drive on the wall (sideways, up) is read off
## his replicated velocity in his own frame (he faces the wall).
func _show_net_climb() -> void:
	PlayerClimb._show_net_climb(self)


## Copies the parts of the internal state that other peers have to see into the
## plain vars the synchronizer carries. Called once a frame by the authority and
## by nobody else.
func _publish_net_state() -> void:
	net_state = state
	net_blocking = is_blocking
	net_crouching = _crouching
	net_airborne = not is_on_floor()
	net_stowed = weapons_stowed()
	net_draw = draw_power() if _drawing else 0.0
	net_aim = _aim_pitch() if has_bow() else 0.0
	net_health = health / maxf(max_health, 1.0)
	net_dead = is_dead
	net_shield = shield_kind
	net_garb = garb
	net_hair = hair
	net_face = face
	net_tint = tint
	net_look = PolysplitLook.to_wire(look)


func _physics_process(delta: float) -> void:
	if not _spawn_known and is_on_floor():
		# Wherever the body first stands is where it comes back to.
		_spawn_known = true
		_spawn_point = global_position
	_game_t += delta
	_tick_timers(delta)
	_tick_charge()
	_tick_heavy_charge(delta)
	_tick_shade(delta)
	_track_sure(delta)
	_judge_whiff()
	_watch_pvp_blades()
	_tick_bash(delta)
	_tick_kick(delta)
	_tick_vitals(delta)
	_tick_combat(delta)
	_track_target(delta)
	_track_pierce(delta)
	if has_bow():
		_tick_bow(delta)
		_level_camera(delta)
		_draw_zoom(delta)

	# A pull-up is played out by hand: the body is carried along an arc that no
	# amount of velocity would produce, so nothing else runs while it does.
	if state == State.CLIMBING:
		_process_climb(delta)
		return

	# Hanging off a face is its own kind of movement — no gravity, no friction,
	# and the surface rather than the camera decides which way is forward — so it
	# runs its own move rather than falling through to the walking one.
	if state == State.WALLCLIMB:
		_process_wall_climb(delta)
		return

	# Knocked flat: no walking, no swinging, nothing but lying there — or rolling
	# out of it.
	if state == State.DOWNED:
		_process_downed(delta)
		return

	# Held up in a creature's grip: carried by its hand till it lets go.
	if _held_by != null:
		_process_held(delta)
		return

	# A zombie's hands on him: held where he stands till he works free
	# ([method _process_seized]), then the hilt into it and the cut.
	if seized_by != null and _process_seized(delta):
		return
	if _shove_left > 0.0:
		_process_shove(delta)
		return

	# The critical is played out by hand too: put before it, the leap, the
	# blade in.
	if _crit_left > 0.0:
		_process_riposte(delta)
		return

	_take_back_push()
	_read_actions()

	if state == State.DASHING or state == State.DODGING:
		_process_dash(delta)
	elif state == State.SLIDING:
		_process_slide(delta)
	else:
		_process_locomotion(delta)

	_carry_push(delta)
	_slide_off_steep_ground(delta)
	velocity.y = maxf(velocity.y, -max_fall_speed)
	_impact_speed = maxf(-velocity.y, 0.0)

	_step_up(delta)
	move_and_slide()
	_resolve_contacts()
	_slip_off_creatures()
	_update_floor_state()


#region Character
## Hangs the chosen character's model under the body and takes their numbers.
##
## The controller is one piece of code for every character; what differs between
## them is a model, a weapon and a handful of figures. Keeping that in a profile
## resource rather than in four copies of this script is what makes the fourth
## character a file rather than a fork.
func _spawn_character() -> void:
	if profile == null:
		var game := get_node_or_null("/root/Game")
		profile = game.profile() if game != null else null
	if profile == null or profile.visuals == null:
		push_error("Player: no character to spawn.")
		return

	var body: Node3D = profile.visuals.instantiate()
	body.name = "Visuals"
	add_child(body)
	rig = body as CharacterRig
	_smoother = VisualSmoother.attach(self, body)
	if rig != null and rig.has_signal(&"slammed"):
		rig.connect(&"slammed", _on_slammed)
	if rig != null and rig.has_signal(&"struck_ground"):
		rig.connect(&"struck_ground", _on_struck_ground)
	if rig != null and rig.has_signal(&"wound_up"):
		rig.connect(&"wound_up", _on_wound_up)
	# His own body wears the hair picked on the hero select; everybody else's
	# comes from `net_hair`.
	var chooser := get_node_or_null("/root/Game")
	if chooser != null and is_multiplayer_authority() and chooser.has_method(&"hair"):
		# the look before the face, so YOUR OWN comes up as it was made
		if chooser.has_method(&"look"):
			var made: Dictionary = chooser.call(&"look", chooser.call(&"character"))
			# what he had on in the last level, if anything, over the made look
			var worn: Dictionary = chooser.call(&"worn", chooser.call(&"character")) if chooser.has_method(&"worn") else {}
			if worn.has("look") and not (worn["look"] as Dictionary).is_empty():
				made = worn["look"]
			set_look(made)
			if int(worn.get("garb", -1)) >= 0:
				set_garb.call_deferred(int(worn["garb"]))
		set_face(int(chooser.call(&"face", chooser.call(&"character"))))
		set_hair(int(chooser.call(&"hair", chooser.call(&"character"))))
		if chooser.has_method(&"tint"):
			set_tint(int(chooser.call(&"tint", chooser.call(&"character"))))
	footsteps = Footsteps.new()
	footsteps.name = "Footsteps"
	add_child(footsteps)
	if not footsteps.attach(body):
		footsteps.queue_free()
		footsteps = null

	run_speed = profile.run_speed
	walk_speed = profile.walk_speed
	# creeping is slower than walking, whatever the walk
	crouch_speed = minf(crouch_speed, walk_speed * 0.75)
	jog_speed = run_speed * jog_share
	dash_speed = profile.dash_speed
	dash_duration = profile.dash_duration
	dodge_speed = profile.dodge_speed
	dodge_duration = profile.dodge_duration
	if profile.jump_height > 0.0:
		jump_height = profile.jump_height
	# The weight he carries (see [CharacterProfile]'s Weight group).
	for key: StringName in [&"ground_acceleration", &"ground_deceleration", &"turn_speed",
			&"turn_speed_still", &"commit_speed_scale", &"blow_shove", &"blow_stagger"]:
		var v: float = float(profile.get(key))
		if v >= 0.0:
			set(key, v)
	_levitate_left = profile.levitation
	max_health = profile.max_health
	p_def = profile.p_def
	m_def = profile.m_def
	health = max_health
	max_stamina = profile.max_stamina
	stamina = max_stamina
	_load_picks()


## True for a character who shoots rather than swings — the bow, or the staff,
## which charges and casts the same way.
func has_bow() -> bool:
	return profile != null and profile.weapon != CharacterProfile.Weapon.MELEE


## The bow itself, not the staff: what the bowstring sounds are for.
func _is_bow() -> bool:
	return profile != null and profile.weapon == CharacterProfile.Weapon.BOW


## True while a held jump is holding the body up on the way down.
func is_levitating() -> bool:
	return _levitating


## How much of the world's gravity the shot falls with.
func _shot_drop() -> float:
	return PlayerBow._shot_drop(self)


#region Locomotion
## Action buttons are polled rather than read from _unhandled_input() so that a
## press is never lost between physics ticks and so simulated input works.
func _read_actions() -> void:
	if menu_open:
		if is_blocking:
			is_blocking = false
			block_changed.emit(false)
		return
	# Looking around, letting go of a target and putting the weapons away are
	# always allowed: none of them moves the body, so none of them is a way out
	# of a swing.
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock()
	if unarmed:
		_read_unarmed()
		return

	# Mid-swing, the only thing the buttons do is queue the next one. Everything
	# below this line is a way of *not* finishing the attack.
	if is_committed():
		if Input.is_action_just_pressed("attack"):
			if _guard_heavy() and Input.is_action_pressed("block"):
				_heavy_buffer = attack_buffer_time
			else:
				_attack_buffer = attack_buffer_time
				_buffer_other = false
		if _other_string_ready() and Input.is_action_just_pressed("block"):
			_attack_buffer = attack_buffer_time
			_buffer_other = true
		if _has_heavy() and Input.is_action_just_pressed("block"):
			_heavy_buffer = attack_buffer_time
		# A light cut that has done its work may be broken off by an evade: the
		# follow-through is his to give up. A heavy blow plays out.
		# Not a cut that went through nothing, while its follow-through drags.
		if Input.is_action_just_pressed("dash") and rig != null and rig.has_method(&"in_recovery") \
				and bool(rig.call(&"in_recovery")) and _now() >= _whiff_until:
			_commit_timer = 0.0
			_attack_buffer = 0.0
			_heavy_buffer = 0.0
		else:
			if Input.is_action_just_pressed("dash") and _now() < _reel_until:
				_reel_dodge_asked = true
			return

	# An evade pressed while he reeled: thrown now he has his feet, ahead of
	# any cut asked for meanwhile.
	if _reel_dodge_asked:
		_reel_dodge_asked = false
		if _now() - _reel_until <= reel_dodge_keep:
			_attack_buffer = 0.0
			_heavy_buffer = 0.0
			_press_dash()
			return

	if Input.is_action_just_pressed("heal") and _drink():
		return

	if Input.is_action_just_pressed("stow"):
		_set_weapons_stowed(not weapons_stowed())

	# At a sprint the block button is no guard but the slide in under it
	# ([member SkinnedRig.run_slide]; Tariel, the user's word 2026-10-07).
	if sprinting and Input.is_action_just_pressed("block") and _run_slide_ready():
		_forced_heavy = _run_slide_slot()
		_attack(true)
		_forced_heavy = -1
		return

	# The shield is only up while the button is held; rolling and sliding drop it.
	# A character with no shield has nothing to raise.
	var raised := Input.is_action_pressed("block") and state == State.GROUNDED \
			and _shield_in_hand()
	if raised:
		# Raising a shield that is on your back takes it off your back first.
		_set_weapons_stowed(false)
	if raised != is_blocking:
		is_blocking = raised
		if raised:
			_guard_raised_at = _now()
		block_changed.emit(is_blocking)

	if Input.is_action_just_pressed("jump"):
		# A ledge in reach turns the jump into a pull-up, so a wall a little too
		# tall to walk up is climbed rather than bounced off. Anything taller than
		# that is taken hold of and climbed instead.
		if not _try_climb() and not _try_wall_climb():
			_jump_buffer_timer = jump_buffer_time
	# An archer has no shield: the block button is a kick for what has come
	# too close (AVTANDIL_POLISH 7).
	if kick_on_block and Input.is_action_just_pressed("block") and _can_kick():
		_kick()
	if Input.is_action_just_pressed("dash"):
		# Behind the shield the press is a charge with it, not an evade.
		if _can_bash():
			_shield_bash()
		else:
			_press_dash()
	for slot in SKILL_SLOTS:
		var action := StringName("skill_%d" % (slot + 1))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			use_skill(slot)
	# Held down at a run this is a slide; held down otherwise it is a crouch, and
	# the slide drops into one when it ends if the button is still down.
	_set_crouching(Input.is_action_pressed("crouch"))
	if Input.is_action_just_pressed("crouch"):
		_try_slide()
	# One button, two weapons: the sword goes on the press, the bow on the
	# release, because what the bow is worth is how long the press lasted.
	if _has_heavy() and Input.is_action_just_pressed("block"):
		_attack(true)
	elif _has_heavy() and _heavy_buffer > 0.0:
		_attack(true)
	elif _guard_heavy() and is_blocking and Input.is_action_just_pressed("attack"):
		# Out of his guard: the shield comes down and the heavy blow goes.
		_attack(true)
	elif _guard_heavy() and _heavy_buffer > 0.0:
		_attack(true)
	elif _other_string_ready() and Input.is_action_just_pressed("block"):
		# No shield in his hand: the block button throws the other string.
		_string_attack(true)
	elif not has_bow() and Input.is_action_just_pressed("attack"):
		_string_attack(false)
	elif not has_bow() and _attack_buffer > 0.0:
		# The swing that was asked for during the last one. Taken the moment the
		# last one lets go, so a flurry is one press per cut.
		_string_attack(_buffer_other)


## The buttons with nothing in his hands: only the ones that move him.
func _read_unarmed() -> void:
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	_attack_buffer = 0.0
	_heavy_buffer = 0.0
	if is_committed():
		return
	if Input.is_action_just_pressed("jump"):
		if not _try_climb() and not _try_wall_climb():
			_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("dash"):
		_press_dash()
	_set_crouching(Input.is_action_pressed("crouch"))
	if Input.is_action_just_pressed("crouch"):
		_try_slide()


func _process_locomotion(delta: float) -> void:
	PlayerMove._process_locomotion(self, delta)


## Surfaces past `floor_max_angle` are not standable, so gravity is redirected
## along them: the player slithers down instead of hanging on the side.
func _slide_off_steep_ground(delta: float) -> void:
	PlayerMove._slide_off_steep_ground(self, delta)


func get_movement_direction() -> Vector3:
	return PlayerMove.get_movement_direction(self)


## His pace behind the raised shield going on (m/s): more than a walk, well
## short of his run.
@export var guard_run_speed: float = 3.6


## Places the body on top of a low ledge. The move itself lives in [StepUp],
## because the creatures need it too — a wolf that cannot follow you up a
## staircase is a wolf you beat by standing on a step.
func _step_up(delta: float) -> void:
	PlayerMove._step_up(self, delta)


## The dash button. One tap is the hero's own evade — the knight's and the
## mage's roll, the hunter's step, the assassin's step. Evades chain: a press
## while one is going is kept and the next starts the moment it ends, and a
## press just after it ends ([member chain_grace]) follows on without waiting
## out the cooldown. So one can go on evading as long as the stamina lasts.
##
## For everyone but the assassin a second tap within `double_tap_time` of the
## first still upgrades the roll in progress into the library's longer dodge;
## a press later in the roll is the next roll.
##
## The assassin (`CharacterProfile.step_then_flip`) alternates: a step, then
## a twisting flip if another press follows, then a step again, and so on.
## With an enemy locked his steps keep facing it — backward too.
func _press_dash() -> void:
	PlayerMove._press_dash(self)


## Starts the evade that is next in the run: `chained` skips the cooldown.
func _start_evade(chained: bool) -> bool:
	return PlayerMove._start_evade(self, chained)


func _try_dash(keep_facing: bool = false, step: bool = false, chained: bool = false) -> bool:
	return PlayerMove._try_dash(self, keep_facing, step, chained)


enum Evade { ROLL, STEP, BACKSTEP, DODGE }

## His evade, as the others see it: the same roll, step, step back or long
## dodge played on their copy of him (coop_seen_test, 2026-10-24: the other
## player saw him sprint, not roll — the evade's clip was only started on
## his own machine, and `dashing` alone shows no roll).
## (`dir` the way it goes, which picks the roll's clip on the mannequin;
## `take` which of its takes, [member SkinnedRig.pick_seed])
@rpc("any_peer", "call_remote", "reliable")
func net_evade(kind: int, way: Vector2, seconds: float, dir: Vector3, take: int) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority() or rig == null:
		return
	_dash_direction = dir
	_take(take)
	match kind:
		Evade.ROLL:
			rig.dodge(seconds)
		Evade.STEP:
			if rig.has_method(&"step_dodge"):
				rig.call(&"step_dodge", way, seconds)
		Evade.BACKSTEP:
			if rig.has_method(&"backstep"):
				rig.call(&"backstep", seconds)
		Evade.DODGE:
			rig.dodge_clip(seconds)
	_take(-1)


## Drives both evades. They differ in how long they last, how fast they travel
## and what the rig is doing, not in how the body is moved.
func _process_dash(delta: float) -> void:
	PlayerMove._process_dash(self, delta)


func _end_dash() -> void:
	PlayerMove._end_dash(self)


## Holds the body down, or lets it back up. Standing waits until there is room:
## under a low gap the crouch simply carries on.
func _set_crouching(down: bool) -> void:
	PlayerMove._set_crouching(self, down)


func is_crouching() -> bool:
	return _crouching


## Puts the sword and shield over the shoulder, or takes them back off it.
## Climbing does the same of its own accord and gives the choice back after.
func _set_weapons_stowed(away: bool) -> void:
	if rig == null or rig.weapons_stowed() == away:
		return
	rig.stow_weapons(away)
	weapons_stowed_changed.emit(away)


## True while the player has put the weapons away.
func weapons_stowed() -> bool:
	return rig != null and rig.weapons_stowed()


## Whether the rig is drawing the sword now.
func _rig_drawing() -> bool:
	return rig != null and rig.has_method(&"is_drawing") and bool(rig.call(&"is_drawing"))


## In a fight or not (the user's word, 2026-10-05): something after him
## (an orc or a fighter whose quarry he is, chasing or fighting; a wolf
## chasing or fighting near him), a blow taken (on the shield too, or his
## health going down, which is how a blow from another player reaches his
## own peer), or something locked on. It lasts `combat_linger` after the last
## of these. Out of it the sprint costs nothing; going into it, or struck,
## the weapons put away (Q) are drawn of themselves. The sword is no longer
## put away by itself: only Q puts it away.
func in_combat() -> bool:
	return _game_t < _combat_until


## Seconds a fight lasts after the last sign of it.
@export var combat_linger: float = 5.0
## How near something after him has to be to count.
@export var hunted_range: float = 40.0
var _combat_until: float = -INF
var _combat_was: bool = false
var _health_seen: float = -1.0
var _hunt_left: float = 0.0
var _hunted: bool = false
var _struck_lately: bool = false


func _tick_combat(delta: float) -> void:
	_hunt_left -= delta
	if _hunt_left <= 0.0:
		_hunt_left = 0.25
		_hunted = _is_hunted()
	var hurt := _health_seen >= 0.0 and health < _health_seen - 0.01
	_health_seen = health
	if hurt or _struck_lately or _hunted or target != null:
		_combat_until = _game_t + combat_linger
	var now := in_combat()
	# into the fight, or a blow taken: the weapons back in hand (not while
	# climbing, which stows them of its own accord and hands them back after)
	if (now and not _combat_was) or hurt or _struck_lately:
		if weapons_stowed() and state != State.CLIMBING and state != State.WALLCLIMB and not is_dead:
			_set_weapons_stowed(false)
	_struck_lately = false
	_combat_was = now


## Something after him: a [Brute] or a [Fighter] chasing or fighting him, a
## [Wolf] chasing or fighting near him.
func _is_hunted() -> bool:
	if is_dead:
		return false
	for group: StringName in [&"enemy", &"wolf"]:
		for node in get_tree().get_nodes_in_group(group):
			var foe := node as Node3D
			if foe == null or foe == self or foe.get(&"is_dead") == true:
				continue
			if foe.global_position.distance_squared_to(global_position) > hunted_range * hunted_range:
				continue
			if foe is Wolf:
				var st := (foe as Wolf).state
				if st == Wolf.State.CHASE or st == Wolf.State.FIGHT:
					return true
				continue
			var mode: Variant = foe.get(&"mode")
			# Brute.Mode and Fighter.Mode are the same: GUARD, CHASE, FIGHT, RETURN
			if mode is int and (int(mode) == Brute.Mode.CHASE or int(mode) == Brute.Mode.FIGHT) \
					and foe.get(&"_quarry") == self:
				return true
	return false
#endregion


#region Slide
## How tall the capsule is when the player is upright, read off the scene rather
## than exported so there is one place it is set.
func stand_height() -> float:
	return _stand_height


## Drops into a slide, which only makes sense off a run: it keeps the momentum
## that was already there, adds a little, and shrinks the capsule so the player
## goes under whatever a standing body would not.
func _try_slide() -> bool:
	return PlayerMove._try_slide(self)


func _process_slide(delta: float) -> void:
	PlayerMove._process_slide(self, delta)


## Pulls the body up over a ledge in front of it, if there is one within reach
## and something to stand on when it gets there.
## What the hands and feet may take hold of or stand on in a climb: the world,
## not a creature (no pulling up onto an orc's shoulders, nor a wall made of a
## troll; the user's word, 2026-10-06).
func _climb_mask() -> int:
	return PlayerClimb._climb_mask(self)


## The heroes' own layer (2): they stand in each other's way (the user's
## word, 2026-10-22: the players must not pass through each other), but no
## one climbs onto another or stands on his head.
const HERO_LAYER := 2


## The physics layer every creature's body is on (4: the third).
const ENEMY_LAYER := 4


## Standing on a creature (come down on its head): slid off it, out the way
## it is from its middle (the user's word, 2026-10-06: no standing on them).
func _slip_off_creatures() -> void:
	PlayerClimb._slip_off_creatures(self)


const CREATURE_SLIP_SPEED := 4.5


func _try_climb() -> bool:
	return PlayerClimb._try_climb(self)


## The pull-up on the others' copies of him, the same take of it as his own.
@rpc("any_peer", "call_remote", "reliable")
func net_mantle(take: int) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority() or rig == null:
		return
	_take(take)
	rig.climb(climb_duration)
	_take(-1)


## Which take of a move with several the rig plays next ([member SkinnedRig.pick_seed]).
func _take(take: int) -> void:
	if rig != null and "pick_seed" in rig:
		rig.set(&"pick_seed", take)


## Carries the body up and then in, rather than straight at the corner: a lerp
## between the two ends would drag it through the wall on the way.
func _process_climb(delta: float) -> void:
	PlayerClimb._process_climb(self, delta)


## How far the body's centre line sits off the face it is on.
func _wall_hold_distance() -> float:
	return PlayerClimb._wall_hold_distance(self)


## Takes hold of whatever steep face is in front of the body. `direction` is the
## way to feel in, defaulting to whichever way the body is facing.
func _try_wall_climb(direction: Vector3 = Vector3.ZERO) -> bool:
	return PlayerClimb._try_wall_climb(self, direction)


## No wall is climbed in a portal's rooms (the user's word, 2026-10-22: he
## climbed a room's wall on up into the sky): their walls go on up unseen to
## keep the heroes in, and a climber went up the unseen part. Ledges within
## reach are still mantled.
func _in_dungeon() -> bool:
	return is_inside_tree() and not get_tree().get_nodes_in_group(&"dungeon").is_empty()


## Catches a face in mid-air. This is the move that makes jumping at a house
## work: nothing is pressed, the jump simply ends on the wall.
##
## It deliberately does not ask how fast the body is travelling into the face.
## By the time the capsule is *against* a wall, move_and_slide() has already
## cancelled the speed that drove it there, so a jump at a wall reads as having
## no interest in it — which is exactly the bug that made a run-up bounce off.
## What is asked instead is intent: the stick pointing at the face, or the body
## already touching one.
func _try_catch_wall(steer: Vector3) -> bool:
	return PlayerClimb._try_catch_wall(self, steer)


func _process_wall_climb(delta: float) -> void:
	PlayerClimb._process_wall_climb(self, delta)


## True while the body is hanging off a face.
func is_wall_climbing() -> bool:
	return state == State.WALLCLIMB
#endregion


#region Target lock
## Holding a target is the controller's business, not a weapon's: the knight
## circles what he is fighting and the archer shoots it, but both of them want
## the same thing from the button — pick the obvious enemy, keep the camera on
## it, and face it until told otherwise.
##
## Movement stays camera-relative while locked, which is what lets the player
## strafe round a target and back away from one without ever turning their back.


## Takes the best target in front of the camera, or lets go of the one held.
func _toggle_lock() -> void:
	PlayerTarget._toggle_lock(self)


func _hold_target(who: Node3D) -> void:
	PlayerTarget._hold_target(self, who)


func _drop_target() -> void:
	PlayerTarget._drop_target(self)


## Moves the lock one part up (+1) or down (-1) the creature it is on.
func _switch_part(step: int) -> void:
	PlayerTarget._switch_part(self, step)


## Swaps to the next target to one side of the one held. Which side is the sign
## of `towards`: negative for left, positive for right.
##
## Ordered by *angle round the camera* rather than by distance, so flicking
## right takes the next one along the line of the horizon — which is what the
## player means by it and what they can see before they do it.
func _switch_target(towards: float) -> void:
	PlayerTarget._switch_target(self, towards)


## The enemy nearest the middle of the view, of those close enough and roughly
## in front. Angle first and distance second: what the player is looking at
## matters more than what happens to be nearest.
func _best_target() -> Node3D:
	return PlayerTarget._best_target(self)


## Whether something is worth holding on to. Anything that has died stops being
## a target the moment it does, which is what keeps the camera off a corpse.
func _targetable(who: Node3D) -> bool:
	return PlayerTarget._targetable(self, who)


## Where on a body the camera looks and an arrow goes: the middle of it rather
## than the floor it stands on.
func _aim_point(who: Node3D) -> Vector3:
	return PlayerTarget._aim_point(self, who)


## Where the held target last stood alive.
var _last_target_at := Vector3.ZERO


## Whether `who` is after him: roused and chasing or fighting him (a camp's
## band, a brute: its quarry him and its mode CHASE or FIGHT; a wolf: chasing
## or fighting, its quarry him). Something that keeps no such state counts.
func _hunting_me(who: Node3D) -> bool:
	return PlayerTarget._hunting_me(self, who)


## The arm's length: out to `camera_reach` (and `camera_reach_big` further
## while a great foe is fought), in at once to whatever is behind him, and
## back out from it at `camera_out_speed`, never a jump.
func _tend_arm(delta: float) -> void:
	PlayerTarget._tend_arm(self, delta)


## Keeps the camera on the target and lets go when there is nothing left to hold.
func _track_target(delta: float) -> void:
	PlayerTarget._track_target(self, delta)


## Turns the body to face the target instead of the way it is travelling, which
## is the whole difference between strafing round something and running past it.
func _face_target(delta: float) -> void:
	PlayerTarget._face_target(self, delta)


## True while something is being fought.
func has_target() -> bool:
	return target != null
#endregion


## Hold to draw, let go to loose. How long it was held is the whole of it: a
## tapped shot leaves at once and lands for a fraction, a held one takes a beat
## and lands for all of it. Nothing else about the shot changes, so the player
## is choosing between rate and weight rather than between two buttons.
func _tick_bow(delta: float) -> void:
	PlayerBow._tick_bow(self, delta)


## How far the string has come back, 0 to 1. Everything a shot is worth is this
## number, so it is the one the HUD would draw.
func draw_power() -> float:
	return PlayerBow.draw_power(self)


## True while the string is being held.
func is_drawing() -> bool:
	return PlayerBow.is_drawing(self)


#region The fan of three (on the block button; AVTANDIL_POLISH 8)
## The block button, for an archer with no shield, draws as the attack does,
## and lets three arrows go side by side: `fan_spread` degrees apart across
## the shot, flat, each `fan_share` of the shot, for a crowd that has come on.
## Then `fan_cooldown` before the next fan (the attack draws as ever).
@export_group("Fan of arrows")
@export var fan_spread: float = 8.0
@export var fan_share: float = 0.55
@export var fan_cooldown: float = 2.5
@export var fan_stamina: float = 8.0
var _fan_draw: bool = false
var _fan_ready_at: float = -INF


## The cast, on every peer: the staff drawn back and brought through. The bolt
## itself follows by `net_loose` when the staff is round.
@rpc("any_peer", "call_local", "reliable")
func net_cast() -> void:
	if rig != null and rig.has_method(&"loose_bow"):
		rig.call(&"loose_bow")


## True while rolling or dashing out of the way of something: a spell that was
## hunting this body lets go of it.
func is_evading() -> bool:
	return (state == State.DODGING or state == State.DASHING) and (is_invulnerable or _now() < _safe_until)


## The arrow, on every peer.
##
## The same trick the sword uses, for the same reason: replicate the **act**,
## and let the code that was already there land in the right place. An arrow
## here is not a physics body — it is a start, a velocity and a sweep, which is
## deterministic — so every peer that is told where it left and how fast builds
## the same flight and draws the same streak. What they do *not* all do is the
## damage: `Wolf.take_hit()` is the host's, so a client's copy of an arrow flies
## and sticks and hurts nobody, while the host's copy of the same arrow is the
## one that counts. Loosed by a client or by the host, it works out the same.
##
## `call_local` because the archer has to see his own shot; `reliable` because a
## dropped arrow is a missed kill.
@rpc("any_peer", "call_local", "reliable")
func net_loose(from: Vector3, flight: Vector3, damage: float, critical: bool,
		quarry: NodePath = NodePath(), power: float = 0.0, perfect: bool = false,
		stun: float = 0.0, quiet: bool = false) -> void:
	# Loose in the world rather than under the body, so the arrow does not ride
	# the archer's own movement after it has left the string. `world_of` is the
	# same answer blood and severed limbs use for the same question.
	var into := Blood.world_of(self)
	var scene := arrow_scene
	if profile != null and profile.projectile != null:
		scene = profile.projectile
	if scene != null and into != null:
		var arrow: Node3D = scene.instantiate()
		into.add_child(arrow)
		arrow.global_position = from
		if arrow.has_method(&"empower"):
			arrow.call(&"empower", power)
		if &"perfect" in arrow:
			arrow.set(&"perfect", perfect)
		if &"stun_chance" in arrow:
			arrow.set(&"stun_chance", stun)
		if stun > 0.0:
			# the stunning arrow streaks electric
			if &"streak_tint" in arrow:
				arrow.set(&"streak_tint", Color(Lightning.SPARK, 0.9))
			if &"crit_tint" in arrow:
				arrow.set(&"crit_tint", Color(Lightning.SPARK, 0.9))
		arrow.call("launch", flight, damage, critical, _gravity * _shot_drop(), self)
		if not quarry.is_empty() and arrow.has_method(&"hunt"):
			arrow.call(&"hunt", get_node_or_null(quarry) as Node3D)
		# the stunning arrow follows what it was loosed at (Arrow.follow); an
		# ordinary shot is only aimed
		if not quarry.is_empty() and stun > 0.0 and arrow.has_method(&"follow"):
			arrow.call(&"follow", get_node_or_null(quarry) as Node3D)
	# The fan's other two go with the first: one snap, one loose.
	if quiet:
		return
	if _is_bow():
		if randf() < 0.5:
			Sfx.play(self, RELEASE_SOUND, self, Vector3.ZERO, randf_range(0.95, 1.06), -8.0)
		else:
			Sfx.play(self, RELEASE_SOUND_2, self, Vector3.ZERO, randf_range(0.95, 1.06), -14.0)
	if stun > 0.0 and rig != null and rig.has_method(&"loose_skill_shot"):
		# the stunning arrow is a skill shot, drawn and held as one; it goes
		# with a crack of lightning off the bow
		rig.call(&"loose_skill_shot")
		if into != null:
			SkillFx.flash(into, from, Lightning.SPARK, 0.22, 0.12)
			Lightning.crackle(into, from, 0.4, 5, 0.12, 14)
		Sfx.play(self, ULT_SHOT, self, Vector3.ZERO, 1.3, -14.0, 0.0)
		return
	# A cast has already been played, by `net_cast`.
	if rig != null and rig.has_method(&"loose_bow") and not rig.has_method(&"cast_lead"):
		rig.call(&"loose_bow")


## Brings the view towards level while the string is held.
##
## Only while there is nothing locked: a lock already points the camera at what
## is being shot at, and two things steering the same camera fight each other.
func _level_camera(delta: float) -> void:
	PlayerBow._level_camera(self, delta)


## Closes the view in on the shot as the string comes back, and opens it
## again after (`draw_zoom_degrees`). Set outright from the resting field of
## view while it is in, so it never drifts; left alone at rest.
func _draw_zoom(delta: float) -> void:
	PlayerBow._draw_zoom(self, delta)


## How far off the level the shot is aimed, in radians, for the rig to lean on.
## The same heading the arrow will leave on, so what the body does and what the
## arrow does are one number rather than two that happen to agree.
func _aim_pitch() -> float:
	return PlayerBow._aim_pitch(self)


## Throws a cut, and **commits to it**.
##
## The commitment is the point. An attack you can call off the instant it starts
## going wrong costs nothing to throw, so there is no reason not to throw it at
## every opportunity, and a fight becomes a mash. Souls games answer that by
## making the swing a decision you have already made: once it is out, it plays,
## and dodging, jumping and swinging again all have to wait. What that buys is
## the other half — reading an opponent's commitment and punishing it — which is
## the whole of the fight and the whole of what will matter in PvP.
##
## A press during a swing is remembered rather than eaten, so a flurry is one
## press per cut at the player's own rhythm instead of a timing test.
func _attack(heavy: bool = false) -> void:
	PlayerMelee._attack(self, heavy)


## A second attack button for a hero with no shield to raise (the assassin):
## his heavy blows ([member SkinnedRig.heavy]).
## A shield in his hand to raise: a hero who blocks, with a shield in his
## off hand (his look's; [method SkinnedRig.holds_shield]). Without one the
## block button raises nothing (no empty arm held up).
func _shield_in_hand() -> bool:
	return PlayerMelee._shield_in_hand(self)


## A hero who would block but has no shield in hand, with more than one
## string (Tariel): the block button throws the other string, the one F6
## would pick (the user's word, 2026-10-04).
func _other_string_ready() -> bool:
	return PlayerMelee._other_string_ready(self)


## A cut from the string F6 picked (`other` false) or the other one, the
## string put on first on every peer.
func _string_attack(other: bool) -> void:
	PlayerMelee._string_attack(self, other)


@rpc("authority", "call_local", "reliable")
func net_wear_string(other: bool) -> void:
	if rig != null and rig.has_method(&"wear_other_string"):
		rig.call(&"wear_other_string", other)


func _has_heavy() -> bool:
	return PlayerMelee._has_heavy(self)


## A hero with a shield throws his heavy blow out of his guard: the attack
## button with the shield up (the knight's leaping slam).
func _guard_heavy() -> bool:
	return PlayerMelee._guard_heavy(self)


## A heavy blow's blade has gone into the ground (see [signal SkinnedRig.slammed]):
## dust thrown up round it, a wave of broken earth running on the way he faces,
## the thump of it and the ground shaking under whoever is near. Every peer
## plays its own copy of the blow, so every peer sees and hears this.
func _on_slammed(at: Vector3, heft: float) -> void:
	PlayerMelee._on_slammed(self, at, heft)


## Heavy blows cost this many light cuts' stamina.
@export var heavy_stamina: float = 1.6

#region The charged heavy and the guard counter (gameplay_plan.md, 2026-10-22)
## Elden Ring's two: a heavy blow held back while its button is held, let go
## heavier the longer it was gathered (to `heavy_charge_max` s: as much again
## as `heavy_charge_bonus`, its weight on a big one's stance twice over); and
## a shield hero's heavy blow thrown out of his guard within
## `guard_counter_window` s of a blow taken on the shield, heavier by
## `guard_counter_weight`, the shield's ring and a flash with it.
@export var heavy_charge_max: float = 1.0
@export var heavy_charge_bonus: float = 0.6
@export var guard_counter_window: float = 0.8
@export var guard_counter_weight: float = 1.4
var _hcharging: bool = false
var _hcharge_from: float = -1.0
var _hcharge_serial: int = -1
var _hgather: HeavyGather = null
## When the last blow was taken on his shield (-100: none lately).
var _blocked_at: float = -100.0
## Guard counters thrown (tests).
var counters_thrown: int = 0
## Heavy blows let go gathered, and how far the last one was (tests).
var charges_let_go: int = 0
var last_charge: float = 0.0


func _tick_heavy_charge(delta: float) -> void:
	PlayerMelee._tick_heavy_charge(self, delta)


@rpc("authority", "call_local", "reliable")
func net_charge_heavy(at: float) -> void:
	if rig != null and rig.has_method(&"charge_heavy"):
		rig.call(&"charge_heavy", at)


@rpc("authority", "call_local", "reliable")
func net_heavy_gather(on: bool, share: float) -> void:
	if is_instance_valid(_hgather):
		_hgather.let_go(share)
	_hgather = null
	if on and rig != null:
		_hgather = HeavyGather.on(rig, heavy_charge_max)
		Sfx.play(self, ULT_CHARGE, self, Vector3.ZERO, 0.8, -14.0, 0.0)


@rpc("authority", "call_local", "reliable")
func net_let_heavy_go(weight: float, share: float) -> void:
	if rig != null and rig.has_method(&"let_heavy_go"):
		rig.call(&"let_heavy_go", weight)
	if is_instance_valid(_hgather):
		_hgather.let_go(share)
	_hgather = null


@rpc("authority", "call_local", "reliable")
func net_guard_counter(weight: float) -> void:
	if rig == null:
		return
	if rig.has_method(&"weigh_heavy"):
		rig.call(&"weigh_heavy", weight)
	var at := global_position + Vector3.UP * 1.3 - global_basis.z * 0.5
	ParryFlash.burst(Blood.world_of(self), at, -global_basis.z, 0.7)
	Sfx.play(self, PARRY_SOUND, self, at - global_position, 1.25, -4.0)
#endregion
## A heavy blow named outright (the sprint's slide), not picked by the
## string: -1 none.
var _forced_heavy: int = -1


## A slide to throw off a sprint: this look has one ([method
## SkinnedRig.run_slide_index]) and its clip, and he has the ground under him.
func _run_slide_ready() -> bool:
	return PlayerMelee._run_slide_ready(self)


## Where the sprint's slide is in the rig's heavy blows, or -1.
func _run_slide_slot() -> int:
	return PlayerMelee._run_slide_slot(self)


## Which heavy blow the string has come to: out of nothing a lunge (or, at a
## run, the flying flip); early in the string the spinning leap; later the
## three great cuts; at its end the whirling combo.
func _heavy_blow() -> int:
	return PlayerMelee._heavy_blow(self)


## The swing, everywhere.
##
## This is the **only** piece of combat that goes over the wire, and it is
## enough. Hit detection in this game is enemy-driven: a wolf reads the
## attacker's `attack_serial` and asks its rig where the blade is
## ([CharacterRig.get_cutting_edge]). So if every peer's copy of every player
## throws the same swing, the host's copy of a remote knight has a real blade in
## a real place, and the existing severing code lands host-authoritative without
## a line of it changing.
##
## `call_local` because the attacker has to play its own swing too. `reliable`
## because a dropped swing is a missed kill.
#region Being hit
## How hard a blow shoves, per point of damage, on top of a base shove. A heavier
## hitter moves the knight further and holds him longer — which is most of what
## "hits harder" can mean while players cannot be hurt.
@export var blow_shove: float = 0.28
## Seconds the knight is held after an unguarded blow, per point of damage.
@export var blow_stagger: float = 0.03
## Past this much damage a blow shoves and staggers no further: it hurts more,
## it does not throw him across the field.
@export var blow_heft_cap: float = 16.0
@export_group("Knockdown")
## Seconds spent lying on the ground once the fall has played, before getting up.
@export var down_time: float = 0.7
## How long getting back up takes.
@export var get_up_time: float = 1.1
## A roll out of a knockdown is allowed this long after hitting the ground.
@export var roll_out_after: float = 0.25
## Falls that follow the blow ([method SkinnedRig.fall]): how long he lies
## once the fall has played out, before getting up (seconds).
@export var fall_lie: float = 0.35
## From this heft ([method hit_heft]) a blow in front launches him through
## the air instead of throwing him back; and how hard (back, up; m/s).
@export var fall_fly_heft: float = 2.0
@export var fall_fly_push: Vector2 = Vector2(5.0, 4.6)
## A fall whose clip carries him over the ground is shoved less by the blow.
@export var fall_carried_shove: float = 1.2
## ...and this much more (m/s) per unit of the weapon's force ([method _swept]).
@export var fall_force_shove: float = 3.0
## A blow's weight ([method hit_heft]) counts as this much force when it is
## more than the weapon's own ([method _knock_down]).
@export var fall_heft_force: float = 1.2

## How the weapon met him ([method _swept]): from this speed (m/s) the
## throw leans to the weapon's sweep, fully (`sweep_lean_most`) this much
## faster; from this speed it has force, 1 this much faster (an imp's fist
## comes at 5-10 m/s, the ogre's club's end at 16-60).
@export var sweep_lean_from: float = 2.0
@export var sweep_lean_span: float = 8.0
@export var sweep_lean_most: float = 0.85
@export var sweep_force_from: float = 6.0
@export var sweep_force_span: float = 30.0
## A blow coming down steeper than this (pitch, -1 straight down) crushes him
## down; rising steeper than `sweep_rise_pitch` with force, it launches him.
@export var sweep_crush_pitch: float = -0.55
@export var sweep_rise_pitch: float = 0.5
## From this force a blow in front launches him, as a heavy one does.
@export var fall_fly_force: float = 1.3
## For the falls' review page only (its films): every fall is the one of
## this number ([constant SkinnedRig.REVIEW]), turned so ([constant
## BLOW_FALLS]); 0 the game's own choice.
var review_fall: int = 0
var review_face: String = ""
## Blows that, landing alone, only make him reel (TR_Big_Side_Hit), not
## fall: a string's close still fells him, and so does the pound's club
## itself on him (the user's word, 2026-10-10: he fell to almost every
## string). The slams, the great blow and the leaps fell as ever.
## A held swing (it stops at the top, then strikes) and the pound's ring are
## heavy ones: they fell (the user's word, 10-10 10:33).
const STAGGERS_ONLY := [&"smash", &"cleave", &"whirl", &"catch"]
## How long the big reel holds him (seconds).
@export var big_stagger_time: float = 0.95
## The blow felt landing (hit stop, [HitFeel]): how long the one who struck
## and he himself are held still (s, [the striker, him]), for a heavy blow
## that makes him reel and for one that fells him. A string's lighter blows
## hold neither: its quick run on from blow to blow is the point of it.
@export var reel_stop: Vector2 = Vector2(0.09, 0.06)
## A lighter blow that gets through holds the one who struck this long (s):
## [with more of its string to come, the last]; him not at all, only shaken
## (`struck_shake.z`), so his own moves are not held up.
@export var flinch_stop: Vector2 = Vector2(0.04, 0.055)
@export var fell_stop: Vector2 = Vector2(0.12, 0.08)
## Shaken where he is held (m along the blow, [HitShake]): a reel, a fall.
@export var struck_shake: Vector3 = Vector3(0.04, 0.055, 0.022)
## His own view knocked along the blow and shaken ([ImpactFx.knock]):
## [knock, shake, seconds] for a lighter blow (times its heft), a reel and a
## fall; and the thud as he meets the ground.
@export var view_flinch: Vector3 = Vector3(0.05, 0.05, 0.2)
@export var view_reel: Vector3 = Vector3(0.13, 0.13, 0.32)
@export var view_fell: Vector3 = Vector3(0.18, 0.2, 0.4)
@export var view_ground: Vector3 = Vector3(0.1, 0.12, 0.28)
## The blow's shove carrying him back over the ground on his feet, dying away
## by `shove_friction` (m/s²): its start (m/s) for a reel and for a lighter
## blow, `shove_force_gain` more per unit of the weapon's force
## ([method _swept]), `shove_most` at most. A blow with more of its string
## still to come shoves him only `shove_mid_string` of it, so the next one
## still reaches him.
@export var reel_shove: float = 2.4
@export var flinch_shove: float = 0.9
@export var shove_force_gain: float = 1.2
@export var shove_most: float = 3.5
@export var shove_friction: float = 9.0
@export var shove_mid_string: float = 0.35
## The shove under way (flat, m/s), and what of it was laid on his velocity
## last tick (taken back off before the controller works on his own pace).
var _flinch_push := Vector3.ZERO
## How far the blow being taken asks him thrown back over the ground on his
## feet (its striker's `blow_shove_m`: the troll's heavy strides, 2026-10-26,
## the user's word: its step carried on after the blow, he not in its way).
var _blow_shove_m: float = 0.0
var _push_applied := Vector3.ZERO
## A flinch's spray this long or longer is the big reel ([method _flinch]).
const BIG_STAGGER_SPRAY := 3.5


func _staggers_only(blows: int) -> bool:
	return PlayerMelee._staggers_only(self, blows)


## The blow that came last, by its name ([method receive_blow]).
var _blow_name: StringName = &""
## ...and where it was dealt from (the side it came from is the striker's,
## not the way its sweep leant: [method _blow_fall]).
var _blow_source: Vector3 = Vector3.ZERO
var _blow_weapon: bool = false
var _blow_held: bool = false
## The fall picked for the blow that felled him ([constant BLOW_FALLS]): its
## number ([constant SkinnedRig.REVIEW], 0 none) and how he is turned for it.
var _down_number: int = 0
## Getting up: what he is still to be turned and moved by, and in how long
## ([method SkinnedRig.rise]'s blend).
var _rise_turn: float = 0.0
var _rise_shift: Vector3 = Vector3.ZERO
var _rise_left: float = 0.0
var _down_face: String = ""
## The falls the user picked for each blow (2026-10-09 22:03, on the review
## page): the blow's name -> {where it came from: "front", "side", "back" or
## "any" -> [[fall's number, how he is turned], ...]} — one of them at
## random. Turned: "" so the fall goes the blow's way, "foe" his face to the
## one who struck (he folds forward at its feet), "keep" as he stands.
## Not here: the kind of blow picks it ([method _fall_kind]).
const BLOW_FALLS := {
	# the user's word 2026-10-09 23:53 (the cleave 10-10 00:08). The falls onto his face from above
	# (Fall_Flat, 10) go the way he faces ("keep": not turned, so facing the
	# camera he falls at it); the smash in front turns him the blow's way
	&"smash": {"front": [[10, ""]], "side": [[27, "keep"]], "back": [[27, "keep"]]},
	# a swing from a side caught in his back (any of them): Avtandil's
	# Death Right 02 (the user's word, 10-10 00:33)
	&"cleave": {"any": [[11, ""], [17, ""]], "back": [[22, ""]]},
	&"wide": {"back": [[22, ""]]},
	&"low": {"back": [[22, ""]]},
	&"backhand": {"back": [[22, ""]]},
	&"jump_slam": {"any": [[10, "keep"]]},
	&"whirl": {"any": [[5, ""]], "back": [[22, ""]]},
	# from behind: on his knees and forward as he stands, his head at the
	# camera, not turned round to it (the user's word, 10-10 09:21)
	&"heavy": {"any": [[24, "foe"]], "back": [[24, "keep"]]},
	# its shock's ring: over backwards; the club itself on him, flat on his face
	&"pound": {"any": [[14, ""]], "weapon": [[10, "keep"]]},
	&"leap_slam": {"any": [[10, "keep"]]},
	&"run_slam": {"any": [[10, "keep"]]},
	&"sweep": {"any": [[5, ""]], "back": [[22, ""]]},
	&"chop": {"any": [[20, ""]]},
	# the ogre's combos' felling blows (2026-10-10): its overhead as the
	# smash's, its leap as the jump slam's, its spin as the whirl's
	&"og_down": {"front": [[10, ""]], "side": [[27, "keep"]], "back": [[27, "keep"]]},
	&"og_jump": {"any": [[10, "keep"]]},
	&"og_spin": {"any": [[5, ""]], "back": [[22, ""]]},
	&"og_ground": {"front": [[10, ""]], "side": [[27, "keep"]], "back": [[27, "keep"]]},
	&"og_mjump": {"any": [[10, "keep"]]},
	# its free hand swung down on him: crushed down where he stands, into the
	# ground (2026-10-12, the user's word: no lift, the swing smashes him down)
	&"grab": {"any": [[10, "keep"]]},
}
## The last blow's force and pitch ([method _swept]), on the peer that owns him.
var _blow_force: float = 0.0
var _blow_pitch: float = 0.0
## The last blow was no weapon's: a skill's blast or a shock ([method net_blow]).
var _blow_area: bool = false
## The last weapon met (host): {"speed", "force", "pitch", "lean"}, for a test.
var last_sweep: Dictionary = {}

## The fall under way ([enum SkinnedRig.Fall]), and whether it is a launch
## not yet come down; what the blow shoved him by, dying away.
var _down_kind: int = 0
var _down_flying: bool = false
var _down_push: Vector3 = Vector3.ZERO
## How much further than the others this hero is thrown ([member SkinnedRig.fall_carry]).
var _down_carry: float = 1.0

## Seconds left of the current part of a knockdown, which part it is, and how
## long he has been down.
var _down_timer: float = 0.0
var _getting_up: bool = false
var _down_for: float = 0.0
## How many blows of each creature's current combo have landed clean, by
## attacker and combo. A combo only knocks him down if every blow of it did.
var _combo_landed: Dictionary = {}

@rpc("authority", "call_local", "reliable")
func net_riposte(seconds: float) -> void:
	if rig != null and rig.has_method(&"riposte"):
		rig.call(&"riposte", seconds)


## Through the critical: carried before it and turned to it over the first
## fifth, held there; the blade in at `crit_hit_at`.
func _process_riposte(delta: float) -> void:
	PlayerMelee._process_riposte(self, delta)


## Host: the critical's blade in — a cut's worth times `crit_power`, a critical
## (its own `stance_crit` on top, [PackBrute]).
@rpc("any_peer", "call_local", "reliable")
func net_riposte_hit(path: NodePath) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var b := get_node_or_null(path) as PackBrute
	if b == null or b.is_dead:
		return
	var worth := cut_worth(b)
	var at := b.global_position + Vector3.UP * 1.1 * b.visual_scale / 1.6
	var hit := HitInfo.make(float(worth[0]) * crit_power, at, (b.global_position - global_position).normalized(),
			true, true, self)
	b.hurtbox().take(hit)


## A creature landed a blow. Called on the host, which is the only peer whose
## creatures think; applied on the peer that drives this body, because that is
## the one that knows whether the shield was up or a roll was under way.
##
## `blow` of `blows` says where in its combo this one falls, and `combo` tells
## one combo from the next: the last blow of a combo that has landed every time
## puts him on the ground. Anything short of that is a flinch.
func receive_blow(damage: float, from: Node3D, blow: int = 0, blows: int = 1, combo: int = 0,
		magic: bool = false, how: StringName = &"") -> void:
	PlayerHurt.receive_blow(self, damage, from, blow, blows, combo, magic, how)


## The way a blow throws him, from how the weapon was moving where it met him
## ([method WeaponSweep.motion_on]; the user's word, 2026-10-09: "every fall
## must follow the club's swing and its power, whatever way it goes"): the
## way along the ground leans from "away from the one who struck" over to the
## weapon's own sweep, the faster it went the more; its speed is the blow's
## force; how steeply it came down (or up) is its pitch. All three ride on
## the vector [method net_blow] gets: its flat part is the way, of length
## 1 + force, its y the pitch (-1 straight down .. 1 straight up).
func _swept(away: Vector3) -> Vector3:
	return PlayerHurt._swept(self, away)


## The kinds of blow the big creatures have ([PackBrute]), after the "!" of a
## combo's key:
## * "guard": a kick at the shield — caught on it, it beats the guard aside
##   ([method _crumple]); "crush" (the ogre's slow blow) the same.
## * "ground": a shock along the ground — off the ground (a jump) it misses,
##   and no shield takes it.
## * "stomp": a blow at him where he lies — it finds him on the ground (a roll
##   out still clears it), and no shield takes it.
## * "spike": stone out of the ground under him — no shield takes it.
## * "smash": the ogre's free hand swung down on him, into the ground — no
##   shield takes it (only a roll beats it).
func _blow_kind(combo: String) -> String:
	return PlayerHurt._blow_kind(self, combo)


## Any peer: whether he holds his shield up, draws his bow (or gathers a
## bolt), as this peer knows it (his own peer from his state, the others
## from what the synchronizer carries).
func guarding() -> bool:
	return is_blocking if is_multiplayer_authority() else net_blocking


func drawing() -> bool:
	return _drawing if is_multiplayer_authority() else net_draw > 0.0


## Host: a creature has him in its grip for `seconds` (it carries him by its
## [method grab_point] till it lets go: [method release_grab]).
func grab_by(by: Node3D, seconds: float) -> void:
	PlayerHurt.grab_by(self, by, seconds)


## Host: let go (its blow, if any, comes after).
func release_grab() -> void:
	PlayerHurt.release_grab(self)


@rpc("any_peer", "call_local", "reliable")
func net_grabbed(path: NodePath, seconds: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead:
		return
	var by := get_node_or_null(path) as Node3D
	if by == null:
		return
	_held_by = by
	if by is PhysicsBody3D:
		add_collision_exception_with(by)
	_held_left = seconds + 1.0
	_held_from = global_position
	_held_time = 0.0
	grabbed_count += 1
	state = State.GROUNDED
	velocity = Vector3.ZERO
	_attack_buffer = 0.0
	_heavy_buffer = 0.0
	_crit_left = 0.0
	is_blocking = false
	net_held.rpc(seconds)


@rpc("any_peer", "call_local", "reliable")
func net_released() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority():
		return
	var was := _held_by
	_held_by = null
	_held_left = 0.0
	if was is PhysicsBody3D and is_instance_valid(was):
		remove_collision_exception_with(was)
	# thrown down: on the ground at once, where its hand let go (no landing
	# on his feet first: the user's word, 2026-10-11)
	if was != null:
		var space := get_world_3d().direct_space_state
		# (from above where it held him: slammed down, his feet are under it)
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0,
				global_position + Vector3.DOWN * 6.0, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			global_position = hit["position"] as Vector3
		velocity = Vector3.ZERO


## Every peer: the look of him held up, kicking.
@rpc("authority", "call_local", "reliable")
func net_held(seconds: float) -> void:
	if rig != null and rig.has_method(&"held"):
		rig.call(&"held", seconds)


#region Pinned on the ground (a ghoul on him, 2026-10-27)
## A ghoul on him where he lies, biting ([GhoulFighter], the user's word from
## its films): he stays down; each press of E (lock-on), F or the attack works
## him free, a little lost each second (`pin_struggle`, shown by [PlayerHud]);
## full, he kicks it off with both feet and springs up (HX_KickUp, every
## hero's: [constant SkinnedRig.ESCAPE_LIB]), nothing striking him while he
## does, and goes straight into a cut at it, still untouchable through its
## start (`KICK_CUT_SAFE`).
const PIN_PRESS := 0.085
const PIN_EASE := 0.12
const KICK_RATE := 1.25
const KICK_TIME := 0.98
const KICK_CUT_SAFE := 0.8
## Who is on him (his own peer's), and how far he has worked free (0 to 1).
var pinned_by: Node3D = null
var pin_struggle: float = 0.0
var _kicked_from: Node3D = null
var _kick_cut_due: bool = false


## Host to his peer: a ghoul is on him.
@rpc("any_peer", "call_local", "reliable")
func net_pinned(path: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead or state != State.DOWNED:
		return
	var by := get_node_or_null(path) as Node3D
	if by == null:
		return
	pinned_by = by
	pin_struggle = 0.0
	_getting_up = false
	_down_timer = maxf(_down_timer, 1.0)


## Host to his peer: it is off him (struck off by a friend, or it let go).
@rpc("any_peer", "call_local", "reliable")
func net_unpinned() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority():
		return
	pinned_by = null
	pin_struggle = 0.0
	if state == State.DOWNED and not is_dead and not _getting_up:
		_down_timer = minf(_down_timer, 0.3)


## Host to his peer: its teeth in him where he lies (no guard, no roll).
@rpc("any_peer", "call_local", "reliable")
func net_pin_bite(damage: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead:
		return
	_take_damage(damage)
	if camera != null and camera.current:
		ImpactFx.knock(camera, Vector3.DOWN, view_ground.x * 0.5, view_ground.y, view_ground.z)


## Every peer: the kick off his back and the spring up.
@rpc("authority", "call_local", "reliable")
func net_kick_up() -> void:
	if rig != null and rig.has_method(&"play_part"):
		rig.call(&"play_part", &"HX_KickUp", KICK_RATE, 0.0, 1.0, 0.2)


#region Seized standing (a zombie's hands on him, 2026-10-27)
## A zombie has him by the shoulders, its teeth at his neck ([ZombieFighter],
## the user's word from its films): he stands where he is, dazed, jolting at
## each bite (his own clips: KV_Stun01, KV_CombatDamage01/02); E (lock-on), F
## or the attack pressed fast works him free (`pin_struggle`, the same bar as
## under the ghoul, shown by [PlayerHud]); full, he drives the hilt into it,
## nothing striking him meanwhile (`SHOVE_SAFE`), and cuts at it.
const SEIZE_PRESS := 0.09
const SEIZE_EASE := 0.12
const SHOVE_TIME := 0.6
const SHOVE_SAFE := 1.2
const SEIZE_LOOK := [&"KV_Stun01", &"SS_Head_Impact", &"Hit_Knockback"]
const SEIZE_JOLT := [[&"KV_CombatDamage01", &"KV_CombatDamage02"], [&"SS_Head_Impact"], [&"Hit_Knockback"]]
const SHOVE_CLIPS := [&"SS_Hilt_Melee", &"Melee_Knee", &"KV_AttackShield01", &"KV_AttackPunch01_R"]
## Who has him (his own peer's).
var seized_by: Node3D = null
var _seize_look_in: float = 0.0
var _shove_left: float = 0.0
var _shoved: Node3D = null


## Host to his peer: a zombie has him where he stands.
@rpc("any_peer", "call_local", "reliable")
func net_seized(path: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead or state == State.DOWNED:
		return
	var by := get_node_or_null(path) as Node3D
	if by == null:
		return
	seized_by = by
	pin_struggle = 0.0
	if by is PhysicsBody3D:
		add_collision_exception_with(by)
	velocity = Vector3.ZERO
	is_blocking = false
	_attack_buffer = 0.0
	_heavy_buffer = 0.0
	_seize_look_in = 0.0


## Host to his peer: it let go of him (a friend struck it off, or it gave up).
@rpc("any_peer", "call_local", "reliable")
func net_unseized() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority():
		return
	_end_seize()


func _end_seize() -> void:
	PlayerHurt._end_seize(self)


## Host to his peer: its teeth in his neck (no guard, no roll).
@rpc("any_peer", "call_local", "reliable")
func net_seize_bite(damage: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead or seized_by == null:
		return
	_take_damage(damage)
	if camera != null and camera.current:
		ImpactFx.knock(camera, Vector3.DOWN, view_ground.x * 0.4, view_ground.y, view_ground.z)
	net_seize_look.rpc(1 + randi() % 2)


## Every peer: held dazed (0), or a jolt at a bite (1, 2: which of his).
@rpc("authority", "call_local", "reliable")
func net_seize_look(jolt: int) -> void:
	if rig == null or not rig.has_method(&"play_part"):
		return
	if jolt <= 0:
		for clip: StringName in SEIZE_LOOK:
			if float(rig.call(&"play_part", clip, 1.0, 0.0, 1.0, 0.25)) > 0.0:
				return
		return
	for takes: Array in SEIZE_JOLT:
		var clip: StringName = takes[(jolt - 1) % takes.size()]
		if float(rig.call(&"play_part", clip, 1.2, 0.0, 0.6, 0.08)) > 0.0:
			return


## Each tick in its hands: true while it holds him.
func _process_seized(delta: float) -> bool:
	return PlayerHurt._process_seized(self, delta)


## Worked free: the hilt into it (every peer sees it), the zombie told on the
## host; untouchable through it, and a cut at it after.
func _shove_free(by: Node3D) -> void:
	PlayerHurt._shove_free(self, by)


## Every peer: the hilt driven into it.
@rpc("authority", "call_local", "reliable")
func net_shove() -> void:
	if rig == null or not rig.has_method(&"play_part"):
		return
	for clip: StringName in SHOVE_CLIPS:
		if float(rig.call(&"play_part", clip, 1.2, 0.0, 1.0, 0.1)) > 0.0:
			return


## The shove played out where he stands, then the cut at it.
func _process_shove(delta: float) -> void:
	PlayerHurt._process_shove(self, delta)


## In the grip: drawn in to its hand over a moment, then hung from it by the
## neck, facing it; let go of if it is gone, dead, or holds on too long.
func _process_held(delta: float) -> void:
	PlayerHurt._process_held(self, delta)


## Held: his neck put in its palm (from where his neck is on him now); run
## each physics tick and each drawn frame, so the grip does not lag its hand.
func _hang() -> void:
	PlayerHurt._hang(self)


## Where he hangs from a hand that holds him: this far below it (m).
const HELD_NECK := 1.45
## ...and this far out past its palm (m).
const HELD_OUT := 0.2


## Only the host deals creatures' blows. A local call reports sender 0.
@rpc("any_peer", "call_local", "reliable")
func net_blow(damage: float, away: Vector3, source: Vector3, combo: String,
		blow: int, blows: int, magic: bool = false, named: StringName = &"") -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead:
		return
	# What his armour takes off it — or, a spell's, his m.def. (Tariel's
	# Challenge stands his p.def higher while it holds, [TarielChallenge].)
	damage = Defence.against(damage, p_def * TarielChallenge.guard(self) - shield_def_off(), m_def, magic) * taken_scale
	var how := _blow_kind(combo)
	_blow_held = String(named).ends_with("@h")
	var bare := String(named).trim_suffix("@h")
	_blow_weapon = bare.ends_with("@w")
	_blow_name = StringName(bare.trim_suffix("@w"))
	_blow_source = source
	# the weapon's force and pitch ride on `away` ([method _swept])
	_blow_pitch = clampf(away.y, -1.0, 1.0)
	away.y = 0.0
	_blow_force = maxf(away.length() - 1.0, 0.0)
	away = away.normalized() if away.length_squared() > 0.0001 else global_basis.z
	# no weapon met him: a skill's blast, a shock along the ground, stone
	# out of it ([method _fall_kind] throws him back from it)
	_blow_area = magic or how == "ground" or how == "spike"
	if how == "stomp" and state == State.DOWNED and not is_dead:
		_stomped(damage, away)
		return
	if how == "ground" and not is_on_floor():
		return
	# A fresh combo from this attacker forgets the last one.
	if blow == 0 or not _combo_landed.has(combo):
		_forget_combos_from(combo)
		_combo_landed[combo] = 0

	# In an evade's untouchable start, or on the ground: the blow goes through
	# empty air. Its recovery after does not (the user's word, 2026-10-12:
	# Elden Ring's — a roll thrown too early is caught at its end).
	var evading := (state == State.DASHING or state == State.DODGING) and (is_invulnerable or _now() < _safe_until)
	if is_invulnerable or evading or state == State.DOWNED or _now() < _safe_until:
		_combo_landed[combo] = -999
		if evading:
			# rolled through its blow: the ground it breaks with that blow
			# does not find him either ([method untouchable_now])
			_dodged_from = combo.get_slice("#", 0)
			_dodged_at = _now()
		if evading and not _evade_was_perfect \
				and _now() - _evade_started_at <= perfect_dodge_window:
			_evade_was_perfect = true
			# The shadow (the assassin, Avtandil, Tariel) is only its look: it no
			# longer covers him after the roll (the user's word, 2026-10-10: a
			# combo's next blow went through him after a perfect dodge). Only
			# the roll itself is safe, as in Elden Ring.
			stamina = minf(stamina + (profile.roll_stamina if profile != null else 20.0), max_stamina)
			_winded = false
			net_react.rpc(Reaction.PERFECT_DODGE, global_position, Vector3.ZERO)
		return
	# Down on his knee (a broken guard, a dodge spent out): a second blow that
	# finds him there throws him down, the way it went (the user's word,
	# 2026-10-09: he knelt there too long, and a blow on him should fell him).
	if _now() < _crumpled_until:
		_crumpled_until = -INF
		_combo_landed[combo] = int(_combo_landed[combo]) + 1
		struck.emit(damage, false)
		var knelt_at := global_position + Vector3.UP * 0.9
		var knelt_spray := (away + Vector3.UP * 0.3).normalized()
		if _take_damage(damage):
			velocity = away * (2.5 + _heft(damage) * blow_shove * 0.5)
			return
		_knock_down(away, damage, how)
		net_react.rpc(Reaction.KNOCKDOWN, knelt_at, knelt_spray * _fall_spray_length())
		return
	var toward := source - global_position
	toward.y = 0.0
	var facing := -global_transform.basis.z
	facing.y = 0.0
	if is_blocking and (how == "guard" or how == "crush") and facing.normalized().dot(toward.normalized()) > 0.2:
		# Kicked or beaten aside: the guard goes, and the blow with it.
		_combo_landed[combo] = -999
		_crumple(damage * (0.4 if how == "guard" else 0.8), away)
		return
	if is_blocking and how != "ground" and how != "stomp" and how != "spike" and how != "smash" and facing.normalized().dot(toward.normalized()) > 0.2:
		_combo_landed[combo] = -999
		# Caught on the shield: a step back, and it costs stamina to hold — never
		# more than most of the bar, so even a raid boss's blow can be taken on
		# the shield once.
		var cost := minf(damage * block_stamina, max_stamina * 0.7)
		if shield_kind == Inventory.Shields.TOWER:
			cost *= tower_block_share
		var had := stamina
		_spend(cost)
		# How hard it was, 0..1 ([method block_strength]): the push back, the
		# jolt, the sparks, the hold and the view all go by it.
		var strength := block_strength(damage)
		if strength >= guard_crumple_from and (had <= max_stamina * guard_crumple_low or stamina <= 0.0):
			_crumple(damage, away)
			return
		var shove := lerpf(block_shove.x, block_shove.y, strength)
		if shield_kind == Inventory.Shields.TOWER:
			shove *= tower_block_share
		velocity += away * shove
		if stamina <= 0.0:
			# Nothing left to hold it with: the guard breaks, and half the blow
			# comes through it.
			is_blocking = false
			block_changed.emit(false)
			_free_swing = false
			_commit(guard_break_time)
			struck.emit(damage * 0.5, false)
			var knock := global_position + Vector3.UP * 1.2
			net_react.rpc(Reaction.FLINCH, knock, (away + Vector3.UP * 0.3).normalized())
			_take_damage(damage * 0.5)
			return
		_struck_lately = true
		_blocked_at = _now()
		struck.emit(damage, true)
		# The one who struck is held with him for the beat ([HitFeel]): the
		# blow felt stopping on the shield.
		var striker := get_node_or_null(NodePath(combo.get_slice("#", 0))) as Node3D if combo.begins_with("/") else null
		if striker != null and striker != self:
			HitFeel.hold(striker, block_hold(strength))
		# the strength rides on the blow's length (it is the way back to him)
		net_react.rpc(Reaction.BLOCK, global_position + Vector3.UP * 1.2 + facing.normalized() * 0.5,
				toward.normalized() * maxf(strength, 0.01))
		return

	if _dodge_spent_out(damage):
		# rolled out of the way too early, on the last of his breath: the
		# heavy blow catches him getting up, and down he goes
		_crumple(damage, away, false)
		return
	_combo_landed[combo] = int(_combo_landed[combo]) + 1
	struck.emit(damage, false)
	var at := global_position + Vector3.UP * 1.2
	var spray := (away + Vector3.UP * 0.3).normalized()
	if _take_damage(damage):
		# That one was the last: he goes down and does not get up.
		velocity = away * (2.5 + _heft(damage) * blow_shove * 0.5)
		return
	if blow >= blows - 1 and int(_combo_landed[combo]) >= blows:
		if _staggers_only(blows):
			# heavy, but alone: he reels and stays on his feet, shoved back
			# over the ground; the two held a beat as it lands
			_shove(away, reel_shove, 1.0)
			_stop_striker(combo, reel_stop.x)
			_free_swing = false
			_commit(big_stagger_time)
			_reel_until = _now() + big_stagger_time
			net_react.rpc(Reaction.FLINCH, at, spray * BIG_STAGGER_SPRAY)
			return
		_stop_striker(combo, fell_stop.x)
		_knock_down(away, damage, how)
		# the fall's kind rides on the spray's length (10 + kind)
		net_react.rpc(Reaction.KNOCKDOWN, at, spray * _fall_spray_length())
		return
	if combo.contains("^b"):
		# too heavy to swing through: his own swing is cut short, he reels
		# (the big side hit, which plays over a swing as a flinch does not)
		_shove(away, reel_shove, 0.8)
		_stop_striker(combo, flinch_stop.y)
		_free_swing = false
		_attack_buffer = 0.0
		_commit(big_stagger_time)
		_reel_until = _now() + big_stagger_time
		net_react.rpc(Reaction.FLINCH, at, spray * BIG_STAGGER_SPRAY)
		return
	_shove(away, flinch_shove, shove_mid_string if blow < blows - 1 else 1.0)
	# the weapon stopped on him a breath, where it met him (the user's word,
	# 2026-10-10: it went through him), a string's blow the least
	_stop_striker(combo, flinch_stop.x if blow < blows - 1 else flinch_stop.y)
	_free_swing = false
	_commit(0.2 + _heft(damage) * blow_stagger)
	_reel_until = _now() + 0.2 + _heft(damage) * blow_stagger
	# how hard it was rides on the spray's length (1 the lightest, 2 the
	# heaviest; the blood takes only its way): [method _flinch]
	net_react.rpc(Reaction.FLINCH, at, spray * (1.0 + hit_heft(damage)))


## What is left of his pace while his swing is held in a bite.
const BITE_GLIDE := 0.12


## Whether his swing is held in a bite now ([SkinnedRig.in_hitstop]).
func _bitten() -> bool:
	return PlayerHurt._bitten(self)


## How hard a blow of `damage` shoves: the damage, up to `blow_heft_cap`.
func _heft(damage: float) -> float:
	return PlayerHurt._heft(self, damage)


## A blow that got through shoves him back over the ground on his feet
## ([member reel_shove]): `base` m/s and more by the weapon's force, `share`
## of it; it dies away in [method _carry_push]. A new blow's shove takes the
## place of what is left of the last.
func _shove(away: Vector3, base: float, share: float) -> void:
	PlayerHurt._shove(self, away, base, share)


## The one who struck (the first part of a combo's key) held still a beat as
## the blow lands on him ([HitFeel]); on the peer that drives this body, as
## the shield's hold is.
func _stop_striker(combo: String, seconds: float) -> void:
	PlayerHurt._stop_striker(self, combo, seconds)


## His own view knocked along a blow that got through him and shaken
## ([ImpactFx.knock]): `how` = [knock, shake, seconds]. Only in his window.
func _view_struck(along: Vector3, how: Vector3) -> void:
	PlayerHurt._view_struck(self, along, how)


## Down on the ground at the end of a fall's drop ([signal SkinnedRig.struck_ground]):
## the view thuds, dust off the ground.
func _on_struck_ground(at: Vector3) -> void:
	PlayerHurt._on_struck_ground(self, at)


## The blow's shove carried on (every tick, on his feet): laid on his
## velocity after the controller has had its say, so the stick does not eat
## it, and dying away by `shove_friction`; held still with him in a bite.
func _carry_push(delta: float) -> void:
	PlayerHurt._carry_push(self, delta)


## Last tick's shove taken back off his velocity — as much of it as is still
## in it (a wall may have taken some) — so the controller works on his own.
func _take_back_push() -> void:
	PlayerHurt._take_back_push(self)


func _forget_combos_from(combo: String) -> void:
	PlayerHurt._forget_combos_from(self, combo)


enum Reaction { FLINCH, KNOCKDOWN, GET_UP, ROLL_OUT, PARRY, DEATH, RESPAWN, PERFECT_DODGE, BLOCK, GUARD_BREAK, STOMPED }

## What a blow did to him, shown in every window: a flinch or a fall with
## blood, or the end of lying there.
@rpc("authority", "call_local", "reliable")
func net_react(reaction: int, at: Vector3, blow: Vector3) -> void:
	match reaction:
		Reaction.FLINCH:
			_interrupt_skill()
			_flinch(blow)
			# the big reel: held a beat as the blow lands ([member reel_stop]),
			# shaken there; his view knocked the way the blow went
			var big := blow.length() >= BIG_STAGGER_SPRAY - 0.1
			if big and rig != null and rig.has_method(&"hitstop"):
				rig.call(&"hitstop", reel_stop.y)
				HitShake.shake(rig, blow, struck_shake.x, reel_stop.y + HitFeel.SHAKE_AFTER)
			var k := 1.0 if big else clampf(blow.length() - 1.0, 0.0, 1.0)
			_view_struck(blow, view_reel if big else view_flinch * k)
			if not big and rig != null:
				HitShake.shake(rig, blow, struck_shake.z * (0.6 + 0.4 * k), flinch_stop.y + HitFeel.SHAKE_AFTER)
			_rig_says(&"hurt")
			Blood.splatter(Blood.world_of(self), at, blow)
		Reaction.KNOCKDOWN:
			_interrupt_skill()
			var told := blow.length()
			var number: int = int(floorf(told / 100.0)) if told > 99.0 else 0
			told -= 100.0 * number
			var kind: int = int(floorf(told)) - 10 if told > 9.9 else 0
			var force: float = maxf(told - floorf(told) - 0.25, 0.0) * 4.0 if told > 9.9 else 0.0
			if rig != null:
				if rig.has_method(&"fall"):
					var lies := float(rig.call(&"fall", kind, force, number))
					# held a beat as the felling blow lands ([member fell_stop]),
					# shaken there; his view knocked the way the blow went
					if rig.has_method(&"hitstop"):
						rig.call(&"hitstop", fell_stop.y)
						HitShake.shake(rig, blow, struck_shake.y, fell_stop.y + HitFeel.SHAKE_AFTER)
					_view_struck(blow, view_fell)
					if rig.has_method(&"jolt"):
						rig.call(&"jolt", Vector3(blow.x, 0.0, blow.z), force)
					if lies > 0.0 and is_multiplayer_authority() and state == State.DOWNED and not _down_flying:
						_down_timer = lies + fall_lie
				else:
					rig.knock_down()
			_rig_says(&"hurt")
			_thud()
			Blood.splatter(Blood.world_of(self), at, blow.normalized())
		Reaction.GET_UP:
			_show_rise(&"")
		Reaction.ROLL_OUT:
			Sfx.play(self, ROLL_SOUND, self, Vector3.ZERO, 1.0, MOVE_VOLUME[MoveSound.ROLL])
			if rig != null:
				rig.leave_ground()
				if not is_multiplayer_authority():
					rig.dodge(dash_duration)
		Reaction.PARRY:
			ParryFlash.burst(Blood.world_of(self), at, blow)
			Sfx.play(self, PARRY_SOUND, self, at - global_position, randf_range(0.93, 1.07), 2.0)
		Reaction.DEATH:
			_interrupt_skill()
			if rig != null:
				if rig.has_method(&"die"):
					rig.call(&"die")
				else:
					rig.knock_down()
			_rig_says(&"hurt")
			_thud()
			Blood.splatter(Blood.world_of(self), at, blow)
		Reaction.RESPAWN:
			if rig != null:
				rig.leave_ground()
		Reaction.PERFECT_DODGE:
			if profile != null and profile.shadow_dodge:
				ShadowTrail.start(self)
				Sfx.play(self, SHADOW_SOUND, self, Vector3.ZERO, 1.0, -1.0)
			perfect_dodged.emit()
		Reaction.BLOCK:
			_feel_block(at, blow)
		Reaction.GUARD_BREAK:
			_feel_guard_break(at, blow)
		Reaction.STOMPED:
			_thud()
			Blood.splatter(Blood.world_of(self), at, blow)
			if is_multiplayer_authority() and camera != null and camera.current:
				ImpactFx.knock(camera, Vector3.DOWN, 0.3, 0.35, 0.4)


## Struck where he lies ("stomp", [method _blow_kind]): it lands whole, and
## keeps him down a moment longer — unless he rolls out first.
func _stomped(damage: float, away: Vector3) -> void:
	PlayerHurt._stomped(self, damage, away)


## The damage (after his armour) at which a blow that gets through is the
## heaviest there is ([method hit_heft] 1).
@export var hit_heaviest: float = 30.0


## How hard a blow of `damage` that got through is: 0..1.
func hit_heft(damage: float) -> float:
	return PlayerHurt.hit_heft(self, damage)


## A blow that got through, shown (TARIEL_POLISH.md 9): which way it came
## from and how hard pick the flinch. `blow` is the blood's spray (the blow's
## way, a little up), its length 1 + how hard.
func _flinch(blow: Vector3) -> void:
	PlayerHurt._flinch(self, blow)


## A blow on the shield at least this hard ([method block_strength])...
@export var guard_crumple_from: float = 0.9
## ...taken with no more than this share of the stamina left (or that takes the
## last of it) breaks the guard outright: [method _crumple].
@export var guard_crumple_low: float = 0.3
## How long he is down on his knee and open, all told (seconds).
@export var guard_crumple_time: float = 1.35


## The guard broken (the user's idea, 2026-10-04): a heavy blow on the shield
## with too little stamina left to hold it. The shield is beaten aside and
## the blow lands whole; the stamina is gone; he reels and goes down on one
## knee, open, and whatever strikes him meanwhile lands too (no guard can be
## raised while he is down). Heard as the shield giving way, felt as a hard
## jolt of the view.
## When his last evade ended ([method _end_dash]), for [method _dodge_spent_out].
var _evade_ended_at: float = -INF
## How long after an evade ends a heavy blow still finds him getting up out
## of it (seconds): a dodge thrown too early.
@export var dodge_mistime_window: float = 0.6


## A heavy blow (as heavy as one that breaks a guard, [member
## guard_crumple_from]) landing just after an evade that ran out his stamina
## (the user's rule, 2026-10-04: the last of the stamina spent on a dodge,
## and the dodge mistimed — he came out of it before the blow): it drops him
## to his knee as a broken guard does ([method _crumple]). A dodge with breath
## left, or a light blow, is only a blow that lands.
func _dodge_spent_out(damage: float) -> bool:
	return PlayerHurt._dodge_spent_out(self, damage)


## Until when he is down on his knee from a broken guard: he does not walk or
## turn on it, whatever the stick says (the shove the blow gave dies away).
var _crumpled_until: float = -INF


## The guard broken (or, `shield` false, a dodge spent out): see
## [method _feel_guard_break].
func _crumple(damage: float, away: Vector3, shield: bool = true) -> void:
	PlayerHurt._crumple(self, damage, away, shield)


## The guard beaten aside, seen and heard on every peer ([method _crumple]).
func _feel_guard_break(at: Vector3, away: Vector3) -> void:
	PlayerHurt._feel_guard_break(self, at, away)


## The view's jolt when the guard breaks: how far (m), how much shake (m),
## how long (s).
@export var guard_break_view := Vector3(0.38, 0.3, 0.75)
## When his knee meets the ground after the guard breaks (seconds).
@export var guard_knee_after: float = 0.95
## The last broken guard ([method _feel_guard_break]), for a test.
var last_guard_break: Dictionary = {}


## How the push back off the shield goes with a blow's strength (m/s added,
## from the lightest to the heaviest; the tower shield takes
## `tower_block_share` of it).
@export var block_shove := Vector2(2.2, 5.5)
## The damage (after his armour) at which a blow on the shield is the hardest
## there is ([method block_strength] 1); the lightest counts as `BLOCK_LEAST`.
@export var block_heaviest: float = 18.0
const BLOCK_LEAST := 0.12


## How hard a blow of `damage` is, caught on the shield: 0..1.
func block_strength(damage: float) -> float:
	return PlayerHurt.block_strength(self, damage)


## How long a blow of `strength` on the shield holds both of them (seconds):
## a light one a breath, a heavy one about as long as a heavy cut's bite.
func block_hold(strength: float) -> float:
	return PlayerHurt.block_hold(self, strength)


## A blow caught on his shield, felt (TARIEL_POLISH.md 8): on every peer the
## block's sound (deeper and louder the harder), sparks off the shield's face
## thrown back at whoever struck, the guard's jolt and the hold; in his own
## window the view knocked back and shaken. `blow` points back at the striker,
## its length the strength.
func _feel_block(at: Vector3, blow: Vector3) -> void:
	PlayerHurt._feel_block(self, at, blow)


## The last blow felt on his shield ([method _feel_block]), for a test.
var last_block_feel: Dictionary = {}


## A sound of the rig's own (`hurt`), if it has it.
func _rig_says(what: StringName) -> void:
	PlayerHurt._rig_says(self, what)


## The body hitting the ground, a moment after it starts to go over.
func _thud() -> void:
	PlayerHurt._thud(self)


## His blade has gone into a creature — told by the host, which is where the
## creatures decide what a swing hit; heard on every peer.
## `matter` is what it went into ([method ImpactFx.matter_of]), heard so.
@rpc("any_peer", "call_local", "unreliable")
func net_blade_landed(matter: StringName = &"flesh") -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != multiplayer.get_unique_id():
		return
	if rig != null and rig.has_method(&"blade_landed"):
		if rig is SkinnedRig:
			(rig as SkinnedRig).blade_landed(matter)
		else:
			rig.call(&"blade_landed")
	if rig != null and rig.get(&"attack_serial") != null:
		_landed_serial = int(rig.get(&"attack_serial"))
	# The blow felt in the hands: his own view knocked the way the blade went.
	if is_multiplayer_authority() and camera != null and camera.current and rig != null:
		var weight := 1.0 if rig.get(&"cut_weight") == null else float(rig.get(&"cut_weight"))
		# Knocked the way the blade went and shaken, every cut: further and
		# harder the heavier the blow ([ImpactFx.knock]).
		var heft := clampf(weight - 0.6, 0.0, 1.2)
		ImpactFx.knock(camera, rig.swing_direction(-global_basis.z),
				0.03 + 0.03 * heft, 0.035 + 0.045 * heft, 0.18 + 0.1 * heft)


## Off his feet. Everything else stops; he slides back with the blow and lies
## there, out of reach of anything else, until he gets up or rolls clear.
## The knockdown's spray length: 10.25 + the fall's kind + a quarter of the
## weapon's force (0..1.5) — how every peer learns both (the quarter's start
## keeps a whole number from rounding down under the float).
func _fall_spray_length() -> float:
	return PlayerHurt._fall_spray_length(self)


## Which way a blow that fells him throws him ([enum SkinnedRig.Fall], the
## user's word 2026-10-09): crushed down by one from above, thrown over to a
## side by one from that side, onto his face by one from behind; one in front
## throws him back, or, heavy enough, launches him through the air.
func _fall_kind(away: Vector3, _damage: float, how: String) -> int:
	return PlayerHurt._fall_kind(self, away, _damage, how)


## Turned on the blow's frame so the fall's clip throws him exactly the way
## the blow goes (each clip throws him one way of his own: back, forward, to
## a side): the turn is at most what lies between two sides (45°), and on
## the frame of the blow it reads as the blow wrenching him round.
func _face_the_throw(away: Vector3) -> void:
	PlayerHurt._face_the_throw(self, away)


## The fall the user picked for the blow that came ([constant BLOW_FALLS]):
## [number, how he is turned], or [] for none.
func _blow_fall(away: Vector3) -> Array:
	return PlayerHurt._blow_fall(self, away)


## Getting up off the ground, on every peer, the get-up `up` his own
## machine picked ("" each its own: [method SkinnedRig.rise_pick]).
@rpc("authority", "call_local", "reliable")
func net_rise(up: StringName) -> void:
	_show_rise(up)


func _show_rise(up: StringName) -> void:
	PlayerHurt._show_rise(self, up)


func _knock_down(away: Vector3, damage: float, how: String = "") -> void:
	PlayerHurt._knock_down(self, away, damage, how)


func _process_downed(delta: float) -> void:
	PlayerHurt._process_downed(self, delta)


#region Aimed cuts
## How far off, and how far round from where he faces (or is pushed), a cut
## finds what it is thrown at when nothing is locked.
@export var strike_assist_range: float = 3.2
@export var strike_assist_cone: float = 70.0
## How near the knife wants to be: from his middle to the near side of what he
## cuts (metres). Further off than this, a cut steps in to it first — quickly,
## over `strike_step_time`, and no further than `strike_step_max`.
@export var strike_close: float = 0.42
@export var strike_step_time: float = 0.13
@export var strike_step_max: float = 1.8
## What the cut in hand is thrown at, on every peer.
var _strike_foe: Node3D = null
var _step_velocity := Vector3.ZERO
var _step_left: float = 0.0


## A cut thrown at something out of the knife's reach steps in to it (no
## further than `reach`).
func _step_in(foe: Node3D, reach: float) -> void:
	PlayerHurt._step_in(self, foe, reach)


## A heavy blow wound up slowly (the assassin's, [member SkinnedRogueRig.WIND_HEAVY])
## edges him in over the gathering (its spec's `creep`, metres) ...
func _creep_in(spec: Dictionary) -> void:
	PlayerHurt._creep_in(self, spec)


## ... and when it is let go he slides in at what it is thrown at, wherever
## it has got to while he gathered (the user's word, 2026-10-05: a slide, a
## leap — it may have stepped off while he wound up): fast and low, held in
## the coiled pose, following it, no further than `lunge` and never past it;
## the blows come when he is there. With nothing to go at, that far ahead
## and no further than a third of it.
@export var glide_speed: float = 18.0
@export var glide_longest: float = 0.42
var _glide_left: float = 0.0
var _glide_foe: Node3D = null
var _glide_dir := Vector3.ZERO


func _on_wound_up(lunge: float) -> void:
	PlayerHurt._on_wound_up(self, lunge)


static func _body_radius(who: Node3D) -> float:
	var r: Variant = who.get(&"body_radius")
	if r == null:
		return 0.45
	var s: Variant = who.get(&"visual_scale")
	return float(r) * (float(s) if s != null else 1.0)


@rpc("any_peer", "call_local", "reliable")
func net_strike_at(foe: NodePath) -> void:
	_strike_foe = get_node_or_null(foe) as Node3D if not foe.is_empty() else null


func _aim_strike() -> void:
	PlayerMelee._aim_strike(self)


@rpc("any_peer", "call_local", "reliable")
func net_attack(style: int) -> void:
	if rig != null:
		rig.attack(style)
		# What this swing's cuts are numbered from: a landing told of after
		# this is one of them ([method _judge_whiff]).
		if rig.get(&"attack_serial") != null:
			_swing_serial0 = int(rig.get(&"attack_serial"))
	# TODO: enable the weapon hitbox for the active frames.


## Holds everything else off for `seconds`. Zero or a shorter time than is
## already left never shortens a commitment already running.
func _commit(seconds: float) -> void:
	PlayerMelee._commit(self, seconds)


## True while an attack is playing out and nothing else may be started.
func is_committed() -> bool:
	return PlayerMelee.is_committed(self)


## The end of a plunge: the blade goes into the ground and the man behind it
## has to get it back out.
##
## This is what the move is **paid for with**. A jumping attack that ends with
## the character back on his feet and ready costs nothing, so there would be no
## reason to throw anything else — and there would be nothing for an opponent to
## punish, which is the half that matters once there are two players. Burying
## the sword and pulling it out is the price, and it is the same price every
## Souls-like charges for the same move.
##
## Everything stops: the run, the input, and any way out of it, for
## `plunge_recovery`. The rig does the standing back up.
func _plant_blade() -> void:
	PlayerMelee._plant_blade(self)


## Puts the body on the target at once, without easing. Nothing to do when there
## is nothing being fought: a free swing goes where the fighter already faces.
func _turn_to_target() -> void:
	PlayerMelee._turn_to_target(self)


#region Cuts that do not miss
@export_group("Sure cuts")
## The running cut and Tariel's skills (TARIEL_POLISH.md 11-12) do not miss
## what they are thrown at — the locked target, else what the move picked —
## for the blade passing over it, under it or a hand's breadth beside it
## (standing within `sure_rise` above or below him).
## They miss it only when it is out of the way: in its dodge
## (`is_evading()`), out of the blade's reach, or gone off to the side: more
## than `sure_cone` degrees round from where he faces AND far enough over that
## the line he faces along no longer goes through the middle `sure_side` of
## its body (a third of it gone past the line, it is missed).
@export var sure_cone: float = 25.0
@export_range(0.0, 1.0) var sure_side: float = 0.65
## Past the blade's own reach (its tip from his middle, along the ground) by
## this much, still in reach; its feet this far above or below his, still cut.
@export var sure_reach_margin: float = 0.45
@export var sure_rise: float = 2.4
## Until the blade starts to cut he turns after it, this quickly (as a lock
## turns him); not after something that has got round behind him.
@export var sure_turn_speed: float = 14.0
@export var sure_follow_cone: float = 110.0
## What the cut in hand does not miss, on every peer, and which swing it is.
var _sure_foe: Node3D = null
var _sure_serial: int = -1


## The swing just thrown does not miss `foe` (every peer is told); `margin`,
## if given, its reach past the blade's own instead of `sure_reach_margin`.
func _mark_sure(foe: Node3D, margin: float = -1.0) -> void:
	PlayerMelee._mark_sure(self, foe, margin)


## The reach past the blade's own for the swing in hand (-1: `sure_reach_margin`).
var _sure_margin: float = -1.0


@rpc("any_peer", "call_local", "reliable")
func net_sure_at(foe: NodePath, margin: float = -1.0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	_sure_foe = get_node_or_null(foe) as Node3D if not foe.is_empty() else null
	_sure_margin = margin
	_sure_serial = int(rig.get(&"attack_serial")) if rig != null and rig.get(&"attack_serial") != null else -1


## The edge of his blade as `who` is to take it (what the creatures read,
## each for itself): the blade's own, or — a cut that does not miss, at what
## it was thrown at, while it cuts — that edge moved onto it, through where a
## cut is aimed at it ([method strike_point]).
func cutting_edge_for(who: Node3D) -> PackedVector3Array:
	return PlayerMelee.cutting_edge_for(self, who)


## Whether the cut in hand, its edge at `edge`, cannot miss `who` now (see
## `sure_cone`).
func sure_holds(who: Node3D, edge: PackedVector3Array) -> bool:
	return PlayerMelee.sure_holds(self, who, edge)


## Until a cut that does not miss starts cutting, he turns after what it is
## thrown at (the owner's; the turn goes out with the body).
func _track_sure(delta: float) -> void:
	PlayerMelee._track_sure(self, delta)


## How wide `who` is to a blade: what the creature's own blade test reads
## (a [Fighter]'s radius is drawn at its size, the others' as it is).
static func _blade_radius(who: Node3D) -> float:
	return PlayerMelee._blade_radius(who)


#region The running cut, the shield charge, the cut that misses
@export_group("Running cut")
## The first cut thrown at more than this share of `run_speed` is the running
## cut: a lunging sweep of its own (the rig's `run_attack`), the string going
## on from its second blow after it.
@export_range(0.0, 1.0) var run_cut_pace: float = 0.75
## His run lasts under it until the blade starts to cut, and then this long
## (one more step through the swing) before he is down to a swing's pace.
@export var run_cut_ease: float = 0.35
## A running cut that winds up (its spec's `hold`) is held wound up while he
## runs in, at most this long, and let go `strike_gap` metres (body to body)
## off what he runs at, or at a second press.
@export var run_cut_hold_max: float = 1.4
## How far ahead (metres, degrees off his way) he picks what to run at.
@export var run_cut_seek: float = 11.0
@export var run_cut_seek_cone: float = 40.0
## Its stamina, in light cuts'.
@export var run_cut_stamina: float = 1.25

@export_group("Shield charge")
## The dash with the shield up: he drives in behind it at `bash_speed` for
## `bash_travel` seconds, and is held for `bash_time` in all.
@export var bash_speed: float = 8.0
@export var bash_travel: float = 0.38
@export var bash_time: float = 0.85
## How near (body to body, metres) and how far round from straight ahead
## (degrees) the shield takes something.
@export var bash_reach: float = 0.55
@export var bash_cone: float = 55.0
## What it does to what it hits: a shove, a share of a cut's worth, and the
## reel ([Recoil]) every creature has for a guard broken, which leaves it
## open to the next blow.
@export var bash_push: float = 6.0
@export var bash_damage: float = 0.35
## Its stamina, in evades'.
@export var bash_stamina: float = 1.3

@export_group("Kick")
## The archer's kick on the block button (he has no shield): the clip played
## from `kick_from` to `kick_to` of it at `kick_rate`, the foot out at
## `kick_contact` of it (measured, `_shots_tmp/kick_probe.gd`: the right foot
## furthest out, 0.75 m ahead at chest height, at 0.47-0.5).
@export var kick_rate: float = 1.6
@export var kick_from: float = 0.12
@export var kick_to: float = 0.85
@export var kick_contact: float = 0.47
## How near (from his middle to the other's body, metres) and how far round
## from straight ahead (degrees) the foot takes something.
@export var kick_reach: float = 1.35
@export var kick_cone: float = 60.0
## What it does: a shove back ([method Brute.react] `knock`, as the shield's
## charge) of `kick_throw` metres on a brute (its shove dies away at 4/s, so
## the push asked for is worked out from that), `kick_push` on anything else
## (a wolf takes it straight onto its speed); a small share of a cut, its
## stamina and how soon another.
@export var kick_throw: float = 2.5
## The kick is off the block button for now (the user's word, 2026-10-05): the
## fan of three arrows is there instead ([member fan_share]).
@export var kick_on_block: bool = false
@export var kick_push: float = 6.0
@export var kick_damage: float = 0.25
@export var kick_stamina: float = 14.0
@export var kick_cooldown: float = 1.5

@export_group("Missed cut")
## A cut of the string that goes through nothing drags on this much longer in
## its follow-through (the clip played at `whiff_slow` over it), and is not
## to be rolled out of until it has: the price of swinging at the air.
@export var whiff_recovery: float = 0.22
@export_range(0.1, 1.0) var whiff_slow: float = 0.5
## Only with something to fight this near (metres) as the cut is thrown:
## swinging at the air with nothing about is no miss.
@export var whiff_near: float = 6.0

## The charge's travel left (seconds), the way it goes and what it has
## already taken: on every peer, the host deciding what it hits.
var _bash_left: float = 0.0
var _bash_dir: Vector3 = Vector3.ZERO
var _bash_struck: Array[Node3D] = []
## The first attack serial of the swing in hand, the serial of the last cut
## told to have landed, the swing last judged, and until when a missed one
## drags.
var _swing_serial0: int = -1
var _landed_serial: int = -1
var _whiff_judged: int = -1
var _whiff_until: float = -100.0
## Whether the swing in hand was thrown with something within `whiff_near`.
var _whiff_counts: bool = false
## A running cut held wound up while he runs in, since when, and at what.
var _cut_charging: bool = false
var _charge_t0: float = -100.0
var _charge_foe: Node3D = null
## The spec of the cut held ([Swordsman] `RUN_ATTACK` or `RISING_CUT`), and
## whether it is the skill (it runs at what it picked of itself, standing
## start or not).
var _charge_spec: Dictionary = {}
## The way the knight's charge runs, and how fast it may be turned (rad/s).
var _charge_dir: Vector3 = Vector3.ZERO
const CHARGE_TURN := 1.1
## Within this many degrees of what he is locked on, the charge is drawn on
## to it this fast (rad/s); and it is let go at it within `CHARGE_STRIKE_CONE`.
const CHARGE_ASSIST_CONE := 45.0
const CHARGE_ASSIST_TURN := 2.6
const CHARGE_STRIKE_CONE := 80.0
var _charge_skill: bool = false
## How long after the swing goes his run is kept whole (till its cut).
var _ease_delay: float = 0.0


## Anything to fight within `reach` metres.
func _foe_within(reach: float) -> bool:
	return PlayerMelee._foe_within(self, reach)


## What a wound-up running cut runs at: the locked target, else the nearest
## thing to fight ahead of the way he is going within `run_cut_seek`.
func _charge_target(seek: float = -1.0) -> Node3D:
	return PlayerMelee._charge_target(self, seek)


func _charge_aim(direction: Vector3) -> Vector3:
	return PlayerMelee._charge_aim(self, direction)


## The wound-up running cut, let go when he is near enough what he runs at,
## when he stops pushing with nothing to run at, at a second press, or when
## it has been held `run_cut_hold_max`. Broken off by anything that takes the
## clip off him (a blow).
func _tick_charge() -> void:
	PlayerMelee._tick_charge(self)


@rpc("any_peer", "call_local", "reliable")
func net_release_cut(leap: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if rig != null and rig.has_method(&"release_cut"):
		rig.call(&"release_cut", leap)


## Whether `from`'s blow now is low enough to pass under a jump: its weapon
## (where the creature can say, [method weapon_low]) under `jump_clear_low`
## over his feet.
func _low_blow(from: Node3D) -> bool:
	return PlayerMelee._low_blow(self, from)


#region The kick (AVTANDIL_POLISH 7)
## The kick's wait for the foot to come out (seconds, on every peer), the way
## it goes, and how soon another may be thrown.
var _kick_wait: float = -1.0
var _kick_dir: Vector3 = Vector3.ZERO
var _kick_cool: float = 0.0


## A hero with no shield and a bow, on his feet, a rig that kicks.
func _can_kick() -> bool:
	return PlayerMelee._can_kick(self)


## He turns to what he is locked on (or what is in front) and kicks it away:
## a draw in hand is let go of, unshot.
func _kick() -> void:
	PlayerMelee._kick(self)


@rpc("any_peer", "call_local", "reliable")
func net_kick(dir: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	_kick_dir = dir
	if rig != null and rig.has_method(&"kick"):
		_kick_wait = float(rig.call(&"kick", kick_rate, kick_from, kick_to, kick_contact))
		var swish: Variant = rig.get(&"swing_sounds")
		if swish is Array:
			Sfx.play_any(self, swish as Array, self, 0.9, -5.0)


## The foot out: the host takes what is in front of it.
func _tick_kick(delta: float) -> void:
	PlayerMelee._tick_kick(self, delta)


## The foot went in: the thud and the jolt, on every peer.
@rpc("any_peer", "call_local", "reliable")
func net_kick_landed(path: NodePath, at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != multiplayer.get_unique_id():
		return
	var who := get_node_or_null(path) as Node3D
	HitFeel.bite(who, 1.0)
	ImpactFx.thud(self, at, false)
	DustRing.burst(Blood.world_of(self), Vector3(at.x, global_position.y, at.z), 0.45)
	if is_multiplayer_authority() and camera != null and camera.current:
		ImpactFx.knock(camera, _kick_dir, 0.05, 0.05, 0.18)
#endregion


## The shield up, on his feet, and a rig that charges with it.
func _can_bash() -> bool:
	return PlayerMelee._can_bash(self)


## The charge behind the shield: he turns to what is in front (or what he is
## locked on) and drives in, the guard coming down for it.
func _shield_bash() -> void:
	PlayerMelee._shield_bash(self)


@rpc("any_peer", "call_local", "reliable")
func net_shield_bash(dir: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	_bash_dir = dir
	_bash_left = bash_travel + 0.06
	_bash_struck.clear()
	if rig != null and rig.has_method(&"shield_bash"):
		rig.call(&"shield_bash", bash_time)
	Sfx.play(self, ROLL_SOUND, self, Vector3.ZERO, 0.85, MOVE_VOLUME[MoveSound.ROLL])


## The charge going: the host looks for what is in front of the shield.
func _tick_bash(delta: float) -> void:
	PlayerMelee._tick_bash(self, delta)


## The shield went into something: the clang and the jolt, on every peer;
## the charge stopped dead on it, and a step back off it.
@rpc("any_peer", "call_local", "reliable")
func net_bash_landed(path: NodePath, at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != multiplayer.get_unique_id():
		return
	_bash_left = 0.0
	var who := get_node_or_null(path) as Node3D
	HitFeel.bite(who, 1.15)
	Sfx.play(self, PARRY_SOUND, self, at - global_position, randf_range(0.8, 0.9), -2.0)
	ImpactFx.thud(self, at, true)
	DustRing.burst(Blood.world_of(self), Vector3(at.x, global_position.y, at.z), 0.6)
	if is_multiplayer_authority():
		_step_velocity = -_bash_dir * 1.6
		_step_left = 0.1
		if camera != null and camera.current:
			ImpactFx.knock(camera, _bash_dir, 0.06, 0.07, 0.22)


## A cut of the string past its cut with nothing landed: it drags on
## (`whiff_recovery`), and the evade may not take him out of it till then.
func _judge_whiff() -> void:
	PlayerMelee._judge_whiff(self)


## Puts on a shield ([enum Inventory.Shields]); every peer sees it through
## `net_shield`.
func set_shield(kind: int) -> void:
	PlayerLooks.set_shield(self, kind)


## Wears one of the rig's `faces`; every peer sees it through `net_face`.
func set_face(index: int) -> void:
	PlayerLooks.set_face(self, index)


## Wears the look made on the hero select ([PolysplitLook]); every peer sees
## it through `net_look`.
func set_look(made: Dictionary) -> void:
	PlayerLooks.set_look(self, made)


## Dyes the rig's clothes (its `TINTS`); every peer sees it through `net_tint`.
func set_tint(index: int) -> void:
	PlayerLooks.set_tint(self, index)


## Wears one of the rig's `hairs`; every peer sees it through `net_hair`.
func set_hair(index: int) -> void:
	PlayerLooks.set_hair(self, index)


## Puts on one of his outfits (an index into the rig's `garbs`); every peer
## sees it through `net_garb`.
func set_garb(index: int) -> void:
	PlayerLooks.set_garb(self, index)


## What he has on now kept for the next level ([method Game.worn]).
func remember_worn() -> void:
	PlayerLooks.remember_worn(self)


## What he has found and carries ([GEAR_SETS.md] §5.7, the user's word
## 2026-10-07): the keys of the bag's things ([method Inventory.key_of]). He
## starts with what he wears and holds; the rest falls from the creatures he
## kills ([LootDrop]). Remembered between runs, by hero ([method Game.owned]).
var _owned: Dictionary = {}
var _owned_read: bool = false


## Whether he carries the thing of `key`.
func owns(key: String) -> bool:
	return PlayerLooks.owns(self, key)


## He has the thing of `key` now; false if he had it already.
func gain(key: String) -> bool:
	return PlayerLooks.gain(self, key)


const PARRY_SOUND := "res://sounds/parry/clang.wav"
const BLOCK_SOUND := "res://unverified/sounds/all/block_1.wav"
const FALL_SOUND := "res://unverified/sounds/all/fall_1.wav"
const SHADOW_SOUND := "res://unverified/sounds/dodge/shadow.wav"
const ROLL_SOUND := "res://unverified/sounds/dodge/roll.wav"

## The body's own moves that are heard: the push off the ground, coming down
## on it, and the evades — the roll, and the assassin's step and flip.
enum MoveSound { JUMP, LAND, ROLL, STEP, FLIP }
const MOVE_SOUNDS: Array[String] = [
	"res://unverified/sounds/all/jump.wav",
	"res://unverified/sounds/all/land.wav",
	ROLL_SOUND,
	"res://unverified/sounds/assassin/step.wav",
	"res://unverified/sounds/assassin/flip.wav",
]
## Each one's loudness, set so a jump is a little over a footfall and the
## evades sit with the fight's other sounds, under the blades.
const MOVE_VOLUME: Array[float] = [-13.0, -12.0, -20.0, -22.0, -20.0]
## A landing is heard from this fall speed up (a jump comes down at about 4.5
## m/s; a curb at 2); louder towards [member hard_landing_speed].
@export var land_sound_speed: float = 3.2
## How many of each [enum MoveSound] this body has made heard, for the tests.
var move_sounds_heard: Array[int] = [0, 0, 0, 0, 0]


## Called by the body's own peer when it jumps, lands or evades; every peer
## plays it (the moves themselves run only where the body is driven).
func _move_sound(kind: MoveSound, strength: float = 1.0) -> void:
	if is_multiplayer_authority():
		net_move_sound.rpc(kind, strength)


@rpc("any_peer", "call_local", "unreliable")
func net_move_sound(kind: int, strength: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if kind < 0 or kind >= MOVE_SOUNDS.size() or not is_inside_tree():
		return
	move_sounds_heard[kind] += 1
	var volume := MOVE_VOLUME[kind]
	if kind == MoveSound.LAND:
		volume += lerpf(0.0, 7.0, clampf(strength, 0.0, 1.0))
	Sfx.play(self, MOVE_SOUNDS[kind], self, Vector3.ZERO, 1.0, volume)


## Shift held, going somewhere, on his feet and with stamina to spend: not
## walking, crouched, behind the shield or with the string drawn, and not
## winded (run dry, he jogs until a fifth of it is back).
func _wants_sprint(direction: Vector3, walking: bool) -> bool:
	if walking or direction.is_zero_approx() or _crouching or is_blocking or _drawing:
		return false
	if not InputMap.has_action(&"sprint") or not Input.is_action_pressed(&"sprint"):
		return false
	# it costs stamina in a fight and out of it (the user's word, 2026-10-23)
	return stamina > 0.0 and not _winded


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Takes `cost` off the stamina, if there is any to take it from.
##
## As in every Souls game, what matters is that there is *some* left, not that
## there is enough: the last of it buys one more roll, and the bar runs out
## under it. Returns false, spending nothing, when it is already empty.
func _spend(cost: float) -> bool:
	if stamina <= 0.0 and cost > 0.0:
		return false
	stamina = maxf(stamina - cost, 0.0)
	_stamina_wait = stamina_delay
	if stamina <= 0.0:
		_winded = true
		_stamina_wait = stamina_empty_delay
	return true


## True from the moment the stamina runs out until it has started back.
func is_winded() -> bool:
	return _winded


func _tick_vitals(delta: float) -> void:
	if is_dead:
		return
	_stamina_wait = maxf(_stamina_wait - delta, 0.0)
	# Nothing comes back while something is being spent: mid-roll, mid-swing.
	var busy := state == State.DASHING or state == State.DODGING or is_committed() or _drawing
	if _stamina_wait <= 0.0 and not busy and stamina < max_stamina:
		stamina = minf(stamina + (stamina_regen_guarded if is_blocking else stamina_regen) * delta,
				max_stamina)
		if stamina > max_stamina * 0.2:
			_winded = false
	_since_hurt += delta
	if _since_hurt >= mend_after and health < max_health:
		health = minf(health + mend_rate * delta, max_health)


## Takes a blow's worth off the health. Returns true if that was the end of him.
func _take_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	_struck_lately = true
	# struck through a drink before it went down: spilt
	_drink_heal_at = -1.0
	_drink_until = -100.0
	health = maxf(health - amount, 1.0 if immortal else 0.0)
	_since_hurt = 0.0
	if health <= 0.0:
		_die()
		return true
	return false


## Fallen. He lies where he fell until `respawn_time` is up and is then put back
## on his feet where he started, whole.
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	state = State.DOWNED
	_respawn_left = respawn_time
	_down_for = 0.0
	is_invulnerable = true
	_drawing = false
	_draw_timer = 0.0
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	_commit_timer = 0.0
	_root_timer = 0.0
	_attack_buffer = 0.0
	_plunging = false
	if target != null:
		_drop_target()
	net_react.rpc(Reaction.DEATH, global_position + Vector3.UP * 1.1, Vector3.UP)
	died.emit()


func _respawn() -> void:
	is_dead = false
	health = max_health
	flasks_left = flask_count
	_drink_heal_at = -1.0
	_drink_until = -100.0
	stamina = max_stamina
	_winded = false
	_since_hurt = 0.0
	velocity = Vector3.ZERO
	if _spawn_known:
		global_position = _spawn_point
	state = State.AIRBORNE
	is_invulnerable = false
	_combo_landed.clear()
	net_react.rpc(Reaction.RESPAWN, Vector3.ZERO, Vector3.ZERO)
	respawned.emit()
#endregion


#region Housekeeping
func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_slide_timer = maxf(_slide_timer - delta, 0.0)
	_slide_cooldown_timer = maxf(_slide_cooldown_timer - delta, 0.0)
	_wall_cooldown_timer = maxf(_wall_cooldown_timer - delta, 0.0)
	# A swing held in its bite holds his clock with it: the commitment, and a
	# cut asked for meanwhile, wait for the clip rather than run out under it.
	var bitten := _bitten()
	if not bitten:
		_commit_timer = maxf(_commit_timer - delta, 0.0)
	_root_timer = maxf(_root_timer - delta, 0.0)
	if _drink_heal_at >= 0.0 and _now() >= _drink_heal_at:
		_drink_heal_at = -1.0
		net_heal(max_health * flask_heal)
	if not bitten and not _rig_drawing():
		_attack_buffer = maxf(_attack_buffer - delta, 0.0)
		_heavy_buffer = maxf(_heavy_buffer - delta, 0.0)
	# A flurry is over once nothing has been swung for a beat, and the next cut
	# counts as a first one again — so running in and hitting something is always
	# the fast swing, however many were thrown a moment ago.
	# A plunge holds the commitment open for as long as the fall lasts. There is
	# no rolling out of one halfway down: the move is thrown and then landed.
	if _plunging:
		_commit_timer = maxf(_commit_timer, delta * 2.0)
	if _commit_timer > 0.0 or _attack_buffer > 0.0:
		_chain_timer = chain_window
	else:
		_chain_timer = maxf(_chain_timer - delta, 0.0)
		if _chain_timer <= 0.0:
			_swing_chain = 0


## Reads back what the move actually hit: the steep ground the next tick has to
## slide off, a ceiling to stop dead against, and any loose body to shove.
func _resolve_contacts() -> void:
	_steep_normal = Vector3.ZERO
	var floor_cos := cos(floor_max_angle)

	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()

		# Faces up, but not enough to stand on.
		var facing := normal.dot(up_direction)
		if facing > 0.05 and facing < floor_cos and facing > _steep_normal.dot(up_direction):
			_steep_normal = normal

		if push_force > 0.0:
			var body := contact.get_collider() as RigidBody3D
			if body != null:
				var push := -normal
				push.y = 0.0
				if not push.is_zero_approx():
					push = push.normalized()
					var into := velocity.dot(push)
					if into > 0.0:
						body.apply_impulse(push * into * push_force,
								contact.get_position() - body.global_position)

	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0


func _update_floor_state() -> void:
	PlayerMove._update_floor_state(self)


func _toggle_fullscreen() -> void:
	var windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED)


#endregion


#region Skills
## The skills, by id: the name on the bar, the stamina one costs, and how long
## before it can be used again. Which of them a hero has, and in which slot, is
## his profile's (`CharacterProfile.skills`).
const SKILLS := {
	&"arrow_rain": {"name": "Rain of Arrows", "stamina": 25.0, "cooldown": 12.0},
	&"hunters_mark": {"name": "Hunter's Mark", "stamina": 12.0, "cooldown": 14.0},
	&"piercing_arrow": {"name": "Piercing Arrow", "stamina": 30.0, "cooldown": 10.0},
	&"fire_arrow": {"name": "Fire Arrow", "stamina": 25.0, "cooldown": 12.0},
	&"stun_arrow": {"name": "Stunning Arrow", "stamina": 22.0, "cooldown": 9.0},
	&"poison_blade": {"name": "Poisoned Blade", "stamina": 15.0, "cooldown": 18.0},
	&"rising_cut": {"name": "Rising Cut", "stamina": 22.0, "cooldown": 8.0},
	&"shadow_slide": {"name": "Shadow Slide", "stamina": 24.0, "cooldown": 9.0},
	&"shadow_lance": {"name": "Shadow Lance", "stamina": 26.0, "cooldown": 10.0},
	&"shadow_step": {"name": "Shadow Step", "stamina": 20.0, "cooldown": 9.0},
	&"vanish": {"name": "Vanish", "stamina": 25.0, "cooldown": 40.0},
	&"challenge": {"name": "Challenge", "stamina": 20.0, "cooldown": 20.0},
	&"frost_spears": {"name": "Frost Spears", "stamina": 25.0, "cooldown": 14.0},
	&"frost_step": {"name": "Frost Step", "stamina": 18.0, "cooldown": 9.0},
	&"dark_grasp": {"name": "Dark Hands", "stamina": 22.0, "cooldown": 11.0},
	&"black_comets": {"name": "Black Comets", "stamina": 30.0, "cooldown": 16.0},
	&"black_sun": {"name": "Black Sun", "stamina": 28.0, "cooldown": 18.0},
	&"frost_nova": {"name": "Frost Nova", "stamina": 22.0, "cooldown": 14.0},
	&"moonwell": {"name": "Moonwell", "stamina": 30.0, "cooldown": 24.0},
	&"moonfall": {"name": "Moonfall", "stamina": 28.0, "cooldown": 10.0},
}
const SKILL_SLOTS := 4

## A skill went off, from `slot` (0..3).
signal skill_used(slot: int, id: StringName)

## Rain of Arrows: how far off it may fall, where it falls with nothing locked,
## and what each arrow is worth as a share of a full draw's damage.
@export_group("Rain of Arrows")
@export var rain_range: float = 18.0
@export var rain_ahead: float = 9.0
@export var rain_share: float = 0.35

## When each skill may be used again, by id, on the clock `_now()` reads.
var _skill_ready_at: Dictionary = {}


## The skills he has picked for the four sockets, in order (the user's word,
## 2026-10-07: a hero with more skills than sockets chooses which,
## [SkillBook]); empty, the first of his profile's. Kept between games.
var skill_picks: PackedStringArray = PackedStringArray()
const PICKS_FILE := "user://skill_picks.cfg"


## Every skill he has, picked or not.
func skill_choices() -> PackedStringArray:
	return PlayerSkills.skill_choices(self)


## Puts skill `id` in `slot`; if it was in another socket, what was in `slot`
## goes there instead. Kept for this hero.
func set_skill_slot(slot: int, id: StringName) -> void:
	PlayerSkills.set_skill_slot(self, slot, id)


func _keep_picks() -> void:
	PlayerSkills._keep_picks(self)


## His picks as he left them last time, if they still fit what he has.
func _load_picks() -> void:
	PlayerSkills._load_picks(self)


## The skill in `slot`, or `&""` for an empty one.
func skill_in(slot: int) -> StringName:
	return PlayerSkills.skill_in(self, slot)


## Seconds before the skill in `slot` can be used again (0 when it can).
func skill_cooldown_left(slot: int) -> float:
	return PlayerSkills.skill_cooldown_left(self, slot)


## Its whole cooldown, for the bar to draw the rest against.
func skill_cooldown(slot: int) -> float:
	return PlayerSkills.skill_cooldown(self, slot)


## Uses the skill in `slot`, if there is one, it is ready and the body is free
## to. True if it went off.
func use_skill(slot: int) -> bool:
	return PlayerSkills.use_skill(self, slot)


## The Rising Cut (Tariel): the sword drawn back low, he runs at what is
## in front (or locked), and near it brings the blade up through it
## ([Swordsman] `RISING_CUT`, UAL 2's Sword_UpperCut held wound up). With
## nothing to run at, a few strides the way he faces and the cut.
@export_group("Rising Cut")
## How far ahead (metres) it picks what to run at.
@export var rising_seek: float = 14.0


## The Shadow Slide (Tariel's second skill, [Swordsman] `SHADOW_SLIDE`): the
## running cut (UAL 2's Sword_Light_D) thrown out of a slide. No standing and
## no frozen pose: as the key goes the shadows start, he gathers into the
## slide (its pace eased in over `shade_ease`) and goes in at what he picked,
## the blade drawn back and coming on slowly (the rig's `creep`) as though a
## spell were being cast, and the sweep let go so it cuts as he arrives.
## With nothing before him he slides further (`slide_blind`).
@export_group("Shadow Slide")
## How far ahead (metres) it picks what to slide at.
@export var shade_seek: float = 12.0
## The slide's pace (m/s) and how long it takes to reach it from standing.
@export var shade_speed: float = 22.0
@export var shade_ease: float = 0.14
## The slide (1) or none (-1); since when; the slide left (metres), its way,
## and whether the cut has been let go.
var _shade_phase: int = -1
var _shade_t0: float = 0.0
var _shade_left: float = 0.0
var _shade_dir: Vector3 = Vector3.ZERO
var _shade_gone: bool = false
## The slide is the lance's (the blade out in front, stopped by what it hits).
var _shade_lance: bool = false
## How far the slide has gone (metres), and its pace this tick.
var _shade_went: float = 0.0
var _shade_pace_now: float = 0.0


## The slide and its cut let go (the owner's, on the physics clock).
func _tick_shade(delta: float) -> void:
	PlayerSkills._tick_shade(self, delta)


## How much a swing timed to a slide's end may be hurried past its own pace.
const SHADE_HURRY := 1.8


## Sliding in now: what slides with him on every peer — the shadows shed
## behind him the length of the slide, and the hiss of it.
@rpc("any_peer", "call_local", "reliable")
func net_slide(seconds: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	ShadowTrail.start(self, seconds + 0.1, 0.028)
	Sfx.play(self, SHADOW_SOUND, self, Vector3.ZERO, 1.15, -3.0)


## Rain of Arrows: one arrow up into the sky, and a moment later a volley down
## over a ring — on what is locked, if it is in reach, or ahead of him.
func _arrow_rain() -> bool:
	return PlayerBow._arrow_rain(self)


## The rain, on every peer, from the same seed: the shot into the sky, the
## arrow up when the string goes, and the volley ([ArrowRain]) after it,
## following what it was loosed at if anything. Only the host's arrows count
## for damage, as always.
@rpc("any_peer", "call_local", "reliable")
func net_arrow_rain(from: Vector3, up: Vector3, centre: Vector3, rain_seed: int,
		quarry: NodePath = NodePath()) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	# Cut short if he is hit before it goes ([method _interrupt_skill]).
	var serial := _skill_serial
	var lead := 0.0
	if rig != null and rig.has_method(&"sky_shot"):
		lead = float(rig.call(&"sky_shot"))
	if lead > 0.0:
		await get_tree().create_timer(lead, false).timeout
		if serial != _skill_serial:
			return
		if not is_inside_tree() or is_dead:
			return
	var into := Blood.world_of(self)
	if into == null or arrow_scene == null:
		return
	var shot_from := from
	if rig != null and rig.has_method(&"bow_hand"):
		shot_from = rig.call(&"bow_hand")
	var shot := arrow_scene.instantiate() as Node3D
	shot.set(&"lifetime", 0.8)
	into.add_child(shot)
	shot.global_position = shot_from
	shot.call(&"launch", up, 0.0, false, _gravity, self)
	Sfx.play(self, RELEASE_SOUND, self, Vector3.ZERO, 0.9, -8.0)
	if lead <= 0.0 and rig != null and rig.has_method(&"loose_bow"):
		rig.call(&"loose_bow")
	var rain := ArrowRain.new()
	rain.name = "ArrowRain"
	into.add_child(rain)
	rain.global_position = centre
	var each := (profile.damage if profile != null else 26.0) * BowKinds.atk(self) * rain_share
	rain.start(self, arrow_scene, rain_seed, each, profile.crit_chance if profile != null else 0.1,
			profile.crit_damage if profile != null else 2.0)
	if not quarry.is_empty():
		rain.follow(get_node_or_null(quarry) as Node3D)


## The skills' own numbers.
@export_group("Hunter's Mark")
## How far off it can be put on something.
@export var mark_range: float = 32.0
## How long the prey stays marked: a bow's blows on it do `Afflictions.MARK_BOW`, anyone else's `MARK_OTHER`.
@export var mark_time: float = 10.0
## How fast the glint flies at it, m/s (straight, like an arrow).
@export var mark_speed: float = 75.0

@export_group("Piercing Arrow")
## How long the string is held past full, gathering the wind.
@export var pierce_hold: float = 0.9
## What the arrow is worth, as a share of a full draw's damage.
@export var pierce_share: float = 1.8
@export var pierce_speed: float = 70.0
@export var pierce_reach: float = 40.0
## How hard what it goes through is thrown back, in m/s.
@export var pierce_knock: float = 6.0
## How hard the shot shoves him back, in m/s.
@export var pierce_recoil: float = 7.0

@export_group("Fire Arrow")
## The shot itself, as a share of a full draw.
@export var fire_share: float = 0.6
## Where it lands with nothing locked: this far ahead.
@export var fire_ahead: float = 13.0
@export var fire_range: float = 26.0
@export var fire_radius: float = 2.6
@export var fire_time: float = 5.0
## Burn a second on whatever stands in it.
@export var fire_dps: float = 14.0

@export_group("Poisoned Blade")
## Rate the coat is played at.
@export var coat_rate: float = 1.4
## How long the blade stays poisoned once coated.
@export var venom_time: float = 10.0
## Each stack on a creature lasts this long and costs it this much a second
## (up to five, the fifth boils it — [constant Afflictions.POISON_MAX],
## [method Afflictions.apply]). No more than 5 a second in all (the user's
## word, 2026-10-06: it was 5 a stack, 25 at five, the assassin too strong).
@export var venom_stack_time: float = 6.0
@export var venom_dps: float = 1.0

## Until when (on `_now()`) this hero's blade poisons what it cuts.
var _venom_until: float = 0.0


## Something to aim a skill at: what is locked, if it is in `reach`, else the
## best thing in front.
func _skill_quarry(reach: float) -> Node3D:
	return PlayerBow._skill_quarry(self, reach)


## Hunter's Mark: he points at the prey and a glint flies from his fingers
## onto it. For `mark_time` it is marked — the sigil over it, an outline, a
## ring on the ground — and every blow on it, anyone's, bites deeper.
func _hunters_mark() -> bool:
	return PlayerBow._hunters_mark(self)


@rpc("any_peer", "call_local", "reliable")
func net_hunters_mark(quarry_path: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	# Cut short if he is hit before it goes ([method _interrupt_skill]).
	var serial := _skill_serial
	var quarry := get_node_or_null(quarry_path) as Node3D
	var lead := 0.4
	if rig != null and rig.has_method(&"point_mark"):
		lead = float(rig.call(&"point_mark", quarry))
	await get_tree().create_timer(lead, false).timeout
	if serial != _skill_serial:
		return
	if not is_inside_tree() or is_dead or quarry == null or not is_instance_valid(quarry):
		return
	var into := Blood.world_of(self)
	if into == null:
		return
	var from := global_position + Vector3.UP * 1.5
	if rig != null and rig.has_method(&"bone_position"):
		from = rig.call(&"bone_position", &"hand_r")
	var light := HuntingLight.new()
	# Straight and fast, like a shot: no arc, at `mark_speed`.
	var aim := HuntingLight._aim_of(quarry)
	light.throw(from, quarry, aim, clampf(from.distance_to(aim) / mark_speed, 0.05, 0.5))
	into.add_child(light)
	Sfx.play(self, RELEASE_SOUND, self, Vector3.ZERO, 1.35, -13.0)
	light.arrived.connect(func(at: Vector3) -> void:
		if not is_instance_valid(quarry) or quarry.get(&"is_dead") == true:
			return
		SkillFx.flash(into, at, Afflictions.CRIMSON, 0.7, 0.22, 3.0)
		SkillFx.burst(into, at, Afflictions.GOLD, 40, Vector2(2.0, 5.0), Vector3.UP, 180.0,
				Vector2(0.02, 0.05), Vector3(0, -3, 0), 0.5)
		var marks := Afflictions.of(quarry)
		if marks != null:
			marks.apply(&"mark", mark_time, self)
		if _decides_here() and quarry.has_method(&"react"):
			quarry.call(&"react", &"mark", self, Vector3.ZERO))
#endregion


## Piercing Arrow: the string held past full while the wind gathers on the
## head, then one arrow, flat and fast, through everything on its line.
func _piercing_arrow() -> bool:
	return PlayerBow._piercing_arrow(self)


@rpc("any_peer", "call_local", "reliable")
func net_piercing(dir: Vector3, damage: float, critical: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	# Cut short if he is hit before it goes ([method _interrupt_skill]).
	var serial := _skill_serial
	var into := Blood.world_of(self)
	if into == null:
		return
	var nock := 0.3
	if rig != null and rig.has_method(&"charged_shot"):
		nock = float(rig.call(&"charged_shot", pierce_hold, asin(clampf(dir.y, -1.0, 1.0)), 1.0))
	Sfx.play(self, ULT_CAST, self, Vector3.ZERO, 1.0, -11.0, 0.0)
	await get_tree().create_timer(nock, false).timeout
	if serial != _skill_serial:
		return
	if not is_inside_tree() or is_dead:
		return
	# Held at full, as still as an ordinary aim, with only a little whirl of
	# air at the arrowhead ([AirSwirl]); the great wind is the shot's
	# ([PiercingShot]).
	Sfx.play(self, ULT_CHARGE, self, Vector3.ZERO, 1.0, -11.0, 0.0)
	var swirl := AirSwirl.new()
	swirl.start(rig, pierce_hold + 0.05)
	into.add_child(swirl)
	_air_swirl = swirl
	await get_tree().create_timer(pierce_hold, false).timeout
	if serial != _skill_serial:
		return
	if not is_inside_tree() or is_dead:
		return
	# Where it goes is decided at the release, by whoever drives this body: at
	# the quarry wherever it has got to (behind him, even — he has turned with
	# it), else the way he faces now.
	if is_multiplayer_authority():
		var aim := dir
		var quarry := _pierce_quarry
		_pierce_quarry = null
		var tip := _arrow_tip()
		if quarry != null and is_instance_valid(quarry) and _targetable(quarry):
			aim = (HuntingLight._aim_of(quarry) - tip).normalized()
		else:
			var face := -global_transform.basis.z
			aim = Vector3(face.x, dir.y, face.z).normalized()
		net_pierce_loose.rpc(aim, damage, critical)


## The Piercing Arrow let go, on every peer, the way its owner decided.
@rpc("any_peer", "call_local", "reliable")
func net_pierce_loose(dir: Vector3, damage: float, critical: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var into := Blood.world_of(self)
	if into == null or is_dead:
		return
	# Off the string: from the head of the arrow he has drawn.
	var from := _arrow_tip()
	var shot := PiercingShot.new()
	shot.launch(from, dir, pierce_speed, pierce_reach, damage, critical, self, pierce_knock)
	into.add_child(shot)
	Sfx.play(self, ULT_SHOT, self, Vector3.ZERO, 1.0, -7.0, 0.0)
	Sfx.play(self, ULT_WIND, self, Vector3.ZERO, 1.0, -14.0, 0.0)
	# The kick of it: he is shoved back a step, dust off his feet, the camera
	# jolts.
	WindBlast.shake(self, 0.2, 0.45)
	WindBlast.kick(self, 7.0, 0.45)
	DustRing.burst(into, global_position, 0.9)
	if is_multiplayer_authority():
		var back := Vector3(-dir.x, 0.0, -dir.z)
		if back.length_squared() > 0.0001:
			velocity += back.normalized() * pierce_recoil
	if rig != null and rig.has_method(&"loose_skill_shot"):
		rig.call(&"loose_skill_shot")
#endregion


## A blow landed while a skill was being taken (every peer, from
## [method net_react]): whatever skill is under way stops here — no shot, no
## glint, no rain — and the string and the stance let go.
func _interrupt_skill() -> void:
	PlayerSkills._interrupt_skill(self)


## Through the Piercing Arrow's draw, keeps him turned on what it was drawn at
## — quickly, but not in a snap — so a quarry that leaps past him or behind
## him is still what the shot goes at. The lock camera follows it as ever.
func _track_pierce(delta: float) -> void:
	PlayerBow._track_pierce(self, delta)


## Where a skill shot leaves from: the head of the arrow on the string, or the
## bow hand, or his chest, whichever the rig can say.
func _arrow_tip() -> Vector3:
	return PlayerBow._arrow_tip(self)


#region Stunning Arrow (in Fire Arrow's slot, the user's word 2026-10-05)
## A quick drawn shot at what is locked (or ahead) that may stun what it goes
## into: `stun_chance`, more at the head (`stun_head_bonus`). Stunned, a
## creature reels where it stands ([Stun]: its own reel, `&"stun"`, with stars
## over its head) and cannot be stunned again for `stun_immunity` seconds.
@export_group("Stunning Arrow")
@export var stun_chance: float = 0.35
@export var stun_head_bonus: float = 0.25
@export var stun_share: float = 0.7
@export var stun_immunity: float = 6.0
## Its draw: braced and held, slower than a shot, a gold light gathering on the
## arrowhead the while ([BowCharge] `stun`), so it is seen coming.
const STUN_HOLD := 0.55
const STUN_QUICK := 1.0
const STUN_BRACE := 1.0


func _stun_arrow() -> bool:
	return PlayerBow._stun_arrow(self)


## The stunning arrow drawn, on every peer: a skill shot's draw and hold.
@rpc("any_peer", "call_local", "reliable")
func net_stun_draw(pitch: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if rig == null or not rig.has_method(&"charged_shot"):
		return
	var nock := float(rig.call(&"charged_shot", STUN_HOLD, pitch, STUN_BRACE, STUN_QUICK))
	Sfx.play(self, ULT_CAST, self, Vector3.ZERO, 1.25, -13.0, 0.0)
	var into := Blood.world_of(self)
	if into != null:
		var glow := BowCharge.new()
		glow.start(rig, &"stun", nock + STUN_HOLD + 0.05)
		into.add_child(glow)


## One of his stunning arrows went into `what` (host, [Arrow]): the roll.
func arrow_stun(what: Node3D, head: bool, chance: float) -> void:
	if what == null or not what.is_inside_tree() or what.get(&"is_dead") == true:
		return
	if _shot_rng.randf() >= chance + (stun_head_bonus if head else 0.0):
		return
	var now := _now()
	if what.has_meta(&"stun_free_at") and now < float(what.get_meta(&"stun_free_at")):
		return
	what.set_meta(&"stun_free_at", now + stun_immunity)
	if what.has_method(&"react"):
		what.call(&"react", &"stun", self, Vector3.ZERO)
	net_stunned.rpc(what.get_path(), Stun.TIME)


## Something stunned, on every peer: the stars over its head ([Stun]).
@rpc("any_peer", "call_local", "reliable")
func net_stunned(path: NodePath, seconds: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	Stun.show_over(get_node_or_null(path) as Node3D, seconds)
#endregion


## Fire Arrow: the head catches as he draws, the arrow is lobbed to come down
## where he aims, and the ground there burns for `fire_time`.
func _fire_arrow() -> bool:
	return PlayerBow._fire_arrow(self)


## How long the burning arrow is held before it goes, and how many times
## faster than an ordinary shot it is drawn: a quick shot.
const FIRE_HOLD := 0.25
const FIRE_QUICK := 2.0


@rpc("any_peer", "call_local", "reliable")
func net_fire_arrow(at: Vector3, damage: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	# Cut short if he is hit before it goes ([method _interrupt_skill]).
	var serial := _skill_serial
	var into := Blood.world_of(self)
	if into == null:
		return
	var nock := 0.3
	if rig != null and rig.has_method(&"charged_shot"):
		# Lobbed: aimed up over the line to the point, more the further it is.
		var off := at - global_position
		var span := Vector2(off.x, off.z).length()
		nock = float(rig.call(&"charged_shot", FIRE_HOLD, clampf(0.12 + span * 0.012, 0.12, 0.5), 0.0, FIRE_QUICK))
	# Drawn and held like any shot; the fire shows once the arrow has gone.
	await get_tree().create_timer(nock + FIRE_HOLD, false).timeout
	if serial != _skill_serial:
		return
	if not is_inside_tree() or is_dead:
		return
	var from := _arrow_tip()
	# A lob: up and over, coming down on the point in `flight` seconds.
	var gap := at - from
	var flat := Vector3(gap.x, 0.0, gap.z)
	var flight := clampf(flat.length() / 22.0, 0.35, 1.2)
	var velocity := flat / flight
	velocity.y = (gap.y + 0.5 * _gravity * flight * flight) / flight
	var shot := FireShot.new()
	into.add_child(shot)
	shot.launch(from, velocity, _gravity, damage, self,
			{"radius": fire_radius, "seconds": fire_time, "dps": fire_dps})
	Sfx.play(self, RELEASE_SOUND, self, Vector3.ZERO, 0.9, -8.0)
	if rig != null and rig.has_method(&"loose_skill_shot"):
		rig.call(&"loose_skill_shot")
#endregion


#region Poisoned Blade
## Poisoned Blade: the Assassin coats his blade from a vial. For `venom_time`
## every cut that lands puts a stack of poison on what it cuts
## ([method blade_hit]).
func _poison_blade() -> bool:
	if rig == null or not rig.has_method(&"coat_blade"):
		return false
	if not _spend(float(SKILLS[&"poison_blade"]["stamina"])):
		return false
	var coat := float(rig.call(&"coat_length", coat_rate))
	_commit(coat)
	_coat_until = _now() + coat
	net_poison_blade.rpc()
	return true


@rpc("any_peer", "call_local", "reliable")
func net_poison_blade() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var coat := 1.6
	if rig != null and rig.has_method(&"coat_blade"):
		coat = float(rig.call(&"coat_blade", coat_rate))
	_venom_until = _now() + coat + venom_time
	var into := Blood.world_of(self)
	if into == null:
		return
	var fx := VenomBlade.new()
	fx.name = "VenomBlade"
	fx.tint = RogueSkills.venom_of(self)
	fx.start(rig, coat_rate, venom_time)
	into.add_child(fx)


## Whether the blade is poisoned now.
func is_venomous() -> bool:
	return _now() < _venom_until


## A cut of this hero's has landed on `creature` at `at`. Host only (the
## creatures call it where they take the cut). A poisoned blade adds a stack.
func blade_hit(creature: Node3D, at: Vector3) -> void:
	if not _decides_here() or creature == null:
		return
	if creature.is_inside_tree():
		var weight := 1.0 if rig == null or rig.get(&"cut_weight") == null else float(rig.get(&"cut_weight"))
		net_bite.rpc(creature.get_path(), weight)
	# out of hiding: seen now that it has landed
	if is_hidden() and _rogue != null and _rogue.hiding:
		net_vanish.rpc(false, false)
	if _backstab_on == creature:
		_backstab_on = null
		var chest := creature.global_position + Vector3.UP * 1.1
		net_backstab.rpc(chest + (at - chest) * 0.5 if at != Vector3.ZERO else chest)
	if not is_venomous():
		return
	# Only the knife that was coated poisons (the user's word, 2026-10-06: not
	# both of two): a cut of the other hand's is a cut and no more.
	if rig != null and rig.has_method(&"cut_by_off_hand") and bool(rig.call(&"cut_by_off_hand")):
		return
	var marks := Afflictions.of(creature, false)
	var first := marks == null or marks.poison_stacks() == 0
	net_afflict.rpc(creature.get_path(), &"poison", venom_stack_time, venom_dps, at)
	if first and creature.has_method(&"react"):
		creature.call(&"react", &"poison", self, Vector3.ZERO)
#endregion


#region An arrow's hit, felt (AVTANDIL_POLISH 4)
## The arrow's own sound is where it lands, and from far off is not heard: the
## archer gets it in his ear too, and a mark on his screen. The same recordings
## of an arrow going in ([constant Arrow.HITS]; the synthesized "tuk" was not
## liked, 2026-10-05): at the head deeper and louder, let go at the moment a
## touch louder. Only he hears and sees it: the host decides the hit and sends
## it to his peer.
const HIT_FELT_PITCH := 1.0
const HEAD_FELT_PITCH := 0.8
const HIT_FELT_DB := -6.0
const HEAD_FELT_DB := -3.0
## The arrow's bite on what it went into ([HitFeel]): weaker than any cut.
const ARROW_BITE := 0.55
var _felt_at: int = -1000


## One of his arrows went into `what` at `where`. Host only ([Arrow]).
func arrow_landed(what: Node3D, where: Vector3, head: bool, perfect: bool) -> void:
	if what != null and what.is_inside_tree():
		net_bite.rpc(what.get_path(), ARROW_BITE * (1.25 if head else 1.0))
	net_arrow_felt.rpc_id(get_multiplayer_authority(), where, head, perfect)


@rpc("any_peer", "call_local", "reliable")
func net_arrow_felt(where: Vector3, head: bool, perfect: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	# a volley (the rain) is one sound, not twenty
	var now := Time.get_ticks_msec()
	var quiet := now - _felt_at < 60
	_felt_at = now
	arrow_hit_felt.emit(where, head, perfect)
	if quiet:
		return
	Sfx.play_flat(self, Arrow.HITS[randi() % Arrow.HITS.size()],
			HEAD_FELT_PITCH if head else HIT_FELT_PITCH,
			(HEAD_FELT_DB if head else HIT_FELT_DB) + (1.5 if perfect else 0.0))
#endregion


## The creature his blade bit, held and lit for the beat his swing is held
## ([HitFeel]) — on every peer, as the swing's own hold is.
@rpc("any_peer", "call_local", "unreliable")
func net_bite(path: NodePath, weight: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != multiplayer.get_unique_id():
		return
	var who := get_node_or_null(path) as Node3D
	HitFeel.bite(who, weight)
	# Into a big one that does not stop for it, his own swing checks only a
	# little ([HitFeel.hold_share]).
	var share := HitFeel.hold_share(who)
	if share < 1.0 and rig != null and rig.has_method(&"trim_hitstop"):
		rig.call(&"trim_hitstop", lerpf(0.45, 1.0, share))
	_bite_felt(who, weight, share)


## The weight of a cut that landed, in his hands and ears (the user's word,
## 2026-10-22; gameplay_plan B2): on a small one the hold above and a little
## knock of the view the way the blade went; on a big one that does not stop
## for it, no more hold but the view knocked harder (`bite_knock_big`) and
## shaken, and under the steel a deep body-blow — and a heavy blow into it
## the rush of air too. Everyone hears; only he feels the view.
@export var bite_knock_small: float = 0.022
@export var bite_knock_big: float = 0.075
func _bite_felt(who: Node3D, weight: float, share: float) -> void:
	if who == null or not who.is_inside_tree():
		return
	var big := clampf(1.0 - share, 0.0, 1.0)
	var heavy := clampf((weight - 1.0) / 0.8, 0.0, 1.0)
	if is_multiplayer_authority() and camera != null:
		var along := who.global_position - global_position
		along.y = 0.0
		along = along.normalized() if along.length_squared() > 0.0001 else -global_basis.z
		if big > 0.1:
			ImpactFx.knock(camera, along + Vector3.DOWN * 0.3 * heavy,
					bite_knock_big * lerpf(0.7, 1.3, heavy) * lerpf(0.6, 1.0, big), 0.03 + 0.05 * heavy, 0.28 + 0.12 * heavy)
		else:
			ImpactFx.nudge(camera, along, bite_knock_small * lerpf(1.0, 1.8, heavy))
	if big > 0.3:
		var chest := who.global_position + Vector3.UP * minf(1.3 * float(who.get(&"visual_scale") if who.get(&"visual_scale") is float else 1.0), 2.4)
		ImpactFx.thud(self, chest, heavy > 0.4)
		if heavy > 0.5:
			ImpactFx.rush(self, who, true, -12.0 + 4.0 * heavy)


## Puts an affliction on a creature on every peer, with a burst where it
## landed. Sent by the host, or by this hero's own peer.
@rpc("any_peer", "call_local", "reliable")
func net_afflict(path: NodePath, kind: StringName, seconds: float, amount: float, at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != get_multiplayer_authority():
		return
	var creature := get_node_or_null(path) as Node3D
	if creature == null:
		return
	var marks := Afflictions.of(creature)
	if marks != null:
		marks.apply(kind, seconds, self, amount)
	var into := Blood.world_of(self)
	if kind == &"poison" and into != null:
		var venom := RogueSkills.venom_of(self)
		RogueSkills.drops(into, at, venom, 10, 0.8)


func _decides_here() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))
#endregion


## What a cut of this hero's blade is worth where it lands (host): p.atk, and
## `crit_chance` of the time a critical. [worth, critical]. On `target`, from
## behind it, the assassin's backstab: a critical worth his `backstab`
## ([RogueSkills]); the first cut out of his Vanish a sure critical.
func cut_worth(target: Node3D = null) -> Array:
	return PlayerMelee.cut_worth(self, target)


#region The assassin's Shadow Step, Vanish and backstab ([RogueSkills])
var _rogue: RogueSkills = null
## The creature the last cut was a backstab on, until it lands ([method blade_hit]).
var _backstab_on: Node3D = null


## His [RogueSkills], made the first time it is asked for (on every peer: the
## first word of it that arrives makes it there).
func rogue() -> RogueSkills:
	if _rogue == null or not is_instance_valid(_rogue):
		_rogue = RogueSkills.new()
		_rogue.name = "RogueSkills"
		add_child(_rogue)
	return _rogue


## The mages' skills ([MageSkills]), made the first time they are asked for.
var _mage: MageSkills = null


func mage() -> MageSkills:
	if _mage == null or not is_instance_valid(_mage):
		_mage = MageSkills.new()
		_mage.name = "MageSkills"
		add_child(_mage)
	return _mage


## The Frost Spears grown, on every peer ([method MageSkills.grow_spears]).
@rpc("any_peer", "call_local", "reliable")
func net_frost_spears() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().grow_spears()


## Her hand down and forward, the Frost Spears about to go, on every peer.
@rpc("any_peer", "call_local", "reliable")
func net_frost_go() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().send_spears()


## Spear `i` thrown, on every peer; only the host's copy hurts.
@rpc("any_peer", "call_local", "reliable")
func net_frost_spear(i: int, from: Vector3, flight: Vector3, damage: float, critical: bool,
		quarry: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().throw_spear(i, from, flight, damage, critical,
			get_node_or_null(quarry) as Node3D if not quarry.is_empty() else null)


## The spears left break, on every peer.
@rpc("any_peer", "call_local", "reliable")
func net_frost_end() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().break_spears()


## The Frost Step, on every peer ([method MageSkills.show_frost_step]).
@rpc("any_peer", "call_local", "reliable")
func net_frost_step(from: Vector3, to: Vector3, pace: float, seconds: float, back: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().show_frost_step(from, to, pace, seconds, back)


## Her glide over, where it stopped ([method MageSkills.end_frost_step]).
@rpc("any_peer", "call_local", "reliable")
func net_frost_step_end(at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	mage().end_frost_step(at)


## The dark elf mage's skills ([DarkSkills]), made the first time they are
## asked for (on every peer: the first word of them that arrives makes them).
var _dark: DarkSkills = null


func dark() -> DarkSkills:
	if _dark == null or not is_instance_valid(_dark):
		_dark = DarkSkills.new()
		_dark.name = "DarkSkills"
		add_child(_dark)
	return _dark


## The elf mage's Frost Nova, Moonwell and Moonfall ([ElfSkills]), made the
## first time they are asked for (on every peer).
var _elf: ElfSkills = null


func elf() -> ElfSkills:
	if _elf == null or not is_instance_valid(_elf):
		_elf = ElfSkills.new()
		_elf.name = "ElfSkills"
		add_child(_elf)
	return _elf


## Her Frost Nova, on every peer: the ring of ice from `at`.
@rpc("any_peer", "call_local", "reliable")
func net_elf_nova(at: Vector3, damage: float, critical: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	elf().show_nova(at, damage, critical)


## Who her Frost Nova froze and for how long, on every peer (the host says).
@rpc("any_peer", "call_local", "reliable")
func net_elf_frozen(paths: Array, times: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	elf().show_frozen(paths, times)


## Her Moonwell, on every peer, at `at`.
@rpc("any_peer", "call_local", "reliable")
func net_elf_moonwell(at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	elf().show_moonwell(at)


## Her Moonfall, on every peer, at `at`.
@rpc("any_peer", "call_local", "reliable")
func net_elf_moonfall(at: Vector3, damage: float, critical: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	elf().show_moonfall(at, damage, critical)


## A flask drunk, on his own peer: too little to drink from, or busy, or off
## his feet, nothing. Every peer sees it ([method net_drink]); a creature that
## punishes a spell punishes this too (`net_casts`).
func _drink() -> bool:
	return PlayerSkills._drink(self)


## Whether he is at a flask now.
func drinking() -> bool:
	return PlayerSkills.drinking(self)


## Every peer: the flask's glow about him as he drinks.
@rpc("any_peer", "call_local", "reliable")
func net_drink() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var into := Blood.world_of(self)
	if into == null:
		return
	SkillFx.particles(into, global_position + Vector3.UP * 1.0, {
		"amount": 36, "life": 1.1, "one_shot": false, "explosiveness": 0.0, "add": true,
		"speed": Vector2(0.2, 0.8), "dir": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, 0.8, 0),
		"damping": 0.5, "size": Vector2(0.04, 0.1), "grow": -0.5, "box": Vector3(0.35, 0.6, 0.35),
		"free_after": 1.6,
		"colors": [Color(1.0, 0.85, 0.45, 0.0), Color(1.0, 0.72, 0.3, 0.9), Color(0.9, 0.4, 0.1, 0.0)],
	})


## Healed `amount` (the elf's Moonwell): the host asks, his own peer, where his
## health is kept, mends it and shows it.
func heal(amount: float) -> void:
	PlayerSkills.heal(self, amount)


@rpc("any_peer", "call_local", "reliable")
func net_heal(amount: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead:
		return
	var was := health
	health = minf(health + amount, max_health)
	if health - was >= 0.5:
		net_healed.rpc(health - was)


## The string's creak as his draw starts, heard by the others too
## (coop_seen_test, 2026-10-24: only he heard it; a tap's draw is over before
## [member net_draw] comes over the wire, so it is a call of its own).
@rpc("any_peer", "call_remote", "unreliable")
func net_creak() -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	Sfx.play(self, DRAW_SOUND, self, Vector3.ZERO, 1.0, -12.0)


## The health he got back, seen by everyone: the green number and the motes
## over him (coop_seen_test, 2026-10-24: only he saw his Moonwell's heal).
@rpc("any_peer", "call_local", "reliable")
func net_healed(amount: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	HealNumber.pop(self, amount)
	# the host: a boss near hears of it and is angered ([Threat])
	var net := get_node_or_null("/root/Net")
	if net == null or bool(net.call("is_host")):
		Threat.on_heal(self, amount)


## Her Dark Hands, on every peer: the circle opening at `at` ([ShadowGrasp]).
@rpc("any_peer", "call_local", "reliable")
func net_dark_grasp(at: Vector3, damage: float, critical: bool, grasp_seed: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	dark().show_grasp(at, damage, critical, grasp_seed)


## Who her Dark Hands caught and for how long, on every peer (the host says).
@rpc("any_peer", "call_local", "reliable")
func net_dark_held(paths: Array, times: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	dark().show_held(paths, times)


## Her Black Sun, on every peer: the sphere over `at` ([BlackSun]).
@rpc("any_peer", "call_local", "reliable")
func net_dark_sun(at: Vector3, damage: float, critical: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	dark().show_sun(at, damage, critical)


## Her Black Comets, on every peer: the rift over `at` and the comets out of
## it, two of them after `quarry` (her lock, if any).
@rpc("any_peer", "call_local", "reliable")
func net_dark_comets(at: Vector3, from: Vector3, rain_seed: int, damages: PackedFloat32Array,
		crits: PackedByteArray, quarry: NodePath = NodePath()) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	dark().show_comets(at, from, rain_seed, damages, crits, quarry)


## Gone from sight in his Vanish, or just out of a Shadow Step: the creatures
## do not go for him, and in PvP a foe cannot lock him ([method Brute.unseen],
## [method _targetable]).
func is_hidden() -> bool:
	return _rogue != null and is_instance_valid(_rogue) and (_rogue.hiding or _rogue.lost())


## The view after a body moved at once: for `seconds` the camera follows at
## `glide_follow_speed` and swings to `yaw` (behind him), with a short widening
## of the lens.
@export_group("Camera glide")
@export var glide_follow_speed: float = 6.0
@export var glide_turn_speed: float = 6.5
@export var glide_fov_kick: float = 8.0
var _glide_until: float = 0.0
var _glide_yaw: float = 0.0
var _glide_fov_rest: float = -1.0
var _fov_tween: Tween = null


func glide_camera(yaw: float, seconds: float) -> void:
	if not is_multiplayer_authority() or camera == null:
		return
	_glide_until = _now() + seconds
	_glide_yaw = yaw
	if _fov_tween != null and _fov_tween.is_valid():
		_fov_tween.kill()
	else:
		_glide_fov_rest = camera.fov
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", _glide_fov_rest + glide_fov_kick, 0.09).set_trans(Tween.TRANS_SINE)
	_fov_tween.tween_property(camera, "fov", _glide_fov_rest, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


@rpc("any_peer", "call_local", "reliable")
func net_shadow_step(from: Vector3, to: Vector3, foe: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	rogue().show_step(from, to, get_node_or_null(foe) as Node3D if not foe.is_empty() else null)


@rpc("any_peer", "call_local", "reliable")
func net_vanish(on: bool, ambush: bool) -> void:
	# his own peer, or the host (where his cut out of hiding lands)
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != get_multiplayer_authority():
		return
	rogue().set_hiding(on, ambush)


## The p.def a shield-bearer has not got with his shield off his arm (0 with
## it, or for anyone else): [member CharacterProfile.shield_p_def].
func shield_def_off() -> float:
	if profile == null or profile.shield_p_def <= 0.0 or rig == null or not rig.has_method(&"holds_shield"):
		return 0.0
	return 0.0 if bool(rig.call(&"holds_shield")) else profile.shield_p_def


## Every peer: Tariel's Challenge ([TarielChallenge]).
@rpc("any_peer", "call_local", "reliable")
func net_challenge() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	TarielChallenge.show(self)


## The move before a skill of his goes, on every peer ([method RogueSkills.play_cue]).
@rpc("any_peer", "call_local", "reliable")
func net_rogue_cue(cue: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	rogue().play_cue(cue)


## A backstab landed at `at` (sent by the host).
@rpc("any_peer", "call_local", "reliable")
func net_backstab(at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	rogue().show_backstab(at)
#endregion


#region PvP: who is a foe, and a hero's blade on a hero ([HurtboxComponent])
## Whether `other` is someone he fights: a creature always; another hero only
## in PvP, while alive, and not of his own side (`team`).
func is_hostile_to(other: Node) -> bool:
	if other == null or other == self or not is_instance_valid(other):
		return false
	if other is Player:
		var hero := other as Player
		return pvp_mode and not hero.is_dead and (team == 0 or hero.team != team)
	return other.is_in_group(&"enemy") or other.is_in_group(&"wolf")


## What a lock, a switch and a cut's step-in may take: the creatures, and in
## PvP the heroes he is hostile to.
func _foes() -> Array[Node3D]:
	var foes: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node is Node3D:
			foes.append(node as Node3D)
	if pvp_mode:
		for node in get_tree().get_nodes_in_group(&"player"):
			if node != self and is_hostile_to(node) and not (node as Player).is_hidden():
				foes.append(node as Node3D)
	return foes


## His [HurtboxComponent]: his own capsule, and only a hostile hero's blade.
func hurtbox() -> HurtboxComponent:
	var box := get_node_or_null(^"Hurtbox") as HurtboxComponent
	if box == null:
		box = HurtboxComponent.of(self)
		box.set_capsule(0.4, 1.85, 0.15)
		box.blade_feedback = false
		box.may_strike = func(attacker: Node3D) -> bool:
			return attacker is Player and (attacker as Player).is_hostile_to(self)
	return box


## In PvP, once a tick on the host: every hostile hero's blade against him.
func _watch_pvp_blades() -> void:
	if not pvp_mode or is_dead or not _decides_here():
		return
	hurtbox().scan()


## A hero's blow on him ([HurtboxComponent.take], host): scaled by the
## attacker's `pvp_damage_scale` and then taken as any blow is
## ([method receive_blow]: his roll, his shield, his armour). True when it is
## likely to have drawn blood (not while he is rolling, dashing or down: his
## own peer decides that, in [method net_blow]).
## Whether a blow landing on him now goes through empty air: an evade, its
## safe time, or on the ground (asked by the stone of a quake, [PackBrute]).
func untouchable_now(by: Node = null) -> bool:
	if by != null and not _dodged_from.is_empty() and String(by.get_path()) == _dodged_from \
			and _now() - _dodged_at <= dodge_shock_cover:
		return true
	return is_dead or is_invulnerable or state == State.DOWNED or _now() < _safe_until


func receive_hit(hit: HitInfo) -> bool:
	var source := hit.attacker()
	if is_dead or source == null:
		return false
	var damage := hit.damage
	var hero := source as Player
	if hero != null:
		if not hero.is_hostile_to(self):
			return false
		damage *= hero.pvp_damage_scale
	receive_blow(damage, source, 0, 1, hit.serial, hit.magic)
	return not (is_invulnerable or state == State.DOWNED or _now() < _safe_until)
#endregion
