class_name PolysplitLook
extends RefCounted
## A hero made on the hero select out of Polysplit's Low-Poly Medieval Fantasy
## Heroes (Basic Pack): which class's clothes, which face, hair, beard and hat,
## which colours and which arms. One Dictionary (a "look") says it all; it is
## kept per hero ([Game]), sent to the other peers, and laid onto the figure
## by `apply()`.
##
## The figure (assets/polysplit/<hero>_<m|f>.glb, vepxis-art
## tools/ps_creator.py) carries every part of the pack as a mesh of its own,
## named for what it is (see there); a look shows some and hides the rest.
##
##   g        "m" / "f"
##   cls      the class it started from (sets the clothes, hat and arms)
##   eyes brows mouth   0..4
##   beard    0 (none), 1..8 — men only
##   hair     0 (none), 1..14
##   top bottom         a class's id, or "" for the bare body
##   extras   [ids]: what else a class wears (capes, scabbards...)
##   hat      an id of `HATS`, or ""
##   skin     1..8  (the pack's body colours: skin, hair, eyes)
##   cloth    1..14 (its object colours: clothes, arms)
##   w o      the arms in the sword hand and the other (see `ARMS`, `AW`)
##   ws       the style the Advanced Weapons are worn in (`STYLES`)

const SKINS := 8
const CLOTHS := 14
const COLOURS := "res://assets/polysplit/colors/"
const PREFIX := "ps_"

## The pack's classes, as its files dress them (tools/ps_creator.py writes
## the same into assets/polysplit/catalog_<g>.json), by gender.
const CLASSES := {
	"m": {
		"swordsman": {"extras": ["swordsman_swordscabbard"], "hat": "skullcap", "weapon": "sword_a"},
		"fighter": {"extras": ["fighter_swordscabbard"], "hat": "headband", "weapon": "sword_a"},
		"knight": {"extras": ["knight_greatswordscabbard", "knight_neckscarf", "knight_pauldrons",
				"knight_swordsheathed"], "hat": "greathelm", "weapon": "greatsword"},
		"archer": {"extras": ["archer_arrowquiver", "archer_cape"], "hat": "tyrolean", "weapon": "bow"},
		"hunter": {"extras": ["hunter_arrowquiver", "hunter_dagger_sheathed_r"], "hat": "felted", "weapon": "bow"},
		"rogue": {"extras": ["rogue_daggerscabbard_l", "rogue_daggerscabbard_r"], "hat": "eyepatch",
				"weapon": "dagger", "off": "dagger"},
		"mage": {"extras": ["mage_slingbag"], "hat": "magehat_a", "weapon": "staff_a"},
		"sorcerer": {"extras": ["sorcerer_cloak", "sorcerer_shoes"], "hat": "bishop", "weapon": "staff_a"},
		"warlock": {"extras": ["warlock_cape"], "hat": "hood", "weapon": "staff_a"},
	},
	"f": {
		"swordsman": {"extras": ["swordsman_swordscabbard"], "hat": "kettle", "weapon": "sword_a"},
		"fighter": {"extras": ["fighter_swordscabbard"], "hat": "leathercoif", "weapon": "sword_a"},
		"knight": {"extras": ["knight_daggerscabbard", "knight_pauldrons", "knight_skirt", "knight_swordscabbard"],
				"hat": "armet", "weapon": "sword_a"},
		"archer": {"extras": ["archer_arrowquiver", "archer_cape"], "hat": "bycocket", "weapon": "bow"},
		"hunter": {"extras": ["hunter_arrowquiver"], "hat": "beret", "weapon": "bow"},
		"rogue": {"extras": ["rogue_daggerscabbard"], "hat": "facemask", "weapon": "dagger", "off": "dagger"},
		"mage": {"extras": ["mage_cape", "mage_scarf"], "hat": "magehat_b", "weapon": "staff_a"},
		"sorcerer": {"extras": ["sorcerer_shawl", "sorcerer_shoes"], "hat": "circlet", "weapon": "staff_a"},
		"witch": {"extras": ["witch_cape", "witch_choker"], "hat": "witchhat", "weapon": "staff_a"},
	},
}
const CLASS_NAMES := {
	"swordsman": "SWORDSMAN", "fighter": "FIGHTER", "knight": "KNIGHT", "archer": "ARCHER", "hunter": "HUNTER",
	"rogue": "ROGUE", "mage": "MAGE", "sorcerer": "SORCERER", "warlock": "WARLOCK", "witch": "WITCH",
}
## Each hero's own classes (shown as OUTFIT on the hero select: they are the
## pack's clothes, nothing more): the only ones he is offered (2026-10-02, the
## user's word: every hero his own body and clothes; hats and arms are free).
## The knight's are the warrior's alone (2026-10-03).
const HERO_CLASSES := {
	&"tariel": ["swordsman", "fighter"],
	&"warrior": ["knight"],
	&"rogue": ["rogue"],
	&"avtandil": ["archer", "hunter"],
	&"mage": ["mage", "sorcerer", "warlock", "witch"],
}
const CLASS_ORDER := ["swordsman", "fighter", "knight", "archer", "hunter", "rogue", "mage", "sorcerer",
		"warlock", "witch"]

## The headwear: what it is called, how much of the hair shows under it ("full":
## all of it, "b": the pack's cut for under a hat, "none"), and whether the
## beard and the face show.
const HATS := {
	"skullcap": {"name": "SKULL CAP AND COIF", "hair": "b"},
	"headband": {"name": "HEADBAND", "hair": "full"},
	"greathelm": {"name": "GREAT HELM", "hair": "none", "beard": false, "face": false},
	"armet": {"name": "ARMET", "hair": "none", "beard": false, "face": false},
	"kettle": {"name": "KETTLE HAT", "hair": "b"},
	"leathercoif": {"name": "LEATHER COIF", "hair": "none"},
	"tyrolean": {"name": "TYROLEAN HAT", "hair": "b"},
	"bycocket": {"name": "BYCOCKET", "hair": "b"},
	"felted": {"name": "FELTED HAT", "hair": "b"},
	"beret": {"name": "BERET", "hair": "b"},
	"eyepatch": {"name": "EYEPATCH", "hair": "full"},
	"facemask": {"name": "FACE MASK", "hair": "full", "beard": false, "mouth": false},
	"circlet": {"name": "CIRCLET", "hair": "full"},
	"magehat_a": {"name": "MAGE'S HAT", "hair": "b"},
	"magehat_b": {"name": "WIDE MAGE'S HAT", "hair": "b"},
	"bishop": {"name": "BISHOP'S HAT", "hair": "b"},
	"hood": {"name": "HOOD", "hair": "b"},
	"witchhat": {"name": "WITCH'S HAT", "hair": "b"},
}
const HAT_ORDER := ["skullcap", "headband", "kettle", "leathercoif", "greathelm", "armet", "tyrolean", "bycocket",
		"felted", "beret", "eyepatch", "facemask", "circlet", "hood", "magehat_a", "magehat_b", "bishop", "witchhat"]

## What each hero can hold: "w" the sword hand, "o" the other — any of the
## pack's arms his figure has a bone for (Avtandil has only his bow's), his
## class's first. An id is a
## figure mesh "ps_w_<id>" / "ps_o_<id>", but for "his_shield" (the hero's
## own, the one his bag says he carries: "ps_shield" / "ps_tower_shield"),
## "own_bow" (Avtandil's own, which bends: "ps_arm_bow") and "none". The mage
## holds a sword (2026-10-02, the user's word), a staff in the other hand if
## he will.
const ARMS := {
	&"tariel": {"w": ["sword_a", "sword_b", "greatsword", "dagger"], "o": ["his_shield", "shield", "none"]},
	&"warrior": {"w": ["greatsword", "sword_a", "sword_b", "dagger"], "o": ["none"]},
	&"rogue": {"w": ["dagger", "sword_a", "sword_b"], "o": ["dagger", "none"]},
	&"avtandil": {"w": ["own_bow", "bow"], "o": ["none"]},
	&"mage": {"w": ["sword_a", "sword_b", "greatsword", "dagger"], "o": ["staff_a", "staff_b", "dagger", "none"]},
}
const ARM_NAMES := {
	"sword_a": "ARMING SWORD", "sword_b": "BROAD SWORD", "greatsword": "GREAT SWORD", "dagger": "DAGGER",
	"staff_a": "STAFF", "staff_b": "CROOKED STAFF", "bow": "HUNTER'S BOW", "own_bow": "HIS OWN BOW",
	"shield": "ROUND SHIELD", "his_shield": "HIS SHIELD", "none": "NONE",
}
## What a class's extra parts are called (its id is "<class>_<part>").
const EXTRA_NAMES := {
	"swordscabbard": "SCABBARD", "greatswordscabbard": "GREAT SCABBARD", "neckscarf": "NECK SCARF",
	"pauldrons": "PAULDRONS", "swordsheathed": "SHEATHED SWORD", "arrowquiver": "QUIVER", "cape": "CAPE",
	"dagger_sheathed_r": "SHEATHED DAGGER", "daggerscabbard_l": "LEFT SHEATH", "daggerscabbard_r": "RIGHT SHEATH",
	"daggerscabbard": "SHEATH", "slingbag": "SLING BAG", "cloak": "CLOAK", "shoes": "SHOES", "skirt": "SKIRT",
	"scarf": "SCARF", "shawl": "SHAWL", "choker": "CHOKER",
}
## The figure mesh (without the prefix) the extra `id` is worn as: a class's
## scabbard gives way to the Advanced sword's (or knife's) own while one is
## in the hand it serves (a left sheath the other hand's), in its style
## ("x_aw_<scabbard>__<name>_<style>", tools/ps_creator.py aw_scabbards).
static func extra_key(look: Dictionary, id: String) -> String:
	if id.contains("scabbard"):
		var knife := id.contains("dagger")
		var held := String(look.get("o" if knife and id.ends_with("_l") else "w", ""))
		var name := aw_name(held)
		if name != "" and (name == "dagger") == knife and bool(AW.get(name, {}).get("sheath", false)):
			return "x_aw_%s__%s" % [id, held.substr(3)]
	return "x_" + id


## A blade: the cut is drawn along it (see [SkinnedRig]).
const BLADES := ["sword_a", "sword_b", "greatsword", "dagger"]

## Polysplit's Advanced Weapons (WEAPONS_PACK.md), on the mannequin's figure
## (vepxis-art tools/ps_creator.py, `AW_ARMS`): an id "aw_<name>_<style>" is
## the mesh "ps_w_<id>" (the sword hand; a bow's is the left fist) or
## "ps_o_<id>" (the other hand; a shield's is the forearm). Each is held as
## the pack holds its own, grip in the fist.
##   kind     the moves it is fought with ([Moveset]): sword, two_hands,
##            spear, knives, bow, or shield (the other hand's)
##   hands    "w", "o" or both
##   sheath   it goes into a scabbard (a sword or a knife)
const AW := {
	"shortsword": {"name": "SHORT SWORD", "kind": &"sword", "hands": "wo", "sheath": true},
	"longsword": {"name": "LONG SWORD", "kind": &"sword", "hands": "w", "sheath": true},
	"curvedsword": {"name": "CURVED SWORD", "kind": &"sword", "hands": "w", "sheath": true},
	"rapier": {"name": "RAPIER", "kind": &"sword", "hands": "w", "sheath": true},
	"greatsword": {"name": "GREAT SWORD (NEW)", "kind": &"two_hands", "hands": "w", "sheath": true},
	"curvedgreatsword": {"name": "CURVED GREAT SWORD", "kind": &"two_hands", "hands": "w", "sheath": true},
	"dagger": {"name": "KNIFE", "kind": &"knives", "hands": "wo", "sheath": true},
	"axe": {"name": "AXE", "kind": &"sword", "hands": "wo"},
	"greataxe": {"name": "GREAT AXE", "kind": &"two_hands", "hands": "w"},
	"hammer": {"name": "HAMMER", "kind": &"sword", "hands": "wo"},
	"greathammer": {"name": "GREAT HAMMER", "kind": &"two_hands", "hands": "w"},
	"mace": {"name": "MACE", "kind": &"sword", "hands": "wo"},
	"morningstar": {"name": "MORNING STAR", "kind": &"sword", "hands": "w"},
	"flail": {"name": "FLAIL", "kind": &"sword", "hands": "w"},
	"spear": {"name": "SPEAR", "kind": &"spear", "hands": "w"},
	"poleaxe": {"name": "POLEAXE", "kind": &"spear", "hands": "w"},
	"staff": {"name": "QUARTERSTAFF", "kind": &"spear", "hands": "wo"},
	"wand": {"name": "WAND", "kind": &"sword", "hands": "wo"},
	"roundshield": {"name": "BUCKLER", "kind": &"shield", "hands": "o"},
	"kiteshield": {"name": "KITE SHIELD", "kind": &"shield", "hands": "o"},
	"towershield": {"name": "TOWER SHIELD", "kind": &"shield", "hands": "o"},
	"bow": {"name": "SHORT BOW", "kind": &"bow", "hands": "w"},
	"longbow": {"name": "LONG BOW", "kind": &"bow", "hands": "w"},
}
## The pack's four styles, each its own models and colours.
## "black" is the obsidian models as first worn, before the pack's shader:
## the pre-coloured texture alone, black and dull, no glow (2026-10-03, the
## user's word: the new and the old both).
const STYLES := ["normal", "ornate", "obsidian", "black", "bone"]
## The models a style is worn in (its meshes' "<style>" in the figure).
const STYLE_MODELS := {"black": "obsidian"}
## How the pack's shader draws each style (its RGBRecolor_<Style>Weapons.mat):
## metal and gloss for the mask's R, G and B, and the imbue glow (on for
## ornate and obsidian), see shaders/aw_weapon.gdshader.
const STYLE_LOOKS := {
	"normal": {"metal": Vector3(0.0, 0.0, 0.25), "smooth": Vector3(0.0, 0.4, 0.25), "imbue": false,
			"color": Color(0.4999, 0.8472, 0.9874), "strength": 0.3, "tiling": Vector2(0.5, 0.1), "scroll": 0.6,
			"edge": 0.9},
	"ornate": {"metal": Vector3(0.0, 0.7, 0.25), "smooth": Vector3(0.0, 0.5, 0.25), "imbue": true,
			"color": Color(0.8148, 0.3372, 0.0160), "strength": 0.75, "tiling": Vector2(2.0, 6.0), "scroll": 0.5,
			"edge": 0.6},
	"obsidian": {"metal": Vector3(0.9, 0.45, 0.65), "smooth": Vector3(0.9, 0.4, 0.4), "imbue": true,
			"color": Color(0.3968, 0.0343, 0.8879), "strength": 0.57, "tiling": Vector2(1.0, 2.0), "scroll": -0.5,
			"edge": 0.9},
	"bone": {"metal": Vector3(0.0, 0.0, 0.25), "smooth": Vector3(0.0, 0.4, 0.25), "imbue": false,
			"color": Color(1.0, 0.0, 0.0), "strength": 0.5, "tiling": Vector2(2.0, 2.0), "scroll": -0.5, "edge": 0.75},
}
const AW_SHADER := "res://shaders/aw_weapon.gdshader"
const AW_MASK := "res://assets/polysplit/aw_mask.png"
static var _aw_mats: Dictionary = {}
const STYLE_NAMES := {"normal": "NORMAL", "ornate": "ORNATE", "obsidian": "OBSIDIAN", "black": "BLACK OBSIDIAN",
		"bone": "BONE"}
## What each class may hold (2026-10-03, the user's word: a class its own
## arms, to be seen in hand on the hero select; no bow for the swordsman).
## "aw_<name>" are the Advanced Weapons (worn in the look's style); the rest
## the Heroes pack's (`ARM_NAMES`), offered only to a hero who has them in
## `ARMS`. A class's first is what it starts with ([method dress] keeps the
## pack's own where the hero has it).
const CLASS_ARMS := {
	"swordsman": {
		"w": ["sword_a", "sword_b", "aw_longsword", "aw_shortsword", "aw_curvedsword", "aw_rapier", "greatsword",
				"aw_greatsword", "aw_curvedgreatsword", "dagger", "aw_dagger", "aw_axe", "aw_mace", "aw_hammer",
				"aw_morningstar", "aw_flail"],
		"o": ["his_shield", "shield", "aw_roundshield", "aw_kiteshield", "aw_towershield", "aw_dagger",
				"aw_shortsword", "none"],
	},
	"fighter": {
		"w": ["sword_a", "sword_b", "aw_axe", "aw_mace", "aw_hammer", "aw_morningstar", "aw_flail", "aw_shortsword",
				"aw_longsword", "aw_curvedsword", "greatsword", "aw_greataxe", "aw_greathammer", "aw_spear",
				"aw_poleaxe", "dagger", "aw_dagger"],
		"o": ["his_shield", "shield", "aw_roundshield", "aw_kiteshield", "aw_axe", "aw_mace", "aw_hammer",
				"aw_dagger", "none"],
	},
	"knight": {
		"w": ["greatsword", "aw_greatsword", "aw_curvedgreatsword", "aw_greataxe", "aw_greathammer", "aw_poleaxe",
				"aw_spear", "sword_a", "sword_b", "aw_longsword", "aw_mace", "aw_morningstar", "dagger"],
		"o": ["none", "aw_kiteshield", "aw_towershield", "aw_roundshield"],
	},
	"archer": {"w": ["own_bow", "bow", "aw_bow", "aw_longbow"], "o": ["none"]},
	"hunter": {"w": ["own_bow", "bow", "aw_longbow", "aw_bow"], "o": ["none"]},
	"rogue": {
		"w": ["dagger", "aw_dagger", "aw_shortsword", "aw_curvedsword", "aw_rapier", "sword_a", "sword_b"],
		"o": ["dagger", "aw_dagger", "aw_shortsword", "none"],
	},
	"mage": {
		"w": ["sword_a", "sword_b", "aw_wand", "aw_shortsword", "aw_longsword", "aw_mace", "greatsword", "dagger",
				"aw_dagger"],
		"o": ["staff_a", "staff_b", "aw_staff", "aw_wand", "dagger", "aw_dagger", "none"],
	},
}


## The Advanced Weapon's name ("longsword") in `id` ("aw_longsword_bone"), or
## "" for one of the Heroes pack's.
static func aw_name(id: String) -> String:
	if not id.begins_with("aw_"):
		return ""
	var rest := id.substr(3)
	for style: String in STYLES:
		if rest.ends_with("_" + style):
			return rest.substr(0, rest.length() - style.length() - 1)
	return rest


## `id` in `style`: an Advanced Weapon's in that style, any other as it is.
static func styled(id: String, style: String) -> String:
	var name := aw_name(id)
	return id if name == "" else "aw_%s_%s" % [name, STYLE_MODELS.get(style, style)]


## What can be held in the `slot` hand ("w" / "o") by `hero` in class `cls`,
## the Advanced Weapons in `style`. With `with` (the sword hand's) both hands'
## (a great sword, a spear or a bow), the other hand holds no shield.
static func arms(hero: StringName, cls: String, slot: String, style: String = "normal", with: String = "") -> Array:
	var own: Array = (ARMS.get(hero, ARMS[&"tariel"]) as Dictionary)[slot]
	var given: Array = (CLASS_ARMS.get(_arms_class(cls), {}) as Dictionary).get(slot, [])
	var out: Array = []
	for id: String in given:
		if id.begins_with("aw_"):
			if String(AW.get(id.substr(3), {}).get("hands", "")).contains(slot):
				out.append(styled(id, style))
		elif own.has(id):
			out.append(id)
	if out.is_empty():
		out = own.duplicate()
	if slot == "o" and both_hands(with):
		var free := out.filter(func(id: String) -> bool: return kind(id) != &"shield")
		if not free.is_empty():
			out = free
		if out.has("none"):
			# (what such a look falls back to: the hand left free)
			out.erase("none")
			out.push_front("none")
	return out


## Whether `w` takes both hands (or one and the arm for a bow's string).
static func both_hands(w: String) -> bool:
	return kind(w) in [&"two_hands", &"spear", &"bow"]


static func _arms_class(cls: String) -> String:
	return "mage" if cls in ["sorcerer", "warlock", "witch"] else cls


## The moves `id` is fought with ([Moveset] sets).
static func kind(id: String) -> StringName:
	var name := aw_name(id)
	if name != "":
		return AW.get(name, {}).get("kind", &"sword")
	match id:
		"greatsword":
			return &"two_hands"
		"dagger":
			return &"knives"
		"bow", "own_bow":
			return &"bow"
		"staff_a", "staff_b":
			return &"spear"
		"shield", "his_shield":
			return &"shield"
	return &"sword"


## Whether the cut is drawn off `id`'s mesh in hand: a blade, or any weapon
## of the Advanced pack's that strikes (not a shield, a bow or a wand).
static func cuts(id: String) -> bool:
	var name := aw_name(id)
	if name == "":
		return BLADES.has(id)
	return not (AW.get(name, {}).get("kind", &"") in [&"shield", &"bow"]) and name != "wand"


## Whether `id` goes into a scabbard.
static func sheathes(id: String) -> bool:
	var name := aw_name(id)
	return BLADES.has(id) if name == "" else bool(AW.get(name, {}).get("sheath", false))


## The material the Advanced Weapons are drawn with in `style` (one for
## every figure), its colours `albedo` (the style's pre-coloured texture).
static func aw_material(style: String, albedo: Texture2D) -> Material:
	if _aw_mats.has(style):
		return _aw_mats[style]
	if not STYLE_LOOKS.has(style):
		# a style drawn as first worn: the texture alone, dull
		var plain := StandardMaterial3D.new()
		plain.albedo_texture = albedo
		plain.roughness = 0.7
		plain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_aw_mats[style] = plain
		return plain
	var spec: Dictionary = STYLE_LOOKS.get(style, STYLE_LOOKS["normal"])
	var m := ShaderMaterial.new()
	m.shader = load(AW_SHADER)
	m.set_shader_parameter(&"albedo_tex", albedo)
	if ResourceLoader.exists(AW_MASK):
		m.set_shader_parameter(&"mask_tex", load(AW_MASK))
	m.set_shader_parameter(&"metal_rgb", spec["metal"])
	m.set_shader_parameter(&"smooth_rgb", spec["smooth"])
	m.set_shader_parameter(&"imbue", spec["imbue"])
	m.set_shader_parameter(&"imbue_color", spec["color"])
	m.set_shader_parameter(&"imbue_strength", spec["strength"])
	m.set_shader_parameter(&"imbue_tiling", spec["tiling"])
	m.set_shader_parameter(&"imbue_scroll", spec["scroll"])
	m.set_shader_parameter(&"edge_strength", spec["edge"])
	_aw_mats[style] = m
	return m


## What the maker calls `id`.
static func arm_name(id: String) -> String:
	var name := aw_name(id)
	if name != "":
		return String(AW.get(name, {}).get("name", name.to_upper()))
	return ARM_NAMES.get(id, id.to_upper())


## "THE WARLOCK'S CAPE" for "warlock_cape".
static func extra_name(id: String) -> String:
	var cut := id.find("_")
	var cls := id.substr(0, cut)
	var part := id.substr(cut + 1)
	return "%s'S %s" % [CLASS_NAMES.get(cls, cls.to_upper()), EXTRA_NAMES.get(part, part.to_upper())]


## The classes `hero` is offered for gender `g`: his own, those the pack has
## for her (or him). One at least: the pack's first, for a hero with none.
static func classes(hero: StringName, g: String) -> Array[String]:
	var out: Array[String] = []
	var have: Dictionary = CLASSES.get(g, {})
	for c: String in HERO_CLASSES.get(hero, []):
		if have.has(c):
			out.append(c)
	if out.is_empty():
		out.append(CLASS_ORDER[0])
	return out


## The extras `hero` may wear in gender `g`: those of his own classes.
static func extras(hero: StringName, g: String) -> Array[String]:
	var out: Array[String] = []
	for c in classes(hero, g):
		for x: String in CLASSES[g][c]["extras"]:
			out.append(x)
	return out


## Every extra any class of `g` wears, in the classes' order.
static func all_extras(g: String) -> Array[String]:
	var out: Array[String] = []
	var have: Dictionary = CLASSES.get(g, {})
	for c: String in CLASS_ORDER:
		if have.has(c):
			for x: String in have[c]["extras"]:
				out.append(x)
	return out


## The look `hero` starts as: his first class, as the pack dresses it.
static func default_look(hero: StringName, g: String = "m") -> Dictionary:
	var look := {"g": g, "eyes": 0, "brows": 0, "mouth": 0, "beard": 1 if g == "m" else 0, "hair": 3,
			"skin": 1, "cloth": 1, "ws": STYLES[0]}
	return dress(look, hero, classes(hero, g)[0])


## `look` in class `cls`'s clothes, hat and arms (the face kept). A weapon the
## hero cannot hold gives way to his first; a staff the mage's class carries
## goes to his other hand, his sword hand keeping a sword.
static func dress(look: Dictionary, hero: StringName, cls: String) -> Dictionary:
	var out := look.duplicate(true)
	var g := String(out.get("g", "m"))
	var spec: Dictionary = CLASSES[g].get(cls, CLASSES[g].values()[0])
	out["cls"] = cls
	out["top"] = cls
	out["bottom"] = cls
	out["extras"] = (spec["extras"] as Array).duplicate()
	out["hat"] = spec["hat"]
	var style := String(out.get("ws", STYLES[0]))
	var held_w := arms(hero, cls, "w", style)
	var w := String(spec.get("weapon", ""))
	var o := String(spec.get("off", ""))
	out["w"] = w if held_w.has(w) else held_w[0]
	var held_o := arms(hero, cls, "o", style, String(out["w"]))
	if held_o.has(o):
		out["o"] = o
	elif held_o.has(w):
		out["o"] = w
	else:
		out["o"] = held_o[0]
	return out


## `look` made whole and valid for `hero`: what is missing from the default,
## what the gender has not got (a beard, a witch's dress) put right.
static func normalized(look: Dictionary, hero: StringName) -> Dictionary:
	var g := String(look.get("g", "m"))
	if g != "m" and g != "f":
		g = "m"
	var base := default_look(hero, g)
	var out := base.duplicate(true)
	for key: String in look:
		out[key] = look[key]
	out["g"] = g
	var own := classes(hero, g)
	if not own.has(String(out["cls"])):
		out = dress(out, hero, own[0])
	for key: String in ["top", "bottom"]:
		if not own.has(String(out[key])):
			out[key] = out["cls"]
	var worn: Array = []
	var known := extras(hero, g)
	var given: Array = out["extras"] if out["extras"] is Array else []
	for x: Variant in given:
		if known.has(String(x)) and not worn.has(String(x)):
			worn.append(String(x))
	out["extras"] = worn
	if String(out["hat"]) != "" and not HATS.has(String(out["hat"])):
		out["hat"] = ""
	for key: String in ["eyes", "brows", "mouth"]:
		out[key] = clampi(int(out[key]), 0, 4)
	out["beard"] = clampi(int(out["beard"]), 0, 8) if g == "m" else 0
	out["hair"] = clampi(int(out["hair"]), 0, 14)
	out["skin"] = clampi(int(out["skin"]), 1, SKINS)
	out["cloth"] = clampi(int(out["cloth"]), 1, CLOTHS)
	if not STYLES.has(String(out.get("ws", ""))):
		out["ws"] = STYLES[0]
	var style := String(out["ws"])
	for slot: String in ["w", "o"]:
		var held := arms(hero, String(out["cls"]), slot, style, String(out["w"]) if slot == "o" else "")
		var id := styled(String(out[slot]), style)
		out[slot] = id if held.has(id) else held[0]
	return out


## The same look in the other gender: the face and colours kept, the class
## kept where she (or he) has it.
static func regendered(look: Dictionary, hero: StringName, g: String) -> Dictionary:
	var out := look.duplicate(true)
	out["g"] = g
	var cls := String(look.get("cls", ""))
	if not CLASSES[g].has(cls):
		cls = classes(hero, g)[0]
	out = dress(out, hero, cls)
	out["w"] = look.get("w", out["w"])
	out["o"] = look.get("o", out["o"])
	if g == "f":
		out["beard"] = 0
	return normalized(out, hero)


## The figure meshes (without the prefix) `look` shows; "shield" and
## "tower_shield" are left to the rig, which knows which one is carried.
static func shown(look: Dictionary) -> Dictionary:
	var on := {}
	var hat: Dictionary = HATS.get(String(look.get("hat", "")), {})
	on["head"] = true
	if hat.get("face", true):
		on["eyes_%d" % int(look["eyes"])] = true
		on["brows_%d" % int(look["brows"])] = true
		if hat.get("mouth", true):
			on["mouth_%d" % int(look["mouth"])] = true
	if int(look.get("beard", 0)) > 0 and hat.get("beard", true):
		on["beard_%d" % int(look["beard"])] = true
	var hair := int(look.get("hair", 0))
	if hair > 0:
		match String(hat.get("hair", "full")):
			"full":
				on["hair_%d" % hair] = true
			"b":
				on["hairb_%d" % hair] = true
				on["hairb_%d_" % hair] = true  # and its parts (a bun, bangs): a prefix
	on["top_" + String(look["top"]) if String(look["top"]) != "" else "topbody"] = true
	on["bottom_" + String(look["bottom"]) if String(look["bottom"]) != "" else "bottombody"] = true
	for x: Variant in look.get("extras", []):
		on[extra_key(look, String(x))] = true
	if String(look.get("hat", "")) != "":
		on["hat_" + String(look["hat"])] = true
	var w := String(look.get("w", ""))
	if w == "own_bow":
		on["arm_bow"] = true
	elif w != "none" and w != "":
		on["w_" + w] = true
	var o := String(look.get("o", ""))
	if o != "none" and o != "his_shield" and o != "":
		on["o_" + o] = true
	return on


## Shows the meshes of `figure` that `look` wears and hides the rest (but the
## hero's own shields), and dyes them.
static func apply(figure: Node3D, look: Dictionary) -> void:
	var on := shown(look)
	var prefixes: Array[String] = []
	for key: String in on:
		if key.ends_with("_"):
			prefixes.append(key)
	for mesh: MeshInstance3D in figure.find_children(PREFIX + "*", "MeshInstance3D", true, false):
		var key := String(mesh.name).trim_prefix(PREFIX)
		if key == "shield" or key == "tower_shield":
			continue
		var visible := on.has(key)
		for pre in prefixes:
			visible = visible or (key.begins_with(pre) and not key.ends_with("_top"))
		mesh.visible = visible
	dye(figure, int(look.get("skin", 1)), int(look.get("cloth", 1)))
	wear_style(figure, String(look.get("ws", STYLES[0])))


## Draws the figure's Advanced Weapons as `style` has them: a style worn on
## another's models ("black" on the obsidian ones) gets its own material.
static func wear_style(figure: Node3D, style: String) -> void:
	var models := String(STYLE_MODELS.get(style, style))
	for s: Array in figure.get_meta(&"aw_surfs", []):
		var mesh := s[0] as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		var own := String(s[2])
		var drawn := style if own == models else own
		mesh.set_surface_override_material(int(s[1]), aw_material(drawn, s[3] as Texture2D))


## Swaps the figure's two textures for the pack's colours `skin` (1..8) and
## `cloth` (1..14). The figure's materials are made its own the first time,
## so one hero's dye does not run into another's.
static func dye(figure: Node3D, skin: int, cloth: int) -> void:
	var mats: Dictionary = figure.get_meta(&"ps_mats", {})
	if mats.is_empty():
		for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			for i in mesh.mesh.get_surface_count():
				var m := mesh.mesh.surface_get_material(i) as BaseMaterial3D
				if m == null:
					continue
				if m.resource_name.begins_with("aw_"):
					# the Advanced Weapons: their style's colours, metal and glow
					# (`wear_style()` picks between the ways a model is drawn)
					var surfs: Array = figure.get_meta(&"aw_surfs", [])
					surfs.append([mesh, i, m.resource_name.substr(3), m.albedo_texture])
					figure.set_meta(&"aw_surfs", surfs)
					mesh.set_surface_override_material(i, aw_material(m.resource_name.substr(3), m.albedo_texture))
					continue
				var kind := "body" if m.resource_name.contains("body") else "objects"
				if not mats.has(m):
					var own := m.duplicate() as BaseMaterial3D
					own.set_meta(&"kind", kind)
					mats[m] = own
				mesh.set_surface_override_material(i, mats[m])
		figure.set_meta(&"ps_mats", mats)
	for m: BaseMaterial3D in mats.values():
		var path := COLOURS + ("body_%d.png" % skin if m.get_meta(&"kind") == "body" else "objects_%d.png" % cloth)
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)


## The look as a short string, for the network (and back).
static func to_wire(look: Dictionary) -> String:
	return JSON.stringify(look) if not look.is_empty() else ""


static func from_wire(text: String) -> Dictionary:
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The colour a texture stands for, for the picker's swatch: the pack lays
## its palette out in quarters, the skin (or the main cloth) in the top left,
## the hair (or the second cloth) in the top right.
static func swatch(kind: String, index: int, second: bool = false) -> Color:
	var path := COLOURS + "%s_%d.png" % [kind, index]
	if not ResourceLoader.exists(path):
		return Color.GRAY
	var tex := load(path) as Texture2D
	var img := tex.get_image() if tex != null else null
	if img == null:
		return Color.GRAY
	if img.is_compressed():
		img.decompress()
	return img.get_pixel(int(img.get_width() * (0.92 if second else 0.42)), int(img.get_height() * 0.45))
