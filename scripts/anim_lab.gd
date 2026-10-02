extends Node3D
## The animation lab: the two packs we bought side by side with what the
## heroes play now, one move at a time, to pick which one each hero gets.
##
## Three figures in Polysplit's clothes, each with the arms of the set shown:
##   1. Kevin Iglesias' Human Melee Animations, on the UAL 2 mannequin
##      (assets/anim/lab/kevin_lib.res, vepxis-art tools/kv_godot.gd)
##   2. Quaternius' UAL 2, on its own mannequin, as made
##      (assets/anim/lab/ual2_mannequin.glb)
##   3. the hero as he is now: his own rig and Mixamo clips, wearing YOUR OWN
## The two mannequins wear the figure built onto the mannequin's limbs
## (assets/polysplit/mannequin_m.glb).
##
## The moves come in sets by what is held (MOVING, SWORD AND SHIELD, TWO
## HANDS, TWO KNIVES, BOW, SPEAR). Keys: Left/Right a move, Up/Down a set,
## 1/2/3 pick that column's for the move (kept in assets/anim/lab/picks.json),
## Space pause, -/= slower/faster, R the move again. The buttons on screen do
## the same.
##
##   Godot --path . res://scenes/tools/anim_lab.tscn
##   ... --write-movie <file>.avi --fixed-fps 30 -- movie [set index]

const KEVIN := "res://assets/anim/lab/kevin_lib.res"
const UAL := "res://assets/anim/lab/ual2_mannequin.glb"
const FIGURE := "res://assets/polysplit/mannequin_m.glb"
const PICKS := "res://assets/anim/lab/picks.json"
const COLUMNS := ["KEVIN IGLESIAS", "QUATERNIUS UAL 2", "NOW (MIXAMO)"]
const SPACING := 2.3

## set -> {"hero": the rig shown in the third column, "look": what all three
## hold ([PolysplitLook]), "moves": [name, [kevin clips], [ual clips], [now
## clips], seconds]}. A clip list plays through, the last looping; [] = the
## pack has nothing for it. "Now" clips are the rig's own: "c:<key>" its clip
## table, "f:<n>" its string's n-th blow, "h:<n>" its n-th heavy one.
const SETS := [
	{"name": "MOVING", "hero": &"tariel", "look": {"cls": "swordsman", "w": "sword_a", "o": "none"}, "moves": [
		["STANDING", ["KV_Idle01"], ["Idle_FoldArms_Loop"], ["c:idle"], 4.0],
		["WALK", ["KV_Walk01_Forward"], ["Walk_Fwd_Loop"], ["c:walk"], 4.0],
		["RUN", ["KV_Run01_Forward"], [], ["c:run"], 4.0],
		["SPRINT", ["KV_Sprint01_Forward"], ["Sprint_Shield_Loop"], ["c:sprint"], 4.0],
		["RUN LEFT", ["KV_StrafeRun01_Left"], ["Walk_L_Loop"], ["c:run_left"], 3.5],
		["RUN BACK", ["KV_Run01_Backward"], ["Walk_Bwd_Loop"], ["c:run_back"], 3.5],
		["DODGE", ["KV_Dodge01"], ["Sword_Dash"], ["c:roll"], 3.0],
		["JUMP", [], ["NinjaJump_Start", "NinjaJump_Idle_Loop", "NinjaJump_Land"], ["c:air"], 3.5],
		["CLIMB UP", [], ["ClimbUp_1m"], ["c:mantle"], 3.0],
		["HIT", ["KV_CombatDamage01"], ["Hit_Knockback"], ["c:hit"], 2.5],
		["DEATH", ["KV_Death01"], [], ["c:down"], 3.5],
	]},
	{"name": "SWORD AND SHIELD", "hero": &"tariel", "look": {"cls": "swordsman", "w": "sword_a", "o": "shield"}, "moves": [
		["ON GUARD", ["KV_CombatIdle1H01"], ["Idle_Shield_Loop"], ["c:idle"], 3.5],
		["CUT 1", ["KV_Attack1H01_R"], ["Sword_Regular_A", "Sword_Regular_A_Rec"], ["f:0"], 2.6],
		["CUT 2", ["KV_Attack1H02_R"], ["Sword_Regular_B", "Sword_Regular_B_Rec"], ["f:1"], 2.6],
		["CUT 3", ["KV_Attack1H03_R"], ["Sword_Regular_C"], ["f:2"], 2.8],
		["COMBO", ["KV_Attack1H01_R", "KV_Attack1H02_R", "KV_Attack1H03_R", "KV_Attack1H04_R"],
				["Sword_Regular_Combo"], ["f:0", "f:1", "f:2", "f:3"], 5.0],
		["HEAVY BLOW", ["KV_Attack1H05_R"], ["Sword_Heavy_Combo"], ["h:0"], 4.5],
		["BLOCK", ["KV_BlockShield01_Loop"], ["Sword_Block"], ["c:block_idle"], 3.0],
		["BLOCK, HIT", ["KV_BlockShield01_Hit"], ["Idle_Shield_Break"], ["c:hit_blocked"], 2.5],
		["SHIELD BASH", ["KV_AttackShield01"], ["Shield_OneShot"], [], 2.6],
		["SWORD DRAWN", ["KV_UnsheatheHips01_R"], [], [], 2.6],
	]},
	{"name": "TWO HANDS", "hero": &"warrior", "look": {"cls": "knight", "w": "greatsword", "o": "none"}, "moves": [
		["ON GUARD", ["KV_CombatIdle2H01"], ["Idle_Shield_Loop"], ["c:idle"], 3.5],
		["CUT 1", ["KV_Attack2H01"], ["Sword_Heavy_A", "Sword_Heavy_A_Rec"], ["f:0"], 3.0],
		["CUT 2", ["KV_Attack2H02"], ["Sword_Heavy_B", "Sword_Heavy_B_Rec"], ["f:1"], 3.0],
		["CUT 3", ["KV_Attack2H03"], ["Sword_Heavy_C", "Sword_Heavy_C_Rec"], ["f:2"], 3.0],
		["CUT 4", ["KV_Attack2H04"], ["Sword_Heavy_D"], ["f:3"], 3.2],
		["PARRY", ["KV_Parry2H01_Loop"], ["Sword_Block"], ["c:block_idle"], 3.0],
		["SLAM", [], ["Sword_GroundPound"], ["h:1"], 3.2],
	]},
	{"name": "TWO KNIVES", "hero": &"rogue", "look": {"cls": "rogue", "w": "dagger", "o": "dagger"}, "moves": [
		["ON GUARD", ["KV_CombatIdle1H01"], ["Idle_Shield_Loop"], ["c:idle"], 3.5],
		["STAB 1", ["KV_AttackDW01"], ["Sword_Light_A", "Sword_Light_A_Rec"], ["f:0"], 2.6],
		["STAB 2", ["KV_AttackDW02"], ["Sword_Light_B", "Sword_Light_B_Rec"], ["f:1"], 2.6],
		["COMBO", ["KV_AttackDW01", "KV_AttackDW02"], ["Sword_Light_Combo"], ["f:0", "f:1", "f:2", "f:3"], 5.0],
		["PARRY", ["KV_ParryDW01_Loop"], ["Sword_Block"], ["c:block_idle"], 3.0],
		["ONE KNIFE", ["KV_Attack1H01_R", "KV_Attack1H02_R"], ["Sword_Light_C"], ["h:0"], 3.5],
	]},
	{"name": "BOW", "hero": &"avtandil", "look": {"cls": "hunter", "w": "bow", "o": "none"}, "moves": [
		["NOCK", [], ["Bow_Notch"], ["AV_Nock_Draw"], 3.0],
		["AIM", [], ["Bow_Aim_Neutral"], ["c:aim_walk"], 3.0],
		["AIM HIGH", [], ["Bow_Aim_Up"], ["AV_Sky_Shot"], 3.0],
		["SHOOT", [], ["Bow_Shoot"], ["AV_Shooting_Arrow"], 2.5],
		["RAPID", [], ["Bow_RapidShoot_Loop"], [], 3.0],
	]},
	{"name": "SPEAR (A STAFF FOR NOW)", "hero": &"mage", "look": {"cls": "mage", "w": "staff_a", "o": "none"}, "moves": [
		["ON GUARD", ["KV_CombatIdlePolearm01"], [], ["c:idle"], 3.5],
		["THRUST 1", ["KV_AttackPolearm01"], [], [], 3.0],
		["THRUST 2", ["KV_AttackPolearm02"], [], [], 3.0],
		["SWEEP", ["KV_AttackPolearm03"], [], [], 3.0],
		["SPIN", ["KV_AttackPolearm04"], [], [], 3.2],
		["PARRY", ["KV_ParryPolearm01_Loop"], [], ["c:block_idle"], 3.0],
	]},
]
const HEROES := {
	&"tariel": "res://scenes/player/tariel_rigged_visuals.tscn",
	&"warrior": "res://scenes/player/warrior_rigged_visuals.tscn",
	&"rogue": "res://scenes/player/rogue_rigged_visuals.tscn",
	&"avtandil": "res://scenes/player/avtandil_rigged_visuals.tscn",
	&"mage": "res://scenes/player/mage_rigged_visuals.tscn",
}

var _set := 0
var _move := 0
var _move_t := 0.0
var _speed := 1.0
var _paused := false
var _movie := false
var _picks: Dictionary = {}
## Per column: {"player", "queue": [clips], "label"}.
var _cols: Array[Dictionary] = []
var _mannequins: Array[Node3D] = []
var _figs: Array[Node3D] = []
var _hero: SkinnedRig
var _hero_body: Node3D
var _title: Label
var _move_label: Label
var _hint: Label
var _pick_buttons: Array[Button] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_movie = args.size() > 0 and args[0] == "movie"
	if _movie and args.size() > 1:
		_set = clampi(int(args[1]), 0, SETS.size() - 1)
	_load_picks()
	_stage()
	var kevin := load(KEVIN) as AnimationLibrary
	for i in 2:
		var man := (load(UAL) as PackedScene).instantiate() as Node3D
		man.position = Vector3((i - 1) * SPACING, 0, 0)
		add_child(man)
		var skel := man.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
		for mesh: MeshInstance3D in man.find_children("*", "MeshInstance3D", true, false):
			mesh.visible = false
		var player := man.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
		if i == 0:
			player.add_animation_library(&"kv", kevin)
		var fig := (load(FIGURE) as PackedScene).instantiate() as Node3D
		man.add_child(fig)
		var fskel := fig.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
		var map := SkinnedRig.polysplit_map({})
		map[&"chest_joint"] = &"spine_03"
		map[&"head_joint"] = &"Head"
		var follow := FigureFollower.new()
		fig.add_child(follow)
		if not follow.setup(skel, fskel, map, &"pelvis_joint"):
			push_warning("anim_lab: the figure does not follow the mannequin.")
		_mannequins.append(man)
		_figs.append(fig)
		_cols.append({"player": player, "queue": [], "prefix": "kv/" if i == 0 else ""})
		player.animation_finished.connect(_on_finished.bind(i))
	_cols.append({"player": null, "queue": [], "prefix": ""})
	_ui()
	_show_set(_set)


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.78, 0.78, 0.84)
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 10)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.34)
	ground.material_override = mat
	add_child(ground)
	for i in 3:
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.005, 2.6)
		line.mesh = box
		line.position = Vector3((i - 1) * SPACING + SPACING * 0.5, 0.003, 0)
		line.visible = i < 2
		add_child(line)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.75, 7.2)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("separation", 2)
	layer.add_child(top)
	_title = _label(30, Color("ece4d6"))
	top.add_child(_title)
	_move_label = _label(44, Color("f2c27a"))
	top.add_child(_move_label)
	var heads := HBoxContainer.new()
	heads.anchor_left = 0.0
	heads.anchor_right = 1.0
	heads.anchor_top = 1.0
	heads.anchor_bottom = 1.0
	heads.offset_top = -118
	heads.offset_bottom = -12
	heads.add_theme_constant_override("separation", 0)
	layer.add_child(heads)
	for i in 3:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := _label(22, Color("ece4d6"))
		head.text = COLUMNS[i]
		col.add_child(head)
		var state := _label(18, Color("d0a044"))
		col.add_child(state)
		_cols[i]["label"] = state
		var pick := Button.new()
		pick.text = "PICK  [%d]" % (i + 1)
		pick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pick.custom_minimum_size = Vector2(150, 34)
		pick.pressed.connect(_pick.bind(i))
		pick.visible = not _movie
		col.add_child(pick)
		_pick_buttons.append(pick)
		heads.add_child(col)
	_hint = _label(15, Color(0.75, 0.75, 0.8))
	_hint.text = "← → move    ↑ ↓ set    1 2 3 pick    space pause    - = speed    R again"
	_hint.visible = not _movie
	top.add_child(_hint)


func _label(size: int, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _show_set(index: int) -> void:
	_set = wrapi(index, 0, SETS.size())
	var spec: Dictionary = SETS[_set]
	var look := PolysplitLook.dress(PolysplitLook.default_look(&"tariel", "m"), &"tariel", spec["look"]["cls"])
	for key: String in spec["look"]:
		look[key] = spec["look"][key]
	for fig in _figs:
		PolysplitLook.apply(fig, look)
	_put_hero(spec["hero"], spec["look"])
	_show_move(0)


## The third column: the hero the set is his, as he plays now, in YOUR OWN
## with the set's arms.
func _put_hero(id: StringName, wanted: Dictionary) -> void:
	if _hero_body != null:
		_hero_body.queue_free()
	_hero_body = Node3D.new()
	_hero_body.position = Vector3(SPACING, 0, 0)
	# the visuals face +Z under a body facing -Z: turned to the camera
	_hero_body.rotation.y = PI
	add_child(_hero_body)
	_hero = (load(HEROES[id]) as PackedScene).instantiate() as SkinnedRig
	var look := PolysplitLook.default_look(id, "m")
	look = PolysplitLook.dress(look, id, PolysplitLook.classes(id, "m")[0])
	for key: String in ["w", "o"]:
		if (PolysplitLook.ARMS[id][key] as Array).has(String(wanted[key])):
			look[key] = wanted[key]
	_hero.ps_look = look
	_hero_body.add_child(_hero)
	_hero.set_face(_hero.faces.find(SkinnedRig.CUSTOM))
	# the lab plays his clips itself
	_hero.set_process(false)
	_hero.set_physics_process(false)
	var player := _hero._anim
	_cols[2]["player"] = player
	if not player.animation_finished.is_connected(_on_finished):
		player.animation_finished.connect(_on_finished.bind(2))


func _show_move(index: int) -> void:
	var moves: Array = SETS[_set]["moves"]
	_move = wrapi(index, 0, moves.size())
	_move_t = 0.0
	var move: Array = moves[_move]
	_title.text = "%s   ·   %d / %d" % [SETS[_set]["name"], _move + 1, moves.size()]
	_move_label.text = move[0]
	for i in 3:
		var queue: Array = []
		for c: String in move[i + 1]:
			var clip := _resolve(i, c)
			if clip != &"":
				queue.append(clip)
		_cols[i]["queue"] = queue
		var picked: bool = _picks.get(SETS[_set]["name"], {}).get(move[0], -1) == i
		var state := _cols[i]["label"] as Label
		if queue.is_empty():
			state.text = "NOT IN THIS PACK"
			state.add_theme_color_override("font_color", Color("d9705a"))
		else:
			state.text = ("★ PICKED   " if picked else "") + String(queue[0]).trim_prefix("kv/")
			state.add_theme_color_override("font_color", Color("7fd06a") if picked else Color("d0a044"))
		_play_next(i, true)


## A clip name as column `col`'s player knows it ("" if it has not got it).
func _resolve(col: int, spec: String) -> StringName:
	if col < 2:
		var player := _cols[col]["player"] as AnimationPlayer
		# (Godot's glb import takes a "_Loop" off a clip's name, and loops it)
		for n: String in [spec, spec.trim_suffix("_Loop")]:
			var clip_name := StringName(String(_cols[col]["prefix"]) + n)
			if player.has_animation(clip_name):
				return clip_name
		return &""
	if _hero == null:
		return &""
	var clip: StringName = StringName(spec)
	if spec.begins_with("c:"):
		clip = _hero.clips.get(StringName(spec.substr(2)), &"")
	elif spec.begins_with("f:"):
		var n := int(spec.substr(2))
		clip = _hero.flurry[n] if n < _hero.flurry.size() else &""
	elif spec.begins_with("h:"):
		var n := int(spec.substr(2))
		clip = (_hero.heavy[n] as Dictionary)["clip"] if n < _hero.heavy.size() else &""
	return clip if clip != &"" and _hero._anim.has_animation(clip) else &""


func _play_next(col: int, _first: bool = false) -> void:
	var player := _cols[col]["player"] as AnimationPlayer
	if player == null:
		return
	var queue: Array = _cols[col]["queue"]
	if queue.is_empty():
		# nothing to show: the column stands at rest
		player.stop()
		if col < 2:
			(_mannequins[col].find_children("*", "Skeleton3D", true, false).front() as Skeleton3D).reset_bone_poses()
		return
	player.play(queue[0], 0.12)
	player.speed_scale = 0.0 if _paused else _speed


## A clip has ended: the next in the list, or the last again.
func _on_finished(_clip: StringName, col: int) -> void:
	var queue: Array = _cols[col]["queue"]
	if queue.size() > 1:
		queue.pop_front()
	_play_next(col)


func _process(delta: float) -> void:
	if _paused:
		return
	_move_t += delta * _speed
	var move: Array = SETS[_set]["moves"][_move]
	if _move_t >= float(move[4]) * (2.0 if not _movie else 1.0):
		if _movie:
			if _move + 1 >= (SETS[_set]["moves"] as Array).size():
				get_tree().quit()
				return
			_show_move(_move + 1)
		else:
			_show_move(_move)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			_show_move(_move + 1)
		KEY_LEFT:
			_show_move(_move - 1)
		KEY_DOWN:
			_show_set(_set + 1)
		KEY_UP:
			_show_set(_set - 1)
		KEY_1, KEY_2, KEY_3:
			_pick(key.keycode - KEY_1)
		KEY_SPACE:
			_paused = not _paused
			for c in _cols:
				if c["player"] != null:
					(c["player"] as AnimationPlayer).speed_scale = 0.0 if _paused else _speed
		KEY_MINUS:
			_set_speed(_speed * 0.5)
		KEY_EQUAL:
			_set_speed(_speed * 2.0)
		KEY_R:
			_show_move(_move)


func _set_speed(to: float) -> void:
	_speed = clampf(to, 0.125, 2.0)
	for c in _cols:
		if c["player"] != null:
			(c["player"] as AnimationPlayer).speed_scale = _speed


## Keeps column `col`'s clips as the pick for this move.
func _pick(col: int) -> void:
	var group: String = SETS[_set]["name"]
	var move: Array = SETS[_set]["moves"][_move]
	if (move[col + 1] as Array).is_empty():
		return
	var chosen: Dictionary = _picks.get(group, {})
	chosen[move[0]] = col
	_picks[group] = chosen
	var file := FileAccess.open(PICKS, FileAccess.WRITE)
	if file != null:
		var out := {}
		for s: String in _picks:
			out[s] = {}
			for m: String in _picks[s]:
				var i := int(_picks[s][m])
				out[s][m] = {"column": COLUMNS[i], "clips": _clips_of(s, m, i)}
		file.store_string(JSON.stringify(out, "\t"))
	_show_move(_move)


func _clips_of(group: String, move_name: String, col: int) -> Array:
	for spec: Dictionary in SETS:
		if spec["name"] == group:
			for move: Array in spec["moves"]:
				if move[0] == move_name:
					return move[col + 1]
	return []


func _load_picks() -> void:
	if not FileAccess.file_exists(PICKS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKS))
	if not parsed is Dictionary:
		return
	for s: String in parsed:
		_picks[s] = {}
		for m: String in parsed[s]:
			_picks[s][m] = COLUMNS.find(String(parsed[s][m]["column"]))
