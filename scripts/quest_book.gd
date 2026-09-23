class_name QuestBook
extends Node

## The quests, and the people who give them.
##
## A [QuestGiver] stands somewhere in the level. Walk up to one and a line at
## the bottom of the screen says so; press **interact** (F) and they tell you
## what they want. Press it again to take the job on, or walk away to leave it.
## Once taken, the job sits in the corner of the screen with a count, and when
## the count is full you go back to whoever gave it for the reward.
##
## The jobs are killing things, because that is what there is to do: the book
## watches every creature in the level and, when one it has not seen dead
## before is dead, counts it against any job that wants that kind. Kinds are
## the creature's scene file name — `wolf`, `imp`, `orc`, `arkdeva` — so a new
## creature is a new kind with nothing to register.
##
## Everything here is this player's own. In a co-op game each player has their
## own jobs, and a kill counts for every player who has a job wanting it: the
## wolves died whoever swung the sword, and nobody should have to fight their
## friends for the last blow.

signal changed

enum State { OFFERED, TAKEN, DONE, REWARDED }

## id -> the job: who, what they say, what they want, and how many.
const JOBS := {
	&"wolves": {
		"giver": "Datvi the Woodcutter",
		"title": "Wolves at the woodpile",
		"offer": "Every night the wolves come down out of the pines and drag my logs about. Timber is heavy enough without chasing it. Thin them out for me — four of them should teach the rest.",
		"waiting": "Still hear them howling. Four, I said.",
		"thanks": "Quiet at last. Here — sit by the fire a while, you look half dead yourself.",
		"kind": &"wolf",
		"count": 4,
	},
	&"imps": {
		"giver": "Ali of the Embers",
		"title": "Stolen embers",
		"offer": "The imps in the wood took my embers — little thieves, they cannot even use them, they only like the glow. Without them the mist comes right up to the water. Put out six of them and the embers will find their own way home.",
		"waiting": "My light is still thin. The imps have the rest.",
		"thanks": "There — do you feel it? Warm all the way through. Take some of it with you.",
		"kind": &"imp",
		"count": 6,
	},
	&"arkdeva": {
		"giver": "Old Baqaq the Fisherman",
		"title": "Poison in the water",
		"offer": "Forty years I have fished this bay and never a dead fish in the nets. Now they come up green. There is a thing in the wood south of the green, all legs and blades, spitting poison into the streams. Arkdeva, they call it. End it, and the water will run clean.",
		"waiting": "Still green, the water. Still green.",
		"thanks": "Look at that — silver again! You have my thanks, and my best net's worth of luck.",
		"kind": &"arkdeva",
		"count": 1,
	},
}

## How far from a giver a player can talk to them, in metres.
@export var talk_range: float = 3.6

var state: Dictionary = {}
var progress: Dictionary = {}

var _givers: Array[QuestGiver] = []
var _seen_dead: Dictionary = {}
var _poll: float = 0.0
var _talking: QuestGiver
var _near: QuestGiver

var _layer: CanvasLayer
var _prompt: Label
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _dialog_keys: Label
var _tracker: VBoxContainer


func _ready() -> void:
	add_to_group(&"quest_book")
	for id: StringName in JOBS:
		state[id] = State.OFFERED
		progress[id] = 0
	_build_hud()


func register(giver: QuestGiver) -> void:
	if not _givers.has(giver):
		_givers.append(giver)


## The job a giver has, and how it stands.
func job(id: StringName) -> Dictionary:
	return JOBS.get(id, {})


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_count_the_dead()
	_update_near()


#region Talking
func _update_near() -> void:
	var me := _local_player()
	var best: QuestGiver = null
	var closest := talk_range
	if me != null:
		for giver in _givers:
			if not is_instance_valid(giver):
				continue
			var gap := giver.global_position.distance_to(me.global_position)
			if gap < closest:
				closest = gap
				best = giver
	_near = best
	if _talking != null and _talking != _near:
		_close()
	if _near != null and _talking == null:
		_prompt.text = "[F]  Talk to %s" % _near.npc_name
		_prompt.show()
	else:
		_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or event.is_echo():
		return
	if _near == null:
		return
	get_viewport().set_input_as_handled()
	if _talking == null:
		_open(_near)
	else:
		_answer(_talking)


## Called by tests and by [method _unhandled_input] alike.
func interact() -> void:
	if _near == null:
		return
	if _talking == null:
		_open(_near)
	else:
		_answer(_talking)


func _open(giver: QuestGiver) -> void:
	_talking = giver
	var id := giver.quest
	var info := job(id)
	var line := ""
	var keys := ""
	match int(state.get(id, State.OFFERED)):
		State.OFFERED:
			line = String(info.get("offer", ""))
			keys = "[F]  Accept        (walk away to decline)"
		State.TAKEN:
			line = String(info.get("waiting", ""))
			keys = "%d / %d  ·  (walk away)" % [progress[id], info.get("count", 1)]
		State.DONE:
			line = String(info.get("thanks", ""))
			keys = "[F]  Take your reward"
		State.REWARDED:
			line = "Safe roads to you, friend."
			keys = "(walk away)"
	_dialog_name.text = giver.npc_name
	_dialog_text.text = line
	_dialog_keys.text = keys
	_dialog.show()
	_prompt.hide()
	giver.turn_to(_local_player())


func _answer(giver: QuestGiver) -> void:
	var id := giver.quest
	match int(state.get(id, State.OFFERED)):
		State.OFFERED:
			state[id] = State.TAKEN
			progress[id] = 0
			changed.emit()
			_close()
		State.DONE:
			state[id] = State.REWARDED
			_reward(id)
			changed.emit()
			_close()
		_:
			_close()
	_refresh_tracker()


func _close() -> void:
	_talking = null
	_dialog.hide()


## Players carry no health or purse yet, so the reward is the giver's word and
## a moment of warm light round the player — something to see that it counted.
func _reward(_id: StringName) -> void:
	var me := _local_player()
	if me == null:
		return
	var glow := CPUParticles3D.new()
	glow.one_shot = true
	glow.explosiveness = 0.7
	glow.amount = 40
	glow.lifetime = 1.4
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 0.6
	glow.direction = Vector3.UP
	glow.spread = 35.0
	glow.gravity = Vector3(0.0, 1.2, 0.0)
	glow.initial_velocity_min = 0.6
	glow.initial_velocity_max = 1.8
	glow.scale_amount_min = 0.05
	glow.scale_amount_max = 0.1
	var spark := SphereMesh.new()
	spark.radius = 0.5
	spark.height = 1.0
	spark.radial_segments = 6
	spark.rings = 3
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color(1.0, 0.82, 0.4)
	light.emission_enabled = true
	light.emission = Color(1.0, 0.7, 0.3)
	spark.material = light
	glow.mesh = spark
	me.add_child(glow)
	glow.position = Vector3.UP * 1.0
	glow.emitting = true
	get_tree().create_timer(2.0).timeout.connect(glow.queue_free)
#endregion


#region Counting
func _count_the_dead() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(&"enemy"):
		if node.get("is_dead") != true:
			continue
		var key := node.get_instance_id()
		if _seen_dead.has(key):
			continue
		_seen_dead[key] = true
		note_kill(kind_of(node))


## One creature of `kind` has died. Counted against every job that wants it.
func note_kill(kind: StringName) -> void:
	var any := false
	for id: StringName in JOBS:
		if int(state[id]) != State.TAKEN:
			continue
		var info: Dictionary = JOBS[id]
		if info.get("kind") != kind:
			continue
		progress[id] = mini(int(progress[id]) + 1, int(info.get("count", 1)))
		if int(progress[id]) >= int(info.get("count", 1)):
			state[id] = State.DONE
		any = true
	if any:
		changed.emit()
		_refresh_tracker()


## `res://scenes/enemies/wolf.tscn` -> `wolf`.
static func kind_of(node: Node) -> StringName:
	var path := node.scene_file_path
	if path.is_empty():
		return StringName(String(node.name).to_lower().rstrip("0123456789_"))
	return StringName(path.get_file().get_basename())
#endregion


#region On screen
func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Player
		if body != null and body.is_multiplayer_authority():
			return body
	return null


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)

	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -220
	_prompt.offset_right = 220
	_prompt.offset_top = -120
	_prompt.offset_bottom = -90
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_prompt, 20, Color(0.96, 0.9, 0.72))
	_prompt.hide()
	_layer.add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.anchor_left = 0.5
	_dialog.anchor_right = 0.5
	_dialog.anchor_top = 1.0
	_dialog.anchor_bottom = 1.0
	_dialog.offset_left = -360
	_dialog.offset_right = 360
	_dialog.offset_top = -300
	_dialog.offset_bottom = -110
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.86)
	box.border_color = Color(0.72, 0.58, 0.3, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	_dialog.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_dialog.add_child(column)
	_dialog_name = Label.new()
	_style_label(_dialog_name, 22, Color(0.95, 0.78, 0.4))
	column.add_child(_dialog_name)
	_dialog_text = Label.new()
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(680, 0)
	_style_label(_dialog_text, 18, Color(0.94, 0.92, 0.86))
	column.add_child(_dialog_text)
	_dialog_keys = Label.new()
	_style_label(_dialog_keys, 16, Color(0.8, 0.74, 0.6))
	column.add_child(_dialog_keys)
	_dialog.hide()
	_layer.add_child(_dialog)

	_tracker = VBoxContainer.new()
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -330
	_tracker.offset_right = -20
	_tracker.offset_top = 90
	_tracker.add_theme_constant_override("separation", 4)
	_layer.add_child(_tracker)


func _refresh_tracker() -> void:
	for child in _tracker.get_children():
		_tracker.remove_child(child)
		child.queue_free()
	for id: StringName in JOBS:
		var s := int(state[id])
		if s != State.TAKEN and s != State.DONE:
			continue
		var info: Dictionary = JOBS[id]
		var line := Label.new()
		if s == State.TAKEN:
			line.text = "%s   %d/%d" % [info["title"], progress[id], info["count"]]
			_style_label(line, 17, Color(0.95, 0.92, 0.84))
		else:
			line.text = "%s   — return to %s" % [info["title"], String(info["giver"]).split(" ")[0]]
			_style_label(line, 17, Color(0.62, 0.95, 0.5))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_tracker.add_child(line)


static func _style_label(label: Label, size: int, colour: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
#endregion
