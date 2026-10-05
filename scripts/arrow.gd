class_name Arrow
extends Node3D

## An arrow in flight.
##
## It is not a physics body. An arrow crosses more ground in one tick than it is
## long — at 46 m/s that is three quarters of a metre — so a collider would fly
## through a wolf as often as it hit one. Instead each tick draws a line from
## where it was to where it is going and asks what that line crossed, which
## cannot be tunnelled through however fast the arrow goes.
##
## What it hits it tells. Anything with a `take_hit()` takes the damage; anything
## else just stops it. Sticking in what it hit rather than vanishing is most of
## what makes a shot feel landed.
##
## Most of this file is about being *seen*. A centimetre-wide shaft crossing half
## a metre a frame, viewed end-on because that is where the camera is, is a thing
## nobody can react to. What carries the shot is the **air it cuts**: a thin pale
## line down the flight path with a wider, fainter wake either side of it, and a
## roll on the shaft.
##
## Deliberately not light. An earlier pass gave the head a glow and put a flare
## at each end of the flight, and what that read as was an explosion crossing the
## field — the shot stopped looking like an arrow. Nothing here goes past white
## or flares: a slipstream is displaced air, and displaced air does not shine.

signal struck(what: Node3D, where: Vector3, critical: bool)

## How long a spent arrow stays in the world before it goes.
@export var linger: float = 6.0
## And how long it takes to fade out of sight once that is up.
@export var sink_time: float = 1.6
## Longest an arrow may be in the air before it is given up on, in seconds.
@export var lifetime: float = 6.0
## How far past the surface it buries itself.
@export var bite: float = 0.12
## How wide the line down the flight path is, in metres, and how much wider the
## wake either side of it is. An arrow is a centimetre across and crosses half a
## metre between one frame and the next, so on its own it is a thing that is
## never actually on screen where you are looking. The line is what makes a shot
## something an opponent can see coming — and duck.
@export var trail_width: float = 0.05
@export var wake_spread: float = 4.5
## How fast the shaft rolls in flight, in turns a second. Fletching spins an
## arrow, and a spinning arrow reads as a thing in flight rather than a sliding
## decal — at this speed it is the flicker of it that is seen, not the turn.
@export var spin: float = 2.4
## The colours of cut air. Kept **at or under white on every channel**: past one
## they run into the glow pass and the shot reads as something burning rather
## than something flying.
@export var streak_tint: Color = Color(1.0, 0.99, 0.95, 0.6)
@export var wake_tint: Color = Color(0.88, 0.92, 0.98, 0.17)
## A shot that lands hard cuts the same air, only a little warmer.
@export var crit_tint: Color = Color(1.0, 0.85, 0.62, 0.7)

## An arrow going into a body (the user's recordings, cut).
const HITS: Array[String] = [
	"res://unverified/sounds/bow/arrow_hit_1.wav", "res://unverified/sounds/bow/arrow_hit_2.wav",
	"res://unverified/sounds/bow/arrow_hit_3.wav", "res://unverified/sounds/bow/arrow_hit_4.wav",
	"res://unverified/sounds/bow/arrow_hit_5.wav",
]

## Loosed by a creature at the heroes ([BowFighter]): it flies through the
## world and the heroes, not the creatures, and what it meets takes it as a
## blow (`receive_blow`, a flinch, never a fall), not as a cut.
var against_heroes: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 6.0
var _damage: float = 0.0
var _critical: bool = false
var _shooter: Node3D = null
## The air it parts, heard as it goes by (AVTANDIL_POLISH 5): synthesized,
## on the arrow, carried along with the doppler shift. A few at a time at most,
## so a volley is not a wall of hiss.
const WHISTLE := "res://sounds/bow/arrow_whistle.wav"
const WHISTLE_DB := -15.0
const MAX_WHISTLES := 4
static var _whistling: int = 0
var _whistle: AudioStreamPlayer3D = null

## The stunning arrow's chance to stun what it goes into ([method
## Player.arrow_stun]); nothing for an ordinary one.
var stun_chance: float = 0.0
## What it was loosed at, when it follows it ([method follow]): the stunning
## arrow does, so a creature stepping aside as it flies is still hit; one that
## dodges ([code]is_evading[/code]) shakes it off and it flies on straight.
var _followed: Node3D = null
var _follow_part: int = -1
## How fast it turns onto its quarry, radians a second.
const HUNT_TURN := 7.0
## Let go at the moment ([method SkinnedArcherRig.release_grade]): told to the
## archer with the hit, which he hears a little brighter.
var perfect: bool = false
var _spent: bool = false
## The line down the flight path, and the wider wake either side of it.
var _trail: SwordTrail
var _wake: SwordTrail
var _age: float = 0.0
var _rested: float = 0.0
## How far the shaft has rolled.
var _roll: float = 0.0
## Carries the trail markers, turned back against the roll so the streak stays
## flat while the shaft spins inside it.
var _steady: Node3D


func _ready() -> void:
	set_physics_process(false)


## Sends it on its way. Everything about the shot is decided by whoever loosed
## it — how hard it was drawn is their business, not the arrow's.
func launch(velocity: Vector3, damage: float, critical: bool, gravity: float,
		shooter: Node3D) -> void:
	_velocity = velocity
	_damage = damage
	_critical = critical
	_gravity = gravity
	_shooter = shooter
	_point_along(velocity)
	_lay_trail()
	_start_whistle()
	set_physics_process(true)
	add_to_group(&"missile")


func _start_whistle() -> void:
	if _whistling >= MAX_WHISTLES or not ResourceLoader.exists(WHISTLE):
		return
	_whistle = AudioStreamPlayer3D.new()
	_whistle.stream = load(WHISTLE)
	_whistle.volume_db = WHISTLE_DB
	_whistle.pitch_scale = randf_range(0.92, 1.08)
	_whistle.unit_size = 2.5
	_whistle.max_distance = 45.0
	_whistle.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_whistle.bus = &"Master"
	add_child(_whistle)
	_whistle.play()
	_whistling += 1
	_whistle.tree_exited.connect(func() -> void: _whistling = maxi(_whistling - 1, 0))


func _stop_whistle() -> void:
	if _whistle != null and is_instance_valid(_whistle):
		var w := _whistle
		_whistle = null
		var tw := w.create_tween()
		tw.tween_property(w, "volume_db", -60.0, 0.05)
		tw.tween_callback(w.queue_free)


## For a creature watching it come ([Wolf]): where it is, where it is going,
## and who loosed it — nothing once it has struck.
func flight() -> Array:
	if _spent or not is_physics_processing():
		return []
	return [global_position, _velocity, _shooter]


func _physics_process(delta: float) -> void:
	if _spent:
		_settle(delta)
		return

	_age += delta
	if _age > lifetime:
		for ribbon in [_trail, _wake]:
			if ribbon != null:
				ribbon.queue_free()
		queue_free()
		return

	if _followed != null:
		_steer(delta)
	else:
		_velocity.y -= _gravity * delta
	_roll += TAU * spin * delta
	var step := _velocity * delta
	var hit := _sweep(global_position, global_position + step)
	if hit.is_empty():
		global_position += step
		# An arrow turns to follow its own arc, which is what makes the drop
		# read as a drop rather than a slide.
		_point_along(_velocity)
		return

	global_position = (hit["position"] as Vector3) + _velocity.normalized() * bite
	_strike(hit["collider"] as Node3D, hit["position"] as Vector3)


## Follows `who` from here on (the stunning arrow, [method Player.net_loose]),
## at the archer's chosen part of it when it is his target.
func follow(who: Node3D) -> void:
	if who == null or not who.is_inside_tree():
		return
	_followed = who
	_follow_part = TargetPoints.default_index(who)
	if is_instance_valid(_shooter) and _shooter.get(&"target") == who:
		var part: Variant = _shooter.get(&"target_part")
		if part is int:
			_follow_part = part


func _steer(delta: float) -> void:
	var q := _followed
	if not is_instance_valid(q) or not q.is_inside_tree() or q.get(&"is_dead") == true \
			or (q.has_method(&"is_evading") and bool(q.call(&"is_evading"))):
		# dodged, or gone: it flies on as it was going
		_followed = null
		return
	var points := TargetPoints.of(q)
	if points.is_empty():
		_followed = null
		return
	var at: Vector3 = points[clampi(_follow_part, 0, points.size() - 1)]
	# at that height, but down the middle of what stops arrows: a wolf's head
	# stands out in front of its capsule, and an arrow through the head point
	# would pass it by
	for shape in q.get_children():
		if shape is CollisionShape3D and not (shape as CollisionShape3D).disabled:
			var mid := (shape as Node3D).global_position
			at.x = mid.x
			at.z = mid.z
			break
	var want := at - global_position
	var speed := _velocity.length()
	if want.length_squared() < 0.0001 or speed < 0.01:
		return
	var going := _velocity / speed
	var need := want.normalized()
	if going.dot(need) < -0.2:
		# gone past it
		_followed = null
		return
	var angle := going.angle_to(need)
	if angle < 0.0001:
		return
	var turn := minf(HUNT_TURN * delta / angle, 1.0)
	_velocity = going.slerp(need, turn).normalized() * speed


## What the arrow crossed between one tick and the next, if anything.
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _shooter is CollisionObject3D:
		exclude.append((_shooter as CollisionObject3D).get_rid())
	# World and enemies: the same things the player's own capsule collides with.
	var query := PhysicsRayQueryParameters3D.create(from, to, 3 if against_heroes else 5, exclude)
	return space.intersect_ray(query)


func _strike(what: Node3D, where: Vector3) -> void:
	_spent = true
	_velocity = Vector3.ZERO
	for ribbon in [_trail, _wake]:
		if ribbon == null:
			continue
		# Stops feeding the ribbon; it fades itself out from there and then goes.
		ribbon.emitting = false
		ribbon.get_tree().create_timer(ribbon.fade_time + 0.1).timeout.connect(
				ribbon.queue_free)
	_trail = null
	_wake = null
	_stop_whistle()
	struck.emit(what, where, _critical)

	if against_heroes:
		if what != null and what.has_method(&"receive_blow") and what.get("net_dead") != true:
			Sfx.play(self, HITS[randi() % HITS.size()], null, where, randf_range(0.94, 1.06), -14.0)
			# Only the host's copy counts, as for the heroes' own arrows.
			if multiplayer.is_server():
				what.call(&"receive_blow", _damage, _shooter if is_instance_valid(_shooter) else self,
						0, 2, get_instance_id() % 100000)
			_stick_in.call_deferred(what, where)
		return

	if what != null and what.has_method("take_hit"):
		var blow := -global_transform.basis.y
		# Blood here rather than inside the hit. Every peer builds this arrow and
		# every peer's copy arrives, but only the host's counts for damage — so
		# the wound is spilled locally, where it is seen, and the hit is asked
		# for without it.
		Blood.splatter(Blood.world_of(self), where, blow.normalized())
		Sfx.play(self, HITS[randi() % HITS.size()], null, where, randf_range(0.94, 1.06), -14.0)
		var alive: bool = what.get(&"is_dead") != true
		# The shooter goes with it: an arrow that hurts something anonymously
		# leaves the creature no reason to come and find out who fired it.
		what.call("take_hit", _damage, where, blow, _critical, false, _shooter)
		# The hit felt by whoever loosed it (AVTANDIL_POLISH 4): the host's copy
		# tells him, he sends it to the archer's own peer.
		if alive and multiplayer.is_server() and is_instance_valid(_shooter) \
				and _shooter.has_method(&"arrow_landed"):
			var head := head_hit(what, where)
			_shooter.call(&"arrow_landed", what, where, head, perfect)
			if stun_chance > 0.0 and _shooter.has_method(&"arrow_stun"):
				_shooter.call(&"arrow_stun", what, head, stun_chance)
		# Arrows that land in something ride it rather than hanging in the air
		# where it used to be — on the bone nearest where it went in, so it goes
		# with the leg or the head it is in, and down with the body when it
		# falls. Deferred, because moving a node between parents in the middle
		# of a physics step is asking the tree to change under the solver that
		# is walking it.
		_stick_in.call_deferred(what, where)


## Whether the arrow went in at the head: on something big enough to have one
## ([TargetPoints], three points), no lower than a share of its height under
## the head point. Height only: the arrow stops on the body's capsule, which
## stands well out in front of the head bone.
static func head_hit(what: Node3D, where: Vector3) -> bool:
	if what == null or not what.is_inside_tree():
		return false
	var points := TargetPoints.of(what)
	if points.size() < 3:
		return false
	var reach := clampf((points[2].y - points[0].y) * 0.28, 0.18, 0.45)
	var up := what.global_transform.basis.y.normalized()
	return (where - points[2]).dot(up) > -reach


## Where in `what` the arrow stays: the bone of its skeleton nearest the hit
## (on a mount made for that bone, shared by every arrow in it), else the piece
## of it the point is in or nearest, else the body itself.
func _stick_in(what: Node3D, where: Vector3) -> void:
	if not is_instance_valid(what) or not is_inside_tree():
		return
	var holder: Node3D = what
	# A hero on the mannequin still carries his old skeleton, its meshes
	# hidden, no longer moving the body you see: only skeletons that move a
	# shown mesh count, and the bone nearest the hit across them is the one.
	var skel: Skeleton3D = null
	var best := -1
	var best_d := INF
	for each in _shown_skeletons(what):
		for b in each.get_bone_count():
			var d := (each.global_transform * each.get_bone_global_pose(b).origin).distance_squared_to(where)
			if d < best_d:
				best_d = d
				best = b
				skel = each
	if skel != null:
		if best >= 0:
			var mount_name := "ArrowMount_%d" % best
			var mount := skel.get_node_or_null(mount_name) as BoneAttachment3D
			if mount == null:
				mount = BoneAttachment3D.new()
				mount.name = mount_name
				skel.add_child(mount)
				mount.bone_idx = best
			holder = mount
	else:
		var near_d := INF
		for m in what.find_children("*", "MeshInstance3D", true, false):
			var mesh := m as MeshInstance3D
			if not mesh.is_visible_in_tree() or mesh is SwordTrail:
				continue
			var box := mesh.global_transform * mesh.get_aabb()
			var d := 0.0 if box.grow(0.05).has_point(where) else box.get_center().distance_squared_to(where)
			if d < near_d:
				near_d = d
				holder = mesh
	reparent(holder, true)


## The skeletons in `what` that move a mesh you can see; if none does (a body
## of bare skeletons), every one shown.
static func _shown_skeletons(what: Node) -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	for node in what.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.skin == null:
			continue
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel != null and not out.has(skel):
			out.append(skel)
	if out.is_empty():
		for node in what.find_children("*", "Skeleton3D", true, false):
			if (node as Skeleton3D).is_visible_in_tree():
				out.append(node as Skeleton3D)
	return out


## Sits in whatever it landed in, then fades away. Arrows that never leave carve
## the ground up into a pincushion and cost a draw call each.
func _settle(delta: float) -> void:
	_rested += delta
	if _rested < linger:
		return
	var gone := (_rested - linger) / maxf(sink_time, 0.01)
	if gone >= 1.0:
		queue_free()
		return
	for m in find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).transparency = gone


## Hangs the cut air off the arrow.
##
## Two ribbons, both the one the sword leaves, given a segment that lies *across*
## the flight rather than along it — so what each sweeps out is a flat band down
## the arrow's path. They write world positions, so they live in the world beside
## the arrow rather than on it, and they outlive the arrow by a fade.
##
## The narrow one is the line the head draws; the wide one is the air pushed
## aside around it, fainter and gone sooner. Two of them rather than one wide
## band because that is the difference between air parting and a searchlight: the
## edge of the wake has to be soft where the line down the middle is not.
func _lay_trail() -> void:
	var into := get_parent()
	if into == null or trail_width <= 0.0:
		return
	# Hung off a node that undoes the roll. The bands have to stay flat sheets
	# down the flight path; carried on a shaft that is spinning they would wind
	# into a corkscrew and pinch to nothing twice a turn.
	_steady = Node3D.new()
	_steady.name = "Steady"
	add_child(_steady)

	var line := crit_tint if _critical else streak_tint
	# Long enough to be a line across the field rather than a smear behind the
	# head: at forty metres a second, twenty samples is most of a second of
	# flight held on screen at once.
	_trail = _ribbon(into, "ArrowTrail", trail_width, line, 20, 0.30, 0.85)
	if wake_spread > 1.0:
		# Even across the band: the wake is air, and air has no bright edge.
		_wake = _ribbon(into, "ArrowWake", trail_width * wake_spread,
				wake_tint, 12, 0.16, 1.0)


## One band of swept air: a pair of markers `width` apart on the steady node, and
## a ribbon stitched between wherever they have been.
func _ribbon(into: Node, ribbon_name: String, width: float, tint: Color,
		samples: int, fade: float, inner: float) -> SwordTrail:
	var left := Marker3D.new()
	left.position = Vector3(-width * 0.5, 0.0, 0.0)
	_steady.add_child(left)
	var right := Marker3D.new()
	right.position = Vector3(width * 0.5, 0.0, 0.0)
	_steady.add_child(right)

	var ribbon := SwordTrail.new()
	ribbon.name = ribbon_name
	ribbon.sample_count = samples
	ribbon.fade_time = fade
	ribbon.inner_edge_alpha = inner
	ribbon.tint = tint
	into.add_child(ribbon)
	ribbon.setup(left, right)
	ribbon.emitting = true
	return ribbon


## Points the shaft along the way it is going. The model is built running up its
## own +Y, so that axis is the one aimed.
func _point_along(heading: Vector3) -> void:
	if heading.length_squared() < 0.0001:
		return
	var forward := heading.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var aimed := Basis(side, forward, side.cross(forward)).orthonormalized()
	# Rolled about its own shaft: the fletching spins an arrow, and the flicker
	# that comes off it is most of what makes one readable in the air. The shaft
	# runs up local +Y, so the roll is a turn about that.
	global_transform.basis = aimed.rotated(forward, _roll)
	if _steady != null:
		_steady.rotation = Vector3(0.0, -_roll, 0.0)
