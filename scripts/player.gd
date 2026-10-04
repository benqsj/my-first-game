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
## One of his arrows went into something living, on his own peer only (the
## HUD's mark): where, whether at the head, whether let go at the moment.
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
## Speed with the sprint held (Shift): his whole run, paid for in stamina
## (`sprint_stamina`). With no modifier he jogs (`jog_share` of it).
@export var run_speed: float = 7.2
## The pace with no modifier held, as a share of `run_speed`: a jog, Kevin's
## run played near its own pace; Shift is the run, Kevin's sprint (the user's
## word, 2026-10-04: going off at once at a run was too fast).
@export_range(0.3, 1.0) var jog_share: float = 0.66
## Stamina a second the sprint costs while he is really going at it. Run dry
## and he is winded: he jogs until it has come back past a fifth.
@export var sprint_stamina: float = 12.0
## The jog's pace, m/s (`run_speed` x `jog_share`, set with the profile).
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
@export var dash_iframes: float = 0.3
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
## Who is being played. Taken from the Game autoload on spawn unless something
## has set it first, which is what the tests do.
var profile: CharacterProfile
@onready var _collider: CollisionShape3D = $CollisionShape3D

var state: State = State.AIRBORNE
var is_invulnerable: bool = false
## Until when (in [method _now] seconds) no blow lands: the whole length of an
## evade — even one cut short by running into a wall or a body — and, after a
## perfect dodge with its shadow, as long as the shadow is shed.
var _safe_until: float = 0.0
## Health and stamina, taken from the profile on spawn. Everything that hurts or
## tires the body goes through [method _take_damage] and [method _spend].
var health: float = 120.0
var max_health: float = 120.0
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
## How long is left of the attack currently being committed to, and an attack
## pressed while it runs, waiting for it to end.
var _commit_timer: float = 0.0
## Until when the blade is being coated: he walks through it (see `_poison_blade()`).
var _coat_until: float = -100.0
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
	var mine := is_multiplayer_authority()
	if mine:
		# Smooth follow keeps the camera stable even though the body only moves
		# on physics ticks. Framerate-independent exponential damping.
		# Following where the body is *drawn*: the body itself only moves on
		# physics ticks, and a camera chasing those steps makes the world judder.
		var at := _smoother.drawn_at() if _smoother != null else global_position
		var follow := at + Vector3.UP * camera_height
		var weight := 1.0 - exp(-camera_follow_speed * delta)
		camera_rig.global_position = camera_rig.global_position.lerp(follow, weight)
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
	if rig == null:
		return
	if not _lean_ready:
		_lean_rest = rig.transform.basis
		_lean_yaw = rotation.y
		_lean_vel = velocity
		_lean_ready = true
	var dt := maxf(delta, 0.0001)
	var yaw_rate := wrapf(rotation.y - _lean_yaw, -PI, PI) / dt
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var accel := (flat - Vector3(_lean_vel.x, 0.0, _lean_vel.z)) / dt
	_lean_yaw = rotation.y
	_lean_vel = velocity
	var roll := 0.0
	var pitch := 0.0
	if not off_ground and not is_committed() and not _bitten() and planar > 0.5:
		roll = clampf(yaw_rate * planar * turn_lean_rate, -turn_lean_max, turn_lean_max)
	if not off_ground and not is_committed():
		var ahead := -global_basis.z
		# Forward lean is a negative turn about the body's x.
		pitch = -clampf(accel.dot(ahead) * pace_lean_rate, -pace_lean_back, pace_lean_max)
	# Pulled up hard out of a run, or thrown back the other way: the feet dig
	# in and kick up a little dust.
	var was_pace := Vector3(_lean_prev_flat.x, 0.0, _lean_prev_flat.z).length()
	_lean_prev_flat = flat
	if not off_ground and was_pace > skid_pace and accel.dot(_lean_prev_dir) < -skid_brake \
			and Time.get_ticks_msec() - _skid_at > 450:
		_skid_at = Time.get_ticks_msec()
		var world := Blood.world_of(self)
		if world != null:
			DustRing.burst(world, global_position + _lean_prev_dir * 0.35, skid_dust)
	if planar > 0.5:
		_lean_prev_dir = flat / planar
	var k := 1.0 - exp(-lean_follow * delta)
	_lean_roll = lerpf(_lean_roll, roll, k)
	# Forward and back on a spring, a little under-damped: pulled up out of a
	# run he rocks back, a touch forward past upright on the way, and is still
	# (`pace_sway_stiffness`, `pace_sway_damping`).
	var pull := (pitch - _lean_pitch) * pace_sway_stiffness - _lean_pitch_speed * pace_sway_damping
	_lean_pitch_speed += pull * minf(delta, 0.05)
	_lean_pitch += _lean_pitch_speed * minf(delta, 0.05)
	_lean_pitch = clampf(_lean_pitch, -pace_lean_back * 1.3, pace_lean_max * 1.3)
	rig.transform.basis = Basis.from_euler(Vector3(_lean_pitch, 0.0, _lean_roll)) * _lean_rest


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
	_tick_shade(delta)
	_track_sure(delta)
	_judge_whiff()
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

	_read_actions()

	if state == State.DASHING or state == State.DODGING:
		_process_dash(delta)
	elif state == State.SLIDING:
		_process_slide(delta)
	else:
		_process_locomotion(delta)

	_slide_off_steep_ground(delta)
	velocity.y = maxf(velocity.y, -max_fall_speed)
	_impact_speed = maxf(-velocity.y, 0.0)

	_step_up(delta)
	move_and_slide()
	_resolve_contacts()
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
	# His own body wears the hair picked on the hero select; everybody else's
	# comes from `net_hair`.
	var chooser := get_node_or_null("/root/Game")
	if chooser != null and is_multiplayer_authority() and chooser.has_method(&"hair"):
		# the look before the face, so YOUR OWN comes up as it was made
		if chooser.has_method(&"look"):
			set_look(chooser.call(&"look", chooser.call(&"character")))
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
	if profile != null and profile.projectile_drop >= 0.0:
		return profile.projectile_drop
	return arrow_drop
#endregion


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
			return

	if Input.is_action_just_pressed("stow"):
		_set_weapons_stowed(not weapons_stowed())

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
	if Input.is_action_just_pressed("block") and _can_kick():
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
	var direction := get_movement_direction()
	var walking := Input.is_action_pressed("walk")
	sprinting = _wants_sprint(direction, walking)
	var speed := walk_speed if walking else (run_speed if sprinting else jog_speed)
	if _crouching:
		speed = crouch_speed
	# Nobody aims at a sprint. Holding the string costs most of the run, which is
	# what makes choosing when to draw a decision rather than a formality.
	if _drawing:
		speed *= draw_speed_scale
	# Behind a raised shield he does not run: the guard is paid for with pace,
	# the same way the draw is. Going on at it he may jog (`guard_run_speed`,
	# the user's word 2026-10-04: a little faster, never his whole pace);
	# walking, backing off or stepping aside he walks.
	if is_blocking:
		var cap := walk_speed
		if not Input.is_action_pressed("walk") and _guard_ahead(direction):
			cap = guard_run_speed
		speed = minf(speed, cap)
	# And nobody runs out of the *second* swing. The first one keeps whatever it
	# was thrown at — a charge that turns into a shuffle the instant the button
	# goes down reads as slow motion, not as weight — and so does anything thrown
	# in the air, where the arc is the jump's and not the sword's. What follows is
	# damped, which is where the weight belongs: standing there hitting something
	# is not a way to cross ground.
	if _now() < _coat_until:
		# Coating the blade he walks on — slowed to a walk, legs walking —
		# rather than sliding along in a standing pose.
		speed = minf(speed, walk_speed)
	elif is_committed() and not _free_swing:
		speed *= commit_speed_scale
	elif is_committed() and is_on_floor():
		# The first cut out of a run keeps its run only for a step: eased down
		# to the swing's pace over `free_swing_ease`, so the charge lands in a
		# lunge instead of the whole cut gliding on at a run with legs running
		# under a body that is swinging.
		# (a running cut keeps the whole of it till its blade cuts, and all
		# the while it is held wound up)
		if not _cut_charging:
			var eased := clampf((_game_t - _swing_t0 - _ease_delay) / maxf(_free_ease, 0.01), 0.0, 1.0)
			speed *= lerpf(1.0, commit_speed_scale, eased)
	# A skill shot is taken standing: from the draw to the release he does not
	# walk (turning to the shot is still the controller's).
	if _root_timer > 0.0:
		speed = 0.0
	# On his knee from a broken guard: no walking it along (it slid him across
	# the ground the way the stick pushed).
	var knelt := _now() < _crumpled_until
	if knelt:
		speed = 0.0
		direction = Vector3.ZERO
	var on_floor := is_on_floor()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# The sprint costs only while it is a sprint: on the ground, faster than
	# the jog (not slowed by a swing, the draw, the shield).
	if sprinting and on_floor and speed > jog_speed and in_combat():
		_spend(sprint_stamina * delta)
	elif sprinting and speed <= jog_speed:
		sprinting = false

	# A ledge met in mid-air is taken without asking, so running at a wall and
	# jumping is enough to get over it. A face too tall to be mantled is caught
	# hold of instead — which is what makes a house something to go up rather
	# than something to bounce off.
	if not on_floor:
		if _try_climb():
			return
		if _try_catch_wall(direction):
			return

	if on_floor:
		# Climbing costs speed, dropping gives a little back.
		speed *= _slope_factor(direction)
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, ground_deceleration * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed, ground_acceleration * delta)
		_aim_body(direction, delta)
		if _bitten():
			# The swing held in its bite holds the body too: no gliding on
			# under a blade that has stopped, and the step waits for it.
			horizontal *= BITE_GLIDE
		elif _shade_phase == 1:
			# The slide: straight in at its own pace, facing where it goes.
			horizontal = _shade_dir * _shade_pace_now
			rotation.y = atan2(-_shade_dir.x, -_shade_dir.z)
		elif _step_left > 0.0:
			_step_left -= delta
			horizontal = _step_velocity
			if _step_left <= 0.0:
				horizontal = _step_velocity * 0.15
		elif _cut_charging:
			# Wound up, running in: at what he picked, else the way he is pushed.
			var aim := _charge_aim(direction)
			if not aim.is_zero_approx():
				var pace := run_speed * float(_charge_spec.get("pace", 1.0))
				# (from the pace he had, not what the stick left of it: the
				# skill runs in without it)
				horizontal = Vector3(velocity.x, 0.0, velocity.z).move_toward(aim * pace, ground_acceleration * delta)
				rotation.y = lerp_angle(rotation.y, atan2(-aim.x, -aim.z), 1.0 - exp(-lock_turn_speed * delta))
	else:
		# In the air the stick steers the arc rather than driving it: the jump
		# keeps the speed it launched with and control only redirects it.
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, air_drag * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed,
					ground_acceleration * air_control * delta)
		_aim_body(direction, delta)
		var cap := maxf(_air_speed_cap, speed)
		if horizontal.length() > cap:
			horizontal = horizontal.limit_length(cap)

	# A flip or a lunge carries him as far as its own clip goes.
	if rig != null and rig.has_method(&"carrying") and bool(rig.call(&"carrying")):
		horizontal = rig.get(&"carry_velocity")
		if _bitten():
			horizontal *= BITE_GLIDE

	# The slide: nothing but the slide moves him.
	if _shade_phase == 1:
		horizontal = _shade_dir * _shade_pace_now

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Vertical movement.
	if not on_floor:
		velocity.y -= _current_gravity() * delta
		_levitate(delta)
	else:
		_levitating = false
		_levitate_left = profile.levitation if profile != null else 0.0

	if _jump_buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0):
		_do_jump()


## A character who can levitate (the mage) hangs in the air while the jump is
## held on the way down: the fall is held to `levitate_fall` until the
## profile's seconds of it run out, and they come back on landing.
func _levitate(delta: float) -> void:
	_levitating = false
	if profile == null or profile.levitation <= 0.0 or _levitate_left <= 0.0:
		return
	if velocity.y >= 0.0 or not Input.is_action_pressed("jump"):
		return
	_levitating = true
	_levitate_left = maxf(_levitate_left - delta, 0.0)
	velocity.y = maxf(velocity.y, -profile.levitate_fall)


## Speed multiplier for running along `direction` on the current floor: below 1
## uphill, above 1 downhill, 1 on the flat or in the air.
func _slope_factor(direction: Vector3) -> float:
	if not is_on_floor() or direction.is_zero_approx():
		return 1.0
	var normal := get_floor_normal()
	if normal.y <= 0.001:
		return 1.0
	# Metres of height per metre travelled: the floor normal leans downhill, so
	# heading against it is a climb.
	var grade := -direction.dot(Vector3(normal.x, 0.0, normal.z)) / normal.y
	var steepest := tan(floor_max_angle)
	var t := clampf(grade / maxf(steepest, 0.01), -1.0, 1.0)
	return 1.0 - t * (slope_climb_penalty if t > 0.0 else slope_descend_bonus)


## Surfaces past `floor_max_angle` are not standable, so gravity is redirected
## along them: the player slithers down instead of hanging on the side.
func _slide_off_steep_ground(delta: float) -> void:
	if is_on_floor() or _steep_normal == Vector3.ZERO:
		return

	var downhill := Vector3.DOWN.slide(_steep_normal)
	if downhill.is_zero_approx():
		return
	velocity += downhill.normalized() * slide_acceleration * delta
	# Nothing is gained by driving into the surface, and keeping that component
	# is what makes a body judder against a slope.
	var into := velocity.dot(_steep_normal)
	if into < 0.0:
		velocity -= _steep_normal * into
	velocity -= velocity.slide(_steep_normal) * clampf(slide_friction * delta, 0.0, 1.0)


func get_movement_direction() -> Vector3:
	if menu_open:
		return Vector3.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.is_zero_approx():
		return Vector3.ZERO

	# WASD is interpreted in the camera's yaw frame, not the world frame.
	var cam_basis := camera_rig.global_transform.basis
	var direction := cam_basis.x * input.x + cam_basis.z * input.y
	direction.y = 0.0
	return direction.normalized()


## Which way the body is pointed this frame, and the one rule everything else
## about fighting hangs off: **the character shoots and cuts where he is facing**,
## so where he is facing has to be somewhere the player chose.
##
## Four cases, in order:
##
## * **Mid-attack** — held on whatever it was thrown at. A swing does not steer.
## * **Drawing** — the body turns to the shot. Without this the bow points one
##   way and the arrow leaves another, which is the only thing worse than an
##   arrow you cannot see.
## * **Locked and running** — the body turns the way it is *going*. Strafing in
##   a circle is for holding ground; once the player is running they are going
##   somewhere, and a character sprinting sideways with his head over his
##   shoulder is not going there. Backing straight off is the exception: walking
##   away from something while watching it is a thing people do.
## * **Otherwise** — the way it is going, as ever.
func _aim_body(direction: Vector3, delta: float) -> void:
	if is_committed() and _now() >= _coat_until:
		return
	if _drawing:
		_face_aim(delta)
		return
	if target != null:
		if not lock_run_turns or direction.is_zero_approx() \
				or (_backing_off(direction) and _watches_backing_off()) or _strafes_on_lock():
			_face_target(delta)
			return
	if not direction.is_zero_approx():
		_face_direction(direction, delta)


## Backing off a target keeps him facing it only behind the shield, or
## walking (careful steps), or with the string drawn (that is [method _face_aim]'s
## before this is asked). Otherwise he turns and runs from it like any other
## way, the camera still on the target: a backpedal at a run is no way for a
## man to go (the user's word, 2026-10-02; for the bow too, 2026-10-04).
func _watches_backing_off() -> bool:
	# (and the assassin: his locked step back is a step facing it, then the flip)
	return is_blocking or Input.is_action_pressed("walk") \
			or (profile != null and profile.step_then_flip)


## His pace behind the raised shield going on (m/s): more than a walk, well
## short of his run.
@export var guard_run_speed: float = 3.6


## Whether `direction` is on ahead of him (the way he faces): behind the
## shield only that way does he jog.
func _guard_ahead(direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	var ahead := -global_basis.z
	ahead.y = 0.0
	return direction.normalized().dot(ahead.normalized()) > 0.7


## Locked on and stepping carefully — behind the raised shield, or walking
## (TARIEL_POLISH.md 10): every way he goes, forward, back or to either side,
## he keeps facing what he fights, his legs stepping the way he goes (the
## rig's strafe walks); only a run turns him the way he runs. The bow too,
## walking (AVTANDIL_POLISH 3; drawn he faces the shot anyway, [method _face_aim]).
func _strafes_on_lock() -> bool:
	return is_blocking or Input.is_action_pressed("walk")


## True when the stick is pointed away from what is being fought — backing off
## rather than breaking off.
func _backing_off(direction: Vector3) -> bool:
	if target == null:
		return true
	var to_them := target.global_position - global_position
	to_them.y = 0.0
	if to_them.length_squared() < 0.0001:
		return true
	return direction.dot(to_them.normalized()) < -0.35


## Turns the body onto the shot: at the target when there is one, down the
## camera otherwise. The arrow leaves along this, so this is the aim.
func _face_aim(delta: float) -> void:
	if target != null and _targetable(target):
		_face_target(delta)
		return
	var looking := -camera.global_transform.basis.z
	looking.y = 0.0
	if looking.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-looking.x, -looking.z),
			1.0 - exp(-lock_turn_speed * delta))


func _face_direction(direction: Vector3, delta: float) -> void:
	# Pivoting on the spot is instant-ish; at a sprint the turn has to carve.
	var pace := clampf(Vector3(velocity.x, 0.0, velocity.z).length() / maxf(run_speed, 0.01), 0.0, 1.0)
	var rate := lerpf(turn_speed_still, turn_speed, pace)
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


## Places the body on top of a low ledge. The move itself lives in [StepUp],
## because the creatures need it too — a wolf that cannot follow you up a
## staircase is a wolf you beat by standing on a step.
func _step_up(delta: float) -> void:
	StepUp.climb(self, delta, max_step_height, step_forward_probe)


func _current_gravity() -> float:
	if velocity.y > 0.0:
		# Cutting the jump short pulls the player back down faster.
		return _gravity * (low_jump_multiplier if not Input.is_action_pressed("jump") else 1.0)
	return _gravity * fall_gravity_multiplier


func _do_jump() -> void:
	velocity.y = _jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	# Whatever ground speed the jump was taken at is the budget for the arc.
	_air_speed_cap = maxf(Vector3(velocity.x, 0.0, velocity.z).length(), run_speed)
	state = State.AIRBORNE
	jumped.emit()
	_move_sound(MoveSound.JUMP)
#endregion


#region Dash
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
	var now := _now()
	var alternating := profile != null and profile.step_then_flip
	var doubled := now - _last_dash_press <= double_tap_time
	_last_dash_press = now
	var landed := false
	if state == State.DASHING or state == State.DODGING:
		# The hunter has no double tap: his dodge comes of itself, sideways
		# on a lock ([method _start_evade]).
		# (a rig with no longer evade to turn it into takes the press as the
		# next evade instead)
		if not alternating and doubled and state == State.DASHING and not _is_bow() and _upgrade_to_dodge():
			return
		if not _evade_landed():
			_evade_queued = true
			return
		# Feet already down: what is left of this one is only standing up out
		# of it, so the next starts now, with no pause between.
		_evade_queued = false
		_end_dash()
		landed = true
	_evade_queued = false
	var follows := landed or now <= _chain_open_until
	_evade_chain = _evade_chain + 1 if follows else 0
	if not _start_evade(follows):
		_evade_chain = 0


## Starts the evade that is next in the run: `chained` skips the cooldown.
func _start_evade(chained: bool) -> bool:
	var kind := MoveSound.ROLL
	var started := false
	if profile != null and profile.step_then_flip:
		if _evade_chain % 2 == 1:
			kind = MoveSound.FLIP
			started = _start_flip(chained)
		else:
			kind = MoveSound.STEP
			var locked := target != null and _targetable(target)
			started = _try_dash(locked, true, chained)
	elif _is_bow() and _sideways_on_lock():
		# The hunter, locked on and going left or right: straight into the
		# long dodge, as a double tap used to give; any other way, a roll.
		started = _try_dash(false, false, chained)
		if started:
			_upgrade_to_dodge()
	else:
		started = _try_dash(false, false, chained)
	if started:
		_move_sound(kind)
	return started


## Locked on something and pushing mostly left or right.
func _sideways_on_lock() -> bool:
	if target == null or not _targetable(target) or menu_open:
		return false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return absf(input.x) > 0.3 and absf(input.x) > absf(input.y)


## The assassin's flip on its own, as the second of a pair: the twisting flip
## the way he is pushing (or on the way he was going), turning to it.
func _start_flip(chained: bool) -> bool:
	var before := _dash_direction
	if not _try_dash(false, false, chained):
		return false
	if get_movement_direction().is_zero_approx() and not before.is_zero_approx():
		_dash_direction = before
	_upgrade_to_dodge()
	return true


func _try_dash(keep_facing: bool = false, step: bool = false, chained: bool = false) -> bool:
	if state != State.GROUNDED and state != State.AIRBORNE:
		return false
	if _dash_cooldown_timer > 0.0 and not chained:
		return false
	if not is_on_floor() and not allow_air_dash:
		return false
	if not _spend(profile.roll_stamina if profile != null else 20.0):
		return false

	# Dash towards the stick/WASD input, or straight ahead when standing still.
	_dash_direction = get_movement_direction()
	if _dash_direction.is_zero_approx():
		_dash_direction = -global_transform.basis.z
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()

	state = State.DASHING
	_evade_started_at = _now()
	_evade_was_perfect = false
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown + dash_duration
	is_invulnerable = dash_iframes > 0.0
	_safe_until = maxf(_safe_until, _now() + dash_duration)

	if not keep_facing:
		rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	if rig != null:
		if step and rig.has_method(&"step_dodge"):
			# Which way the step goes, seen from the body: +x its right, -z ahead.
			var local := global_transform.basis.inverse() * _dash_direction
			rig.call(&"step_dodge", Vector2(local.x, local.z), dash_duration)
		else:
			# An evade that cuts on the way (Tariel's dash) cannot be made
			# with the sword away: it comes to the hand as the dash goes.
			var moves: Variant = rig.get(&"moves")
			if moves is Dictionary and (moves as Dictionary).has("evade"):
				_set_weapons_stowed(false)
			rig.dodge(dash_duration)
	dash_started.emit(_dash_direction)
	return true


## Turns the roll already under way into the longer, animated dodge, keeping the
## direction it was thrown in.
func _upgrade_to_dodge() -> bool:
	if stamina <= 0.0:
		return false  # Nothing left to stretch the roll into a dodge with.
	if profile != null and profile.step_then_flip:
		# A flip goes the way he is going, whichever way he was facing.
		rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	if rig != null and not rig.dodge_clip(dodge_duration):
		return false  # No clip to upgrade to; the roll carries on as it is.
	_spend(profile.dodge_stamina if profile != null else 8.0)
	state = State.DODGING
	_dodge_timer = dodge_duration
	_dash_cooldown_timer = dash_cooldown + dodge_duration
	is_invulnerable = dodge_iframes > 0.0
	_safe_until = maxf(_safe_until, _now() + dodge_duration)
	dodge_started.emit(_dash_direction)
	return true


## Drives both evades. They differ in how long they last, how fast they travel
## and what the rig is doing, not in how the body is moved.
func _process_dash(delta: float) -> void:
	var dodging := state == State.DODGING
	var length := dodge_duration if dodging else dash_duration
	var left := _dodge_timer if dodging else _dash_timer
	var iframes := dodge_iframes if dodging else dash_iframes

	# Ease the evade out so it does not end with a hard velocity cut.
	var t := clampf(left / maxf(length, 0.001), 0.0, 1.0)
	var speed := (dodge_speed if dodging else dash_speed) * lerpf(0.55, 1.0, t)
	# Where the clip puts the feet down, the travel stops: no skating on after
	# the landing.
	var land := _land_at(dodging)
	if land < 1.0:
		speed *= 1.0 - smoothstep(land - 0.1, land + 0.04, 1.0 - t)
	velocity.x = _dash_direction.x * speed
	velocity.z = _dash_direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if iframes > 0.0 and length - left >= iframes:
		is_invulnerable = false

	# A press kept from earlier goes the moment the feet are down, rather than
	# waiting out the clip's recovery.
	if _evade_queued and _evade_landed():
		_end_dash()
		return

	# Going face-first into a wall should stop the evade, not scrape along it.
	if dash_cancels_on_wall and is_on_wall() and get_wall_normal().dot(_dash_direction) < -0.6:
		_end_dash()
		return

	if left <= 0.0:
		_end_dash()


## Whether the evade under way has put the feet back down already (past its
## [method _land_at] point): from there on the next evade may cut in.
func _evade_landed() -> bool:
	var dodging := state == State.DODGING
	if state != State.DODGING and state != State.DASHING:
		return false
	var land := _land_at(dodging)
	if land >= 1.0:
		return false
	var length := dodge_duration if dodging else dash_duration
	var left := _dodge_timer if dodging else _dash_timer
	return 1.0 - left / maxf(length, 0.001) >= land + 0.02


## Where in this evade the feet land ([member CharacterProfile.dodge_land_at]).
func _land_at(dodging: bool) -> float:
	if profile == null:
		return 1.0
	return profile.dodge_land_at if dodging else profile.dash_land_at


func _end_dash() -> void:
	var dodging := state == State.DODGING
	_evade_ended_at = _now()
	is_invulnerable = false
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	# Bleed off the evade so the player keeps a bit of momentum — unless the
	# clip has already landed him, when there is none left to keep.
	var keep := 0.0 if _land_at(dodging) < 1.0 else 0.4
	velocity.x *= keep
	velocity.z *= keep
	if dodging:
		dodge_ended.emit()
	else:
		dash_ended.emit()
	_chain_open_until = _now() + chain_grace
	if _evade_queued:
		# Pressed while this one was going: the next follows straight on.
		_evade_queued = false
		_evade_chain += 1
		if not _start_evade(true):
			_evade_chain = 0
#endregion


#region Crouch
## Holds the body down, or lets it back up. Standing waits until there is room:
## under a low gap the crouch simply carries on.
func _set_crouching(down: bool) -> void:
	if state == State.SLIDING or state == State.CLIMBING:
		return
	# Taking hold of a wall drops the crouch on the way in, which is the one time
	# it is set from this state; nothing else may touch it while hanging.
	if state == State.WALLCLIMB and down:
		return
	# Wanting to stand and being able to are different things, so the body is
	# only up once the full capsule fits. `or` short-circuits, which is what
	# keeps the stand-up probe out of the way while the button is still held.
	var held := down or not _stand_up()
	if held == _crouching:
		return

	_crouching = held
	if held:
		_set_capsule(crouch_height)
	if rig != null:
		rig.crouch(held)


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
	if state != State.GROUNDED or _slide_cooldown_timer > 0.0:
		return false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < slide_min_speed:
		return false

	_slide_direction = horizontal.normalized()
	_slide_speed = horizontal.length() * slide_boost
	_slide_timer = slide_duration
	state = State.SLIDING
	_set_capsule(slide_height)
	if rig != null:
		rig.crouch(false)
		rig.slide(true)
	slide_started.emit()
	return true


func _process_slide(delta: float) -> void:
	_slide_speed = maxf(_slide_speed - slide_drag * delta, 0.0)
	velocity.x = _slide_direction.x * _slide_speed
	velocity.z = _slide_direction.z * _slide_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	# Held down, the slide keeps going as long as it is still going somewhere;
	# released, it ends there and then.
	var holding := Input.is_action_pressed("crouch")
	var spent := _slide_timer <= 0.0 or _slide_speed < slide_min_speed * 0.45
	if is_on_wall() or not is_on_floor() or spent or not holding:
		_end_slide()


## Comes out of the slide. Still holding the button leaves the player crouched
## rather than standing straight back up, which is also what happens under a low
## gap whether they asked for it or not.
func _end_slide() -> void:
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	_slide_cooldown_timer = slide_cooldown
	if rig != null:
		rig.slide(false)
	slide_ended.emit()

	_crouching = false
	_set_crouching(Input.is_action_pressed("crouch"))


## Resizes the capsule about the feet, so shrinking it never lifts the body off
## the ground or drops it through it.
func _set_capsule(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = height
	_collider.position.y = _stand_centre - (_stand_height - height) * 0.5


## True once the capsule is back to its standing size. False means something is
## in the way and the player has to stay down.
func _stand_up() -> bool:
	var capsule := _collider.shape as CapsuleShape3D
	if capsule == null or is_equal_approx(capsule.height, _stand_height):
		return true

	var crouched := capsule.height
	var crouched_centre := _collider.position.y
	_set_capsule(_stand_height)
	if not test_move(global_transform, Vector3.ZERO):
		return true

	capsule.height = crouched
	_collider.position.y = crouched_centre
	return false
#endregion


#region Climb
## Pulls the body up over a ledge in front of it, if there is one within reach
## and something to stand on when it gets there.
func _try_climb() -> bool:
	if state != State.GROUNDED and state != State.AIRBORNE:
		return false
	var landing := _find_ledge()
	if landing == Vector3.ZERO:
		return false
	_begin_mantle(landing)
	return true


## Hands the body over to the pull-up, wherever it was called from: off the
## ground, out of a jump, or off the top of a face that has just been climbed.
func _begin_mantle(landing: Vector3) -> void:
	if state == State.WALLCLIMB and rig != null:
		rig.wall_climb(false)
	_climb_from = global_position
	_climb_to = landing
	_climb_timer = climb_duration
	state = State.CLIMBING
	velocity = Vector3.ZERO
	# A plunge only ends in `_land()`, and a mantle finishes standing without
	# ever passing through it — so a jump-attack that catches a ledge would hold
	# the commitment open forever. The pull-up takes the fall's place.
	_plunging = false
	_jump_buffer_timer = 0.0
	if rig != null:
		rig.climb(climb_duration)
	climb_started.emit(landing)


## Where the body would end up after mantling whatever is in front of it, or
## ZERO if there is nothing to mantle.
##
## Three questions, in the order that rules the most out soonest: is there a
## face to grab, does it have a top edge within reach, and is there room to
## stand on it.
func _find_ledge() -> Vector3:
	var facing := -global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return Vector3.ZERO
	facing = facing.normalized()

	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]

	var chest := global_position + up_direction * climb_min_height
	var face := PhysicsRayQueryParameters3D.create(
			chest, chest + facing * climb_reach, collision_mask, exclude)
	if space.intersect_ray(face).is_empty():
		return Vector3.ZERO

	# Feel down for the top from above the tallest ledge that can be taken — at
	# the face itself first and then further in, so the top of something thin (a
	# fence rail) is found too, not only the ground beyond it.
	var hit := {}
	var rise := 0.0
	for reach: float in [0.4, 0.55, climb_reach]:
		var above := global_position + up_direction * (climb_max_height + 0.4) + facing * reach
		var top := PhysicsRayQueryParameters3D.create(
				above, above - up_direction * (climb_max_height + 0.4), collision_mask, exclude)
		hit = space.intersect_ray(top)
		if hit.is_empty():
			continue
		rise = ((hit.position as Vector3) - global_position).dot(up_direction)
		if rise >= climb_min_height and rise <= climb_max_height:
			break
		hit = {}
	if hit.is_empty():
		return Vector3.ZERO

	var lip: Vector3 = hit.position
	if (hit.normal as Vector3).dot(up_direction) < cos(floor_max_angle):
		return Vector3.ZERO  # The top is too steep to be a landing.

	# Far enough in from the edge that the capsule is not left overhanging it.
	var landing: Vector3 = lip + facing * 0.25
	_vault_peak = -INF
	var headroom := PhysicsRayQueryParameters3D.create(
			landing + up_direction * 0.05, landing + up_direction * climb_headroom,
			collision_mask, exclude)
	if not space.intersect_ray(headroom).is_empty():
		return Vector3.ZERO
	# A thin top — a fence rail, the coping of a wall — is nowhere to stand: the
	# landing past its edge has nothing under it. Over it instead, to the
	# ground on the far side (a vault), rather than up into the air beyond it.
	var under := PhysicsRayQueryParameters3D.create(landing + up_direction * 0.3,
			landing - up_direction * 0.4, collision_mask, exclude)
	if space.intersect_ray(under).is_empty():
		var beyond := lip + facing * 1.1
		var down := PhysicsRayQueryParameters3D.create(beyond + up_direction * 0.3,
				beyond - up_direction * (rise + 2.0), collision_mask, exclude)
		var ground := space.intersect_ray(down)
		if ground.is_empty() or (ground.normal as Vector3).dot(up_direction) < cos(floor_max_angle):
			return Vector3.ZERO
		_vault_peak = lip.y + 0.35
		return ground.position
	return landing


## Carries the body up and then in, rather than straight at the corner: a lerp
## between the two ends would drag it through the wall on the way.
func _process_climb(delta: float) -> void:
	_climb_timer = maxf(_climb_timer - delta, 0.0)
	var through := 1.0 - _climb_timer / maxf(climb_duration, 0.001)
	var lift := smoothstep(0.0, 0.7, through)
	var reach := smoothstep(0.35, 1.0, through)

	var here := _climb_from.lerp(_climb_to, reach)
	here.y = lerpf(_climb_from.y, _climb_to.y, lift)
	if _vault_peak > -INF:
		# Over the top in an arc, clear of the rail, and down the far side.
		here = _climb_from.lerp(_climb_to, smoothstep(0.0, 1.0, through))
		var base := lerpf(_climb_from.y, _climb_to.y, through)
		here.y = base + maxf(_vault_peak - base, 0.0) * sin(PI * through)
	global_position = here
	velocity = Vector3.ZERO

	if _climb_timer <= 0.0:
		_vault_peak = -INF
		state = State.GROUNDED
		_was_on_floor = true
		_coyote_timer = coyote_time
		_air_speed_cap = run_speed
#endregion


#region Wall climb
## Free climbing. Where the mantle is one move that ends on top of something,
## this is a state the player lives in: the body hangs off a face, gravity is
## off, and the stick drives it up, down and along the surface until it reaches
## the top, climbs back down, or lets go.
##
## Everything is resolved against the face's own normal rather than the camera,
## so rounding a corner or following a wall that leans does not need the view to
## be re-aimed — which is what makes a building climbable as one surface instead
## of as four flat walls.

## Height up the body the grip is felt from. Roughly chest height, which is
## where a climber's hands are when their feet are on the same face.
func _grip_height() -> float:
	return _stand_height * 0.6


## How far the body's centre line sits off the face it is on.
func _wall_hold_distance() -> float:
	return _stand_radius + wall_gap


## Takes hold of whatever steep face is in front of the body. `direction` is the
## way to feel in, defaulting to whichever way the body is facing.
func _try_wall_climb(direction: Vector3 = Vector3.ZERO) -> bool:
	if not wall_climb_enabled or _wall_cooldown_timer > 0.0:
		return false
	if profile != null and not profile.can_climb:
		return false
	if state != State.GROUNDED and state != State.AIRBORNE:
		return false

	var facing := direction
	if facing.is_zero_approx():
		facing = -global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return false
	facing = facing.normalized()

	var grip := _feel_wall(facing)
	if grip.is_empty():
		return false

	# Something with its top already in reach is a mantle, and a mantle is the
	# better move: it puts the player on top rather than leaving them hanging.
	var normal: Vector3 = grip["normal"]
	var above := global_position + up_direction * (_grip_height() + wall_min_face)
	if _scan_wall(above, -normal).is_empty():
		return false

	_grab_wall(grip["position"], normal)
	return true


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
	if not wall_climb_enabled or _wall_cooldown_timer > 0.0:
		return false

	# Touching one is intent enough; otherwise the stick has to be pointing at it.
	if is_on_wall() and _try_wall_climb(-get_wall_normal()):
		return true
	if steer.is_zero_approx():
		return false
	return _try_wall_climb(steer)


## The face in front of the body, felt for the way a climber would: straight
## ahead first, then higher and lower, then round to either side.
##
## Scenery is not made of flat slabs. A window at chest height, a beam, the
## corner of a building — any of them would lose a single probe a wall that is
## plainly still there, and every one of them is a thing a player will try to
## climb.
func _feel_wall(facing: Vector3) -> Dictionary:
	for height: float in [_grip_height(), _stand_height * 0.3, _stand_height * 0.85]:
		var grip := _scan_wall(global_position + up_direction * height, facing)
		if not grip.is_empty():
			return grip

	var chest := global_position + up_direction * _grip_height()
	for sweep: float in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var grip := _scan_wall(chest, facing.rotated(up_direction, sweep))
		if not grip.is_empty():
			return grip
	return {}


## The face in front of `origin`, or an empty dictionary if there is nothing
## there worth holding onto.
func _scan_wall(origin: Vector3, facing: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
			origin, origin + facing * wall_grip_reach, collision_mask, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}

	var normal: Vector3 = hit["normal"]
	# Only faces too steep to walk up are worth gripping, and never a ceiling or
	# an overhang: there is nothing for the feet to push against on either.
	if absf(normal.dot(up_direction)) > cos(deg_to_rad(wall_min_angle)):
		return {}
	# The face has to be turned towards the body rather than brushed edge-on,
	# which is also what keeps the back side of a wall from being caught.
	if normal.dot(facing) > -0.35:
		return {}
	return {"position": hit["position"] as Vector3, "normal": normal}


func _grab_wall(point: Vector3, normal: Vector3) -> void:
	state = State.WALLCLIMB
	# Same as a mantle: catching a face mid-plunge never lands, so it must not
	# leave the plunge (and its endless commitment) behind.
	_plunging = false
	_wall_point = point
	_wall_normal = normal
	_wall_drive = Vector2.ZERO
	velocity = Vector3.ZERO

	# Stand off the face properly *now* rather than easing out to it. A grab
	# usually happens with the capsule already pressed against the wall, and the
	# body is narrower than the arms are long: a few frames spent too close is a
	# few frames with the hands inside the masonry. Moved rather than teleported,
	# so backing off a wall in a narrow gap stops at whatever is behind.
	var chest := global_position + up_direction * _grip_height()
	var gap := (_wall_point + _wall_normal * _wall_hold_distance()) - chest
	move_and_collide(_wall_normal * gap.dot(_wall_normal))
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	# Nothing else the body was doing survives taking hold of a wall.
	_set_crouching(false)
	if rig != null:
		rig.wall_climb(true)
	wall_grabbed.emit(normal)


func _process_wall_climb(delta: float) -> void:
	# Three ways off: let go and drop, push off backwards, or reach the top.
	if Input.is_action_just_pressed("crouch"):
		_release_wall(Vector3.ZERO)
		return
	if Input.is_action_just_pressed("jump"):
		_release_wall(_wall_normal * wall_jump_back + up_direction * wall_jump_up)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Read in the face's frame, not the camera's: forward on the stick is up the
	# wall however the view happens to be pointing.
	var drive := Vector2(input.x, -input.y)
	_wall_drive = _wall_drive.lerp(drive, 1.0 - exp(-14.0 * delta))

	# Checked before the move, because the face runs out at exactly the moment
	# there is somewhere to stand: losing it here is arriving, not falling.
	if drive.y > 0.1:
		var landing := _find_wall_top()
		if landing != Vector3.ZERO:
			_begin_mantle(landing)
			return

	var held := global_position
	var right := up_direction.cross(_wall_normal).normalized()
	var up_face := _wall_normal.cross(right).normalized()
	velocity = right * drive.x * wall_shimmy_speed + up_face * drive.y * wall_climb_speed
	move_and_slide()

	if not _hold_wall(delta):
		# Climbed off the end of the face with nowhere to go. Coming back to
		# where the hands still had something beats letting go of a wall that is
		# still there — a climber who runs out of holds stops, they do not drop.
		global_position = held
		velocity = Vector3.ZERO
		if not _hold_wall(delta):
			_release_wall(Vector3.ZERO)
			return

	# Climbing back down onto the ground steps off by itself.
	if drive.y < 0.0 and is_on_floor():
		_release_wall(Vector3.ZERO)


## Re-fits the body against the face and turns it to look at it. False means the
## face is gone and there is nothing left to hang off.
func _hold_wall(delta: float) -> bool:
	var chest := global_position + up_direction * _grip_height()
	var grip := _feel_wall(-_wall_normal)
	if grip.is_empty():
		return false

	_wall_point = grip["position"]
	var weight := 1.0 - exp(-wall_settle_speed * delta)
	_wall_normal = _wall_normal.slerp(grip["normal"] as Vector3, weight).normalized()

	# Only the distance to the face is corrected. Sliding along it is what the
	# stick is for, and pulling the body sideways would fight it.
	var wanted := (_wall_point + _wall_normal * _wall_hold_distance()) - chest
	var depth := _wall_normal * wanted.dot(_wall_normal)
	global_position += depth.limit_length(wall_shimmy_speed * delta + 0.02)

	rotation.y = lerp_angle(rotation.y, atan2(_wall_normal.x, _wall_normal.z), weight)
	return true


## Where the body would end up after pulling over the top of the face it is on,
## or ZERO while there is still wall above it.
func _find_wall_top() -> Vector3:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var facing := -_wall_normal
	var head := global_position + up_direction * (_stand_height + 0.55)

	# Still wall in front of the face? Then this is not the top of it, and any
	# floor found above would be one *inside* the building — mantling onto which
	# would post the player through the wall of the house they were climbing.
	if not _scan_wall(global_position + up_direction * (_stand_height * 0.95), facing).is_empty():
		return Vector3.ZERO

	# Feel down for a top face from above the head, a step in past the lip. How
	# far in has to clear the body's own standoff from the wall — probe any
	# closer and the ray comes down in front of the face it is looking for. The
	# nearest depth that works wins, so a ledge a plank wide still counts.
	for depth: float in [0.15, 0.45, 0.9]:
		var over := head + facing * (_wall_hold_distance() + depth)
		var top := PhysicsRayQueryParameters3D.create(
				over, over - up_direction * 1.3, collision_mask, exclude)
		var hit := space.intersect_ray(top)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).dot(up_direction) < cos(floor_max_angle):
			continue

		var landing: Vector3 = hit["position"]
		var headroom := PhysicsRayQueryParameters3D.create(
				landing + up_direction * 0.05, landing + up_direction * climb_headroom,
				collision_mask, exclude)
		if space.intersect_ray(headroom).is_empty():
			return landing
	return Vector3.ZERO


## Lets go of the face. `impulse` is whatever the body leaves with — nothing at
## all when it simply drops, or a push off the wall when it jumps.
func _release_wall(impulse: Vector3) -> void:
	state = State.AIRBORNE
	velocity = impulse
	_wall_normal = Vector3.ZERO
	_wall_drive = Vector2.ZERO
	_wall_cooldown_timer = wall_regrab_delay
	_air_speed_cap = maxf(Vector3(impulse.x, 0.0, impulse.z).length(), run_speed)
	if rig != null:
		rig.wall_climb(false)
	wall_released.emit()
	if impulse.y > 0.0:
		_move_sound(MoveSound.JUMP)  # Pushed off the face, not let go.


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
	if target != null:
		_drop_target()
		return
	var found := _best_target()
	if found == null:
		return
	_hold_target(found)


func _hold_target(who: Node3D) -> void:
	target = who
	_last_target_at = who.global_position
	target_part = TargetPoints.default_index(who)
	_flick_up = 0.0
	_show_marker()
	target_locked.emit(target)


func _drop_target() -> void:
	if target == null:
		return
	target = null
	_flick = 0.0
	_show_marker()
	target_lost.emit()


## Puts the dot on the target, building it the first time it is needed. Built
## here rather than in the scene because it belongs to the lock, not to the body
## — and because a marker with nothing to mark is a node doing nothing.
func _show_marker() -> void:
	if _marker == null:
		if target == null:
			return
		_marker = TargetMarker.new()
		_marker.name = "TargetMarker"
		add_child(_marker)
		_marker.aim_at = func() -> Vector3: return _aim_point(target) if target != null else global_position
	_marker.mark(target, camera)


## Moves the lock one part up (+1) or down (-1) the creature it is on.
func _switch_part(step: int) -> void:
	if target == null:
		return
	var parts := TargetPoints.of(target).size()
	target_part = clampi(target_part + step, 0, parts - 1)


## Swaps to the next target to one side of the one held. Which side is the sign
## of `towards`: negative for left, positive for right.
##
## Ordered by *angle round the camera* rather than by distance, so flicking
## right takes the next one along the line of the horizon — which is what the
## player means by it and what they can see before they do it.
func _switch_target(towards: float) -> void:
	if target == null or absf(towards) < 0.01:
		return
	var eye := camera.global_position
	var right := camera.global_transform.basis.x
	var held := _bearing(target, eye, right)

	var best: Node3D = null
	var best_gap := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or who == target or not _targetable(who):
			continue
		if eye.distance_to(_aim_point(who)) > lock_range:
			continue
		# Only what lies the way the stick was pushed, and the nearest of those.
		var gap := (_bearing(who, eye, right) - held) * signf(towards)
		if gap <= 0.01 or gap >= best_gap:
			continue
		best_gap = gap
		best = who
	if best != null:
		_hold_target(best)


## How far round to the right of the camera something sits, in radians.
static func _bearing(who: Node3D, eye: Vector3, right: Vector3) -> float:
	var to_them := who.global_position - eye
	return atan2(to_them.dot(right), to_them.dot(-right.cross(Vector3.UP)))


## The enemy nearest the middle of the view, of those close enough and roughly
## in front. Angle first and distance second: what the player is looking at
## matters more than what happens to be nearest.
func _best_target() -> Node3D:
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var widest := cos(deg_to_rad(lock_cone))
	var best: Node3D = null
	var best_score := -INF

	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not _targetable(who):
			continue
		var to_them: Vector3 = _aim_point(who) - eye
		var range_to := to_them.length()
		if range_to > lock_range or range_to < 0.01:
			continue
		var facing := looking.dot(to_them / range_to)
		if facing < widest:
			continue
		# Straight ahead beats close by, but not by so much that something on
		# the far side of the field wins for being centred.
		var score := facing - range_to / lock_range * 0.25
		if score > best_score:
			best_score = score
			best = who
	return best


## Whether something is worth holding on to. Anything that has died stops being
## a target the moment it does, which is what keeps the camera off a corpse.
func _targetable(who: Node3D) -> bool:
	if not is_instance_valid(who) or not who.is_inside_tree():
		return false
	if who.get("is_dead") == true:
		return false
	return true


## Where on a body the camera looks and an arrow goes: the middle of it rather
## than the floor it stands on.
func _aim_point(who: Node3D) -> Vector3:
	var points := TargetPoints.of(who)
	if who == target:
		return points[clampi(target_part, 0, points.size() - 1)]
	return points[TargetPoints.default_index(who)]


## Where the held target last stood alive.
var _last_target_at := Vector3.ZERO


## Of the enemies that can be locked, the nearest to `spot`, within lock range
## of him; null if there are none.
func _nearest_to(spot: Vector3) -> Node3D:
	var best: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or who == target or not _targetable(who):
			continue
		if global_position.distance_to(who.global_position) > lock_range:
			continue
		var gap := spot.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	return best


## Keeps the camera on the target and lets go when there is nothing left to hold.
func _track_target(delta: float) -> void:
	if target == null:
		return
	if not _targetable(target):
		# Killed (or gone): straight on to whichever of the rest stood nearest
		# it, so a fight with a pack does not need the lock taken again after
		# every kill. Only if there is one in reach; otherwise let go.
		var next := _nearest_to(_last_target_at)
		if next != null:
			_hold_target(next)
			return
		_drop_target()
		return
	if global_position.distance_to(target.global_position) > lock_break_range:
		_drop_target()
		return
	_last_target_at = target.global_position
	_show_marker()

	# The camera is swung round rather than snapped: a lock that jumps the view
	# is a lock that loses the player.
	var to_them := _aim_point(target) - camera_rig.global_position
	if to_them.length_squared() < 0.01:
		return
	var weight := 1.0 - exp(-lock_camera_speed * delta)
	camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y,
			atan2(-to_them.x, -to_them.z), weight)
	# Pitch: negative puts the camera up and looks down, which is the way to
	# watch a fight. Aiming straight at the target is not enough on its own —
	# the rig already sits above it, so a pure aim is nearly level and the
	# ground between the two disappears. `lock_camera_tilt` is what lifts it.
	var flat := Vector2(to_them.x, to_them.z).length()
	var aimed := atan2(to_them.y, flat) - deg_to_rad(lock_camera_tilt)
	spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x,
			clampf(aimed, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg)),
			weight * 0.7)


## Turns the body to face the target instead of the way it is travelling, which
## is the whole difference between strafing round something and running past it.
func _face_target(delta: float) -> void:
	var to_them := _aim_point(target) - global_position
	to_them.y = 0.0
	if to_them.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to_them.x, -to_them.z),
			1.0 - exp(-lock_turn_speed * delta))


## True while something is being fought.
func has_target() -> bool:
	return target != null
#endregion


#region Bow
## Hold to draw, let go to loose. How long it was held is the whole of it: a
## tapped shot leaves at once and lands for a fraction, a held one takes a beat
## and lands for all of it. Nothing else about the shot changes, so the player
## is choosing between rate and weight rather than between two buttons.
func _tick_bow(delta: float) -> void:
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	if _draw_sound != null and not _drawing:
		Sfx.stop(_draw_sound)
		_draw_sound = null
	var holding := Input.is_action_pressed("attack") and not menu_open and not unarmed
	# Committed as well as rolling: the beat after the string goes belongs to the
	# shot that was just taken, and an archer who can start the next draw before
	# his arm has come down is an archer with no rate of fire to manage.
	var busy := (state != State.GROUNDED and state != State.AIRBORNE) or is_committed()

	if busy:
		# Rolling or climbing with a drawn bow is not a thing. The draw is lost,
		# not banked: it has to be earned again.
		_drawing = false
		_draw_timer = 0.0
	elif holding and not _drawing:
		if _shot_timer <= 0.0 and stamina > 0.0:
			_drawing = true
			_draw_timer = 0.0
			_set_weapons_stowed(false)
			if _is_bow():
				_draw_sound = Sfx.play(self, DRAW_SOUND, self, Vector3.ZERO, 1.0, -12.0)
	elif holding and _drawing:
		_draw_timer += delta
		# Held, a draw or a charge costs breath as it goes; run out and it goes.
		var drain := profile.draw_stamina if profile != null else 0.0
		if drain > 0.0:
			_spend(drain * delta)
			if stamina <= 0.0:
				_loose_arrow()
	elif _drawing:
		_loose_arrow()

	if rig != null and rig.has_method(&"aim_bow"):
		rig.call(&"aim_bow", draw_power() if _drawing else 0.0, _aim_pitch())


## How far the string has come back, 0 to 1. Everything a shot is worth is this
## number, so it is the one the HUD would draw.
func draw_power() -> float:
	if profile == null or profile.draw_time <= 0.0:
		return 1.0
	return clampf(_draw_timer / profile.draw_time, 0.0, 1.0)


## True while the string is being held.
func is_drawing() -> bool:
	return _drawing


## Lets the arrow go.
func _loose_arrow() -> void:
	var power := draw_power()
	_drawing = false
	_draw_timer = 0.0
	_shot_timer = profile.shot_cooldown if profile != null else 0.2
	_spend(profile.attack_stamina if profile != null else 12.0)

	# Where the shot is pointed is decided *before* the body is turned onto the
	# target, so a shot loosed while running sideways goes at what is being
	# fought rather than past it.
	_turn_to_target()
	var speed := lerpf(profile.arrow_speed_snap, profile.arrow_speed, power)
	# A tap is worth `snap_share` of a full draw and no less; the rest of the
	# scale is earned by holding.
	var carry := lerpf(profile.snap_share, 1.0, power)
	var critical := _shot_rng.randf() < profile.crit_chance
	var damage := profile.shot_power() * carry * (profile.crit_damage if critical else 1.0)
	# The moment to let go: read off the rig before the loose resets it.
	var grade := int(rig.call(&"release_grade")) if rig != null and rig.has_method(&"release_grade") else 0
	var shaking := float(rig.call(&"shake")) if rig != null and rig.has_method(&"shake") else 0.0
	if grade == 1:
		damage *= perfect_release_bonus
	# Held all the way: the mage's full charge is a bigger bolt, and hits harder
	# than the draw's scale alone would make it.
	if power >= 0.97:
		damage *= profile.full_charge_bonus
	# The shot is thrown; now it has to be lived with. The string going is the
	# same kind of commitment a swing is — the difference is that the archer
	# chooses when, because the draw itself can be held or let go of.
	_commit(loose_recovery)
	arrow_loosed.emit(power, damage, critical)

	# A spell is thrown with the staff, and leaves it from the crystal when the
	# staff comes through — a beat after the button, which the rig says.
	var lead := 0.0
	if rig != null and rig.has_method(&"cast_lead"):
		lead = float(rig.call(&"cast_lead"))
	if lead > 0.0:
		net_cast.rpc()
		await get_tree().create_timer(lead, false).timeout
		if not is_inside_tree() or state == State.DOWNED:
			return
	var from := global_position + up_direction * arrow_height
	# Off the bow, where the arrow on the string was, when there is one: shot
	# from the fixed height it left from below the bow.
	if rig != null and rig.has_method(&"loose_point"):
		var nocked: Vector3 = rig.call(&"loose_point")
		if nocked.is_finite():
			from = nocked
	if rig != null and rig.has_method(&"spell_origin"):
		from = rig.call(&"spell_origin")
	var heading := _shot_heading(from, speed)
	if shaking > 0.0:
		var wander := deg_to_rad(release_spread) * shaking
		var across := heading.cross(up_direction)
		if across.length() > 0.01:
			heading = heading.rotated(across.normalized(), wander * _shot_rng.randf_range(-1.0, 1.0))
		heading = heading.rotated(up_direction, wander * _shot_rng.randf_range(-1.0, 1.0)).normalized()
	# Everywhere, not just here. A locked shot is told what it was loosed at,
	# which a bolt hunts.
	var quarry := NodePath()
	if target != null and _targetable(target):
		quarry = target.get_path()
	net_loose.rpc(from, heading * speed, damage, critical, quarry, power, grade == 1)


## The cast, on every peer: the staff drawn back and brought through. The bolt
## itself follows by `net_loose` when the staff is round.
@rpc("any_peer", "call_local", "reliable")
func net_cast() -> void:
	if rig != null and rig.has_method(&"loose_bow"):
		rig.call(&"loose_bow")


## True while rolling or dashing out of the way of something: a spell that was
## hunting this body lets go of it.
func is_evading() -> bool:
	return state == State.DODGING or state == State.DASHING


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
		quarry: NodePath = NodePath(), power: float = 0.0, perfect: bool = false) -> void:
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
		arrow.call("launch", flight, damage, critical, _gravity * _shot_drop(), self)
		if not quarry.is_empty() and arrow.has_method(&"hunt"):
			arrow.call(&"hunt", get_node_or_null(quarry) as Node3D)
	if _is_bow():
		if randf() < 0.5:
			Sfx.play(self, RELEASE_SOUND, self, Vector3.ZERO, randf_range(0.95, 1.06), -8.0)
		else:
			Sfx.play(self, RELEASE_SOUND_2, self, Vector3.ZERO, randf_range(0.95, 1.06), -14.0)
	# A cast has already been played, by `net_cast`.
	if rig != null and rig.has_method(&"loose_bow") and not rig.has_method(&"cast_lead"):
		rig.call(&"loose_bow")


## Where the shot goes.
##
## Down the line the **body** is facing, at the pitch the aim asks for. Not down
## the camera: the camera can be looking anywhere, and an arrow that leaves at
## forty degrees to the bow held on screen is an arrow the player cannot aim,
## however correct the maths behind it. `_face_aim()` is the other half — while
## the string is held the body turns onto the shot, so by the time it is loosed
## the two are the same line.
func _shot_heading(from: Vector3, speed: float = 40.0) -> Vector3:
	var wanted := _aim_direction(from, speed)
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return wanted
	forward = forward.normalized()
	# The pitch is the aim's; the bearing is the body's. Keeping the pitch is
	# what lets a shot be lofted or put into something below without the body
	# having to lean.
	var rise := clampf(wanted.y, -1.0, 1.0)
	return (forward * sqrt(maxf(1.0 - rise * rise, 0.0)) + Vector3.UP * rise).normalized()


## Where the shot is *asked* to go: at whatever is being fought, or at whatever
## the camera is pointing at when nothing is. What actually leaves the bow is
## `_shot_heading()`, which keeps this pitch and takes its bearing off the body.
##
## A locked shot leads its target. An arrow takes a beat to arrive and a wolf
## does not wait where it was standing, so aiming at where it *is* means a slow
## shot at a moving target is a miss the player did nothing wrong to earn. What
## the lock is for is not having to solve that by hand.
func _aim_direction(from: Vector3, speed: float = 40.0) -> Vector3:
	if target != null and _targetable(target):
		var at := _aim_point(target)
		var moving: Variant = target.get("velocity")
		if moving is Vector3:
			var flight := from.distance_to(at) / maxf(speed, 1.0)
			at += (moving as Vector3) * flight
			# And the drop over that flight, so the arc is aimed through rather
			# than along.
			at.y += 0.5 * _gravity * _shot_drop() * flight * flight
		var to_them := at - from
		if to_them.length_squared() > 0.0001:
			return to_them.normalized()

	# Down the middle of the view, at whatever it lands on — so the arrow goes
	# where the crosshair is rather than parallel to it.
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			eye, eye + looking * lock_range * 2.0, collision_mask, [get_rid()])
	var hit := space.intersect_ray(query)
	var at := eye + looking * lock_range * 2.0
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		# Anything this close under the crosshair is the ground at your feet.
		# Shooting at it is how an arrow ends up buried three paces away.
		if eye.distance_to(landed) > aim_min_range:
			at = landed
	var heading := at - from
	return heading.normalized() if heading.length_squared() > 0.0001 else looking


## Brings the view towards level while the string is held.
##
## Only while there is nothing locked: a lock already points the camera at what
## is being shot at, and two things steering the same camera fight each other.
func _level_camera(delta: float) -> void:
	if not _drawing or target != null:
		return
	spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x,
			clampf(deg_to_rad(aim_camera_pitch), deg_to_rad(min_pitch_deg),
					deg_to_rad(max_pitch_deg)),
			1.0 - exp(-aim_camera_speed * delta))


## Closes the view in on the shot as the string comes back, and opens it
## again after (`draw_zoom_degrees`). Set outright from the resting field of
## view while it is in, so it never drifts; left alone at rest.
func _draw_zoom(delta: float) -> void:
	if camera == null or not camera.current or not _is_bow():
		return
	if _fov_rest < 0.0:
		_fov_rest = camera.fov
	var want := draw_zoom_degrees * draw_power() if _drawing else 0.0
	var was := _draw_zoom_now
	_draw_zoom_now = lerpf(_draw_zoom_now, want, 1.0 - exp(-draw_zoom_speed * delta))
	if _draw_zoom_now < 0.02 and want <= 0.0:
		_draw_zoom_now = 0.0
		if was > 0.0:
			camera.fov = _fov_rest
		else:
			_fov_rest = camera.fov
		return
	camera.fov = _fov_rest - _draw_zoom_now


## How far off the level the shot is aimed, in radians, for the rig to lean on.
## The same heading the arrow will leave on, so what the body does and what the
## arrow does are one number rather than two that happen to agree.
func _aim_pitch() -> float:
	var from := global_position + up_direction * arrow_height
	return asin(clampf(_shot_heading(from).y, -1.0, 1.0))
#endregion


#region Combat
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
	if is_committed():
		if heavy:
			_heavy_buffer = attack_buffer_time
		else:
			_attack_buffer = attack_buffer_time
		return
	if state != State.GROUNDED and state != State.AIRBORNE:
		return
	# The sword away: one press draws it, and the cut goes as it comes out
	# (the press is kept till the draw is done). Off the ground, or with no
	# clip for it, the sword is simply in the hand (below).
	if _rig_drawing() or (state == State.GROUNDED and weapons_stowed() and rig.has_method(&"draw_time") \
			and float(rig.call(&"draw_time")) > 0.0):
		if not _rig_drawing():
			_set_weapons_stowed(false)
		if heavy:
			_heavy_buffer = attack_buffer_time
		else:
			_attack_buffer = attack_buffer_time
		return
	var cost := profile.attack_stamina if profile != null else 16.0
	if heavy:
		cost *= heavy_stamina
	# The first cut thrown at a run is the running cut ([method _run_cut_ready]).
	var run_cut := not heavy and _run_cut_ready()
	if run_cut:
		cost *= run_cut_stamina
	if not _spend(cost):
		_attack_buffer = 0.0
		_heavy_buffer = 0.0
		return
	# Which heavy blow, before the rig's string is ended by it.
	var blow := _heavy_blow() if heavy else -1
	# A heavy blow out of the guard lowers the shield for as long as it lasts.
	if heavy and is_blocking:
		is_blocking = false
		block_changed.emit(false)
	# Swinging a sword that is on your back takes it off your back first. There
	# is no draw clip in the library, so the blade crosses back to the hand over
	# the same beat as the wind-up rather than being drawn during it.
	_set_weapons_stowed(false)
	# Facing is part of the commitment: a cut thrown while running sideways round
	# something goes where the fighter is *pointed*, and the fighter points at
	# what he is fighting. It snaps here rather than easing, because the swing
	# starts now and an attack that turns into the target halfway through it is a
	# cut that misses.
	_turn_to_target()
	# A rig that aims its cuts ([StrikeAim]) is turned to what it is thrown at
	# and every peer is told what that is: the host's copy of the swing is the
	# one that cuts.
	if _aims_strikes():
		var foe := _strike_candidate()
		if foe != null and foe != target:
			var to_them := foe.global_position - global_position
			to_them.y = 0.0
			if to_them.length_squared() > 0.0001:
				rotation.y = atan2(-to_them.x, -to_them.z)
		net_strike_at.rpc(foe.get_path() if foe != null else NodePath())
		# (a running cut steps in on the run itself, not by a step of its own)
		var reach := 0.0 if run_cut else strike_step_max
		rig.set(&"carry_scale", 1.0)
		if blow >= 0:
			var spec: Dictionary = rig.get(&"heavy")[blow]
			reach = float(spec.get("step", strike_step_max))
			# A blow that carries him (a flip) is made to land where the thing
			# stands, not a fixed distance on past it or short of it.
			if spec.has("travel") and foe != null:
				var gap := Vector2(foe.global_position.x - global_position.x,
						foe.global_position.z - global_position.z).length() - _body_radius(foe) - strike_close
				rig.set(&"carry_scale", clampf(gap / float(spec["travel"]), 0.35, 1.25))
				reach = 0.0
		_step_in(foe, reach)
	# A swing out of a run, or out of a jump, keeps the speed it was thrown at.
	# Only the cuts after it are slowed: the first one is the one the player
	# committed their momentum to, and damping it turns a charge into a shuffle.
	var airborne := not is_on_floor()
	_free_swing = _swing_chain == 0 or airborne
	_free_ease = run_cut_ease if run_cut else free_swing_ease
	_whiff_counts = _foe_within(whiff_near)
	_swing_t0 = _game_t
	_swing_chain += 1
	# A cut thrown in the air is a **plunge**, and a plunge is owed its landing:
	# whatever it passes through on the way down, it finishes in the ground.
	_plunging = airborne
	attack_started.emit()
	if rig != null:
		# In the air the blade comes down from over the head. Nothing else reads
		# as a jumping attack: a horizontal cut thrown off a jump is a man
		# swinging at the air he is passing through.
		var style := CharacterRig.AttackStyle.OVERHEAD if airborne else -1
		if blow >= 0 and not airborne:
			style = SkinnedRig.HEAVY + blow
		elif run_cut:
			style = SkinnedRig.RUN_CUT
		net_attack.rpc(style)
		if run_cut:
			_mark_sure(_sure_pick())
		elif _sure_foe != null:
			net_sure_at.rpc(NodePath())
		_commit(rig.swing_time())
		_ease_delay = 0.0
		if run_cut and rig.has_method(&"holding_cut"):
			if bool(rig.call(&"holding_cut")):
				_cut_charging = true
				_charge_skill = false
				_charge_spec = rig.call(&"run_cut_spec")
				_charge_t0 = _game_t
				_charge_foe = _charge_target()
				_commit(run_cut_hold_max + 2.0)
			else:
				_ease_delay = float(rig.call(&"time_to_cut"))
	_attack_buffer = 0.0
	_heavy_buffer = 0.0


## A second attack button for a hero with no shield to raise (the assassin):
## his heavy blows ([member SkinnedRig.heavy]).
## A shield in his hand to raise: a hero who blocks, with a shield in his
## off hand (his look's; [method SkinnedRig.holds_shield]). Without one the
## block button raises nothing (no empty arm held up).
func _shield_in_hand() -> bool:
	if profile != null and not profile.can_block:
		return false
	return rig == null or not rig.has_method(&"holds_shield") or bool(rig.call(&"holds_shield"))


## A hero who would block but has no shield in hand, with more than one
## string (Tariel): the block button throws the other string, the one F6
## would pick (the user's word, 2026-10-04).
func _other_string_ready() -> bool:
	return profile != null and profile.can_block and not has_bow() and not _shield_in_hand() \
			and rig != null and rig.has_method(&"string_count") and int(rig.call(&"string_count")) > 1


## A cut from the string F6 picked (`other` false) or the other one, the
## string put on first on every peer.
func _string_attack(other: bool) -> void:
	# kept for the press held over (a draw first): it is still this string's
	_buffer_other = other
	if not is_committed() and rig != null and rig.has_method(&"wear_other_string"):
		net_wear_string.rpc(other)
	_attack()


@rpc("authority", "call_local", "reliable")
func net_wear_string(other: bool) -> void:
	if rig != null and rig.has_method(&"wear_other_string"):
		rig.call(&"wear_other_string", other)


func _has_heavy() -> bool:
	if profile == null or profile.can_block or has_bow() or rig == null:
		return false
	var blows: Variant = rig.get(&"heavy")
	return blows is Array and not (blows as Array).is_empty()


## A hero with a shield throws his heavy blow out of his guard: the attack
## button with the shield up (the knight's leaping slam).
func _guard_heavy() -> bool:
	if profile == null or not profile.can_block or has_bow() or rig == null:
		return false
	var blows: Variant = rig.get(&"heavy")
	return blows is Array and not (blows as Array).is_empty()


## A heavy blow's blade has gone into the ground (see [signal SkinnedRig.slammed]):
## dust thrown up round it, a wave of broken earth running on the way he faces,
## the thump of it and the ground shaking under whoever is near. Every peer
## plays its own copy of the blow, so every peer sees and hears this.
func _on_slammed(at: Vector3, heft: float) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var ahead := -global_basis.z
	ahead.y = 0.0
	DustRing.burst(world, at, 1.1 + 0.2 * heft)
	GroundFx.eruption(world, at, 0.8)
	GroundFx.wave(world, at, ahead.normalized(), 4.5, false, 0.9)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.18, 0.4, 14.0)


## Heavy blows cost this many light cuts' stamina.
@export var heavy_stamina: float = 1.6


## Which heavy blow the string has come to: out of nothing a lunge (or, at a
## run, the flying flip); early in the string the spinning leap; later the
## three great cuts; at its end the whirling combo.
func _heavy_blow() -> int:
	var count := (rig.get(&"heavy") as Array).size()
	var at: int = int(rig.call(&"flurry_position")) if rig.has_method(&"flurry_position") else -1
	var pace := Vector2(velocity.x, velocity.z).length()
	var pick := 0
	if at < 0:
		pick = 4 if pace > run_speed * 0.7 else 0
	elif at <= 1:
		pick = 1
	elif at <= 3:
		pick = 2
	else:
		pick = 3
	return mini(pick, count - 1)


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

## Seconds left of the current part of a knockdown, which part it is, and how
## long he has been down.
var _down_timer: float = 0.0
var _getting_up: bool = false
var _down_for: float = 0.0
## How many blows of each creature's current combo have landed clean, by
## attacker and combo. A combo only knocks him down if every blow of it did.
var _combo_landed: Dictionary = {}

## A creature landed a blow. Called on the host, which is the only peer whose
## creatures think; applied on the peer that drives this body, because that is
## the one that knows whether the shield was up or a roll was under way.
##
## `blow` of `blows` says where in its combo this one falls, and `combo` tells
## one combo from the next: the last blow of a combo that has landed every time
## puts him on the ground. Anything short of that is a flinch.
func receive_blow(damage: float, from: Node3D, blow: int = 0, blows: int = 1, combo: int = 0,
		magic: bool = false) -> void:
	if from == null:
		return
	var away := global_position - from.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = global_transform.basis.z
	net_blow.rpc_id(get_multiplayer_authority(), damage, away.normalized(), from.global_position,
			"%s#%d" % [from.get_path(), combo], blow, blows, magic)


## Only the host deals creatures' blows. A local call reports sender 0.
@rpc("any_peer", "call_local", "reliable")
func net_blow(damage: float, away: Vector3, source: Vector3, combo: String,
		blow: int, blows: int, magic: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if not is_multiplayer_authority() or is_dead:
		return
	# What his armour takes off it — or, a spell's, his m.def.
	damage = Defence.against(damage, p_def, m_def, magic)
	# A fresh combo from this attacker forgets the last one.
	if blow == 0 or not _combo_landed.has(combo):
		_forget_combos_from(combo)
		_combo_landed[combo] = 0

	# Rolling, dashing or already on the ground: the blow goes through empty air.
	# The whole evade counts, not only its first few frames.
	var evading := state == State.DASHING or state == State.DODGING \
			or _now() - _evade_started_at <= maxf(dash_duration, 0.0) and _now() < _safe_until
	if is_invulnerable or evading or state == State.DOWNED or _now() < _safe_until:
		_combo_landed[combo] = -999
		if evading and not _evade_was_perfect \
				and _now() - _evade_started_at <= perfect_dodge_window:
			_evade_was_perfect = true
			# With the shadow (the assassin, Avtandil) nothing lands while it
			# is being shed.
			if profile != null and profile.shadow_dodge:
				_safe_until = maxf(_safe_until, _now() + ShadowTrail.GUARD)
			stamina = minf(stamina + (profile.roll_stamina if profile != null else 20.0), max_stamina)
			_winded = false
			net_react.rpc(Reaction.PERFECT_DODGE, global_position, Vector3.ZERO)
		return
	var toward := source - global_position
	toward.y = 0.0
	var facing := -global_transform.basis.z
	facing.y = 0.0
	if is_blocking and facing.normalized().dot(toward.normalized()) > 0.2:
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
		_knock_down(away, damage)
		net_react.rpc(Reaction.KNOCKDOWN, at, spray)
		return
	velocity += away * (2.0 + _heft(damage) * blow_shove)
	_free_swing = false
	_commit(0.2 + _heft(damage) * blow_stagger)
	# how hard it was rides on the spray's length (1 the lightest, 2 the
	# heaviest; the blood takes only its way): [method _flinch]
	net_react.rpc(Reaction.FLINCH, at, spray * (1.0 + hit_heft(damage)))


## What is left of his pace while his swing is held in a bite.
const BITE_GLIDE := 0.12


## Whether his swing is held in a bite now ([SkinnedRig.in_hitstop]).
func _bitten() -> bool:
	return rig != null and is_committed() and rig.has_method(&"in_hitstop") and bool(rig.call(&"in_hitstop"))


## How hard a blow of `damage` shoves: the damage, up to `blow_heft_cap`.
func _heft(damage: float) -> float:
	return minf(damage, blow_heft_cap)


func _forget_combos_from(combo: String) -> void:
	var attacker := combo.get_slice("#", 0)
	for key: String in _combo_landed.keys():
		if key.get_slice("#", 0) == attacker:
			_combo_landed.erase(key)


enum Reaction { FLINCH, KNOCKDOWN, GET_UP, ROLL_OUT, PARRY, DEATH, RESPAWN, PERFECT_DODGE, BLOCK, GUARD_BREAK }

## What a blow did to him, shown in every window: a flinch or a fall with
## blood, or the end of lying there.
@rpc("authority", "call_local", "reliable")
func net_react(reaction: int, at: Vector3, blow: Vector3) -> void:
	match reaction:
		Reaction.FLINCH:
			_interrupt_skill()
			_flinch(blow)
			_rig_says(&"hurt")
			Blood.splatter(Blood.world_of(self), at, blow)
		Reaction.KNOCKDOWN:
			_interrupt_skill()
			if rig != null:
				rig.knock_down()
			_rig_says(&"hurt")
			_thud()
			Blood.splatter(Blood.world_of(self), at, blow)
		Reaction.GET_UP:
			if rig != null:
				rig.get_up(get_up_time)
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


## The damage (after his armour) at which a blow that gets through is the
## heaviest there is ([method hit_heft] 1).
@export var hit_heaviest: float = 30.0


## How hard a blow of `damage` that got through is: 0..1.
func hit_heft(damage: float) -> float:
	return clampf(damage / maxf(hit_heaviest, 0.01), 0.0, 1.0)


## Which side of him a blow going `away` (from whoever struck to him) came
## from: [enum SkinnedRig.From].
func blow_side(away: Vector3) -> int:
	var from := -Vector3(away.x, 0.0, away.z)
	var ahead := -global_basis.z
	var right := global_basis.x
	var f := from.dot(ahead)
	var r := from.dot(right)
	if absf(f) >= absf(r):
		return SkinnedRig.From.FRONT if f >= 0.0 else SkinnedRig.From.BACK
	return SkinnedRig.From.RIGHT if r > 0.0 else SkinnedRig.From.LEFT


## A blow that got through, shown (TARIEL_POLISH.md 9): which way it came
## from and how hard pick the flinch. `blow` is the blood's spray (the blow's
## way, a little up), its length 1 + how hard.
func _flinch(blow: Vector3) -> void:
	if rig == null:
		return
	if not rig.has_method(&"flinch_from"):
		rig.flinch()
		return
	var away := Vector3(blow.x, 0.0, blow.z)
	var heft := clampf(blow.length() - 1.0, 0.0, 1.0)
	rig.call(&"flinch_from", away.normalized() if away.length_squared() > 0.000001 else global_basis.z,
			blow_side(away), heft)


## A blow on the shield at least this hard ([method block_strength])...
@export var guard_crumple_from: float = 0.9
## ...taken with no more than this share of the stamina left (or that takes the
## last of it) breaks the guard outright: [method _crumple].
@export var guard_crumple_low: float = 0.3
## How long he is down on his knee and open, all told (seconds).
@export var guard_crumple_time: float = 2.1


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
	if not _winded or block_strength(damage) < guard_crumple_from:
		return false
	if state == State.DASHING or state == State.DODGING:
		return false
	return _now() - _evade_ended_at <= dodge_mistime_window


## Until when he is down on his knee from a broken guard: he does not walk or
## turn on it, whatever the stick says (the shove the blow gave dies away).
var _crumpled_until: float = -INF


## The guard broken (or, `shield` false, a dodge spent out): see
## [method _feel_guard_break].
func _crumple(damage: float, away: Vector3, shield: bool = true) -> void:
	is_blocking = false
	block_changed.emit(false)
	_free_swing = false
	stamina = 0.0
	_winded = true
	_stamina_wait = stamina_empty_delay
	velocity += away * block_shove.y
	_commit(guard_crumple_time)
	_crumpled_until = _now() + guard_crumple_time
	struck.emit(damage, false)
	var at := global_position + Vector3.UP * 1.2
	if _take_damage(damage):
		velocity = away * (2.5 + _heft(damage) * blow_shove * 0.5)
		return
	guard_broken.emit()
	# no shield in it (a dodge spent out) rides on the length: 2, not 1
	net_react.rpc(Reaction.GUARD_BREAK, at, away.normalized() * (1.0 if shield else 2.0))


## The guard beaten aside, seen and heard on every peer ([method _crumple]).
func _feel_guard_break(at: Vector3, away: Vector3) -> void:
	_interrupt_skill()
	var flat := Vector3(away.x, 0.0, away.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else global_basis.z
	if rig != null:
		if rig.has_method(&"guard_crumple"):
			rig.call(&"guard_crumple", guard_crumple_time, flat)
		else:
			rig.flinch()
	# the shield giving way: the block struck deep and loud, wood splitting,
	# a crunch under it and a deep rush of air; then his knee on the ground.
	# (A dodge spent out has no shield in it: the blow in flesh, the rush.)
	var shield := away.length() < 1.5
	var shield_at := at + (-flat) * 0.5
	if shield:
		Sfx.play(self, BLOCK_SOUND, self, shield_at - global_position, randf_range(0.66, 0.72), -3.0)
		ImpactFx.strike(self, shield_at, &"wood", 2.0)
		ImpactFx.strike(self, shield_at, &"stone", 1.8)
	ImpactFx.thud(self, at, true)
	ImpactFx.rush(self, self, true, -6.0)
	get_tree().create_timer(guard_knee_after).timeout.connect(_knee_down_heard)
	_rig_says(&"hurt")
	if shield:
		ParryFlash.burst(Blood.world_of(self), shield_at, -flat, 1.0)
	Blood.splatter(Blood.world_of(self), at, (flat + Vector3.UP * 0.3).normalized())
	for foot: Vector3 in (rig.call(&"foot_points") if rig != null and rig.has_method(&"foot_points") else [global_position]):
		SkidDust.kick(Blood.world_of(self), foot, flat, 1.0)
	if is_multiplayer_authority() and camera != null and camera.current:
		# hard: the whole view thrown and shaken
		ImpactFx.knock(camera, flat, guard_break_view.x, guard_break_view.y, guard_break_view.z)
	last_guard_break = {"at": at, "shield": shield}


## The view's jolt when the guard breaks: how far (m), how much shake (m),
## how long (s).
@export var guard_break_view := Vector3(0.38, 0.3, 0.75)
## When his knee meets the ground after the guard breaks (seconds).
@export var guard_knee_after: float = 0.95
## The last broken guard ([method _feel_guard_break]), for a test.
var last_guard_break: Dictionary = {}


func _knee_down_heard() -> void:
	if is_dead or rig == null or not rig.has_method(&"crumpled") or not bool(rig.call(&"crumpled")):
		return
	Sfx.play(self, FALL_SOUND, self, Vector3.ZERO, randf_range(0.9, 1.0), -8.0)
	DustRing.burst(Blood.world_of(self), global_position, 0.35)


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
	return clampf(damage / maxf(block_heaviest, 0.01), BLOCK_LEAST, 1.0)


## How long a blow of `strength` on the shield holds both of them (seconds):
## a light one a breath, a heavy one about as long as a heavy cut's bite.
func block_hold(strength: float) -> float:
	return lerpf(0.035, 0.11, clampf(strength, 0.0, 1.0))


## A blow caught on his shield, felt (TARIEL_POLISH.md 8): on every peer the
## block's sound (deeper and louder the harder), sparks off the shield's face
## thrown back at whoever struck, the guard's jolt and the hold; in his own
## window the view knocked back and shaken. `blow` points back at the striker,
## its length the strength.
func _feel_block(at: Vector3, blow: Vector3) -> void:
	var strength := clampf(blow.length(), 0.0, 1.0)
	var back := blow.normalized() if blow.length_squared() > 0.000001 else -global_basis.z
	Sfx.play(self, BLOCK_SOUND, self, at - global_position, randf_range(0.95, 1.05) * lerpf(1.06, 0.88, strength),
			lerpf(-15.0, -9.0, strength))
	ParryFlash.burst(Blood.world_of(self), at, back, lerpf(0.3, 0.75, strength))
	if rig != null:
		if rig.has_method(&"block_jolt"):
			rig.call(&"block_jolt", strength, -back)
		if rig.has_method(&"hitstop"):
			rig.call(&"hitstop", block_hold(strength))
	# his feet driven back along the ground: dirt off each heel, thrown the way
	# he slides
	var feet: Array = rig.call(&"foot_points") if rig != null and rig.has_method(&"foot_points") \
			else [global_position]
	for foot: Vector3 in feet:
		SkidDust.kick(Blood.world_of(self), foot, -back, strength)
	if is_multiplayer_authority() and camera != null and camera.current:
		# the view jolted back, away from the striker, and shaken: a blow felt
		ImpactFx.knock(camera, -back, lerpf(0.06, 0.16, strength), lerpf(0.05, 0.15, strength),
				lerpf(0.24, 0.42, strength))
	last_block_feel = {"strength": strength, "at": at}


## The last blow felt on his shield ([method _feel_block]), for a test.
var last_block_feel: Dictionary = {}


## A sound of the rig's own (`hurt`), if it has it.
func _rig_says(what: StringName) -> void:
	if rig != null and rig.has_method(what):
		rig.call(what)


## The body hitting the ground, a moment after it starts to go over.
func _thud() -> void:
	get_tree().create_timer(0.45).timeout.connect(_play_thud)


func _play_thud() -> void:
	if is_inside_tree():
		Sfx.play(self, FALL_SOUND, self, Vector3.ZERO, randf_range(0.95, 1.05), -15.0)


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
func _knock_down(away: Vector3, damage: float) -> void:
	state = State.DOWNED
	_down_timer = down_time + 0.8
	_getting_up = false
	_down_for = 0.0
	is_invulnerable = true
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	_commit_timer = 0.0
	_root_timer = 0.0
	_attack_buffer = 0.0
	velocity = away * (2.5 + _heft(damage) * blow_shove * 0.5)


func _process_downed(delta: float) -> void:
	_down_for += delta
	velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_update_floor_state()

	# Fallen for good: no rolling out and no getting up — only the wait.
	if is_dead:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()
		return

	# The way up that is always open: a roll, the moment he has hit the ground.
	if _down_for >= roll_out_after and Input.is_action_just_pressed("dash"):
		_roll_out()
		return
	_down_timer -= delta
	if _down_timer > 0.0:
		return
	if not _getting_up:
		_getting_up = true
		_down_timer = get_up_time
		net_react.rpc(Reaction.GET_UP, Vector3.ZERO, Vector3.ZERO)
	else:
		_stand_up_from_down()


func _stand_up_from_down() -> void:
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	is_invulnerable = false


## Up and away in one move: the roll, thrown the way the stick points (or back
## out of the fight if it points nowhere), with the whole of it untouchable.
func _roll_out() -> void:
	_stand_up_from_down()
	net_react.rpc(Reaction.ROLL_OUT, Vector3.ZERO, Vector3.ZERO)
	_dash_cooldown_timer = 0.0
	if get_movement_direction().is_zero_approx():
		rotation.y += PI
	_try_dash()
#endregion


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
	_step_left = 0.0
	if foe == null or reach <= 0.0 or not is_on_floor():
		return
	var to := foe.global_position - global_position
	to.y = 0.0
	var gap := to.length() - _body_radius(foe) - strike_close
	if gap <= 0.05 or to.length() < 0.01:
		return
	var go := minf(gap, reach)
	_step_velocity = to.normalized() * go / strike_step_time
	_step_left = strike_step_time


static func _body_radius(who: Node3D) -> float:
	var r: Variant = who.get(&"body_radius")
	if r == null:
		return 0.45
	var s: Variant = who.get(&"visual_scale")
	return float(r) * (float(s) if s != null else 1.0)


func _aims_strikes() -> bool:
	return rig != null and rig.get(&"strike_aim") == true


## The locked target if it is near enough to cut, or else the nearest enemy
## within `strike_assist_range` in front — in front of the way he is pushed, if
## he is, or of the way he faces.
func _strike_candidate() -> Node3D:
	if target != null and _targetable(target) \
			and global_position.distance_to(target.global_position) < strike_assist_range + 1.5:
		return target
	var ahead := get_movement_direction()
	if ahead.is_zero_approx():
		ahead = -global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var widest := cos(deg_to_rad(strike_assist_cone))
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not _targetable(who):
			continue
		var to := who.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > strike_assist_range or d < 0.01 or ahead.dot(to / d) < widest:
			continue
		if d < best_d:
			best_d = d
			best = who
	return best


## Where on it a cut is aimed: its own answer if it has one, the middle of its
## body if it says how tall it is, else where a lock would sit.
static func strike_point(who: Node3D) -> Vector3:
	if who.has_method(&"strike_point"):
		return who.call(&"strike_point")
	var tall: Variant = who.get(&"body_height")
	if tall != null:
		var s: Variant = who.get(&"visual_scale")
		return who.global_position + Vector3.UP * float(tall) * (float(s) if s != null else 1.0) * 0.5
	var points := TargetPoints.of(who)
	return points[TargetPoints.default_index(who)]


@rpc("any_peer", "call_local", "reliable")
func net_strike_at(foe: NodePath) -> void:
	_strike_foe = get_node_or_null(foe) as Node3D if not foe.is_empty() else null


func _aim_strike() -> void:
	if not _aims_strikes():
		return
	var on := _strike_foe != null and _targetable(_strike_foe)
	rig.call(&"aim_strike", strike_point(_strike_foe) if on else Vector3.ZERO, on)
#endregion


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
	if not attacks_commit:
		return
	_commit_timer = maxf(_commit_timer, seconds)


## True while an attack is playing out and nothing else may be started.
func is_committed() -> bool:
	return _commit_timer > 0.0


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
	_plunging = false
	velocity.x = 0.0
	velocity.z = 0.0
	_commit(plunge_recovery)
	if rig != null:
		rig.plunge(plunge_recovery)
	# Where the blade went in: in front of the feet, which is where the arm put
	# it. Dust rather than a flash — a sword going into dirt throws dirt.
	var at := global_position - global_transform.basis.z * plunge_reach
	DustRing.burst(Blood.world_of(self), at, plunge_dust)
	blade_planted.emit(at)


## Puts the body on the target at once, without easing. Nothing to do when there
## is nothing being fought: a free swing goes where the fighter already faces.
func _turn_to_target() -> void:
	if target == null or not _targetable(target):
		return
	var to_them := _aim_point(target) - global_position
	to_them.y = 0.0
	if to_them.length_squared() > 0.0001:
		rotation.y = atan2(-to_them.x, -to_them.z)
#endregion


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


## What a cut that does not miss is thrown at: the locked target, else the
## nearest thing to fight ahead of the way he goes.
func _sure_pick() -> Node3D:
	if target != null and _targetable(target):
		return target
	return _charge_target()


## The swing just thrown does not miss `foe` (every peer is told); `margin`,
## if given, its reach past the blade's own instead of `sure_reach_margin`.
func _mark_sure(foe: Node3D, margin: float = -1.0) -> void:
	net_sure_at.rpc(foe.get_path() if foe != null else NodePath(), margin)


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
	var edge: PackedVector3Array = rig.get_cutting_edge() if rig != null else PackedVector3Array()
	if edge.is_empty() or who == null or who != _sure_foe or not sure_holds(who, edge):
		return edge
	# Onto the line up its middle, at the blade's own height as near as it may
	# be: between a quarter of the way up to where a cut is aimed at it and
	# there (over a wolf, down to its back; under a tall orc's chest, up to it).
	var foot := who.global_position
	var top := maxf(strike_point(who).y, foot.y + 0.3)
	var axis := Geometry3D.get_closest_points_between_segments(edge[0], edge[1],
			foot, Vector3(foot.x, top, foot.z))
	var near: Vector3 = axis[0]
	var onto := Vector3(foot.x, clampf(near.y, lerpf(foot.y, top, 0.25), top), foot.z)
	var shift := onto - near
	return PackedVector3Array([edge[0] + shift, edge[1] + shift])


## Whether the cut in hand, its edge at `edge`, cannot miss `who` now (see
## `sure_cone`).
func sure_holds(who: Node3D, edge: PackedVector3Array) -> bool:
	if who != _sure_foe or rig == null or int(rig.get(&"attack_serial")) != _sure_serial:
		return false
	if not _targetable(who) or (who.has_method(&"is_evading") and bool(who.call(&"is_evading"))):
		return false
	if absf(who.global_position.y - global_position.y) > sure_rise:
		return false
	var to := who.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var r := _blade_radius(who)
	# (how far ahead of him the blade is: a blade drawn back behind him
	# reaches nothing in front)
	var ahead := -global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var reach := 0.0
	for p in edge:
		reach = maxf(reach, (p - global_position).dot(ahead))
	if d - r > reach + (_sure_margin if _sure_margin >= 0.0 else sure_reach_margin):
		return false
	if d < maxf(r, 0.01):
		return true
	var facing := -global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	if facing.dot(to) < 0.0:
		return false
	var off := rad_to_deg(acos(clampf(facing.dot(to / d), -1.0, 1.0)))
	var side := absf(facing.cross(to).y)
	return off <= sure_cone or side <= r * sure_side


## Until a cut that does not miss starts cutting, he turns after what it is
## thrown at (the owner's; the turn goes out with the body).
func _track_sure(delta: float) -> void:
	if _sure_foe == null or not is_instance_valid(_sure_foe) or rig == null or not _targetable(_sure_foe):
		return
	if int(rig.get(&"attack_serial")) != _sure_serial or not is_committed() or _shade_phase == 1:
		return
	if not rig.has_method(&"time_to_cut"):
		return
	if not (bool(rig.call(&"holding_cut")) or float(rig.call(&"time_to_cut")) > 0.0):
		return
	if _sure_foe.has_method(&"is_evading") and bool(_sure_foe.call(&"is_evading")):
		return
	var to := _sure_foe.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var facing := -global_basis.z
	facing.y = 0.0
	if facing.normalized().dot(to.normalized()) < cos(deg_to_rad(sure_follow_cone)):
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-sure_turn_speed * delta))


## How wide `who` is to a blade: what the creature's own blade test reads
## (a [Fighter]'s radius is drawn at its size, the others' as it is).
static func _blade_radius(who: Node3D) -> float:
	var r: Variant = who.get(&"body_radius")
	if r == null:
		return 0.45
	if who is Fighter:
		var s: Variant = who.get(&"visual_scale")
		return float(r) * maxf(float(s) if s != null else 1.0, 0.01)
	return float(r)
#endregion


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
var _charge_skill: bool = false
## How long after the swing goes his run is kept whole (till its cut).
var _ease_delay: float = 0.0


## Anything to fight within `reach` metres.
func _foe_within(reach: float) -> bool:
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who != null and _targetable(who) and who.global_position.distance_to(global_position) <= reach:
			return true
	return false


## What a wound-up running cut runs at: the locked target, else the nearest
## thing to fight ahead of the way he is going within `run_cut_seek`.
func _charge_target(seek: float = -1.0) -> Node3D:
	if seek < 0.0:
		seek = run_cut_seek
	if target != null and _targetable(target):
		return target
	var ahead := get_movement_direction()
	if ahead.is_zero_approx():
		ahead = -global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var widest := cos(deg_to_rad(run_cut_seek_cone))
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not _targetable(who):
			continue
		var to := who.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > seek or d < 0.01 or ahead.dot(to / d) < widest:
			continue
		if d < best_d:
			best_d = d
			best = who
	return best


func _charge_aim(direction: Vector3) -> Vector3:
	if _charge_foe != null and is_instance_valid(_charge_foe) and _targetable(_charge_foe):
		var to := _charge_foe.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			return to.normalized()
	if not direction.is_zero_approx():
		return direction
	if _charge_skill:
		var ahead := -global_basis.z
		ahead.y = 0.0
		return ahead.normalized()
	return Vector3.ZERO


## The wound-up running cut, let go when he is near enough what he runs at,
## when he stops pushing with nothing to run at, at a second press, or when
## it has been held `run_cut_hold_max`. Broken off by anything that takes the
## clip off him (a blow).
func _tick_charge() -> void:
	if not _cut_charging:
		return
	if rig == null or not bool(rig.call(&"holding_cut")):
		_cut_charging = false
		return
	var held := _game_t - _charge_t0
	var spec := _charge_spec
	var go := held >= float(spec.get("hold_max", run_cut_hold_max))
	if _charge_foe != null and is_instance_valid(_charge_foe) and _targetable(_charge_foe):
		var to := _charge_foe.global_position - global_position
		to.y = 0.0
		# (its body as a blade finds it: its own radius, not the drawn size)
		var r: Variant = _charge_foe.get(&"body_radius")
		var radius := float(r) if r != null else 0.45
		go = go or to.length() - radius - 0.4 <= float(spec.get("strike_gap", 0.9))
	elif _charge_skill:
		# Nothing to run at: a few strides the way he faces, and the cut.
		go = go or held >= float(spec.get("blind_hold", 0.45))
	elif held >= 0.25 and get_movement_direction().is_zero_approx():
		go = true
	if _attack_buffer > 0.0 and held >= 0.12:
		_attack_buffer = 0.0
		go = true
	if go:
		_cut_charging = false
		net_release_cut.rpc()
		_commit_timer = 0.0
		_commit(float(rig.get(&"_swing_commit")))
		_swing_t0 = _game_t
		_ease_delay = float(rig.call(&"time_to_cut"))


@rpc("any_peer", "call_local", "reliable")
func net_release_cut() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if rig != null and rig.has_method(&"release_cut"):
		rig.call(&"release_cut")


## A cut out of a run: on his feet, the first of a string, at a run, with the
## shield down, and a rig with a running cut.
func _run_cut_ready() -> bool:
	if state != State.GROUNDED or not is_on_floor() or _swing_chain != 0 or is_blocking:
		return false
	if rig == null or not rig.has_method(&"has_run_cut") or not bool(rig.call(&"has_run_cut")):
		return false
	return Vector2(velocity.x, velocity.z).length() > run_speed * run_cut_pace


#region The kick (AVTANDIL_POLISH 7)
## The kick's wait for the foot to come out (seconds, on every peer), the way
## it goes, and how soon another may be thrown.
var _kick_wait: float = -1.0
var _kick_dir: Vector3 = Vector3.ZERO
var _kick_cool: float = 0.0


## A hero with no shield and a bow, on his feet, a rig that kicks.
func _can_kick() -> bool:
	if profile == null or profile.can_block or not has_bow() or unarmed:
		return false
	if state != State.GROUNDED or not is_on_floor() or _kick_cool > 0.0 or is_committed():
		return false
	return rig != null and rig.has_method(&"kick")


## He turns to what he is locked on (or what is in front) and kicks it away:
## a draw in hand is let go of, unshot.
func _kick() -> void:
	if not _spend(kick_stamina):
		return
	_drawing = false
	_draw_timer = 0.0
	_set_weapons_stowed(false)
	var foe := target if target != null and _targetable(target) else _strike_candidate()
	var aim := get_movement_direction()
	if foe != null:
		aim = foe.global_position - global_position
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		rotation.y = atan2(-aim.x, -aim.z)
	var dir := -global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	_kick_cool = kick_cooldown
	var secs := float(rig.call(&"kick_length", kick_rate, kick_from, kick_to))
	_commit(secs)
	attack_started.emit()
	net_kick.rpc(dir)


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
	_kick_cool = maxf(_kick_cool - delta, 0.0)
	if _kick_wait < 0.0:
		return
	_kick_wait -= delta
	if _kick_wait >= 0.0:
		return
	if not _decides_here() or is_dead:
		return
	var widest := cos(deg_to_rad(kick_cone))
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not _targetable(who):
			continue
		var to := who.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d - _body_radius(who) > kick_reach or _kick_dir.dot(to / d) < widest:
			continue
		var at := strike_point(who) - to / d * _body_radius(who)
		at.y = minf(at.y, global_position.y + 1.2)
		var worth := cut_worth()
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", float(worth[0]) * kick_damage, at, _kick_dir, false, false, self)
		if who.has_method(&"react"):
			var taken: Variant = who.get(&"shove_taken")
			var push := kick_push
			if taken is float and float(taken) > 0.01:
				push = kick_throw * 4.0 / float(taken)
			who.call(&"react", &"knock", self, _kick_dir * push)
		net_kick_landed.rpc(who.get_path(), at)


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
	if not is_blocking or state != State.GROUNDED or not is_on_floor():
		return false
	return rig != null and rig.has_method(&"can_shield_bash") and bool(rig.call(&"can_shield_bash"))


## The charge behind the shield: he turns to what is in front (or what he is
## locked on) and drives in, the guard coming down for it.
func _shield_bash() -> void:
	if _dash_cooldown_timer > 0.0:
		return
	if not _spend((profile.roll_stamina if profile != null else 20.0) * bash_stamina):
		return
	is_blocking = false
	block_changed.emit(false)
	_set_weapons_stowed(false)
	var foe := target if target != null and _targetable(target) else _strike_candidate()
	var aim := get_movement_direction()
	if foe != null:
		aim = foe.global_position - global_position
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		rotation.y = atan2(-aim.x, -aim.z)
	var dir := -global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	_step_velocity = dir * bash_speed
	_step_left = bash_travel
	_free_swing = true
	_swing_chain = 0
	_dash_cooldown_timer = dash_cooldown + bash_time
	_commit(bash_time)
	attack_started.emit()
	net_shield_bash.rpc(dir)


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
	if _bash_left <= 0.0:
		return
	_bash_left -= delta
	if not _decides_here() or is_dead:
		return
	var widest := cos(deg_to_rad(bash_cone))
	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or _bash_struck.has(who) or not _targetable(who):
			continue
		var to := who.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d - _body_radius(who) - 0.4 > bash_reach or _bash_dir.dot(to / d) < widest:
			continue
		_bash_struck.append(who)
		var at := strike_point(who) - to / d * _body_radius(who)
		var worth := cut_worth()
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", float(worth[0]) * bash_damage, at, _bash_dir, false, false, self)
		if who.has_method(&"react"):
			who.call(&"react", &"knock", self, _bash_dir * bash_push)
		net_bash_landed.rpc(who.get_path(), at)
		bashed.emit(who)


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
	if rig == null or _swing_serial0 < 0 or _whiff_judged == _swing_serial0 or _plunging:
		return
	if not rig.has_method(&"in_recovery") or not rig.has_method(&"current_swing"):
		return
	if StringName(rig.call(&"current_swing")) == &"" or bool(rig.call(&"is_heavy")) \
			or not bool(rig.call(&"in_recovery")):
		return
	_whiff_judged = _swing_serial0
	if _landed_serial >= _swing_serial0 or not _whiff_counts:
		return
	_whiff_until = _now() + whiff_recovery
	if attacks_commit:
		_commit_timer += whiff_recovery
	if rig.has_method(&"overreach"):
		rig.call(&"overreach", whiff_recovery, whiff_slow)
	whiffed.emit()
#endregion


#region Vitals
## Puts on a shield ([enum Inventory.Shields]); every peer sees it through
## `net_shield`.
func set_shield(kind: int) -> void:
	shield_kind = kind
	if rig != null and rig.has_method(&"set_shield"):
		rig.call(&"set_shield", kind)


## Wears one of the rig's `faces`; every peer sees it through `net_face`.
func set_face(index: int) -> void:
	face = index
	if rig != null and rig.has_method(&"set_face"):
		rig.call(&"set_face", index)


## Wears the look made on the hero select ([PolysplitLook]); every peer sees
## it through `net_look`.
func set_look(made: Dictionary) -> void:
	if rig != null and rig.has_method(&"set_look"):
		rig.call(&"set_look", made)
		look = rig.call(&"get_look")
	else:
		look = made.duplicate(true)


## Dyes the rig's clothes (its `TINTS`); every peer sees it through `net_tint`.
func set_tint(index: int) -> void:
	tint = index
	if rig != null and rig.has_method(&"set_tint"):
		rig.call(&"set_tint", index)


## Wears one of the rig's `hairs`; every peer sees it through `net_hair`.
func set_hair(index: int) -> void:
	hair = index
	if rig != null and rig.has_method(&"set_hair"):
		rig.call(&"set_hair", index)


## Puts on one of his outfits (an index into the rig's `garbs`); every peer
## sees it through `net_garb`.
func set_garb(index: int) -> void:
	garb = index
	if rig != null and rig.has_method(&"set_garb"):
		rig.call(&"set_garb", index)


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
	# out of a fight it costs nothing, so being winded does not stop it
	return not in_combat() or (stamina > 0.0 and not _winded)


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
	var on_floor := is_on_floor()
	# States that run their own course own the state field until they are done.
	var held := state != State.GROUNDED and state != State.AIRBORNE

	if on_floor:
		_coyote_timer = coyote_time
		if not _was_on_floor:
			_land()
		if not held:
			state = State.GROUNDED
	elif not held:
		if _was_on_floor:
			# Walked off an edge: the arc keeps the speed it left with.
			_air_speed_cap = maxf(Vector3(velocity.x, 0.0, velocity.z).length(), run_speed)
		state = State.AIRBORNE

	_was_on_floor = on_floor


func _land() -> void:
	# Coming down hard costs some of the run — a drop should be felt.
	if _impact_speed > hard_landing_speed and state != State.DASHING:
		velocity.x *= hard_landing_grip
		velocity.z *= hard_landing_grip
	# The fall is over; anything left on the vertical axis only fights the floor
	# snap on the next tick.
	velocity.y = 0.0
	_air_speed_cap = run_speed
	if _impact_speed >= land_sound_speed:
		_move_sound(MoveSound.LAND, clampf(
				inverse_lerp(land_sound_speed, hard_landing_speed, _impact_speed), 0.0, 1.0))
	landed.emit(_impact_speed)
	_impact_speed = 0.0
	if _plunging:
		_plant_blade()


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
	&"poison_blade": {"name": "Poisoned Blade", "stamina": 15.0, "cooldown": 18.0},
	&"rising_cut": {"name": "Rising Cut", "stamina": 22.0, "cooldown": 8.0},
	&"shadow_slide": {"name": "Shadow Slide", "stamina": 24.0, "cooldown": 9.0},
	&"shadow_lance": {"name": "Shadow Lance", "stamina": 26.0, "cooldown": 10.0},
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


## The skill in `slot`, or `&""` for an empty one.
func skill_in(slot: int) -> StringName:
	if profile == null or slot < 0 or slot >= profile.skills.size():
		return &""
	var id := StringName(profile.skills[slot])
	return id if SKILLS.has(id) else &""


## Seconds before the skill in `slot` can be used again (0 when it can).
func skill_cooldown_left(slot: int) -> float:
	var id := skill_in(slot)
	if id == &"":
		return 0.0
	return maxf(float(_skill_ready_at.get(id, 0.0)) - _now(), 0.0)


## Its whole cooldown, for the bar to draw the rest against.
func skill_cooldown(slot: int) -> float:
	var id := skill_in(slot)
	return float(SKILLS[id]["cooldown"]) if id != &"" else 0.0


## Uses the skill in `slot`, if there is one, it is ready and the body is free
## to. True if it went off.
func use_skill(slot: int) -> bool:
	var id := skill_in(slot)
	if id == &"" or is_dead or skill_cooldown_left(slot) > 0.0:
		return false
	if state != State.GROUNDED or is_committed():
		return false
	var went := false
	match id:
		&"arrow_rain":
			went = _arrow_rain()
		&"hunters_mark":
			went = _hunters_mark()
		&"piercing_arrow":
			went = _piercing_arrow()
		&"fire_arrow":
			went = _fire_arrow()
		&"poison_blade":
			went = _poison_blade()
		&"rising_cut":
			went = _rising_cut()
		&"shadow_slide":
			went = _shadow_slide()
		&"shadow_lance":
			went = _shadow_slide(&"shadow_lance")
	if not went:
		return false
	_skill_ready_at[id] = _now() + float(SKILLS[id]["cooldown"])
	skill_used.emit(slot, id)
	return true


## The Rising Cut (Tariel): the sword drawn back low, he runs at what is
## in front (or locked), and near it brings the blade up through it
## ([Swordsman] `RISING_CUT`, UAL 2's Sword_UpperCut held wound up). With
## nothing to run at, a few strides the way he faces and the cut.
@export_group("Rising Cut")
## How far ahead (metres) it picks what to run at.
@export var rising_seek: float = 14.0


func _rising_cut() -> bool:
	if rig == null or not rig.has_method(&"has_cut") or not bool(rig.call(&"has_cut", "rising_cut")):
		return false
	if not is_on_floor():
		return false
	if not _spend(float(SKILLS[&"rising_cut"]["stamina"])):
		return false
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	_set_weapons_stowed(false)
	var foe := _charge_target(rising_seek)
	if foe != null:
		var to := foe.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			rotation.y = atan2(-to.x, -to.z)
	_free_swing = true
	_swing_t0 = _game_t
	_swing_chain = 1
	_free_ease = run_cut_ease
	_whiff_counts = _foe_within(whiff_near)
	attack_started.emit()
	net_attack.rpc(SkinnedRig.RISING_CUT)
	_cut_charging = true
	_charge_skill = true
	_charge_spec = rig.call(&"cut_spec", "rising_cut")
	_charge_t0 = _game_t
	_charge_foe = foe
	_mark_sure(foe)
	_commit(float(_charge_spec.get("hold_max", run_cut_hold_max)) + 2.0)
	_attack_buffer = 0.0
	return true


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


## `key` "shadow_lance": the Shadow Lance (Tariel's third skill, [Swordsman]
## `SHADOW_LANCE`): the same slide, the sword thrust out in front as it
## starts and held there, so the point is what runs into the thing; struck,
## the slide stops on it and the thrust is drawn back out.
func _shadow_slide(key: StringName = &"shadow_slide") -> bool:
	if rig == null or not rig.has_method(&"has_cut") or not bool(rig.call(&"has_cut", String(key))):
		return false
	if not is_on_floor():
		return false
	if not _spend(float(SKILLS[key]["stamina"])):
		return false
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	_set_weapons_stowed(false)
	var foe := _charge_target(shade_seek)
	_charge_spec = rig.call(&"cut_spec", String(key))
	var spec := _charge_spec
	_shade_lance = bool(spec.get("lance", false))
	_shade_dir = -global_basis.z
	_shade_dir.y = 0.0
	_shade_left = float(spec.get("slide_blind", 8.0))
	if foe != null:
		var to := foe.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			_shade_dir = to
		_shade_left = clampf(to.length() - _blade_radius(foe) - float(spec.get("strike_gap", 1.0)),
				0.0, float(spec.get("slide_max", 7.0)))
	_shade_dir = _shade_dir.normalized()
	rotation.y = atan2(-_shade_dir.x, -_shade_dir.z)
	_free_swing = false
	_swing_t0 = _game_t
	_swing_chain = 1
	_whiff_counts = _foe_within(whiff_near)
	attack_started.emit()
	net_attack.rpc(SkinnedRig.SHADOW_LANCE if _shade_lance else SkinnedRig.SHADOW_SLIDE)
	_charge_foe = foe
	_mark_sure(foe, float(spec.get("sure_margin", -1.0)))
	_shade_phase = 1
	_shade_t0 = _game_t
	_shade_gone = false
	_shade_went = 0.0
	_shade_pace_now = _shade_pace_at(0.0)
	# (as long as the slide takes, eased in, and the shadows' own fading)
	net_slide.rpc(_shade_left / maxf(shade_speed, 0.1) + shade_ease * 0.5)
	_commit(3.0)
	_attack_buffer = 0.0
	return true


## The slide's pace now: eased in from standing over `shade_ease`.
func _shade_pace() -> float:
	return _shade_pace_at(_game_t - _shade_t0)


func _shade_pace_at(since: float) -> float:
	var t := clampf(since / maxf(shade_ease, 0.01), 0.0, 1.0)
	return shade_speed * lerpf(0.25, 1.0, t * t * (3.0 - 2.0 * t))


## The slide and its cut let go (the owner's, on the physics clock).
func _tick_shade(delta: float) -> void:
	if _shade_phase < 0:
		return
	if rig == null or (not _shade_gone and not bool(rig.call(&"holding_cut"))):
		# broken off (a blow took the clip off him)
		_shade_phase = -1
		return
	var foe := _charge_foe if _charge_foe != null and is_instance_valid(_charge_foe) \
			and _targetable(_charge_foe) else null
	# On at what it was thrown at (followed, not led), unless it dodges.
	if foe != null and not (foe.has_method(&"is_evading") and bool(foe.call(&"is_evading"))):
		var to := foe.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			_shade_dir = _shade_dir.slerp(to.normalized(), 1.0 - exp(-10.0 * delta)).normalized()
	var pace := _shade_pace()
	_shade_pace_now = pace
	if _charge_spec.has("peak"):
		_tick_shade_peak(foe, pace, delta)
		return
	# Let go as the blade will cut when he arrives: the ground he covers from
	# now to the cut.
	if not _shade_gone and _shade_left <= pace * float(rig.call(&"time_to_cut")) + 0.05:
		_shade_let_go()
	_shade_left -= pace * delta
	if _shade_left <= 0.0:
		_shade_phase = -1
		velocity.x = _shade_dir.x * 4.0
		velocity.z = _shade_dir.z * 4.0
		if not _shade_gone:
			_shade_let_go()


## A slide whose swing has a `peak` (the Shadow Slide, the Shadow Lance): the
## swing's peak — the blade come round or thrust out level ahead — falls on
## the slide's end, however long the slide (the user's word: never the blade
## off to the side, the swing unfinished, as the slide ends). The slide's end
## follows what it is thrown at; the swing is let go when what is left of the
## slide is what the swing takes at its own pace, and from then on is paced
## (`SkinnedRig.pace_to`) to reach its peak as the slide runs out: faster for
## a short slide, slower if the thing came on to meet him. Struck before the
## peak (a sweep coming round into it), the slide is cut to a last step and
## the swing hurried to its peak there; struck at it, the slide stops.
func _tick_shade_peak(foe: Node3D, pace: float, delta: float) -> void:
	var peak := float(_charge_spec.get("peak", 0.2))
	var at := float(rig.call(&"_progress"))
	var serial := int(rig.get(&"attack_serial"))
	if foe != null:
		# the end of the slide where it is now (no further than it may go)
		var to := foe.global_position - global_position
		to.y = 0.0
		var want := to.length() - _blade_radius(foe) - float(_charge_spec.get("strike_gap", 1.5))
		_shade_left = clampf(want, 0.0, _shade_reach_left())
	if _landed_serial == serial:
		if _shade_gone and at >= peak - 0.03:
			# at its peak, in it: the slide stops on it
			_shade_end(1.2)
			return
		_shade_left = minf(_shade_left, 0.3)
	# The swing's time to its peak: at its own pace, and at the quickest it
	# may be hurried to. A slide too short for it is slowed to it (a thing
	# close by, or one that came on to meet him): the slide ends with the
	# swing, never before it.
	var own := _shade_to_peak()
	var quickest := own / SHADE_HURRY
	if _shade_left / maxf(pace, 0.1) < quickest:
		pace = _shade_left / maxf(quickest, 0.01)
	_shade_pace_now = pace
	var left_t := _shade_left / maxf(pace, 0.1) if pace > 0.01 else quickest
	if not _shade_gone and left_t <= own + 0.01:
		_shade_let_go()
	if _shade_gone:
		rig.call(&"pace_to", peak, maxf(left_t, quickest))
	_shade_left -= pace * delta
	_shade_went += pace * delta
	if _shade_left <= 0.001 and (not _shade_gone or at < peak - 0.01):
		# no ground left and the swing not there yet: it finishes where he is
		_shade_left = 0.0
		return
	if _shade_left <= 0.0:
		_shade_end(1.5 if _shade_lance else 4.0)


## How much a swing timed to a slide's end may be hurried past its own pace.
const SHADE_HURRY := 1.8


## How much further this slide may go (`slide_max` in all).
func _shade_reach_left() -> float:
	return maxf(float(_charge_spec.get("slide_max", 7.0)) - _shade_went, 0.0)


## The slide over: what is left of it carried on (m/s), the swing let go if it
## was not, and at its own pace again.
func _shade_end(carry: float) -> void:
	_shade_phase = -1
	velocity.x = _shade_dir.x * carry
	velocity.z = _shade_dir.z * carry
	if not _shade_gone:
		_shade_let_go()
	rig.call(&"pace_own")


## Seconds from where the lance's clip is to its peak, let go now (at its rate).
func _shade_to_peak() -> float:
	var length := float(rig.get(&"_action_len"))
	var at := float(rig.call(&"_progress"))
	return maxf(length * (float(_charge_spec.get("peak", 0.26)) - at), 0.0) \
			/ maxf(float(rig.get(&"_action_rate")), 0.01)


func _shade_let_go() -> void:
	_shade_gone = true
	net_release_cut.rpc()
	_commit_timer = 0.0
	_commit(float(rig.get(&"_swing_commit")))
	_swing_t0 = _game_t


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
	if not _is_bow() or arrow_scene == null:
		return false
	if not _spend(float(SKILLS[&"arrow_rain"]["stamina"])):
		return false
	_drawing = false
	_draw_timer = 0.0
	var centre := _rain_centre()
	var lead := float(rig.call(&"sky_lead")) if rig != null and rig.has_method(&"sky_lead") else 0.0
	var toward := centre - global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		rotation.y = atan2(-toward.x, -toward.z)
	# Stood still through the shot, until just after the string goes.
	_commit(lead + 0.35 if lead > 0.0 else 0.55)
	var from := global_position + up_direction * arrow_height
	var up := (toward.normalized() * 0.3 + Vector3.UP).normalized() * 38.0
	var quarry := NodePath()
	if target != null and _targetable(target) and centre.distance_to(target.global_position) < 3.0:
		quarry = target.get_path()
	net_arrow_rain.rpc(from, up, centre, randi(), quarry)
	return true


## Where the rain falls: on the locked target in reach, else ahead; on the
## ground under that point.
func _rain_centre() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var at := global_position + forward * rain_ahead
	if target != null and _targetable(target):
		var off := target.global_position - global_position
		off.y = 0.0
		at = global_position + off.limit_length(rain_range)
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		at = hit["position"]
	return at


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
	var each := (profile.damage if profile != null else 26.0) * rain_share
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
## Each stack on a creature lasts this long and costs it this much a second.
@export var venom_stack_time: float = 6.0
## Gentle on purpose: three stacks are 7.5 a second, which with the blade
## is a help, not the whole of the kill.
@export var venom_dps: float = 2.5

## Until when (on `_now()`) this hero's blade poisons what it cuts.
var _venom_until: float = 0.0


## Something to aim a skill at: what is locked, if it is in `reach`, else the
## best thing in front.
func _skill_quarry(reach: float) -> Node3D:
	if target != null and _targetable(target) and global_position.distance_to(target.global_position) <= reach:
		return target
	var best := _best_target()
	if best != null and global_position.distance_to(best.global_position) <= reach:
		return best
	return null


func _face_point(at: Vector3) -> void:
	var toward := at - global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		rotation.y = atan2(-toward.x, -toward.z)


#region Hunter's Mark
## Hunter's Mark: he points at the prey and a glint flies from his fingers
## onto it. For `mark_time` it is marked — the sigil over it, an outline, a
## ring on the ground — and every blow on it, anyone's, bites deeper.
func _hunters_mark() -> bool:
	if not _is_bow():
		return false
	var quarry := _skill_quarry(mark_range)
	if quarry == null:
		return false
	if not _spend(float(SKILLS[&"hunters_mark"]["stamina"])):
		return false
	# On the run: he does not stop or turn; the string hand flicks out at the
	# prey and the glint goes ([method SkinnedArcherRig.point_mark]). A draw
	# under way is let down — that hand is busy.
	_drawing = false
	_draw_timer = 0.0
	net_hunters_mark.rpc(quarry.get_path())
	return true


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


#region Piercing Arrow
## Piercing Arrow: the string held past full while the wind gathers on the
## head, then one arrow, flat and fast, through everything on its line.
func _piercing_arrow() -> bool:
	if not _is_bow():
		return false
	if not _spend(float(SKILLS[&"piercing_arrow"]["stamina"])):
		return false
	_drawing = false
	_draw_timer = 0.0
	var quarry := _skill_quarry(pierce_reach)
	# Followed through the draw: body (and so the camera's lock) turn with it.
	_pierce_quarry = quarry
	if quarry != null:
		_face_point(quarry.global_position)
	var nock := float(rig.call(&"nock_lead", 1.0)) if rig != null and rig.has_method(&"nock_lead") else 0.3
	_commit(nock + pierce_hold + 0.45)
	_root(nock + pierce_hold + 0.45)
	var from := global_position + up_direction * arrow_height
	var dir := -global_transform.basis.z
	if quarry != null:
		dir = HuntingLight._aim_of(quarry) - from
	dir = dir.normalized()
	var critical := _shot_rng.randf() < (profile.crit_chance if profile != null else 0.1)
	var damage := (profile.damage if profile != null else 30.0) * pierce_share \
			* ((profile.crit_damage if profile != null else 2.0) if critical else 1.0)
	net_piercing.rpc(dir, damage, critical)
	return true


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
	_skill_serial += 1
	_pierce_quarry = null
	_root_timer = 0.0
	if rig != null and rig.has_method(&"cancel_skill_shot"):
		rig.call(&"cancel_skill_shot")
	if _air_swirl != null and is_instance_valid(_air_swirl):
		_air_swirl.queue_free()
	_air_swirl = null


## Through the Piercing Arrow's draw, keeps him turned on what it was drawn at
## — quickly, but not in a snap — so a quarry that leaps past him or behind
## him is still what the shot goes at. The lock camera follows it as ever.
func _track_pierce(delta: float) -> void:
	if _pierce_quarry == null:
		return
	if not is_instance_valid(_pierce_quarry) or not is_committed() or is_dead:
		_pierce_quarry = null
		return
	var toward := _pierce_quarry.global_position - global_position
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		return
	var want := atan2(-toward.x, -toward.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-14.0 * delta))


## Stands him where he is for `seconds`: the way he was going stops now,
## rather than sliding out.
func _root(seconds: float) -> void:
	_root_timer = maxf(_root_timer, seconds)
	velocity.x = 0.0
	velocity.z = 0.0


## Where a skill shot leaves from: the head of the arrow on the string, or the
## bow hand, or his chest, whichever the rig can say.
func _arrow_tip() -> Vector3:
	if rig != null and rig.has_method(&"arrow_tip"):
		return rig.call(&"arrow_tip")
	if rig != null and rig.has_method(&"bow_hand"):
		return rig.call(&"bow_hand")
	return global_position + up_direction * arrow_height


#region Fire Arrow
## Fire Arrow: the head catches as he draws, the arrow is lobbed to come down
## where he aims, and the ground there burns for `fire_time`.
func _fire_arrow() -> bool:
	if not _is_bow():
		return false
	if not _spend(float(SKILLS[&"fire_arrow"]["stamina"])):
		return false
	_drawing = false
	_draw_timer = 0.0
	var at := _fire_point()
	_face_point(at)
	var nock := float(rig.call(&"nock_lead", 0.0, FIRE_QUICK)) if rig != null and rig.has_method(&"nock_lead") else 0.3
	_commit(nock + FIRE_HOLD + 0.45)
	_root(nock + FIRE_HOLD + 0.45)
	var damage := (profile.damage if profile != null else 30.0) * fire_share
	net_fire_arrow.rpc(at, damage)
	return true


## How long the burning arrow is held before it goes, and how many times
## faster than an ordinary shot it is drawn: a quick shot.
const FIRE_HOLD := 0.25
const FIRE_QUICK := 2.0


## Where the fire goes: on what is locked in range, else ahead; on the ground.
func _fire_point() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var at := global_position + forward * fire_ahead
	var quarry := _skill_quarry(fire_range)
	if quarry != null:
		at = quarry.global_position + (global_position - quarry.global_position).normalized() * 0.4
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1))
	if not hit.is_empty():
		at = hit["position"]
	return at


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
	if not is_venomous():
		return
	var marks := Afflictions.of(creature, false)
	var first := marks == null or marks.poison_stacks() == 0
	net_afflict.rpc(creature.get_path(), &"poison", venom_stack_time, venom_dps, at)
	if first and creature.has_method(&"react"):
		creature.call(&"react", &"poison", self, Vector3.ZERO)
#endregion


#region An arrow's hit, felt (AVTANDIL_POLISH 4)
## The arrow's own sound is where it lands, and from far off is not heard: the
## archer gets his own, in his ear, and a mark on his screen. The head has a
## sharper one; a shot let go at the moment a little brighter. Only he hears
## and sees it: the host decides the hit and sends it to his peer.
const HIT_FELT_SOUND := "res://sounds/bow/hit_confirm.wav"
const HEAD_FELT_SOUND := "res://sounds/bow/hit_head.wav"
const HIT_FELT_DB := -7.0
const HEAD_FELT_DB := -4.0
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
	Sfx.play_flat(self, HEAD_FELT_SOUND if head else HIT_FELT_SOUND, 1.08 if perfect else 1.0,
			(HEAD_FELT_DB if head else HIT_FELT_DB) + (1.5 if perfect else 0.0))
#endregion


## The creature his blade bit, held and lit for the beat his swing is held
## ([HitFeel]) — on every peer, as the swing's own hold is.
@rpc("any_peer", "call_local", "unreliable")
func net_bite(path: NodePath, weight: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != multiplayer.get_unique_id():
		return
	HitFeel.bite(get_node_or_null(path) as Node3D, weight)


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
		SkillFx.burst(into, at, Afflictions.VENOM, 22, Vector2(1.0, 3.5), Vector3.UP, 120.0,
				Vector2(0.012, 0.03), Vector3(0, -7, 0), 0.45)
		SkillFx.ring(into, at, Vector3.UP, Afflictions.VENOM, 0.05, 0.5, 0.25, 0.04, 2.0)


func _decides_here() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))
#endregion


## What a cut of this hero's blade is worth where it lands (host): p.atk, and
## `crit_chance` of the time a critical. [worth, critical].
func cut_worth() -> Array:
	var worth: Array = [26.0, false] if profile == null else profile.cut(_shot_rng)
	# A heavy blow, or the last cut of a string, is worth more.
	if rig != null and rig.get(&"cut_weight") != null:
		worth[0] = float(worth[0]) * float(rig.get(&"cut_weight"))
	return worth
