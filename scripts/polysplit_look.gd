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
##   w o      the arms in the sword hand and the other (see `ARMS`)

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
## Each hero's own classes: the only ones he is offered (2026-10-02, the
## user's word: every hero his own body and clothes; hats and arms are free).
const HERO_CLASSES := {
	&"tariel": ["swordsman", "fighter", "knight"],
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
## A blade: the cut is drawn along it (see [SkinnedRig]).
const BLADES := ["sword_a", "sword_b", "greatsword", "dagger"]


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
			"skin": 1, "cloth": 1}
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
	var arms: Dictionary = ARMS.get(hero, ARMS[&"tariel"])
	var w := String(spec.get("weapon", ""))
	var o := String(spec.get("off", ""))
	out["w"] = w if (arms["w"] as Array).has(w) else arms["w"][0]
	if (arms["o"] as Array).has(o):
		out["o"] = o
	elif (arms["o"] as Array).has(w):
		out["o"] = w
	else:
		out["o"] = arms["o"][0]
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
	var arms: Dictionary = ARMS.get(hero, ARMS[&"tariel"])
	if not (arms["w"] as Array).has(String(out["w"])):
		out["w"] = arms["w"][0]
	if not (arms["o"] as Array).has(String(out["o"])):
		out["o"] = arms["o"][0]
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
		on["x_" + String(x)] = true
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
