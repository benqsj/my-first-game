class_name PortalEvent
extends Node3D

## The portal's other quiet place (the user's word, 2026-10-22; the
## merchant taken out, 2026-10-26), put in between the steps as the spring
## and the prisoners are ([RestSpot]): no creatures, the way on open at once,
## and not a step of the run.
##
## * **altar** ("სამსხვერპლო") — two altars, one or the other: blood (a
##   fifth of his life, for good this run, for a blessing) or gold (half of
##   it, for a blade heavier by a fifth).
##
## The host decides every deal ([method host_deal]): the gold is its to take.
## A hero on another peer asks through the [Dungeon] ([method Dungeon.net_ask_deal]);
## what is bought is put on him by his own game ([method deal_done]).

const NEAR := 1.9
const BLOOD := Color(0.85, 0.08, 0.1)
const GOLD := Color(1.0, 0.76, 0.25)
## The altar of blood takes this share of his life; the altar of gold this
## share of his gold (at least `GOLD_LEAST`), for a blade heavier by `GOLD_BLADE`.
const BLOOD_SHARE := 0.2
const GOLD_SHARE := 0.5
const GOLD_LEAST := 3
const GOLD_BLADE := 1.2

var kind: String = ""
var _d: Dungeon
## What is on offer: [{"id", "at", "node", "sold"}], the two altars as
## "blood" and "gold".
var _deals: Array = []
var _used: bool = false
var _near: int = -1
var _layer: CanvasLayer
var _prompt: Label
## Deals made (tests).
var done: Array[String] = []


## The place `what` in `room` (its index `i`): the ring of standing stones
## in the pine wood ([AltarCircle], 2026-10-26), the two altars on its dais.
static func build(d: Dungeon, room: Node3D, i: int, what: String) -> void:
	var r := d._room(i)
	var ev := PortalEvent.new()
	ev.name = "Event"
	ev.kind = what
	ev._d = d
	room.add_child(ev)
	var got := AltarCircle.build(d, room, float(r["w"]), float(r["l"]), d._rng, ev)
	ev._build_altar(got)
	ev._ui()


#region The altar
## The two altars' deals: the crimson crystal (blood) and the bowl of molten
## gold, each with its light and its words over it.
func _build_altar(got: Dictionary) -> void:
	for k in 2:
		var id := "blood" if k == 0 else "gold"
		var tint := BLOOD if k == 0 else GOLD
		var at := AltarCircle.BLOOD_AT if k == 0 else AltarCircle.GOLD_AT
		var light := OmniLight3D.new()
		light.light_color = tint.lerp(Color.WHITE, 0.15)
		light.light_energy = 1.8
		light.omni_range = 6.5
		light.position = at + Vector3(0.0, 2.0, 0.0)
		light.set_meta(&"designed_shadow", false)
		add_child(light)
		var words := "სისხლის სამსხვერპლო\nსიცოცხლის 20% → კურთხევა" if k == 0 \
				else "ოქროს სამსხვერპლო\nოქროს ნახევარი → ხმალი +20%"
		var tag := _label(words, tint.lerp(Color.WHITE, 0.45), 32)
		tag.position = at + Vector3(0.0, 3.3, 0.0)
		_deals.append({"id": id, "at": at + Vector3(0.0, 0.0, 1.6), "node": got.get(id), "tag": tag, "light": light, "sold": false})
	var note := _label("მხოლოდ ერთი", Color(0.9, 0.85, 0.8), 26)
	note.position = Vector3(0.0, 2.1, 0.4)
#endregion


#region Dealing
func _hero() -> Player:
	for hero in _d._heroes():
		if hero.is_multiplayer_authority() and not hero.is_dead:
			return hero
	return null


func _process(_delta: float) -> void:
	if _d == null or _prompt == null:
		return
	var hero := _hero()
	_near = -1
	if hero != null and not (kind == "altar" and _used):
		for k in _deals.size():
			var deal: Dictionary = _deals[k]
			if bool(deal["sold"]):
				continue
			var spot := to_global(deal["at"] as Vector3)
			if Vector2(hero.global_position.x - spot.x, hero.global_position.z - spot.z).length() < NEAR:
				_near = k
				break
	_prompt.visible = _near >= 0
	if _near >= 0:
		_prompt.text = _words(_near, hero)


func _words(k: int, hero: Player) -> String:
	var id := String(_deals[k]["id"])
	var purse := Purse.of(hero)
	var have := purse.gold if purse != null else 0
	match id:
		"blood":
			return "[F]  შესწირე სიცოცხლის 20%% — მიიღე კურთხევა"
		"gold":
			if have < GOLD_LEAST:
				return "ოქრო არ გყოფნის (საჭიროა %d, გაქვს %d)" % [GOLD_LEAST, have]
			return "[F]  შესწირე %d ოქრო — ხმალი +20%%" % _gold_price(have)
	return ""


static func _gold_price(have: int) -> int:
	return maxi(int(ceil(float(have) * GOLD_SHARE)), GOLD_LEAST)


func _unhandled_input(event: InputEvent) -> void:
	if _near < 0 or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	interact()


## [F] on the deal he stands at (tests call it too).
func interact() -> void:
	var hero := _hero()
	if hero == null or _near < 0:
		return
	if _d.decides():
		host_deal(_near, hero)
	else:
		_d.net_ask_deal.rpc_id(1, _near, hero.get_path())


## Host: deal `k` for `hero`, if he can pay for it.
func host_deal(k: int, hero: Player) -> void:
	if hero == null or k < 0 or k >= _deals.size() or bool(_deals[k]["sold"]) or (kind == "altar" and _used):
		return
	var id := String(_deals[k]["id"])
	var purse := Purse.of(hero)
	match id:
		"blood":
			pass
		"gold":
			if purse == null or purse.gold < GOLD_LEAST:
				return
			purse.take(_gold_price(purse.gold))
		_:
			return
	if id == "blood":
		# its three lights, before the altar
		_d.lay_lights(to_global(Vector3(0.0, 0.0, 3.5)))
	if _d.online():
		_d.net_deal_done.rpc(k, hero.get_path())
	else:
		deal_done(k, hero)


## On every peer: deal `k` made by `hero`; on his own, put on him.
func deal_done(k: int, hero: Player) -> void:
	if k < 0 or k >= _deals.size():
		return
	var deal: Dictionary = _deals[k]
	var id := String(deal["id"])
	deal["sold"] = true
	done.append(id)
	_d.deals_made.append(id)
	_used = true
	for other: Dictionary in _deals:
		var light := other.get("light") as OmniLight3D
		if light != null:
			create_tween().tween_property(light, "light_energy", 0.25 if other != deal else 3.0, 0.6)
		(other["tag"] as Node3D).visible = false
	var tint: Color = BLOOD if id == "blood" else GOLD
	if hero != null and _d.mine(hero):
		_put_on(hero, id)
	if hero != null:
		var world := Blood.world_of(self)
		if world != null:
			SkillFx.burst(world, hero.global_position + Vector3.UP * 1.2, tint, 50,
					Vector2(1.0, 3.5), Vector3.UP, 180.0, Vector2(0.06, 0.16), Vector3(0, 1.0, 0), 1.3)
		Sfx.play(_d, Dungeon.SND + "portal_open.wav", null, hero.global_position + Vector3.UP, 1.5, -6.0)
	var said := "შეწირულია"
	if id == "blood":
		said += " — აირჩიე კურთხევა"
	_d._say(said, 3.0)


func _put_on(hero: Player, id: String) -> void:
	match id:
		"blood":
			hero.max_health *= 1.0 - BLOOD_SHARE
			if hero.profile != null:
				hero.profile.max_health = hero.max_health
			hero.health = minf(hero.health, hero.max_health)
		"gold":
			var book := hero.get_node_or_null("Leveling") as Leveling
			if book != null:
				book.boost_blows(GOLD_BLADE)
#endregion


#region Bits
func _ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.64
	_prompt.offset_left = -380
	_prompt.offset_right = 380
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.hide()
	_layer.add_child(_prompt)


func _label(text: String, tint: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = tint
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	return l
#endregion
