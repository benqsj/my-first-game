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
## puts on what can be put on (a shield, an outfit), I or Escape closes. Enter
## or a click on the shield in his hand takes it off (3 too; the user's word,
## 2026-10-05): he fights with the sword alone, the block button throwing the
## other string ([method SkinnedRig.holds_shield]); 1 or 2 puts one on again.

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
const ARMS_ART := "res://assets/ui/icons/arms/"
## The arms' pictures loaded so far, by id (null for one there is none of).
var _arts: Dictionary = {}
## The gap between two slots of the grid.
const SLOT_GAP := 8.0
## What each thing's glyph ([UiArt] "item_<icon>") is tinted.
const ICON_TINTS := {
	"bow": Color(0.92, 0.72, 0.46), "sword": Color(0.86, 0.9, 0.98), "greatsword": Color(0.8, 0.84, 0.94),
	"dagger": Color(0.78, 0.8, 0.88), "staff": Color(0.78, 0.66, 1.0), "round": Color(0.9, 0.74, 0.46),
	"tower": Color(0.95, 0.4, 0.36),
}
## The hero himself, at the head of the status column (made when the bag is
## first opened: his model, in what he wears).
var _portrait: CharacterPortrait
const PORTRAIT := Vector2(312, 250)

var player: Player

var _root: Control
var _tab: int = Tab.WEAPONS
var _chosen: int = 0
var _slots_rect: Rect2
## The first row of the grid shown (more things than five rows hold).
var _top_row: int = 0
const GRID_ROWS := 5


## The first row to show for `count` things: the chosen one always in sight.
func _grid_top(count: int) -> int:
	var last := maxi(ceili(float(count) / COLUMNS) - GRID_ROWS, 0)
	var row := floori(float(_chosen) / COLUMNS)
	var top := clampi(_top_row, 0, last)
	if row < top:
		top = row
	elif row >= top + GRID_ROWS:
		top = row - GRID_ROWS + 1
	return clampi(top, 0, last)
var _tabs_rect: Rect2
## The look's off hand before the shield was taken off, to put the same back.
var _off_hand_before: String = ""


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
				if (event as InputEventKey).shift_pressed and _chosen < items.size() and items[_chosen].has("blade"):
					_hold_blade(String(items[_chosen].blade), true)
				else:
					_use(_chosen)
			KEY_X:
				_hands_empty()
			KEY_1:
				equip(Shields.ROUND)
			KEY_2:
				equip(Shields.TOWER)
			KEY_3:
				take_off()
	else:
		return
	get_viewport().set_input_as_handled()
	_root.queue_redraw()


func _on_gui(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var wheel := (event as InputEventMouseButton).button_index
	if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
		var count := _items().size()
		_chosen = clampi(_chosen + (COLUMNS if wheel == MOUSE_BUTTON_WHEEL_DOWN else -COLUMNS), 0, maxi(count - 1, 0))
		_root.queue_redraw()
		return
	var at := (event as InputEventMouseButton).position
	if _tabs_rect.has_point(at):
		_switch_tab(int((at.x - _tabs_rect.position.x) / (_tabs_rect.size.x / TAB_NAMES.size())))
	elif _slots_rect.has_point(at):
		var cell := ((at - _slots_rect.position) / (SLOT + Vector2(SLOT_GAP, SLOT_GAP))).floor()
		var i := (int(cell.y) + _top_row) * COLUMNS + int(cell.x)
		if i < _items().size():
			var item: Dictionary = _items()[i]
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and item.has("blade"):
				_hold_blade(String(item.blade), true)
			elif i == _chosen or (event as InputEventMouseButton).double_click:
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
	if _root.visible:
		_dress_portrait()
	player.menu_open = _root.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_CAPTURED
	_root.queue_redraw()


func equip(kind: int) -> void:
	if player == null or not _has_shield():
		return
	if not _shield_on():
		var look := _look()
		if not look.is_empty():
			look["o"] = _off_hand_before if _off_hand_before not in ["", "none"] else "his_shield"
			player.set_look(look)
	player.set_shield(kind)
	_root.queue_redraw()


## Takes the shield off his arm (his look's off hand "none"); a hero whose look
## cannot change (not on the mannequin) keeps his.
func take_off() -> void:
	if player == null or not _has_shield() or not _shield_on():
		return
	var look := _look()
	if look.is_empty():
		return
	_off_hand_before = String(look.get("o", ""))
	look["o"] = "none"
	player.set_look(look)
	_root.queue_redraw()


## Whether a shield is on his arm.
func _shield_on() -> bool:
	if player.rig != null and player.rig.has_method(&"holds_shield"):
		return bool(player.rig.call(&"holds_shield"))
	return true


## The look he wears (empty when his rig has none to change).
func _look() -> Dictionary:
	if player.rig == null or not player.rig.has_method(&"get_look"):
		return {}
	return player.rig.call(&"get_look")


func _use(i: int) -> void:
	var items := _items()
	if i < 0 or i >= items.size():
		return
	var item: Dictionary = items[i]
	if item.has("shield"):
		if item.get("worn", false):
			take_off()
		else:
			equip(int(item.shield))
	elif item.has("garb"):
		player.set_garb(int(item.garb))
		_root.queue_redraw()
	elif item.has("blade"):
		_take_blade(String(item.blade))
	elif item.has("bow") and not item.get("worn", false):
		var look := _look()
		if not look.is_empty():
			look["w"] = String(item.bow)
			player.set_look(look)
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
			var bows := _bows()
			var blades := _blades()
			for id: String in blades:
				out.append(_blade_item(p, id))
			if blades.is_empty() and bows.is_empty():
				var held := _weapon(p)
				# the picture of what is really in his hand, when his look says
				held["art"] = String(_look().get("w", ""))
				out.append(held)
			for id: String in bows:
				out.append(_bow_item(p, id))
		Tab.SHIELDS:
			if _has_shield():
				out.append({
					"name": "Round Shield", "kind": "Small shield", "icon": "round", "art": "his_shield", "shield": Shields.ROUND,
					"worn": player.shield_kind == Shields.ROUND and _shield_on(),
					"stats": [["Guard", "100 %"], ["Stamina per blow", "× %.1f" % player.block_stamina]],
					"text": "Light and quick: up in an instant, and it goes with him wherever he turns.",
				})
				out.append({
					"name": "Tower Shield", "kind": "Greatshield", "icon": "tower", "art": "his_tower_shield",
					"shield": Shields.TOWER,
					"worn": player.shield_kind == Shields.TOWER and _shield_on(),
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
			var held := String(_look().get("w", ""))
			if BowKinds.key_of(held) != "":
				return _bow_item(p, held)
			crit.append(["Full draw", "%.2f s" % p.draw_time])
			crit.append(["Arrow speed", "%.0f m/s" % p.arrow_speed])
			return {"name": "Archer's Longbow", "kind": "Bow", "icon": "bow", "worn": true, "stats": crit,
					"text": "Avtandil's bow. Hold to draw, let go to loose: a tapped shot flies fast and light, a full draw lands for all of it."}
		CharacterProfile.Weapon.STAFF:
			crit.append(["Full charge", "%.2f s" % p.draw_time])
			crit.append(["Bolt speed", "%.0f m/s" % p.arrow_speed])
			return {"name": "Staff of the Storm", "kind": "Staff", "icon": "staff", "worn": true, "stats": crit,
					"text": "Hold to gather a bolt of lightning at the crystal, let go to throw it. Thrown at what he has locked on to, the bolt hunts it."}
	if p.display_name.to_lower().contains("warrior"):
		return {"name": "The Black Great Sword", "kind": "Great sword", "icon": "greatsword", "worn": true, "stats": crit,
				"text": "A long blade and a hilt for both hands. Slow to get moving, and nothing stands in its way once it is."}
	if p.display_name.to_lower().contains("rogue") or p.display_name.to_lower().contains("assassin"):
		return {"name": "Shadow Knife", "kind": "Dagger", "icon": "dagger", "worn": true, "stats": crit,
				"text": "A long knife, black-hilted, kept keen. Quick cuts, one after another, faster than anything can answer."}
	return {"name": "Tariel's Sword", "kind": "Straight sword", "icon": "sword", "worn": true, "stats": crit,
			"text": "The knight's sword. Cuts that chain into a flurry; thrown from a jump, it comes down and plants."}


## The assassin's blades (the user's word, 2026-10-05: every knife, in every
## style, to hold in either hand): the knives and the short swords his look
## can hold, each in the pack's four styles, and whatever is in his hands.
## Empty for any other hero, or one whose look cannot change.
const BLADE_STYLES := ["normal", "ornate", "obsidian", "bone"]


## The hero, his outfit's class, and whether his look can hold arms from
## the bag: every hero who fights with a blade (not the archers and their
## bows, not the mages and their staves), the user's word 2026-10-06.
func _arms_hero() -> StringName:
	var p := player.profile
	if p == null or player.rig == null or p.weapon != CharacterProfile.Weapon.MELEE:
		return &""
	var hero: Variant = player.rig.get(&"polysplit_hero")
	return hero if hero is StringName and _look().size() > 0 else &""


func _is_blade(id: String) -> bool:
	return id not in ["", "none"] and PolysplitLook.kind(id) not in [&"shield", &"bow"]


## What he may hold, in every style: the arms of his sword hand and of the
## other (no shields: those are under Shields), and whatever is in his hands.
func _blades() -> Array[String]:
	var out: Array[String] = []
	var hero := _arms_hero()
	if hero == &"":
		return out
	var look := _look()
	var cls := String(look.get("cls", ""))
	for slot: String in ["w", "o"]:
		for style: String in BLADE_STYLES:
			for id: String in PolysplitLook.arms(hero, cls, slot, style):
				if _is_blade(id) and not out.has(id):
					out.append(id)
	for key: String in ["w", "o"]:
		var held := String(look.get(key, ""))
		if _is_blade(held) and not out.has(held):
			out.append(held)
	return out


## Whether `id` can go into his other hand (as his class holds it, with
## what is in his sword hand).
func _left_can(id: String, with: String) -> bool:
	if PolysplitLook.both_hands(id) or PolysplitLook.both_hands(with):
		return false
	var look := _look()
	var style := PolysplitLook.style_of(id)
	return PolysplitLook.arms(_arms_hero(), String(look.get("cls", "")), "o", style if style != "" else "normal",
			with).has(id)


func _blade_item(p: CharacterProfile, id: String) -> Dictionary:
	var look := _look()
	var right := String(look.get("w", "")) == id
	var left := String(look.get("o", "")) == id
	var style := PolysplitLook.style_of(id)
	var title := PolysplitLook.arm_name(id).capitalize()
	if style != "":
		title += " — " + String(PolysplitLook.STYLE_NAMES.get(style, style.to_upper())).capitalize()
	var held := "In both hands" if right and left else ("In his right hand" if right else ("In his left hand" if left else ""))
	var kinds := {&"knives": "Knife", &"two_hands": "Two-handed", &"spear": "Polearm"}
	var kind := String(kinds.get(PolysplitLook.kind(id), "One-handed"))
	var text := "Enter or click: into his hand — the right one if it is empty, else the left, else in place of the left (a shield stays where it is). On what he holds: taken off. X: every blade off."
	if player.rig.get(&"polysplit_hero") == &"rogue":
		text = "A blade in each hand and he fights with both, each hand in turn: quicker, and tiring. One, and he fights as he always has: slower, and lasting. " + text
	elif PolysplitLook.both_hands(id):
		text = "Held in both hands: the other hand lets go of what it held. " + text
	return {"name": title, "kind": kind + ("  ·  " + held if held != "" else ""), "icon": "dagger", "art": id,
			"blade": id, "worn": right or left,
			"stats": [["P.ATK", "%.0f" % p.damage], ["Attack speed", "%.0f %%" % (PolysplitLook.arm_speed(id) * 100.0)],
				["Both hands now", "%.0f %%" % (PolysplitLook.arms_speed(look) * 100.0)],
				["Critical chance", "%.0f %%" % (p.crit_chance * 100.0)],
				["Critical damage", "× %.1f" % p.crit_damage], ["Stamina per attack", "%.0f" % p.attack_stamina]],
			"text": text}


## The bag's one press on a blade (the user's word, 2026-10-06), for every
## hero who holds one: a blade he holds is taken off (out of his left hand
## first; out of his right, a blade in the left goes over into it); one he
## does not goes into his right hand if it is empty, else into his left,
## else in place of the left one. A shield in the left stays: the new blade
## takes the right hand's place. A two-handed one takes both hands.
func _take_blade(id: String) -> void:
	var look := _look()
	if look.is_empty():
		return
	var w := String(look.get("w", "none"))
	var o := String(look.get("o", "none"))
	if o == id:
		o = "none"
	elif w == id:
		if _is_blade(o) and not PolysplitLook.both_hands(o):
			w = o
			o = "none"
		else:
			w = "none"
	elif PolysplitLook.both_hands(id):
		w = id
		o = "none"
	elif not _is_blade(w):
		w = id
	elif _is_blade(o) or o in ["", "none"]:
		if _left_can(id, w):
			o = id
		else:
			w = id
	else:
		# a shield in his left: the blade goes into his right
		w = id
	look["w"] = w if w != "" else "none"
	look["o"] = o if o != "" else "none"
	look["own_styles"] = true
	player.set_look(look)
	_root.queue_redraw()


## Every blade taken out of his hands (a shield stays on his arm).
func _hands_empty() -> void:
	var look := _look()
	if look.is_empty() or _blades().is_empty():
		return
	look["w"] = "none"
	if _is_blade(String(look.get("o", ""))):
		look["o"] = "none"
	look["own_styles"] = true
	player.set_look(look)
	_root.queue_redraw()


## Puts blade `id` in his right hand (`left` false) or his left.
func _hold_blade(id: String, left: bool) -> void:
	var look := _look()
	if look.is_empty():
		return
	look["o" if left else "w"] = id
	# each hand keeps the style of what was put in it
	look["own_styles"] = true
	player.set_look(look)
	_root.queue_redraw()


## His left hand empty: one blade, and he fights one-handed.
func _left_hand_empty() -> void:
	var look := _look()
	if look.is_empty() or _blades().is_empty():
		return
	look["o"] = "none"
	player.set_look(look)
	_root.queue_redraw()


## His bows ([BowKinds]) as his look can hold them (the Advanced Weapons' in
## the look's style), in [constant BowKinds.KINDS]' order; none for a hero without.
func _bows() -> Array[String]:
	var out: Array[String] = []
	var p := player.profile
	if p == null or p.weapon != CharacterProfile.Weapon.BOW or player.rig == null:
		return out
	var look := _look()
	var hero: Variant = player.rig.get(&"polysplit_hero")
	if look.is_empty() or not hero is StringName or hero == &"":
		return out
	var held := PolysplitLook.arms(hero, String(look.get("cls", "")), "w", String(look.get("ws", "normal")))
	for key: String in BowKinds.KINDS:
		for id: String in held:
			if BowKinds.key_of(id) == key:
				out.append(id)
				break
	return out


## One of his bows in the bag: its own P.ATK and draw ([BowKinds]), the rest
## his profile's.
func _bow_item(p: CharacterProfile, id: String) -> Dictionary:
	var info: Dictionary = BowKinds.KINDS.get(BowKinds.key_of(id), {})
	var atk := float(info.get("atk", 1.0))
	var draw := float(info.get("draw", 1.0))
	var stats := [["P.ATK", "%.0f" % (p.damage * atk)], ["Full draw", "%.2f s" % (p.draw_time * draw)],
			["Critical chance", "%.0f %%" % (p.crit_chance * 100.0)], ["Critical damage", "× %.1f" % p.crit_damage],
			["Stamina per attack", "%.0f" % p.attack_stamina], ["Arrow speed", "%.0f m/s" % p.arrow_speed]]
	return {"name": info.get("name", PolysplitLook.arm_name(id)), "kind": info.get("kind", "Bow"), "icon": "bow",
			"bow": id, "art": id, "worn": String(_look().get("w", "")) == id, "stats": stats, "text": info.get("text", "")}
#endregion


#region Drawing
## The hero in the status column: made once, dressed as he is each time the
## bag opens.
func _dress_portrait() -> void:
	if player.profile == null:
		return
	if _portrait == null:
		_portrait = CharacterPortrait.of(player.profile, PORTRAIT, CharacterPortrait.Frame.FULL)
		_portrait.name = "Portrait"
		_portrait.turn_speed = 0.35
		_root.add_child(_portrait)
	var model := _portrait.rig()
	if model == null or player.rig == null:
		return
	if model.has_method(&"set_look") and player.rig.has_method(&"get_look"):
		model.call(&"set_look", player.rig.call(&"get_look"))
	if model.has_method(&"set_face"):
		model.call(&"set_face", int(player.rig.get(&"face")))
	if model.has_method(&"set_garb") and "garb" in player.rig:
		model.call(&"set_garb", int(player.rig.get(&"garb")))


func _draw_all() -> void:
	var c := _root
	var screen := c.size
	# The world, darkened and cooled behind the bag, darker still at the edges.
	c.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.022, 0.03, 0.8))
	for k in 6:
		var inset := 60.0 * k
		c.draw_rect(Rect2(Vector2.ZERO, screen).grow(-inset), Color(0, 0, 0, 0.06), false, 60.0)
	# The head: the bag, the word, the hero, a gilt rule under it.
	var head_h := 70.0
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(screen.x, 0), Vector2(screen.x, head_h),
			Vector2(0, head_h)]), PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.7), Color(0.06, 0.05, 0.04, 0.5),
			Color(0.06, 0.05, 0.04, 0.5)]))
	var bag := UiArt.icon("item_bag")
	if bag != null:
		c.draw_texture_rect(bag, Rect2(36, 14, 42, 42), false, Color(0.9, 0.72, 0.45))
	UiArt.text_shadowed(c, Vector2(90, 47), "INVENTORY", 30, CREAM, "title")
	var p := player.profile
	var book := player.get_node_or_null(^"Leveling") as Leveling
	var who := "%s   ·   LEVEL %d" % [p.display_name.to_upper() if p != null else "", book.level if book != null else 1]
	UiArt.text(c, Vector2(0, 44), who, 18, GOLD, "head", HORIZONTAL_ALIGNMENT_RIGHT, screen.x - 40.0)
	UiArt.rule(c, Vector2(24, head_h), Vector2(screen.x - 24, head_h), Color(GOLD_DIM, 0.8))

	var top := 96.0
	var bottom := screen.y - 58.0
	var grid_w := SLOT.x * COLUMNS + SLOT_GAP * (COLUMNS - 1)
	var left := Rect2(32, top, grid_w + 64, bottom - top)
	var right_w := 380.0
	var right := Rect2(screen.x - right_w - 32, top, right_w, bottom - top)
	var middle := Rect2(left.end.x + 24, top, right.position.x - left.end.x - 48, bottom - top)

	_draw_left(c, left)
	UiArt.draw_frame(c, middle, "panel", 30.0)
	var items := _items()
	if _chosen < items.size():
		_draw_item(c, middle.grow(-36.0), items[_chosen])
	else:
		UiArt.text(c, middle.position + Vector2(40, 64), "Nothing here yet.", 20, MUTED, "body")
	_draw_status(c, right)

	# The keys, along the foot.
	var keys := [["◂ ▸ ▴ ▾", "choose"], ["Q / E", "tab"], ["Enter", "put on / take off"], ["I", "close"]]
	var x := 40.0
	for pair: Array in keys:
		var key := String(pair[0])
		var w := UiArt.font("bold").get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
		var box := Rect2(x, screen.y - 40.0, w, 24.0)
		c.draw_rect(box, Color(0.1, 0.09, 0.08, 0.9))
		c.draw_rect(box, Color(GOLD_DIM, 0.9), false, 1.0)
		UiArt.text(c, box.position + Vector2(8, 17), key, 15, CREAM, "bold")
		UiArt.text(c, Vector2(box.end.x + 8, box.position.y + 17), String(pair[1]), 15, Color(CREAM, 0.7), "body")
		x = box.end.x + 16.0 + UiArt.font("body").get_string_size(String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22.0
	if _portrait != null:
		_portrait.position = right.position + Vector2((right.size.x - PORTRAIT.x) * 0.5, 52.0)
		_portrait.size = PORTRAIT


func _draw_left(c: Control, box: Rect2) -> void:
	UiArt.draw_frame(c, box, "panel", 30.0)
	var inner := box.grow(-32.0)
	# The tabs: a glyph and a word each, the open one lit.
	_tabs_rect = Rect2(inner.position, Vector2(inner.size.x, 44))
	var w := inner.size.x / TAB_NAMES.size()
	var glyphs := ["item_tab_weapons", "item_tab_shields", "item_tab_goods", "item_tab_attire"]
	for i in TAB_NAMES.size():
		var r := Rect2(inner.position + Vector2(w * i, 0), Vector2(w - 4, 44))
		var on := i == _tab
		UiArt.draw_frame(c, r, "tab_on" if on else "tab", 4.0)
		var glyph := UiArt.icon(glyphs[i])
		if glyph != null:
			c.draw_texture_rect(glyph, Rect2(r.position + Vector2((r.size.x - 22) * 0.5, 3), Vector2(22, 22)), false,
					GOLD.lightened(0.2) if on else Color(MUTED, 0.7))
		UiArt.text(c, Vector2(r.position.x, r.position.y + 39), String(TAB_NAMES[i]).to_upper(), 11,
				UiArt.GOLD_LIGHT if on else MUTED, "head", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var items := _items()
	var title := String(items[_chosen].name) if _chosen < items.size() else "—"
	UiArt.text(c, inner.position + Vector2(2, 76), title, 19, CREAM, "head")
	# The grid: five rows shown, empty slots drawn as sockets.
	var rows := 5
	_slots_rect = Rect2(inner.position + Vector2(0, 94), Vector2(COLUMNS, rows) * (SLOT + Vector2(SLOT_GAP, SLOT_GAP)))
	# more than fit: the rows scroll with the one chosen (and the wheel)
	_top_row = _grid_top(items.size())
	for cell in COLUMNS * rows:
		var k := cell + _top_row * COLUMNS
		var at := _slots_rect.position + Vector2(cell % COLUMNS, floori(float(cell) / COLUMNS)) \
				* (SLOT + Vector2(SLOT_GAP, SLOT_GAP))
		var r := Rect2(at, SLOT)
		var chosen := k == _chosen and k < items.size()
		if chosen:
			for g in 3:
				c.draw_rect(r.grow(3.0 + 3.0 * g), Color(1.0, 0.78, 0.35, 0.12), false, 3.0)
		UiArt.draw_frame(c, r, "socket_lit" if chosen else "socket", 8.0)
		if k < items.size():
			var item: Dictionary = items[k]
			_glyph(c, r.grow(-10.0), item)
			if item.get("worn", false):
				_worn_mark(c, r.position + Vector2(13, SLOT.y - 13))
	# A count under the grid.
	var shown := "%d / %d" % [items.size(), COLUMNS * rows] if items.size() <= COLUMNS * rows else \
			"%d  ·  rows %d–%d of %d" % [items.size(), _top_row + 1, _top_row + rows, ceili(float(items.size()) / COLUMNS)]
	UiArt.text(c, Vector2(_slots_rect.position.x, _slots_rect.end.y + 22), shown, 14, MUTED, "body")


## The real thing's picture (assets/ui/icons/arms, baked off the figure's own
## meshes by `_shots_tmp/bake_arm_icons.gd`; the user's word, 2026-10-05: the
## bow as it is seen in his hands) for an arm id of his look, null for none.
## His own bow is worn as the pack's on the mannequin, so it is that picture.
func _arm_art(id: String) -> Texture2D:
	if id == "" or id == "none":
		return null
	if id == "own_bow":
		id = "bow"
	if _arts.has(id):
		return _arts[id]
	var path := ARMS_ART + id + ".png"
	var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
	_arts[id] = tex
	# loaded in the middle of a draw it comes up blank (white) until it is
	# drawn again: the bag only redraws on a key, so it is asked for once more
	if tex != null:
		get_tree().create_timer(0.05).timeout.connect(_root.queue_redraw)
	return tex


## The small gold diamond with an E: in his hands, or on him.
func _worn_mark(c: Control, at: Vector2) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(10, 0), at + Vector2(0, 10),
			at + Vector2(-10, 0)]), Color(0.12, 0.09, 0.04))
	c.draw_polyline(PackedVector2Array([at + Vector2(0, -10), at + Vector2(10, 0), at + Vector2(0, 10),
			at + Vector2(-10, 0), at + Vector2(0, -10)]), GOLD, 1.5)
	UiArt.text(c, at + Vector2(-10, 5), "E", 12, UiArt.GOLD_LIGHT, "title", HORIZONTAL_ALIGNMENT_CENTER, 20.0)


## A thing's picture in `rect`: its glyph, tinted, or the drawn one.
func _glyph(c: Control, rect: Rect2, item: Dictionary) -> void:
	var art := _arm_art(String(item.get("art", "")))
	if art != null:
		c.draw_texture_rect(art, rect.grow(rect.size.x * 0.08), false)
		return
	var kind := String(item.icon)
	var tex := UiArt.icon("item_" + kind)
	if tex == null:
		_icon(c, rect.get_center(), kind, rect.size.x * 0.4, item.get("colour", Color.WHITE))
		return
	var tint: Color = ICON_TINTS.get(kind, Color.WHITE)
	if kind == "garb":
		var cloth: Color = item.get("colour", Color(0.6, 0.6, 0.55))
		tint = cloth.lightened(0.45)
	c.draw_texture_rect(tex, rect, false, tint)


func _draw_item(c: Control, box: Rect2, item: Dictionary) -> void:
	var y := box.position.y
	var pic_size := 156.0
	var text_w := box.size.x - pic_size - 24.0
	UiArt.text_shadowed(c, Vector2(box.position.x, y + 30), String(item.name), 30, CREAM, "title", 
			HORIZONTAL_ALIGNMENT_LEFT, text_w)
	UiArt.text(c, Vector2(box.position.x, y + 58), String(item.kind).to_upper(), 15, GOLD, "head")
	var worn: bool = item.get("worn", false)
	if worn:
		var badge := Rect2(box.position.x, y + 72, 104, 24)
		c.draw_rect(badge, Color(0.25, 0.18, 0.06, 0.9))
		c.draw_rect(badge, GOLD, false, 1.0)
		UiArt.text(c, badge.position + Vector2(0, 17), "EQUIPPED", 12, UiArt.GOLD_LIGHT, "title",
				HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	# The picture of it, in a lit socket, light behind it.
	var pic := Rect2(Vector2(box.end.x - pic_size, y), Vector2(pic_size, pic_size))
	UiArt.draw_frame(c, pic, "socket_lit", 8.0)
	var glow: Color = ICON_TINTS.get(String(item.icon), item.get("colour", Color(0.9, 0.8, 0.6)))
	for k in range(8, 0, -1):
		c.draw_circle(pic.get_center(), pic_size * 0.06 * k, Color(glow, 0.025))
	_glyph(c, pic.grow(-22.0), item)
	# Its numbers.
	y += pic_size + 30.0
	_section(c, Vector2(box.position.x, y), box.size.x, "ATTRIBUTES")
	y += 14.0
	var stripe := false
	for line: Array in item.stats:
		var row := Rect2(box.position.x, y, box.size.x, 30)
		if stripe:
			c.draw_rect(row, Color(1, 1, 1, 0.035))
		stripe = not stripe
		UiArt.text(c, Vector2(row.position.x + 12, y + 21), String(line[0]), 17, MUTED, "body")
		UiArt.text(c, Vector2(row.position.x, y + 21), String(line[1]), 17, CREAM, "bold", HORIZONTAL_ALIGNMENT_RIGHT,
				row.size.x - 12.0)
		y += 30.0
	y += 30.0
	_section(c, Vector2(box.position.x, y), box.size.x, "DESCRIPTION")
	y += 12.0
	c.draw_multiline_string(UiArt.font("plain"), Vector2(box.position.x + 4, y + 24), String(item.text),
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 17, -1, Color(CREAM, 0.88))
	var status := ""
	if item.has("blade"):
		status = ("Enter / click: take it off" if worn else "Enter / click: into his hand") + \
				"   ·   Shift+Enter / right-click: left hand   ·   X: all off"
	elif item.has("shield"):
		status = "Enter / click to take it off" if worn else "Enter / click to put it on"
	elif (item.has("garb") or item.has("bow")) and not worn:
		status = "Enter / click to put it on"
	if not status.is_empty():
		UiArt.text(c, Vector2(box.position.x, box.end.y - 6.0), "◆  " + status, 16, Color(GOLD, 0.95), "body")


## A section's heading: gold capitals and a rule running out from them.
func _section(c: Control, at: Vector2, width: float, title: String) -> void:
	UiArt.text(c, at, title, 15, GOLD, "title")
	var w := UiArt.font("title").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_line(at + Vector2(w + 12, -5), at + Vector2(width, -5), Color(GOLD_DIM, 0.7), 1.0)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(width, -9), at + Vector2(width + 4, -5),
			at + Vector2(width, -1), at + Vector2(width - 4, -5)]), GOLD_DIM)


func _draw_status(c: Control, box: Rect2) -> void:
	var p := player.profile
	UiArt.draw_frame(c, box, "panel", 30.0)
	var x := box.position.x + 32
	var w := box.size.x - 64
	var y := box.position.y + 40
	UiArt.text(c, Vector2(box.position.x, y), "CHARACTER", 18, CREAM, "title", HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	# the hero stands here (the portrait), on a pool of light
	var stand := Vector2(box.position.x + box.size.x * 0.5, box.position.y + 52 + PORTRAIT.y * 0.92)
	c.draw_set_transform(stand, 0.0, Vector2(1.0, 0.22))
	for k in range(6, 0, -1):
		c.draw_circle(Vector2.ZERO, 30.0 + 14.0 * k, Color(GOLD, 0.03))
	c.draw_arc(Vector2.ZERO, 92.0, 0.0, TAU, 48, Color(GOLD, 0.5), 1.5)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	y = box.position.y + 52 + PORTRAIT.y + 18
	var rows: Array = []
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
			rows.append(["P.ATK", "%.0f" % (p.damage * BowKinds.atk(player))])
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
			rows.append(["Shield", ("Round Shield" if player.shield_kind == Shields.ROUND else "Tower Shield")
					if _shield_on() else "None"])
	for r: Array in rows:
		if String(r[0]) == "":
			y += 6
			c.draw_line(Vector2(x, y), Vector2(x + w, y), Color(GOLD_DIM, 0.35), 1.0)
			y += 4
			continue
		y += 24
		if r[0] in ["HP", "Stamina"]:
			# a thin bar under the figure
			var full := player.health / maxf(player.max_health, 1.0) if r[0] == "HP" \
					else maxf(player.stamina, 0.0) / maxf(player.max_stamina, 1.0)
			var bar := Rect2(x, y + 4, w, 3)
			c.draw_rect(bar, Color(1, 1, 1, 0.06))
			c.draw_rect(Rect2(bar.position, Vector2(w * clampf(full, 0.0, 1.0), 3)),
					Color(0.78, 0.16, 0.12) if r[0] == "HP" else Color(0.38, 0.7, 0.32))
		UiArt.text(c, Vector2(x, y), String(r[0]), 16, MUTED, "body")
		UiArt.text(c, Vector2(x, y), String(r[1]), 16, CREAM, "bold", HORIZONTAL_ALIGNMENT_RIGHT, w)


## The things, drawn: every icon is a few shapes, so none needs a file.
func _icon(c: Control, at: Vector2, kind: String, r: float, tint: Color = Color.WHITE) -> void:
	var gold := Color(0.85, 0.62, 0.2)
	var steel := Color(0.8, 0.82, 0.86)
	var dark := Color(0.14, 0.13, 0.13)
	match kind:
		"hand":
			# an open hand, empty: a palm, four fingers and a thumb
			var skin := Color(0.78, 0.66, 0.52, 0.85)
			c.draw_circle(at + Vector2(0, r * 0.2), r * 0.42, skin)
			for k in 4:
				var x := (k - 1.5) * r * 0.22
				c.draw_line(at + Vector2(x, 0), at + Vector2(x * 1.15, -r * (0.75 if k in [1, 2] else 0.62)), skin,
						maxf(r * 0.16, 2.0))
			c.draw_line(at + Vector2(-r * 0.3, r * 0.25), at + Vector2(-r * 0.72, -r * 0.05), skin, maxf(r * 0.16, 2.0))
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
