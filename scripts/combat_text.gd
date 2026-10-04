class_name CombatText
extends Node3D

## What the fight says over the creatures' heads:
##
## * **The level** of every creature near you, over its health bar — "Lv 3
##   Wolf" — coloured by how it stands against yours: grey far below, green
##   below, white the same, yellow above, red far above.
## * **What each blow took off it**, a number that jumps up off it and fades:
##   white, or for a critical larger and red, with "CRITICAL" over it.
##
## Hung under [World] once. It reads, it does not listen: every frame it looks at
## each creature near the camera and compares its `health` with last frame's —
## so it works for every weapon, spell, fire and poison without any of them
## knowing it is there, and on a client too, where `health` arrives replicated.
## Whether a blow was a critical the creature notes itself (`crit_at` meta,
## host-side; [method mark_critical]).

## How far off a creature's level is shown.
const TAG_RANGE := 24.0
## How far off its blows are counted.
const NUMBER_RANGE := 45.0
## How long a number stays up.
const NUMBER_LIFE := 1.0

## A critical's red: bright, a little warm, so it reads over blood and bark.
const CRIT_RED := Color(1.0, 0.2, 0.14)

## The render layer the words are on — one the map's photograph from above
## leaves out ([WorldMap]), so no level or number is caught in it.
const LAYER := 1 << 19

const NAMES := {&"wolf": "Wolf", &"imp": "Imp", &"puglin": "Puglin", &"orc": "Orc", &"arkdeva": "Arkdeva"}

var _world: World
var _last: Dictionary = {}
var _tags: Dictionary = {}
var _numbers: Array = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _drift: PackedVector3Array = PackedVector3Array()
var _rng := RandomNumberGenerator.new()


## A creature notes that the blow it is taking is a critical.
static func mark_critical(creature: Node) -> void:
	creature.set_meta(&"crit_at", Time.get_ticks_msec())


func _ready() -> void:
	_world = get_parent() as World
	top_level = true


func _process(delta: float) -> void:
	_age_numbers(delta)
	if _world == null:
		return
	var creatures := _world.get_node_or_null(^"Enemies")
	if creatures == null:
		return
	var port := get_viewport()
	var eye: Camera3D = port.get_camera_3d() if port != null else null
	var me: Player = _world.player() if _world.is_inside_tree() else null
	var from: Vector3 = eye.global_position if eye != null else (me.global_position if me != null else Vector3.ZERO)
	var mine := 1
	if me != null:
		var book := me.get_node_or_null(^"Leveling") as Leveling
		if book != null:
			mine = book.level
	for node in creatures.get_children():
		var creature := node as Node3D
		if creature == null or creature.get("health") == null:
			continue
		var id := creature.get_instance_id()
		var health := float(creature.get("health"))
		var dead: bool = creature.get("is_dead") == true
		var far := creature.global_position.distance_to(from)
		var was: float = _last.get(id, health)
		_last[id] = health
		if far < NUMBER_RANGE and health < was - 0.05:
			_number(creature, was - health, _critical(creature))
		_tag(creature, far < TAG_RANGE and not dead, mine)
	# Forget what has gone.
	for key: int in _tags.keys():
		if not is_instance_id_valid(key):
			# The tag went with its creature, most likely: not cast, only checked.
			var gone: Variant = _tags[key]
			if is_instance_valid(gone):
				(gone as Node).queue_free()
			_tags.erase(key)
			_last.erase(key)


func _critical(creature: Node) -> bool:
	if not creature.has_meta(&"crit_at"):
		return false
	return Time.get_ticks_msec() - int(creature.get_meta(&"crit_at")) < 150


## How high over the creature its bar floats: the highest [HealthBar] on it.
## A bar may be `top_level` (placed in the world, not under the creature), so
## it is measured from where the creature stands.
static func _bar_height(creature: Node3D) -> float:
	var top := -1.0
	for child in creature.get_children():
		if child is HealthBar:
			var bar := child as Node3D
			var up: float = bar.global_position.y - creature.global_position.y if bar.top_level else bar.position.y
			top = maxf(top, up)
	return clampf(top, 1.0, 5.0) if top > 0.0 else 2.2


func _tag(creature: Node3D, wanted: bool, mine: int) -> void:
	var id := creature.get_instance_id()
	var held: Variant = _tags.get(id)
	var tag: Label3D = held if is_instance_valid(held) else null
	if tag == null:
		if not wanted:
			return
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.layers = LAYER
		tag.fixed_size = true
		tag.pixel_size = 0.0011
		tag.font_size = 30
		tag.outline_size = 9
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.no_depth_test = true
		tag.render_priority = 2
		tag.outline_render_priority = 1
		var level := Leveling.level_of(creature)
		var kind := Leveling.kind_of(creature)
		tag.text = "Lv %d  %s" % [level, NAMES.get(kind, String(kind).capitalize())]
		creature.add_child(tag)
		tag.position = Vector3(0.0, _bar_height(creature) + 0.22, 0.0)
		_tags[id] = tag
	tag.visible = wanted
	if wanted:
		tag.position = Vector3(0.0, _bar_height(creature) + 0.22, 0.0)
		tag.modulate = _standing(Leveling.level_of(creature) - mine)


## The colour of a level against yours.
static func _standing(diff: int) -> Color:
	if diff <= -3:
		return Color(0.62, 0.62, 0.62)
	if diff < 0:
		return Color(0.55, 0.9, 0.5)
	if diff == 0:
		return Color(1.0, 1.0, 1.0)
	if diff <= 2:
		return Color(1.0, 0.86, 0.3)
	return Color(1.0, 0.35, 0.28)


func _number(creature: Node3D, amount: float, critical: bool) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.layers = LAYER
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 56 if critical else 40
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.02, 0.0, 0.9)
	label.no_depth_test = true
	label.render_priority = 3
	label.outline_render_priority = 2
	var shown := maxi(roundi(amount), 1)
	label.text = str(shown)
	label.modulate = CRIT_RED if critical else Color(1.0, 1.0, 1.0)
	add_child(label)
	var side := _rng.randf_range(-0.45, 0.45)
	label.global_position = creature.global_position + Vector3(side, _bar_height(creature) + 0.5, 0.0)
	_numbers.append(label)
	_ages.append(0.0)
	_drift.append(Vector3(side * 0.6, 1.0, 0.0))
	if critical:
		# The word over the number, going up with it (the user's word, 2026-10-05).
		var word := label.duplicate() as Label3D
		word.text = "CRITICAL"
		word.font_size = 34
		word.outline_size = 11
		word.modulate = CRIT_RED
		add_child(word)
		# over the number by screen pixels: the labels are a fixed size on
		# screen, so a lift in metres was nothing at range
		word.global_position = label.global_position
		word.offset = Vector2(0.0, 52.0)
		_numbers.append(word)
		_ages.append(0.0)
		_drift.append(Vector3(side * 0.6, 1.0, 0.0))


func _age_numbers(delta: float) -> void:
	var k := _numbers.size() - 1
	while k >= 0:
		var held: Variant = _numbers[k]
		var label: Label3D = held if is_instance_valid(held) else null
		_ages[k] += delta
		var t := _ages[k]
		if label == null or t >= NUMBER_LIFE:
			if label != null:
				label.queue_free()
			_numbers.remove_at(k)
			_ages.remove_at(k)
			_drift.remove_at(k)
		else:
			# Jumps up quickly, slows, and fades at the end; pops big first.
			var rise := 1.0 - pow(1.0 - clampf(t / NUMBER_LIFE, 0.0, 1.0), 3.0)
			var step := _drift[k] * 0.9 * (rise - (1.0 - pow(1.0 - clampf((t - delta) / NUMBER_LIFE, 0.0, 1.0), 3.0)))
			label.global_position += step
			var pop := 1.0 + 0.6 * (1.0 - clampf(t / 0.12, 0.0, 1.0))
			label.scale = Vector3.ONE * pop
			var c := label.modulate
			c.a = 1.0 - clampf((t - NUMBER_LIFE * 0.6) / (NUMBER_LIFE * 0.4), 0.0, 1.0)
			label.modulate = c
			var o := label.outline_modulate
			o.a = 0.9 * c.a
			label.outline_modulate = o
		k -= 1
