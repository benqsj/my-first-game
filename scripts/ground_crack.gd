class_name GroundCrack
extends RefCounted

## A crack let go along the ground from a weapon brought down into it (the
## minotaur's axe, the butcher's cleaver; 2026-10-22): a line, not a ring
## (the user's word), running out at `speed` to `reach`. Whoever is on the
## ground within `width` of it when its front passes under him is thrown
## down; a jump or a roll clears it, no shield takes it ("ground").
##
## The host keeps one per crack and ticks it ([method reached]); every peer
## draws it with [method show].

var from: Vector3
var way: Vector3
var reach: float
var speed: float
var width: float
var id: int
var t: float = 0.0
var _hit: Array = []


func _init(at: Vector3, along: Vector3, how_far: float, how_fast: float, how_wide: float, key: int) -> void:
	from = at
	way = along.normalized()
	reach = how_far
	speed = how_fast
	width = how_wide
	id = key


## Host: on by `delta`; the heroes its front reached now (each once).
func reached(delta: float, tree: SceneTree) -> Array:
	t += delta
	var out := []
	var front := t * speed
	for node in tree.get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or _hit.has(who) or bool(who.get("is_dead")) or not who.has_method(&"receive_blow"):
			continue
		var rel := who.global_position - from
		if absf(rel.y) > 1.2:
			continue
		rel.y = 0.0
		var along := rel.dot(way)
		var side := (rel - way * along).length()
		if along < 0.0 or along > minf(front, reach) or along < front - 1.6 or side > width:
			continue
		_hit.append(who)
		out.append(who)
	return out


func done() -> bool:
	return t * speed > reach + 1.6


## Every peer: the ground split open along the line, piece by piece as its
## front runs, stone thrown up; `tint` the dust.
static func show(owner: Node3D, at: Vector3, along: Vector3, how_far: float, how_fast: float,
		tint: Color = Color(0.42, 0.36, 0.3)) -> void:
	var world := Blood.world_of(owner)
	if world == null:
		return
	Sfx.play_any(owner, ["res://sounds/ogre/club_ground_1.wav", "res://sounds/ogre/club_ground_3.wav"],
			null, 0.8, 2.0)
	var n := int(how_far / 1.1)
	for k in n:
		var spot := at + along * (1.1 * float(k) + 0.5)
		var tw := world.create_tween()
		tw.tween_interval((1.1 * float(k)) / how_fast)
		tw.tween_callback(GroundCrack._piece.bind(world, spot, along, k, tint))


static func _piece(world: Node, at: Vector3, along: Vector3, k: int, tint: Color) -> void:
	if not is_instance_valid(world):
		return
	var d := DarkFx.decal(world, at, DarkFx.CRACK, 1.7, Color(0.1, 0.07, 0.05, 1.0), 0.0, 0.9)
	d.rotation.y = atan2(along.x, along.z) + (0.5 if k % 2 == 0 else -0.5)
	var tw := d.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(d, "modulate:a", 0.0, 1.0)
	tw.tween_callback(d.queue_free)
	SkillFx.burst(world, at + Vector3.UP * 0.1, tint, 12, Vector2(2.0, 4.5), Vector3.UP, 35.0,
			Vector2(0.05, 0.11), Vector3(0, -12.0, 0), 0.7)
