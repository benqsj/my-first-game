class_name SkillBook
extends CanvasLayer

## Which of his skills go in the four sockets (the user's word, 2026-10-07: the
## elf has five, and the player picks four). K opens it over the skill bar:
## every skill he has in a row, each with its name, and under them the four
## sockets as they are. Click a skill and then a socket (or a socket and then a
## skill) to put it there; if it was in another socket, what was in this one
## goes to that one. K or Esc closes it. Kept between games
## ([method Player.set_skill_slot]).

const ICON := 66.0
const GAP := 18.0
const NAME_H := 26.0
const PAD := 26.0
const GOLD := Color(1.0, 0.82, 0.4)

var player: Player

var _root: Control
## What is chosen and waiting for its other half: a skill (>= 0) or a socket.
var _picked_skill: int = -1
var _picked_slot: int = -1
var _hover := Vector2(-1, -1)


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.draw.connect(_draw_book)
	_root.gui_input.connect(_on_gui)
	add_child(_root)


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	_picked_skill = -1
	_picked_slot = -1
	player.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	_root.queue_redraw()


func _input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_K:
		# not over another window that has the mouse
		if _root.visible or not player.menu_open:
			toggle()
			get_viewport().set_input_as_handled()
		return
	if _root.visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


## Where everything is: the panel, each skill's square, each socket's.
func _layout() -> Dictionary:
	var all := player.skill_choices()
	var n := maxi(all.size(), Player.SKILL_SLOTS)
	var row := ICON * n + GAP * (n - 1)
	var w := row + PAD * 2.0
	var h := PAD + 30.0 + ICON + NAME_H + 22.0 + ICON + PAD
	var view := _root.size
	var panel := Rect2(Vector2((view.x - w) * 0.5, view.y - 140.0 - h), Vector2(w, h))
	var skills: Array[Rect2] = []
	var x0 := panel.position.x + PAD + (row - (ICON * all.size() + GAP * maxi(all.size() - 1, 0))) * 0.5
	var y1 := panel.position.y + PAD + 30.0
	for i in all.size():
		skills.append(Rect2(Vector2(x0 + (ICON + GAP) * i, y1), Vector2(ICON, ICON)))
	var slots: Array[Rect2] = []
	var srow := ICON * Player.SKILL_SLOTS + GAP * (Player.SKILL_SLOTS - 1)
	var x1 := panel.position.x + (w - srow) * 0.5
	var y2 := y1 + ICON + NAME_H + 22.0
	for i in Player.SKILL_SLOTS:
		slots.append(Rect2(Vector2(x1 + (ICON + GAP) * i, y2), Vector2(ICON, ICON)))
	return {"panel": panel, "skills": skills, "slots": slots, "all": all}


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = (event as InputEventMouseMotion).position
		_root.queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var lay := _layout()
	var all: PackedStringArray = lay["all"]
	for i in (lay["skills"] as Array).size():
		if (lay["skills"][i] as Rect2).has_point(click.position):
			if _picked_slot >= 0:
				player.set_skill_slot(_picked_slot, StringName(all[i]))
				_picked_slot = -1
			else:
				_picked_skill = -1 if _picked_skill == i else i
			_root.queue_redraw()
			return
	for s in (lay["slots"] as Array).size():
		if (lay["slots"][s] as Rect2).has_point(click.position):
			if _picked_skill >= 0:
				player.set_skill_slot(s, StringName(all[_picked_skill]))
				_picked_skill = -1
			else:
				_picked_slot = -1 if _picked_slot == s else s
			_root.queue_redraw()
			return
	_picked_skill = -1
	_picked_slot = -1
	_root.queue_redraw()


func _draw_book() -> void:
	if player == null or not is_instance_valid(player):
		return
	var lay := _layout()
	var panel: Rect2 = lay["panel"]
	var all: PackedStringArray = lay["all"]
	var title := UiArt.font("title")
	var body := UiArt.font("body")
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.35))
	UiArt.draw_frame(_root, panel, "panel", 30.0)
	_root.draw_string(title, Vector2(panel.position.x, panel.position.y + PAD + 8.0), "Skills",
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, GOLD)
	var on := player.skill_choices()
	var socketed: Array = []
	for s in Player.SKILL_SLOTS:
		socketed.append(player.skill_in(s))
	for i in all.size():
		var r: Rect2 = lay["skills"][i]
		var id := StringName(all[i])
		var lit := _picked_skill == i or r.has_point(_hover)
		UiArt.draw_frame(_root, r.grow(3.0), "socket_lit" if lit else "socket", 8.0)
		_draw_icon(id, r, 1.0 if socketed.has(id) else 0.55)
		if _picked_skill == i:
			_root.draw_rect(r.grow(4.0), GOLD, false, 2.5)
		var label := String(Player.SKILLS[id]["name"])
		_root.draw_string(body, Vector2(r.position.x - GAP * 0.5, r.end.y + 19.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, ICON + GAP, 14, Color(1, 0.95, 0.85, 1.0 if socketed.has(id) else 0.6))
	for s in Player.SKILL_SLOTS:
		var r: Rect2 = lay["slots"][s]
		var lit := _picked_slot == s or r.has_point(_hover)
		UiArt.draw_frame(_root, r.grow(3.0), "socket_lit" if lit else "socket", 8.0)
		var id: StringName = socketed[s]
		if id != &"":
			_draw_icon(id, r, 1.0)
		if _picked_slot == s:
			_root.draw_rect(r.grow(4.0), GOLD, false, 2.5)
	var hint := "Pick a skill, then a socket" if on.size() > 0 else "No skills"
	if _picked_skill >= 0:
		hint = "Now the socket for %s" % String(Player.SKILLS[StringName(all[_picked_skill])]["name"])
	elif _picked_slot >= 0:
		hint = "Now the skill for this socket"
	_root.draw_string(body, Vector2(panel.position.x, panel.end.y + 22.0), hint + "   ·   K closes",
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, Color(1, 1, 1, 0.75))


func _draw_icon(id: StringName, rect: Rect2, alpha: float) -> void:
	var inner := rect.grow(-3.0)
	var tex := UiArt.icon("skill_" + String(id))
	if tex != null:
		_root.draw_texture_rect(tex, inner, false, Color(1, 1, 1, alpha))
	elif player._hud != null and is_instance_valid(player._hud):
		player._hud.draw_icon_on(_root, id, rect)
		if alpha < 1.0:
			_root.draw_rect(inner, Color(0, 0, 0, 1.0 - alpha))
