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
## The skeletons' clothes' pictures (tools/bake_garb_icons.gd).
const GARB_ART := "res://assets/ui/icons/garb/"
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
const PORTRAIT := Vector2(300, 430)
## The size he is drawn at this time (smaller on a narrow screen).
var _pv := PORTRAIT
## The sockets beside him for what he wears and holds (the user's word,
## 2026-10-06): head, body and legs on his left, his hands on his right.
const EQUIP := 52.0
var _equip_rects: Array = []
var _portrait_rect: Rect2

var player: Player

var _root: Control
var _tab: int = Tab.WEAPONS
var _chosen: int = 0
var _slots_rect: Rect2
## The first row of the grid shown (more things than five rows hold).
var _top_row: int = 0
const GRID_ROWS := 6
## The rows follow the chosen one (the keys) or stay where the wheel or the
## bar put them (the user's word, 2026-10-07: the bag scrolls).
var _follow := true
## The scroll bar beside the grid, and whether it is being dragged.
var _bar_rect: Rect2
var _bar_drag := false


## The first row to show for `count` things: the chosen one in sight, unless
## the player scrolled away from it.
func _grid_top(count: int) -> int:
	var last := maxi(ceili(float(count) / COLUMNS) - GRID_ROWS, 0)
	var row := floori(float(_chosen) / COLUMNS)
	var top := clampi(_top_row, 0, last)
	if not _follow:
		return top
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
	# what he starts with, once his look is on him
	get_tree().create_timer(0.6).timeout.connect(_start_kit)


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
		_follow = true
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
	# the scroll bar, pressed or dragged: the rows go where it is
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var b := event as InputEventMouseButton
		_bar_drag = b.pressed and _bar_rect.grow(8.0).has_point(b.position)
		if _bar_drag:
			_scroll_to_bar(b.position.y)
			return
	if event is InputEventMouseMotion and _bar_drag:
		if ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_bar_drag = false
		else:
			_scroll_to_bar((event as InputEventMouseMotion).position.y)
		return
	# Dragged across, he turns on his stand, to be seen from every side.
	if event is InputEventMouseMotion and _portrait != null \
			and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
			and _portrait_rect.grow(30.0).has_point((event as InputEventMouseMotion).position):
		_portrait.spin((event as InputEventMouseMotion).relative.x * 0.012)
		return
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var press_at := (event as InputEventMouseButton).position
	for slot: Array in _equip_rects:
		if (slot[0] as Rect2).has_point(press_at):
			_take_off_slot(String(slot[1]))
			return
	var wheel := (event as InputEventMouseButton).button_index
	if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
		# the wheel scrolls the rows, the chosen one stays chosen
		var last := maxi(ceili(float(_items().size()) / COLUMNS) - GRID_ROWS, 0)
		_follow = false
		_top_row = clampi(_top_row + (1 if wheel == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, last)
		_root.queue_redraw()
		return
	var at := (event as InputEventMouseButton).position
	if _tabs_rect.has_point(at):
		_follow = true
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
	_dress_portrait()
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
	_dress_portrait()
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
	_use_item(i)
	# what was put on is on him now, not in the bag: the choice stays in it
	_chosen = clampi(_chosen, 0, maxi(_items().size() - 1, 0))
	# what he now wears, on him at once in the bag's picture of him
	if _root.visible:
		_dress_portrait()


func _use_item(i: int) -> void:
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
	elif item.has("own"):
		# his own clothes: a coat, breeches, a hat, a cloak or the like
		var look := _look()
		if not look.is_empty():
			var part := String(item.own)
			var key := String(item.key)
			match part:
				"top":
					look["top"] = key
					look.erase("sk_top")
					look.erase("bare_top")
				"bottom":
					look["bottom"] = key
					look.erase("bare_bottom")
				"hat":
					look["hat"] = key
					look.erase("sk_head")
				"feet":
					look["feet"] = key
					look.erase("sk_feet")
				"extra":
					var worn: Array = (look.get("extras", []) as Array).duplicate()
					if not worn.has(key):
						worn.append(key)
					look["extras"] = worn
			player.set_look(look)
		_root.queue_redraw()
	elif item.has("sk"):
		# the skeletons' clothes ([SkeletonGarb]): on, or off again
		var look := _look()
		if not look.is_empty():
			var id := String(item.sk)
			var slot := String(SkeletonGarb.PIECES[id][0])
			if String(look.get(slot, "")) == id:
				look.erase(slot)
			else:
				look[slot] = id
			player.set_look(look)
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


## He wears his own figure, the maker's (YOUR OWN), on which the skeletons'
## clothes go.
func _wears_own_figure() -> bool:
	var rig: Node = player.rig
	if rig == null or not (&"faces" in rig) or not (&"face" in rig):
		return false
	var faces: Array = rig.get(&"faces")
	var face := int(rig.get(&"face"))
	return face >= 0 and face < faces.size() and faces[face] == &"custom"


func _has_shield() -> bool:
	return player.profile != null and player.profile.can_block
#endregion


#region What he carries
## Everything in the bag whether he has found it or not (the tests; the
## arena). Off in play: he has what he started with and what he found
## ([GEAR_SETS.md] §5.7).
static var everything: bool = under_test()


## Whether this is a test run (`--script res://tests/...`, or a probe in
## `_shots_tmp/`): everything is in
## the bag then, and what a hero carries is not written to the player's own
## settings ([method Player.gain]).
static func under_test() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.contains("tests/") or arg.contains("_shots_tmp/"):
			return true
	return false

## The tabs a found thing can be under.
const LOOT_TABS := [Tab.WEAPONS, Tab.SHIELDS, Tab.ATTIRE]
var _kit_done: bool = false


## The key a thing of the bag is known by in what he carries
## ([method Player.owns]): "" for one that cannot be taken off or found (the
## weapon of a hero whose look cannot change).
static func key_of(item: Dictionary) -> String:
	if item.has("shield"):
		return "shield:%d" % int(item.shield)
	if item.has("gid"):
		return "garb:" + String(item.gid)
	if item.has("own"):
		return "own:%s:%s" % [String(item.own), String(item.key)]
	if item.has("sk"):
		return "sk:" + String(item.sk)
	if item.has("blade"):
		return "blade:" + String(item.blade)
	if item.has("bow"):
		return "bow:" + String(item.bow)
	return ""


func _has(item: Dictionary) -> bool:
	var key := key_of(item)
	return key == "" or player.owns(key)


func _claim(item: Dictionary) -> void:
	var key := key_of(item)
	if key != "":
		player.gain(key)


## What he starts with (the user's word, 2026-10-07: the heroes keep only
## their first weapons): the arms in his hands that he has not found give way
## to his class's own (his default look's), the tower shield to the round one;
## then whatever he wears and holds is his. Once, when his look is on him.
func _start_kit() -> void:
	if _kit_done or player == null or not is_instance_valid(player) or player.profile == null:
		return
	if player.rig == null:
		# his body not made yet: again in a moment
		if is_inside_tree():
			get_tree().create_timer(0.5).timeout.connect(_start_kit)
		return
	_kit_done = true
	if everything:
		return
	var look := _look()
	var hero: Variant = player.rig.get(&"polysplit_hero") if player.rig != null else null
	if not look.is_empty() and hero is StringName and hero != &"":
		var start := PolysplitLook.default_look(hero, String(look.get("g", "m")), String(look.get("race", "")))
		var changed := false
		for slot: String in ["w", "o"]:
			var held := String(look.get(slot, "none"))
			var first := String(start.get(slot, "none"))
			if held in ["", "none"] or held == first:
				continue
			var kind := "bow:" if PolysplitLook.kind(held) == &"bow" else "blade:"
			if PolysplitLook.kind(held) == &"shield" or player.owns(kind + held):
				continue
			look[slot] = first
			changed = true
		if changed:
			look["ws"] = String(start.get("ws", "normal"))
			look.erase("own_styles")
			player.set_look(look)
	if _has_shield() and player.shield_kind != Shields.ROUND \
			and not player.owns("shield:%d" % player.shield_kind):
		player.set_shield(Shields.ROUND)
	var was := _tab
	for tab: int in LOOT_TABS:
		_tab = tab
		for item: Dictionary in _all_items():
			if item.get("worn", false):
				_claim(item)
	_tab = was


## Something he has not got yet, for a creature to drop ([LootDrop]): drawn
## at random over the bag's tabs (the clothes more often than the arms),
## his own old outfits ([member GARBS], the heroes' renowned garb, §5.3) and
## the arms' rarer styles less often. Empty when he has everything.
func roll_loot(rng: RandomNumberGenerator) -> Dictionary:
	_start_kit()
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	var was := _tab
	for tab: int in LOOT_TABS:
		_tab = tab
		for item: Dictionary in _all_items():
			var key := key_of(item)
			if key == "" or item.get("worn", false) or player.owns(key):
				continue
			var w := 1.0 if tab == Tab.ATTIRE else 0.6
			if item.has("gid"):
				w = 0.15
			elif item.has("blade") or item.has("bow"):
				var style := PolysplitLook.style_of(String(item.get("blade", item.get("bow", ""))))
				if style not in ["", "normal"]:
					w *= 0.35
			var found := item.duplicate()
			found["tab"] = tab
			found["loot_key"] = key
			pool.append(found)
			weights.append(w)
	_tab = was
	if pool.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += w
	var pick := rng.randf() * total
	for i in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


## The picture of a found thing (its baked one, or the arm's), or null.
func picture_of(item: Dictionary) -> Texture2D:
	if item.has("pic"):
		return _picture(String(item.pic))
	if item.has("art"):
		return _arm_art(String(item.art))
	return null
#endregion


#region What he has
## The things in the bag under the open tab: what he wears or holds is on
## him, in the sockets beside him, not in the bag (the user's word,
## 2026-10-07); his clothes in order, head, body, cloak, legs.
func _items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_start_kit()
	for item: Dictionary in _all_items():
		if item.get("worn", false):
			_claim(item)
		elif everything or _has(item):
			out.append(item)
	if _tab == Tab.ATTIRE:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 1)) < int(b.get("order", 1)))
	return out


## The things under the open tab, worn or not, each a dictionary: name, kind,
## icon, the lines of numbers, a line of text, and whether it is on him.
func _all_items() -> Array[Dictionary]:
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
			# his model's own outfits, when he wears his model (on his own
			# figure they are not on him)
			var garbs := _garbs() if not _wears_own_figure() else []
			for i in garbs.size():
				var info: Dictionary = GARBS.get(StringName(garbs[i]), {})
				out.append({
					"name": info.get("name", String(garbs[i])), "kind": info.get("kind", "Outfit"),
					"icon": "garb", "colour": info.get("colour", Color(0.4, 0.4, 0.35)), "garb": i,
					"gid": String(garbs[i]), "order": 1,
					"worn": player.garb == i, "stats": info.get("stats", []), "text": info.get("text", ""),
				})
			# The skeletons' clothes, on his own figure (YOUR OWN) only: the
			# kit is made for its skeleton ([SkeletonGarb]).
			if _wears_own_figure():
				var look := _look()
				out.append_array(_own_pieces(look))
				for id: String in SkeletonGarb.PIECES:
					var piece: Array = SkeletonGarb.PIECES[id]
					var paint: Array = PackCreature.MATERIALS[String(piece[4])]
					out.append({
						"name": piece[2], "kind": piece[3], "icon": "garb", "colour": paint[0], "sk": id,
						"pic": GARB_ART + id + ".png",
						"order": {"sk_head": 0, "sk_top": 1, "sk_bottom": 3, "sk_feet": 4}[String(piece[0])],
						"worn": String(look.get(String(piece[0]), "")) == id,
						"stats": [["Worn", {"sk_head": "on the head", "sk_top": "over the body",
								"sk_bottom": "on the legs", "sk_feet": "on the feet"}[String(piece[0])]],
								["From", "the barrow's dead"]],
						"text": piece[5],
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
		# still, but for the player's dragging (the user's word, 2026-10-07)
		_portrait.turn_speed = 0.0
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
	# the hero's side wide, the thing's own page narrower (the user's word,
	# 2026-10-07), the hero as big as the side lets him be
	var right_w := clampf(screen.x * 0.34, 420.0, 560.0)
	_pv = PORTRAIT * minf(1.0, (right_w - 2.0 * (EQUIP + 56.0)) / PORTRAIT.x)
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
	var keys := [["◂ ▸ ▴ ▾", "choose"], ["Q / E", "tab"], ["Enter", "put on / take off"], ["drag", "turn him"],
			["I", "close"]]
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
		_portrait.position = right.position + Vector2((right.size.x - _pv.x) * 0.5, 52.0)
		_portrait.size = _pv
		_portrait_rect = Rect2(_portrait.position, _pv)


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
	var rows := GRID_ROWS
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
	# the scroll bar, in the frame's margin right of the grid
	var all_rows := ceili(float(items.size()) / COLUMNS)
	_bar_rect = Rect2()
	if all_rows > rows:
		var track := Rect2(inner.end.x + 10.0, _slots_rect.position.y, 6.0, _slots_rect.size.y - SLOT_GAP)
		_bar_rect = track
		c.draw_rect(track, Color(0, 0, 0, 0.45))
		var h := maxf(track.size.y * float(rows) / all_rows, 24.0)
		var at := track.position.y + (track.size.y - h) * float(_top_row) / float(all_rows - rows)
		c.draw_rect(Rect2(track.position.x, at, track.size.x, h), Color(GOLD, 0.75 if _bar_drag else 0.5))


## The rows put where the bar is pressed at height `y`.
func _scroll_to_bar(y: float) -> void:
	var last := maxi(ceili(float(_items().size()) / COLUMNS) - GRID_ROWS, 0)
	var f := clampf((y - _bar_rect.position.y) / maxf(_bar_rect.size.y, 1.0), 0.0, 1.0)
	_follow = false
	_top_row = clampi(roundi(f * last), 0, last)
	_root.queue_redraw()


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


## His own clothes, piece by piece (the user's word, 2026-10-06): the coat
## and the breeches of each of his classes, every hat, and the cloaks,
## capes, shawls and the like his classes wear, each its own thing in the bag
## (its picture baked by tools/bake_own_garb_icons.gd; a hat or a cloak with
## none for his figure is left out). Put on, a coat takes the place of a
## skeleton's coat on him.
func _own_pieces(look: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hero: Variant = player.rig.get(&"polysplit_hero") if player.rig != null else null
	if not hero is StringName or look.is_empty():
		return out
	var g := String(look.get("g", "m"))
	var pic := func(key: String) -> String: return GARB_ART + "own_%s_%s_%s.png" % [hero, g, key]
	for cls: String in PolysplitLook.classes(hero, g):
		var outfit := String(PolysplitLook.CLASS_NAMES.get(cls, cls)).capitalize()
		for part: String in ["top", "bottom"]:
			out.append({
				"name": "%s's %s" % [outfit, "Coat" if part == "top" else "Breeches"],
				"kind": "Coat" if part == "top" else "Breeches", "icon": "garb", "colour": Color(0.55, 0.5, 0.42),
				"own": part, "key": cls, "pic": pic.call("%s_%s" % [part, cls]), "order": 1 if part == "top" else 3,
				"worn": String(look.get(part, "")) == cls and not look.get("bare_" + part, false)
						and not (part == "top" and look.has("sk_top")),
				"stats": [["Worn", "over the body" if part == "top" else "on the legs"], ["Outfit", outfit]],
				"text": "His own, as he came: the %s of the %s's outfit." % [
						"coat" if part == "top" else "breeches", outfit.to_lower()],
			})
	for cls: String in PolysplitLook.classes(hero, g):
		var outfit := String(PolysplitLook.CLASS_NAMES.get(cls, cls)).capitalize()
		var on_feet := String(look.get("feet", look.get("bottom", "")))
		out.append({
			"name": "%s's Boots" % outfit, "kind": "Boots", "icon": "garb", "colour": Color(0.55, 0.5, 0.42),
			"own": "feet", "key": cls, "pic": pic.call("feet_" + cls), "order": 4,
			"worn": on_feet == cls and not look.has("sk_feet"),
			"stats": [["Worn", "on the feet"], ["Outfit", outfit]],
			"text": "His own, as he came: the boots of the %s's outfit." % outfit.to_lower(),
		})
	# the sandals and the wraps made for the bare feet (the user's word,
	# 2026-10-07)
	for kind: String in UnderGarb.FOOTWEAR:
		var info: Dictionary = UnderGarb.FOOTWEAR[kind]
		out.append({
			"name": info.name, "kind": info.kind, "icon": "garb", "colour": Color(0.55, 0.3, 0.3),
			"own": "feet", "key": kind, "pic": pic.call("shoe_" + kind), "order": 4,
			"worn": String(look.get("feet", "")) == kind and not look.has("sk_feet"),
			"stats": [["Worn", "on the feet"]], "text": info.text,
		})
	for hat: String in PolysplitLook.HAT_ORDER:
		var path: String = pic.call("hat_" + hat)
		if not ResourceLoader.exists(path):
			continue
		out.append({
			"name": String(PolysplitLook.HATS[hat]["name"]).capitalize(), "kind": "Hat", "icon": "garb",
			"colour": Color(0.55, 0.5, 0.42), "own": "hat", "key": hat, "pic": path, "order": 0,
			"worn": String(look.get("hat", "")) == hat and not look.has("sk_head"),
			"stats": [["Worn", "on the head"]],
			"text": "A %s, as the maker has them." % String(PolysplitLook.HATS[hat]["name"]).to_lower(),
		})
	for x: String in PolysplitLook.extras(hero, g):
		if not _is_cloth(x):
			continue
		var path: String = pic.call("x_" + x)
		if not ResourceLoader.exists(path):
			continue
		out.append({
			"name": _extra_name(x), "kind": "Cloak and the like", "icon": "garb", "colour": Color(0.55, 0.5, 0.42),
			"own": "extra", "key": x, "pic": path, "order": 4 if x.ends_with("_shoes") else 2,
			"worn": (look.get("extras", []) as Array).has(x),
			"stats": [["Worn", "over his clothes"]],
			"text": "Part of his outfit, to wear or to leave off.",
		})
	return out


static func _cloakish(x: String) -> bool:
	return x.contains("cape") or x.contains("cloak") or x.contains("shawl") or x.contains("mantle")


## An extra of his outfits that is clothing (a cape, a cloak, a shawl, a
## scarf, pauldrons...), not what carries his arms (a scabbard, a quiver).
static func _is_cloth(x: String) -> bool:
	for word in ["scabbard", "sheathed", "quiver", "dagger"]:
		if x.contains(word):
			return false
	return true


static func _extra_name(x: String) -> String:
	var cls := x.get_slice("_", 0)
	var thing := x.substr(cls.length() + 1)
	var names := {"cape": "Cape", "cloak": "Cloak", "shawl": "Shawl", "scarf": "Scarf", "neckscarf": "Neck Scarf",
			"choker": "Choker", "pauldrons": "Pauldrons", "skirt": "Skirt", "shoes": "Shoes", "slingbag": "Sling Bag"}
	return "%s's %s" % [String(PolysplitLook.CLASS_NAMES.get(cls, cls)).capitalize(), names.get(thing, thing.capitalize())]


## A picture by its path (the clothes' own), loaded once; null for none.
func _picture(path: String) -> Texture2D:
	if path == "":
		return null
	if _arts.has(path):
		return _arts[path]
	var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
	_arts[path] = tex
	if tex != null:
		get_tree().create_timer(0.05).timeout.connect(_root.queue_redraw)
	return tex


## What he wears and holds, socket by socket: [slot, label, item-like
## dictionary (name, icon, pic or art, colour) or {} for nothing]. Head, body
## and legs; weapon, off hand and cloak.
func _equipped() -> Array:
	var look := _look()
	var own := _wears_own_figure()
	var hero: Variant = player.rig.get(&"polysplit_hero") if player.rig != null else null
	var g := String(look.get("g", "m"))
	var out: Array = []
	for slot: Array in [["sk_head", "HEAD", "hat"], ["sk_top", "BODY", "top"], ["sk_bottom", "LEGS", "bottom"],
			["sk_feet", "FEET", "feet"]]:
		var thing := {}
		var id := String(look.get(String(slot[0]), "")) if own else ""
		var part := String(slot[2])
		if SkeletonGarb.PIECES.has(id):
			var piece: Array = SkeletonGarb.PIECES[id]
			thing = {"name": piece[2], "icon": "garb", "pic": GARB_ART + id + ".png", "sk": id,
					"colour": (PackCreature.MATERIALS[String(piece[4])] as Array)[0]}
		elif own and part == "feet" and String(look.get("feet", look.get("bottom", ""))) != "":
			var cls := String(look.get("feet", look.get("bottom", "")))
			thing = {"name": "%s's Boots" % String(PolysplitLook.CLASS_NAMES.get(cls, cls)).capitalize(), "icon": "garb",
					"colour": Color(0.55, 0.5, 0.42), "pic": GARB_ART + "own_%s_%s_feet_%s.png" % [hero, g, cls]}
			if UnderGarb.FOOTWEAR.has(cls):
				thing = {"name": UnderGarb.FOOTWEAR[cls].name, "icon": "garb", "colour": Color(0.55, 0.3, 0.3),
						"pic": GARB_ART + "own_%s_%s_shoe_%s.png" % [hero, g, cls]}
		elif own and part != "feet" and String(look.get(part, "")) != "" and not look.get("bare_" + part, false):
			var key := String(look[part])
			var label := String(PolysplitLook.HATS.get(key, {}).get("name", key)).capitalize() if part == "hat" \
					else "%s's %s" % [String(PolysplitLook.CLASS_NAMES.get(key, key)).capitalize(),
							"Coat" if part == "top" else "Breeches"]
			thing = {"name": label, "icon": "garb", "colour": Color(0.55, 0.5, 0.42),
					"pic": GARB_ART + "own_%s_%s_%s_%s.png" % [hero, g, part, key]}
		elif not own and part == "top":
			var garbs := _garbs()
			if not garbs.is_empty():
				var info: Dictionary = GARBS.get(StringName(garbs[player.garb]), {})
				thing = {"name": info.get("name", garbs[player.garb]), "icon": "garb",
						"colour": info.get("colour", Color(0.5, 0.5, 0.45))}
		out.append([slot[0], slot[1], thing])
	var p := player.profile
	var w := String(look.get("w", ""))
	var held := {}
	if w != "" and w != "none":
		held = {"name": PolysplitLook.arm_name(w) if w != "own_bow" else "His own bow", "icon": "sword", "art": w}
	elif p != null and look.is_empty():
		held = _weapon(p)
	out.append(["w", "WEAPON", held])
	var o := String(look.get("o", ""))
	var other := {}
	if o == "his_shield" or (look.is_empty() and _has_shield() and _shield_on()):
		var tower := player.shield_kind == Shields.TOWER
		other = {"name": "Tower Shield" if tower else "Round Shield", "icon": "tower" if tower else "round",
				"art": "his_tower_shield" if tower else "his_shield"}
	elif o != "" and o != "none":
		other = {"name": PolysplitLook.arm_name(o), "icon": "sword", "art": o}
	out.append(["o", "OFF HAND", other])
	var cloak := {}
	if own:
		# the cloak itself before a choker or a scarf worn with it
		var on: Array = (look.get("extras", []) as Array).filter(func(x: Variant) -> bool: return _is_cloth(String(x)))
		on.sort_custom(func(a: Variant, b: Variant) -> bool: return _cloakish(String(a)) and not _cloakish(String(b)))
		for x: Variant in on:
			if true:
				cloak = {"name": _extra_name(String(x)), "icon": "garb", "colour": Color(0.55, 0.5, 0.42),
						"pic": GARB_ART + "own_%s_%s_x_%s.png" % [hero, g, String(x)], "extra": String(x)}
				break
	out.append(["cloak", "CLOAK", cloak])
	return out


## A socket beside him clicked: what is in it comes off him and into the bag.
func _take_off_slot(slot: String) -> void:
	var look := _look()
	match slot:
		"w":
			_hands_empty()
		"o":
			if _is_blade(String(look.get("o", ""))):
				_left_hand_empty()
			else:
				take_off()
		_:
			if look.is_empty():
				return
			match slot:
				"sk_head":
					if look.has("sk_head"):
						look.erase("sk_head")
					else:
						look["hat"] = ""
				"sk_top":
					if look.has("sk_top"):
						look.erase("sk_top")
					else:
						look["bare_top"] = true
				"sk_bottom":
					if look.has("sk_bottom"):
						look.erase("sk_bottom")
					else:
						look["bare_bottom"] = true
				"sk_feet":
					if look.has("sk_feet"):
						look.erase("sk_feet")
					else:
						look["feet"] = ""
				"cloak":
					var worn: Array = (look.get("extras", []) as Array).duplicate()
					for x: Variant in worn:
						if _is_cloth(String(x)):
							worn.erase(x)
							break
					look["extras"] = worn
			player.set_look(look)
	_dress_portrait()
	_root.queue_redraw()


## The sockets beside him: three on his left (head, body, legs), his two
## hands and his cloak on his right; what is in each drawn, its name under
## it. A click on one takes it off.
func _draw_equipped(c: Control, area: Rect2) -> void:
	_equip_rects.clear()
	var things := _equipped()
	for k in things.size():
		var entry: Array = things[k]
		var left := k < 4
		var row := k if left else k - 4
		var x := area.position.x if left else area.end.x - EQUIP
		var y := area.position.y + 6.0 + row * (EQUIP + 40.0)
		var r := Rect2(x, y, EQUIP, EQUIP)
		var thing: Dictionary = entry[2]
		UiArt.text(c, Vector2(r.position.x - 10.0, r.position.y - 4.0), String(entry[1]), 10, Color(GOLD, 0.85),
				"head", HORIZONTAL_ALIGNMENT_CENTER, EQUIP + 20.0)
		UiArt.draw_frame(c, r, "socket_lit" if not thing.is_empty() else "socket", 6.0)
		if not thing.is_empty():
			_glyph(c, r.grow(-6.0), thing)
			var caption := String(thing.get("name", ""))
			if caption.length() > 13:
				caption = caption.substr(0, 12) + "…"
			UiArt.text(c, Vector2(r.position.x - 14.0, r.end.y + 13.0), caption, 10, Color(CREAM, 0.8), "body",
					HORIZONTAL_ALIGNMENT_CENTER, EQUIP + 28.0)
			_equip_rects.append([r, String(entry[0])])


## The small gold diamond with an E: in his hands, or on him.
func _worn_mark(c: Control, at: Vector2) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(10, 0), at + Vector2(0, 10),
			at + Vector2(-10, 0)]), Color(0.12, 0.09, 0.04))
	c.draw_polyline(PackedVector2Array([at + Vector2(0, -10), at + Vector2(10, 0), at + Vector2(0, 10),
			at + Vector2(-10, 0), at + Vector2(0, -10)]), GOLD, 1.5)
	UiArt.text(c, at + Vector2(-10, 5), "E", 12, UiArt.GOLD_LIGHT, "title", HORIZONTAL_ALIGNMENT_CENTER, 20.0)


## A thing's picture in `rect`: its glyph, tinted, or the drawn one.
func _glyph(c: Control, rect: Rect2, item: Dictionary) -> void:
	var art := _picture(String(item.get("pic", ""))) if item.has("pic") else _arm_art(String(item.get("art", "")))
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
	# the name smaller till it fits beside the picture (the page is narrower)
	var title_px := 30
	while title_px > 18 and UiArt.font("title").get_string_size(String(item.name), HORIZONTAL_ALIGNMENT_LEFT, -1,
			title_px).x > text_w:
		title_px -= 2
	UiArt.text_shadowed(c, Vector2(box.position.x, y + 30), String(item.name), title_px, CREAM, "title", 
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
	elif item.has("sk") or (item.has("own") and String(item.own) == "hat"):
		status = "Enter / click to take it off" if worn else "Enter / click to put it on"
	elif (item.has("garb") or item.has("bow") or item.has("own")) and not worn:
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
	# what he wears and holds, in sockets either side of him
	_draw_equipped(c, Rect2(box.position.x + 24.0, box.position.y + 58.0, box.size.x - 48.0, _pv.y))
	# the hero stands here (the portrait), on a pool of light
	var stand := Vector2(box.position.x + box.size.x * 0.5, box.position.y + 52 + _pv.y * 0.92)
	c.draw_set_transform(stand, 0.0, Vector2(1.0, 0.22))
	for k in range(6, 0, -1):
		c.draw_circle(Vector2.ZERO, 30.0 + 14.0 * k, Color(GOLD, 0.03))
	c.draw_arc(Vector2.ZERO, 92.0 * _pv.x / 216.0, 0.0, TAU, 48, Color(GOLD, 0.5), 1.5)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	y = box.position.y + 52 + _pv.y + 22
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
		var garbs := _garbs() if not _wears_own_figure() else []
		if not garbs.is_empty():
			rows.append(["Attire", String(GARBS.get(StringName(garbs[player.garb]), {}).get("name", garbs[player.garb]))])
		if _has_shield():
			rows.append(["Shield", ("Round Shield" if player.shield_kind == Shields.ROUND else "Tower Shield")
					if _shield_on() else "None"])
	# two columns under him (the user's word, 2026-10-07: the hero bigger,
	# the numbers lower): his level and his life on the left, the rest right
	var split := 0
	var seps := 0
	for k in rows.size():
		if String(rows[k][0]) == "":
			seps += 1
			if seps == 2:
				split = k
				break
	var col_w := (w - 28.0) * 0.5
	if split > 0:
		_stat_rows(c, rows.slice(0, split), x, y, col_w)
		_stat_rows(c, rows.slice(split + 1), x + col_w + 28.0, y, col_w)
	else:
		_stat_rows(c, rows, x, y, w)


## The status rows from `y` down, `w` wide at `x`.
func _stat_rows(c: Control, rows: Array, x: float, y: float, w: float) -> void:
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
		UiArt.text(c, Vector2(x, y), String(r[0]), 15, MUTED, "body")
		UiArt.text(c, Vector2(x, y), String(r[1]), 15, CREAM, "bold", HORIZONTAL_ALIGNMENT_RIGHT, w)


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
