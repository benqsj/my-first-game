class_name WeaponSweep
extends RefCounted

## A blow as the thing that throws it — the axe, the scythe, the claws — rather
## than a patch of ground in front of the one throwing it.
##
## While a blow is live, a few stretches of the weapon or the limb are followed
## from one frame to the next, each a capsule from `from` to `to`, `radius`
## thick, wherever the pose has put it. A player is struck only if one of those
## capsules passes through his body on the way: in between two frames the
## stretch is swept in small enough steps that a fast blow cannot skip over him.
## What does not touch him does not hurt him, however close he stands.
##
## A stretch moving slower than `min_speed` (metres a second, at its far end) is
## not a blow at all — the axe raised overhead and held, a scythe settling after
## it struck — and does not hurt either.
##
## `parts` is called once a frame and returns the stretches as they are now:
## an Array of [Vector3 from, Vector3 to, float radius], always in the same
## order. Each player is met once per sweep.

## The player's body as a blow sees it: an upright capsule from his feet — a
## little narrower than the one he walks with, which is his shoulders' width.
const BODY_RADIUS := 0.3
const BODY_LOW := 0.12
const BODY_HIGH := 1.78
## The allowance for a blow that visibly grazes him.
const GRAZE := 0.08

## Draws every live sweep's stretches in the world, for looking at blows.
static var show: bool = false

var parts: Callable
var min_speed: float = 0.0
## Players it has met: none of them is met again by this sweep.
var caught: Dictionary = {}
## When it is live, on its owner's act clock, and the act it belongs to: an act
## cut short (a parry, a knock) takes its sweeps with it.
var from: float = 0.0
var until: float = 0.0
var serial: int = 0
## What it does to a player it meets.
var on_hit: Callable

var _last: Array = []
## What the stretches looked like this frame, for `show`.
var _drawn: Array = []


func _init(stretches: Callable, slowest: float = 0.0) -> void:
	parts = stretches
	min_speed = slowest


## A sweep for one blow of an act: live from `start` to `end` on the owner's act
## clock, doing `effect` to whoever it meets.
static func blow(stretches: Callable, slowest: float, start: float, end: float, act: int,
		effect: Callable) -> WeaponSweep:
	var sweep := WeaponSweep.new(stretches, slowest)
	sweep.from = start
	sweep.until = end
	sweep.serial = act
	sweep.on_hit = effect
	return sweep


## Runs a creature's sweeps one frame, dropping those whose blow is over or
## whose act has been cut short. Host only; call it after the pose is set.
static func run(list: Array[WeaponSweep], clock: float, act: int, tree: SceneTree,
		delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var sweep := list[i]
		if sweep.serial != act or clock > sweep.until:
			list.remove_at(i)
			continue
		if clock < sweep.from:
			sweep.track()
			continue
		for who in sweep.step(tree, delta):
			if sweep.on_hit.is_valid():
				sweep.on_hit.call(who)
		sweep._drawn = sweep._last


## Lines along every live stretch (and a ring of its thickness at each end),
## while `show` is on: a debug view of where a blow can land.
static func draw(owner: Node3D, list: Array[WeaponSweep]) -> void:
	var view := owner.get_node_or_null("SweepView") as MeshInstance3D
	if not show:
		if view != null:
			view.visible = false
		return
	if view == null:
		view = MeshInstance3D.new()
		view.name = "SweepView"
		view.top_level = true
		view.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.15, 0.1)
		mat.no_depth_test = true
		view.material_override = mat
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		owner.add_child(view)
	view.visible = true
	view.global_transform = Transform3D.IDENTITY
	var im := view.mesh as ImmediateMesh
	im.clear_surfaces()
	var any := false
	for sweep in list:
		for part: Array in sweep._drawn:
			if not any:
				im.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			var a: Vector3 = part[0]
			var b: Vector3 = part[1]
			var r: float = part[2]
			im.surface_add_vertex(a)
			im.surface_add_vertex(b)
			var along := (b - a).normalized() if a.distance_to(b) > 0.001 else Vector3.UP
			var side := along.cross(Vector3.UP)
			if side.length() < 0.1:
				side = along.cross(Vector3.RIGHT)
			side = side.normalized() * r
			var up := along.cross(side).normalized() * r
			for end in [a, b]:
				for k in 12:
					var t0 := TAU * k / 12.0
					var t1 := TAU * (k + 1) / 12.0
					im.surface_add_vertex(end + side * cos(t0) + up * sin(t0))
					im.surface_add_vertex(end + side * cos(t1) + up * sin(t1))
			for k in 4:
				var o := side * cos(TAU * k / 4.0) + up * sin(TAU * k / 4.0)
				im.surface_add_vertex(a + o)
				im.surface_add_vertex(b + o)
	if any:
		im.surface_end()


## Forgets the last frame and whoever it met, for a sweep used again.
func reset() -> void:
	_last = []
	caught.clear()


## Takes this frame's pose without hurting anyone: kept up to date while a blow
## is not live yet, so the first live frame sweeps from where the weapon really
## was rather than from wherever it was left.
func track() -> void:
	_last = parts.call()


## One frame of the blow: whoever the weapon passed through since the last one.
func step(tree: SceneTree, delta: float) -> Array[Node3D]:
	var met: Array[Node3D] = []
	var now: Array = parts.call()
	var before: Array = _last if _last.size() == now.size() else now
	_last = now
	var bodies := targets(tree)
	if bodies.is_empty():
		return met
	for i in now.size():
		var part: Array = now[i]
		var was: Array = before[i]
		var a1: Vector3 = part[0]
		var b1: Vector3 = part[1]
		var r: float = part[2]
		var a0: Vector3 = was[0]
		var b0: Vector3 = was[1]
		if min_speed > 0.0 and b1.distance_to(b0) / maxf(delta, 0.0001) < min_speed:
			continue
		var travel := maxf(a1.distance_to(a0), b1.distance_to(b0))
		var steps := clampi(ceili(travel / maxf(0.5 * (r + BODY_RADIUS), 0.05)), 1, 32)
		for who in bodies:
			if caught.has(who):
				continue
			var low := who.global_position + Vector3.UP * BODY_LOW
			var high := who.global_position + Vector3.UP * BODY_HIGH
			for k in steps + 1:
				var t := float(k) / float(steps)
				if touches(a0.lerp(a1, t), b0.lerp(b1, t), r, low, high):
					caught[who] = true
					met.append(who)
					break
	return met


## Whether a stretch `radius` thick, `a` to `b`, meets the body between `low`
## and `high`.
static func touches(a: Vector3, b: Vector3, radius: float, low: Vector3, high: Vector3) -> bool:
	var pts := Geometry3D.get_closest_points_between_segments(a, b, low, high)
	return pts[0].distance_to(pts[1]) <= radius + BODY_RADIUS + GRAZE


## The players a blow may land on: standing, and able to take one.
static func targets(tree: SceneTree) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in tree.get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method("receive_blow") or who.get("net_dead") == true:
			continue
		out.append(who)
	return out


## A stretch of a node-marked weapon: from one marker to the other, `radius`
## thick in the markers' own units — scaled with whatever holds them.
static func between(from: Node3D, to: Node3D, radius: float) -> Array:
	var grow := from.global_transform.basis.get_scale()
	return [from.global_position, to.global_position, radius * (grow.x + grow.y + grow.z) / 3.0]


## A stretch of a skeleton: bone `a`'s head to `b`'s (or to a point in `b`'s own
## frame, `tip`), `radius` metres thick.
static func bones(skeleton: Skeleton3D, a: int, b: int, radius: float,
		tip: Vector3 = Vector3.ZERO) -> Array:
	var frame := skeleton.global_transform
	var from := frame * skeleton.get_bone_global_pose(a).origin
	var to := frame * (skeleton.get_bone_global_pose(b) * tip)
	return [from, to, radius]
