class_name Inventory
extends CanvasLayer

## The bag, opened with **I**: what he carries, what each thing is worth, and
## where he stands — laid out as Elden Ring lays its own out.
##
## * **Left**, the things themselves: tabs along the top (weapons, shields,
##   goods), a grid of them below, the chosen one ringed in gold.
## * **Middle**, the chosen one: its name, what kind of thing it is, what it is
##   worth — attack, critical hits, what blocking with it costs — and a line
##   on it.
## * **Right**, the character: health, stamina, what his blows are worth, how
##   fast and how far he goes, and what is in his hands.
##
## Everything shown is read off the character's profile and the controller, so
## the numbers are the ones the game plays with. The world does not stop while
## it is open — the game may be online — so the body just stands
## ([member Player.menu_open]).
##
## The arrow keys or the mouse move the choice, Q / E the tab, Enter or a click
## puts on what can be put on (a shield, an outfit), I or Escape closes.

enum Shields { ROUND, TOWER }
enum Tab { WEAPONS, SHIELDS, GOODS, ATTIRE }

const TAB_NAMES := ["Weapons", "Shields", "Goods", "Attire"]
## The outfits, by the name of their mesh in the model (the rig's `garbs`).
const GARBS := {
	&"avtandil_ranger": {"name": "Ranger's Mantle", "kind": "Hooded mantle", "colour": Color("3f5a3a"),
		"stats": [["Cloth", "wool"], ["Hood", "up"], ["Length", "mid-thigh"]],
		"text": "A grey-green tunic to mid-thigh under a long mantle of moss wool, its hood up. The hunter's own: it keeps the rain off and the face in shadow."},
	&"avtandil_wanderer": {"name": "Wanderer's Kaftan", "kind": "Kaftan and cowl", "colour": Color("6a6438"),
		"stats": [["Cloth", "wool"], ["Hood", "deep cowl"], ["Length", "mid-calf"]],
		"text": "An olive kaftan to mid-calf wrapped across the chest, bound with a crimson sash, a deep brown cowl drawn forward over the face. For the long roads."},
	&"tariel_vk_berserker": {"name": "Berserker's Harness", "kind": "Jerkin and bear fur", "colour": Color("5a4130"),
		"stats": [["Chest", "bare"], ["Mantle", "bear fur"], ["Arms", "gold rings"]],
		"text": "Bare-chested under a leather jerkin open to the belt, a great bear's fur over the shoulders, gold rings on the bare arms, the shins bound."},
	&"tariel_vk_tunic": {"name": "Norse Tunic", "kind": "Tunic and fur", "colour": Color("3e5566"),
		"stats": [["Cloth", "wool"], ["Band", "woven, red and gold"], ["Mantle", "grey fur"]],
		"text": "A blue-grey wool tunic to the knee, a woven band of red and gold at the hem and the neck, long sleeves, a grey fur mantle pinned in gold."},
	&"tariel_vk_mail": {"name": "Mail Shirt", "kind": "Mail and fur", "colour": Color("8d939b"),
		"stats": [["Mail", "to the thigh"], ["Arms", "bound, silver rings"], ["Mantle", "short fur"]],
		"text": "A mail shirt to the thigh, mail over the upper arms, the forearms bare and bound, silver rings, a short fur mantle and the leather guard."},
	&"tariel_vk_warrior": {"name": "Warrior's Tunic", "kind": "Tunic and wraps", "colour": Color("5e2c20"),
		"stats": [["Cloth", "wool"], ["Arms", "bare, bound in linen"], ["Shoulder", "leather guard"]],
		"text": "A sleeveless tunic of earth red to above the knee, the arms bare and bound in white linen, a leather guard on the left shoulder and a baldric across the chest."},
	&"tariel_vk_warrior_slate": {"name": "Warrior's Tunic, Slate", "kind": "Tunic and wraps", "colour": Color("2c3a3e"),
		"stats": [["Cloth", "wool"], ["Arms", "bare, bound in linen"], ["Sash", "crimson"]],
		"text": "The warrior's cut in slate blue edged in crimson, a crimson sash at the waist."},
	&"tariel_vk_warrior_hide": {"name": "Panther's Tunic", "kind": "Tunic and wraps", "colour": Color("b9772d"),
		"stats": [["Hide", "panther"], ["Arms", "bare, bound in linen"], ["Shoulder", "leather guard"]],
		"text": "The warrior's tunic cut from the panther's hide itself."},
	&"rogue_sand_shorts": {"name": "Dune Runner", "kind": "Loose top and breeches", "colour": Color("a08c69"),
		"stats": [["Cloth", "linen"], ["Hood", "up, scarf over the mouth"], ["Legs", "breeches, wrapped"]],
		"text": "A loose sand top with short sleeves, bloused over the belt; brown breeches cut above the knee, the legs wrapped. Light, for running."},
	&"rogue_shade_shorts": {"name": "Shade Runner", "kind": "Loose top and breeches", "colour": Color("1b1b20"),
		"stats": [["Cloth", "linen"], ["Hood", "up"], ["Legs", "breeches, wrapped"]],
		"text": "The runner's cut in black, edged in red, a red scarf at the mouth and its tail loose behind."},
	&"rogue_ash_shorts": {"name": "Ash Runner", "kind": "Loose top and breeches", "colour": Color("8d948f"),
		"stats": [["Cloth", "linen"], ["Hood", "up"], ["Legs", "breeches, wrapped"]],
		"text": "The runner's cut in ash grey over black breeches, a black scarf at the mouth."},
	&"rogue_wraith_red": {"name": "Wraith's Coat, Red", "kind": "Coat and cowl", "colour": Color("1b1b20"),
		"stats": [["Cloth", "wool"], ["Hood", "pointed cowl"], ["Cape", "long"]],
		"text": "A black coat below the knee, wrapped across the chest and buttoned in silver, edged in red; a pointed cowl and a long black cloak."},
	&"rogue_nightblade": {"name": "Nightblade", "kind": "Coat and hood", "colour": Color("2b3142"),
		"stats": [["Cloth", "wool"], ["Hood", "up"], ["Cape", "short"]],
		"text": "A night-blue coat to the knee, open over the leather vest, crimson at every edge; a hood and a short cape."},
	&"rogue_crimson": {"name": "Crimson Hood", "kind": "Coat and hood", "colour": Color("701823"),
		"stats": [["Cloth", "wool"], ["Hood", "dagged capelet"], ["Cape", "short"]],
		"text": "A black-plum coat to mid-thigh under a crimson hood, its capelet cut in points, and a short crimson cape."},
	&"rogue_wraith_white": {"name": "Wraith's Coat, White", "kind": "Coat and cowl", "colour": Color("e3ded2"),
		"stats": [["Cloth", "wool"], ["Hood", "pointed cowl"], ["Cape", "long"]],
		"text": "The wraith's black coat and cowl edged in ivory, and a long black cloak with an ivory hem."},
	&"rogue_sandstrider": {"name": "Sandstrider", "kind": "Coat and hood", "colour": Color("a08c69"),
		"stats": [["Cloth", "leather and wool"], ["Hood", "up, scarf over the mouth"], ["Cape", "none"]],
		"text": "A leather-brown coat to the shin, split at the sides; a sand hood and a scarf wound over the mouth against the dust."},
	&"mage_storm": {"name": "Storm Robe", "kind": "Robe and hood", "colour": Color("22305a"),
		"stats": [["Cloth", "wool"], ["Hood", "up"], ["Runes", "at the hem"]],
		"text": "A deep blue robe to the ankles edged in silver, a band of glowing runes at the hem and the sleeves, a hood with a capelet."},
	&"mage_ember": {"name": "Ember Robe", "kind": "Robe and cowl", "colour": Color("8e1222"),
		"stats": [["Cloth", "wool"], ["Hood", "deep, pointed"], ["Sash", "crimson"]],
		"text": "A black robe edged in red, a crimson sash, a deep pointed hood; violet runes at the hem."},
	&"mage_sage": {"name": "Sage's Robe", "kind": "Robe and mantle", "colour": Color("ddd6c6"),
		"stats": [["Cloth", "linen"], ["Hat", "papakha"], ["Mantle", "gold-hemmed"]],
		"text": "An ivory robe edged in gold under a short mantle cut in points; the old papakha on his head."},
	&"mage_wine": {"name": "Wine Robe", "kind": "Robe and mantle", "colour": Color("5e1422"),
		"stats": [["Cloth", "wool"], ["Hat", "papakha"], ["Runes", "gold"]],
		"text": "The old wine robe, now of cloth, edged and runed in gold, a mantle over the shoulders and the papakha."},
}
const GOLD := Color("d0a044")
const GOLD_DIM := Color("8a6a2c")
const CREAM := Color("ece4d6")
const MUTED := Color(0.72, 0.68, 0.6)
const SLOT := Vector2(78, 78)
const COLUMNS := 5

var player: Player

var _root: Control
var _tab: int = Tab.WEAPONS
var _chosen: int = 0
var _slots_rect: Rect2
var _tabs_rect: Rect2


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_all)
	_root.gui_input.connect(_on_gui)
	add_child(_root)


#region Opening, and choosing
func _input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
	elif event is InputEventKey and event.pressed and not event.echo:
		var items := _items()
		match (event as InputEventKey).physical_keycode:
			KEY_LEFT, KEY_A:
				_chosen = maxi(_chosen - 1, 0)
			KEY_RIGHT, KEY_D:
				_chosen = mini(_chosen + 1, maxi(items.size() - 1, 0))
			KEY_UP, KEY_W:
				_chosen = maxi(_chosen - COLUMNS, 0)
			KEY_DOWN, KEY_S:
				_chosen = mini(_chosen + COLUMNS, maxi(items.size() - 1, 0))
			KEY_Q:
				_switch_tab(_tab - 1)
			KEY_E:
				_switch_tab(_tab + 1)
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				_use(_chosen)
			KEY_1:
				equip(Shields.ROUND)
			KEY_2:
				equip(Shields.TOWER)
	else:
		return
	get_viewport().set_input_as_handled()
	_root.queue_redraw()


func _on_gui(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var at := (event as InputEventMouseButton).position
	if _tabs_rect.has_point(at):
		_switch_tab(int((at.x - _tabs_rect.position.x) / (_tabs_rect.size.x / TAB_NAMES.size())))
	elif _slots_rect.has_point(at):
		var cell := ((at - _slots_rect.position) / (SLOT + Vector2(8, 8))).floor()
		var i := int(cell.y) * COLUMNS + int(cell.x)
		if i < _items().size():
			if i == _chosen or (event as InputEventMouseButton).double_click:
				_use(i)
			_chosen = i
	_root.queue_redraw()


func _switch_tab(to: int) -> void:
	_tab = wrapi(to, 0, TAB_NAMES.size())
	_chosen = 0


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	player.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	_root.queue_redraw()


func equip(kind: int) -> void:
	if player == null or not _has_shield():
		return
	player.set_shield(kind)
	_root.queue_redraw()


func _use(i: int) -> void:
	var items := _items()
	if i < 0 or i >= items.size():
		return
	var item: Dictionary = items[i]
	if item.has("shield"):
		equip(int(item.shield))
	elif item.has("garb"):
		player.set_garb(int(item.garb))
		_root.queue_redraw()


## The outfits his model carries (the rig's `garbs`); empty for a hero with one.
func _garbs() -> Array:
	if player.rig == null:
		return []
	var list: Variant = player.rig.get(&"garbs")
	return list if list is Array else []


func _has_shield() -> bool:
	return player.profile != null and player.profile.can_block
#endregion


#region What he has
## The things under the open tab, each a dictionary: name, kind, icon, the
## lines of numbers, a line of text, and whether it is in his hands.
func _items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := player.profile
	if p == null:
		return out
	match _tab:
		Tab.WEAPONS:
			out.append(_weapon(p))
		Tab.SHIELDS:
			if _has_shield():
				out.append({
					"name": "Round Shield", "kind": "Small shield", "icon": "round", "shield": Shields.ROUND,
					"worn": player.shield_kind == Shields.ROUND,
					"stats": [["Guard", "100 %"], ["Stamina per blow", "× %.1f" % player.block_stamina]],
					"text": "Light and quick: up in an instant, and it goes with him wherever he turns.",
				})
				out.append({
					"name": "Tower Shield", "kind": "Greatshield", "icon": "tower", "shield": Shields.TOWER,
					"worn": player.shield_kind == Shields.TOWER,
					"stats": [["Guard", "100 %"],
							["Stamina per blow", "× %.1f" % (player.block_stamina * player.tower_block_share)],
							["Stance", "crouched"]],
					"text": "Tall, heavy, crimson, with the gold cross. A blow on it costs half as much to hold, and he crouches right down behind it.",
				})
		Tab.ATTIRE:
			var garbs := _garbs()
			for i in garbs.size():
				var info: Dictionary = GARBS.get(StringName(garbs[i]), {})
				out.append({
					"name": info.get("name", String(garbs[i])), "kind": info.get("kind", "Outfit"),
					"icon": "garb", "colour": info.get("colour", Color(0.4, 0.4, 0.35)), "garb": i,
					"worn": player.garb == i, "stats": info.get("stats", []), "text": info.get("text", ""),
				})
	return out


func _weapon(p: CharacterProfile) -> Dictionary:
	var worth := float(p.get("m_atk")) if p.weapon == CharacterProfile.Weapon.STAFF and "m_atk" in p else p.damage
	var crit := [["M.ATK" if p.weapon == CharacterProfile.Weapon.STAFF else "P.ATK", "%.0f" % worth], ["Critical chance", "%.0f %%" % (p.crit_chance * 100.0)],
			["Critical damage", "× %.1f" % p.crit_damage], ["Stamina per attack", "%.0f" % p.attack_stamina]]
	match p.weapon:
		CharacterProfile.Weapon.BOW:
			crit.append(["Full draw", "%.2f s" % p.draw_time])
			crit.append(["Arrow speed", "%.0f m/s" % p.arrow_speed])
			return {"name": "Hunter's Longbow", "kind": "Bow", "icon": "bow", "worn": true, "stats": crit,
					"text": "Avtandil's bow. Hold to draw, let go to loose: a tapped shot flies fast and light, a full draw lands for all of it."}
		CharacterProfile.Weapon.STAFF:
			crit.append(["Full charge", "%.2f s" % p.draw_time])
			crit.append(["Bolt speed", "%.0f m/s" % p.arrow_speed])
			return {"name": "Staff of the Storm", "kind": "Staff", "icon": "staff", "worn": true, "stats": crit,
					"text": "Hold to gather a bolt of lightning at the crystal, let go to throw it. Thrown at what he has locked on to, the bolt hunts it."}
	if p.display_name.to_lower().contains("rogue") or p.display_name.to_lower().contains("assassin"):
		return {"name": "Shadow Knife", "kind": "Dagger", "icon": "dagger", "worn": true, "stats": crit,
				"text": "A long knife, black-hilted, kept keen. Quick cuts, one after another, faster than anything can answer."}
	return {"name": "Tariel's Sword", "kind": "Straight sword", "icon": "sword", "worn": true, "stats": crit,
			"text": "The knight's sword. Cuts that chain into a flurry; thrown from a jump, it comes down and plants."}
#endregion


#region Drawing
func _draw_all() -> void:
	var c := _root
	var screen := c.size
	var font := ThemeDB.fallback_font
	# The world, darkened and cooled behind the menu.
	c.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.025, 0.03, 0.82))
	var band := Color(0.0, 0.0, 0.0, 0.35)
	c.draw_rect(Rect2(0, 0, screen.x, 64), band)
	c.draw_rect(Rect2(0, screen.y - 44, screen.x, 44), band)
	_bag_icon(c, Vector2(40, 32))
	c.draw_string(font, Vector2(66, 41), "Inventory", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, CREAM)
	c.draw_line(Vector2(24, 64), Vector2(screen.x - 24, 64), Color(GOLD_DIM, 0.6), 1.0)

	var left := Rect2(40, 90, SLOT.x * COLUMNS + 8 * (COLUMNS - 1) + 24, screen.y - 160)
	var right_w := 360.0
	var right := Rect2(screen.x - right_w - 40, 90, right_w, screen.y - 160)
	var middle := Rect2(left.end.x + 40, 90, right.position.x - left.end.x - 80, screen.y - 160)

	_draw_left(c, font, left)
	var items := _items()
	if _chosen < items.size():
		_draw_item(c, font, middle, items[_chosen])
	else:
		c.draw_string(font, middle.position + Vector2(0, 28), "Nothing here yet.", HORIZONTAL_ALIGNMENT_LEFT, -1,
				18, MUTED)
	_draw_status(c, font, right)

	var keys := "Arrows / mouse  choose      Q / E  tab      Enter  put on      I  close"
	c.draw_string(font, Vector2(40, screen.y - 16), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(CREAM, 0.7))


func _draw_left(c: Control, font: Font, box: Rect2) -> void:
	# Tabs.
	_tabs_rect = Rect2(box.position, Vector2(box.size.x, 40))
	var w := box.size.x / TAB_NAMES.size()
	for i in TAB_NAMES.size():
		var r := Rect2(box.position + Vector2(w * i, 0), Vector2(w - 4, 36))
		var on := i == _tab
		c.draw_rect(r, Color(0.16, 0.14, 0.1, 0.9) if on else Color(0.08, 0.08, 0.08, 0.7))
		if on:
			c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), GOLD)
		var tw := font.get_string_size(TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		c.draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, 24), TAB_NAMES[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD if on else MUTED)
	var items := _items()
	var title := String(items[_chosen].name) if _chosen < items.size() else "—"
	c.draw_string(font, box.position + Vector2(0, 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CREAM)
	# The grid: four rows shown, empty slots drawn as sockets.
	_slots_rect = Rect2(box.position + Vector2(0, 86), Vector2(COLUMNS, 4) * (SLOT + Vector2(8, 8)))
	var frame := _slots_rect.grow(10.0)
	c.draw_rect(frame, Color(0.05, 0.05, 0.05, 0.75))
	c.draw_rect(frame, Color(GOLD_DIM, 0.5), false, 1.0)
	for k in COLUMNS * 4:
		var at := _slots_rect.position + Vector2(k % COLUMNS, floori(float(k) / COLUMNS)) * (SLOT + Vector2(8, 8))
		var r := Rect2(at, SLOT)
		c.draw_rect(r, Color(0.11, 0.1, 0.09, 0.9))
		c.draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
		if k < items.size():
			var item: Dictionary = items[k]
			_icon(c, r.get_center(), String(item.icon), 30.0, item.get("colour", Color.WHITE))
			if item.get("worn", false):
				c.draw_string(font, r.position + Vector2(6, SLOT.y - 8), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
		if k == _chosen and k < items.size():
			c.draw_rect(r.grow(2.0), GOLD, false, 2.0)
			c.draw_rect(r.grow(5.0), Color(GOLD, 0.25), false, 2.0)


func _draw_item(c: Control, font: Font, box: Rect2, item: Dictionary) -> void:
	var y := box.position.y
	c.draw_string(font, Vector2(box.position.x, y + 26), String(item.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	c.draw_string(font, Vector2(box.position.x, y + 54), String(item.kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
	c.draw_line(Vector2(box.position.x, y + 68), Vector2(box.end.x - 170, y + 68), Color(GOLD_DIM, 0.6), 1.0)
	# The picture of it, framed, to the right of the name.
	var pic := Rect2(Vector2(box.end.x - 150, y), Vector2(150, 150))
	c.draw_rect(pic, Color(0.06, 0.06, 0.06, 0.9))
	c.draw_rect(pic, Color(GOLD_DIM, 0.7), false, 1.5)
	c.draw_rect(pic.grow(-6), Color(GOLD_DIM, 0.3), false, 1.0)
	_icon(c, pic.get_center(), String(item.icon), 56.0, item.get("colour", Color.WHITE))
	# Its numbers.
	y += 100
	c.draw_string(font, Vector2(box.position.x, y), "Attributes", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
	y += 12
	for line: Array in item.stats:
		y += 30
		c.draw_string(font, Vector2(box.position.x + 14, y), String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
		c.draw_string(font, Vector2(box.position.x + 14, y), String(line[1]), HORIZONTAL_ALIGNMENT_RIGHT,
				box.size.x - 200, 17, CREAM)
		c.draw_line(Vector2(box.position.x + 14, y + 8), Vector2(box.position.x + box.size.x - 186, y + 8),
				Color(1, 1, 1, 0.05), 1.0)
	y += 48
	c.draw_string(font, Vector2(box.position.x, y), "Effect", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
	y += 12
	c.draw_multiline_string(font, Vector2(box.position.x + 14, y + 22), String(item.text), HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 40, 16, -1, Color(CREAM, 0.85))
	y += 110
	var worn: bool = item.get("worn", false)
	var status := "Equipped" if worn else ("Enter / click to put on" if item.has("shield") or item.has("garb") else "")
	if not status.is_empty():
		c.draw_string(font, Vector2(box.position.x, y), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				GOLD if worn else Color(CREAM, 0.7))


func _draw_status(c: Control, font: Font, box: Rect2) -> void:
	var p := player.profile
	c.draw_rect(box, Color(0.05, 0.05, 0.05, 0.55))
	c.draw_rect(Rect2(box.position, Vector2(1, box.size.y)), Color(GOLD_DIM, 0.5))
	var x := box.position.x + 22
	var w := box.size.x - 44
	var y := box.position.y + 30
	c.draw_string(font, Vector2(x, y), "Character Status", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREAM)
	y += 10
	c.draw_line(Vector2(x, y), Vector2(x + w, y), Color(GOLD_DIM, 0.6), 1.0)
	var rows: Array = []
	rows.append(["Name", p.display_name if p != null else "—"])
	var book := player.get_node_or_null(^"Leveling") as Leveling
	if book != null:
		rows.append(["Level", "%d" % book.level])
		rows.append(["Experience", "max" if book.at_top() else "%.2f %%" % book.xp])
	else:
		rows.append(["Level", "1"])
	rows.append(["", ""])
	rows.append(["HP", "%.0f / %.0f" % [player.health, player.max_health]])
	rows.append(["Stamina", "%.0f / %.0f" % [maxf(player.stamina, 0.0), player.max_stamina]])
	rows.append(["", ""])
	if p != null:
		var m_atk := float(p.get("m_atk")) if "m_atk" in p else 0.0
		if p.weapon == CharacterProfile.Weapon.STAFF:
			rows.append(["M.ATK", "%.0f" % m_atk])
		else:
			rows.append(["P.ATK", "%.0f" % p.damage])
		rows.append(["P.DEF  /  M.DEF", "%.0f  /  %.0f" % [player.p_def,
				float(player.get("m_def")) if "m_def" in player else 0.0]])
		rows.append(["Critical", "%.0f %%  × %.1f" % [p.crit_chance * 100.0, p.crit_damage]])
		rows.append(["Run speed", "%.1f m/s" % p.run_speed])
		rows.append(["Roll", "%.1f m" % (p.dash_speed * p.dash_duration)])
		rows.append(["", ""])
		rows.append(["Weapon", String(_weapon(p).name)])
		var garbs := _garbs()
		if not garbs.is_empty():
			rows.append(["Attire", String(GARBS.get(StringName(garbs[player.garb]), {}).get("name", garbs[player.garb]))])
		if _has_shield():
			rows.append(["Shield", "Round Shield" if player.shield_kind == Shields.ROUND else "Tower Shield"])
	for r: Array in rows:
		y += 30 if String(r[0]) != "" else 14
		if String(r[0]) == "":
			continue
		c.draw_string(font, Vector2(x, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
		c.draw_string(font, Vector2(x, y), String(r[1]), HORIZONTAL_ALIGNMENT_RIGHT, w, 17, CREAM)


func _bag_icon(c: Control, at: Vector2) -> void:
	c.draw_circle(at + Vector2(0, 4), 12.0, Color(0.45, 0.32, 0.18))
	c.draw_rect(Rect2(at + Vector2(-5, -12), Vector2(10, 7)), Color(0.45, 0.32, 0.18))
	c.draw_line(at + Vector2(-7, -6), at + Vector2(7, -6), GOLD, 2.0)


## The things, drawn: every icon is a few shapes, so none needs a file.
func _icon(c: Control, at: Vector2, kind: String, r: float, tint: Color = Color.WHITE) -> void:
	var gold := Color(0.85, 0.62, 0.2)
	var steel := Color(0.8, 0.82, 0.86)
	var dark := Color(0.14, 0.13, 0.13)
	match kind:
		"round":
			c.draw_circle(at, r, Color(0.55, 0.42, 0.18))
			c.draw_circle(at, r * 0.9, Color(0.78, 0.8, 0.84))
			for k in 8:
				var a := TAU * k / 8.0
				c.draw_line(at, at + Vector2(cos(a), sin(a)) * r * 0.85, gold, maxf(r * 0.06, 1.5))
				c.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.76, r * 0.07, dark)
			c.draw_circle(at, r * 0.22, gold)
		"tower":
			var w := r * 1.25
			var h := r * 2.0
			var body := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				body.append(at + Vector2(cos(a) * w * 0.5, -h * 0.5 + w * 0.4 + sin(a) * w * 0.4))
			body.append(at + Vector2(w * 0.5, h * 0.5))
			body.append(at + Vector2(-w * 0.5, h * 0.5))
			c.draw_colored_polygon(body, dark)
			var inner := PackedVector2Array()
			for q in body:
				inner.append(at + (q - at) * 0.88)
			c.draw_colored_polygon(inner, Color(0.5, 0.06, 0.07))
			c.draw_rect(Rect2(at + Vector2(-r * 0.07, -r * 0.62), Vector2(r * 0.14, r * 1.25)), gold)
			c.draw_rect(Rect2(at + Vector2(-r * 0.42, -r * 0.14), Vector2(r * 0.84, r * 0.14)), gold)
			c.draw_circle(at + Vector2(0, -r * 0.07), r * 0.14, gold)
		"sword":
			var dir := Vector2(1, -1).normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := at + dir * r * 1.1
			var hilt := at - dir * r * 0.55
			c.draw_colored_polygon(PackedVector2Array([tip, hilt + side * r * 0.1, hilt - side * r * 0.1]), steel)
			c.draw_line(hilt + side * r * 0.35, hilt - side * r * 0.35, gold, r * 0.12)
			c.draw_line(hilt, hilt - dir * r * 0.4, Color(0.35, 0.2, 0.1), r * 0.12)
			c.draw_circle(hilt - dir * r * 0.45, r * 0.1, gold)
		"dagger":
			var dir := Vector2(1, -1).normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := at + dir * r * 0.95
			var hilt := at - dir * r * 0.15
			c.draw_colored_polygon(PackedVector2Array([tip, hilt + side * r * 0.16, hilt - side * r * 0.12]),
					Color(0.55, 0.57, 0.62))
			c.draw_line(hilt + side * r * 0.3, hilt - side * r * 0.3, Color(0.5, 0.05, 0.07), r * 0.1)
			c.draw_line(hilt, hilt - dir * r * 0.6, Color(0.08, 0.07, 0.07), r * 0.14)
			c.draw_circle(hilt - dir * r * 0.65, r * 0.09, Color(0.5, 0.05, 0.07))
		"bow":
			var pts := PackedVector2Array()
			for k in 17:
				var t := -1.0 + 2.0 * k / 16.0
				pts.append(at + Vector2(-r * 0.35 + r * 0.45 * (1.0 - t * t), t * r))
			c.draw_polyline(pts, Color(0.5, 0.3, 0.12), r * 0.12)
			c.draw_line(pts[0], pts[pts.size() - 1], Color(0.9, 0.88, 0.8), 1.5)
			c.draw_line(at + Vector2(-r * 0.6, 0), at + Vector2(r * 0.8, 0), Color(0.7, 0.6, 0.4), 2.0)
		"garb":
			# A tunic laid flat: sleeves out, a hood at the neck, a belt, a hem.
			var body := PackedVector2Array([
				at + Vector2(-r * 0.3, -r * 0.62), at + Vector2(-r * 0.95, -r * 0.3), at + Vector2(-r * 0.8, -r * 0.05),
				at + Vector2(-r * 0.4, -r * 0.25), at + Vector2(-r * 0.55, r * 0.95), at + Vector2(r * 0.55, r * 0.95),
				at + Vector2(r * 0.4, -r * 0.25), at + Vector2(r * 0.8, -r * 0.05), at + Vector2(r * 0.95, -r * 0.3),
				at + Vector2(r * 0.3, -r * 0.62)])
			c.draw_colored_polygon(body, tint)
			c.draw_polyline(body + PackedVector2Array([body[0]]), tint.darkened(0.45), maxf(r * 0.05, 1.5))
			c.draw_circle(at + Vector2(0, -r * 0.66), r * 0.26, tint.darkened(0.3))
			c.draw_circle(at + Vector2(0, -r * 0.62), r * 0.13, Color(0.08, 0.07, 0.06))
			c.draw_line(at + Vector2(-r * 0.44, r * 0.15), at + Vector2(r * 0.44, r * 0.15), Color(0.3, 0.18, 0.1), r * 0.1)
			c.draw_line(at + Vector2(-r * 0.55, r * 0.9), at + Vector2(r * 0.55, r * 0.9), tint.darkened(0.5), r * 0.06)
		"staff":
			c.draw_line(at + Vector2(-r * 0.3, r), at + Vector2(r * 0.2, -r * 0.7), Color(0.45, 0.28, 0.14), r * 0.14)
			c.draw_circle(at + Vector2(r * 0.25, -r * 0.8), r * 0.22, Color(1.0, 0.85, 0.45))
			c.draw_circle(at + Vector2(r * 0.25, -r * 0.8), r * 0.36, Color(1.0, 0.8, 0.4, 0.25))
#endregion
