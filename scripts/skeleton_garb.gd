class_name SkeletonGarb
extends RefCounted

## The skeletons' clothes and headgear worn by the heroes (the user's word,
## 2026-10-06): the pieces of Polysplit's all-in-one skeleton kit
## (`Skeleton_AllinOne.fbx`, CREATURES_PACK.md), out of the bag (Attire).
##
## The kit is skinned to the same 99 bones as the Heroes pack the maker's
## figure is made of, rest for rest, so each piece is put on the figure's own
## skeleton with a skin of its own: every bind taken from the kit's bone to
## the figure's bone of the same name (`_skin_for`), the two rests lined up at
## the pelvis (1.7 cm apart).
##
## A look carries what is worn as `sk_head`, `sk_top`, `sk_bottom` (ids of
## [constant PIECES]); sent with the look to every peer. What a piece covers
## is taken off underneath it ([method strip]): a coat takes his own top off
## (the figure's bare body under it), a skirt his breeches, headgear his hat
## and his hair. Nothing is worn over his own clothes.

const KIT := "res://assets/creatures/Skeleton_AllinOne.fbx"
## Under the figure's skeleton, so a look worn again takes them off first.
const TAG := "SkGarb_"

## id -> [slot, the kit's mesh, name, kind, its colours (PackCreature), text]
const PIECES := {
	"sk_warrior_helm": ["sk_head", "Skeleton_Warrior_Helm", "Barrow Helm", "Open helm",
			"Objects_SkelWarrior", "An old open helm off a dead warrior, its brow-band green with age."],
	"sk_archer_hat": ["sk_head", "Skeleton_Archer_Hat", "Bone Archer's Hat", "Brimmed hat",
			"Objects_SkelArcher", "A wide-brimmed leather hat, cracked, that kept the sun off a dead archer's skull."],
	"sk_mage_hood": ["sk_head", "SkeletonMage_Hood", "Grave Hood", "Hood",
			"Objects_SkelMage", "A deep hood of grave-cloth, purple gone grey, off a dead mage."],
	"sk_warrior_top": ["sk_top", "Skeleton_Warrior_Top", "Barrow Harness", "Coat and pauldron",
			"Objects_SkelWarrior", "A leather coat with an iron pauldron and a gorget, as the barrow's warriors wear it."],
	"sk_archer_top": ["sk_top", "Skeleton_Archer_Top", "Bone Archer's Jerkin", "Jerkin and mantle",
			"Objects_SkelArcher", "A short jerkin and a tattered mantle over the shoulders."],
	"sk_mage_top": ["sk_top", "Skeleton_Mage_Top", "Grave Mantle", "Mantle and chain",
			"Objects_SkelMage", "A mage's mantle hung with a chain of brass, the grave-cloth hood down."],
	"sk_warrior_bottom": ["sk_bottom", "Skeleton_Warrior_Bottom", "Barrow Kilt", "Kilt and greaves",
			"Objects_SkelWarrior", "A war kilt of leather strips over greaves and knee-cops."],
	"sk_archer_bottom": ["sk_bottom", "Skeleton_Archer_Bottom", "Bone Archer's Leggings", "Leggings and boots",
			"Objects_SkelArcher", "Ragged leggings and tall boots."],
	"sk_mage_bottom": ["sk_bottom", "Skeleton_Mage_Bottom", "Grave Robe", "Robe",
			"Objects_SkelMage", "The long skirt of a mage's robe, frayed at the hem."],
}
const SLOTS := ["sk_head", "sk_top", "sk_bottom"]

static var _kit: Node3D
static var _kit_skel: Skeleton3D


## The ids worn in `look`, slot by slot.
static func worn(look: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot: String in SLOTS:
		var id := String(look.get(slot, ""))
		if PIECES.has(id):
			out.append(id)
	return out


## What his own figure shows (PolysplitLook.shown's keys), with what the
## worn pieces cover taken off: his top, his breeches, his hat and his hair.
static func strip(on: Dictionary, look: Dictionary) -> void:
	var covered := {}
	for id in worn(look):
		covered[String(PIECES[id][0])] = true
	if covered.is_empty():
		return
	for key: String in on.keys():
		if covered.has("sk_top") and key.begins_with("top_"):
			on.erase(key)
		elif covered.has("sk_bottom") and key.begins_with("bottom_"):
			on.erase(key)
		elif covered.has("sk_head") and (key.begins_with("hat_") or key.begins_with("hair_")
				or key.begins_with("hairb_")):
			on.erase(key)
	if covered.has("sk_top"):
		on["topbody"] = true
	if covered.has("sk_bottom"):
		on["bottombody"] = true


## Puts what `look` wears on the figure's skeleton `skel` (and takes off what
## it no longer does).
static func wear(skel: Skeleton3D, look: Dictionary) -> void:
	if skel == null:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(TAG):
			skel.remove_child(child)
			child.queue_free()
	var ids := worn(look)
	if ids.is_empty() or not _load_kit():
		return
	for id in ids:
		var piece: Array = PIECES[id]
		var src := _kit.find_child(String(piece[1]), true, false) as MeshInstance3D
		if src == null or src.skin == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = TAG + id
		mi.mesh = src.mesh
		mi.skin = _skin_for(src.skin, skel)
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		var mat := PackCreature.material(String(piece[4]))
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)


static func _load_kit() -> bool:
	if _kit != null and is_instance_valid(_kit):
		return true
	var scene := load(KIT) as PackedScene
	if scene == null:
		return false
	_kit = scene.instantiate() as Node3D
	var skels := _kit.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return false
	_kit_skel = skels[0] as Skeleton3D
	return true


static func _rest(sk: Skeleton3D, bone: int) -> Transform3D:
	var t := sk.get_bone_rest(bone)
	var p := sk.get_bone_parent(bone)
	while p >= 0:
		t = sk.get_bone_rest(p) * t
		p = sk.get_bone_parent(p)
	return t


## The kit piece's skin made over for `skel`: each bind from the kit's bone
## to the figure's of the same name, the rests lined up at the pelvis.
static func _skin_for(kit_skin: Skin, skel: Skeleton3D) -> Skin:
	# the kit's skeleton in its own scene (not in a tree: composed by hand)
	var k := Transform3D.IDENTITY
	var n: Node = _kit_skel
	while n != null and n != _kit:
		if n is Node3D:
			k = (n as Node3D).transform * k
		n = n.get_parent()
	var pf := skel.find_bone("pelvis_joint")
	var pk := _kit_skel.find_bone("pelvis_joint")
	var line := Transform3D.IDENTITY
	if pf >= 0 and pk >= 0:
		line = _rest(skel, pf) * (k * _rest(_kit_skel, pk)).affine_inverse()
	var skin := Skin.new()
	for i in kit_skin.get_bind_count():
		var bname := kit_skin.get_bind_name(i)
		var kb := _kit_skel.find_bone(String(bname)) if bname != &"" else kit_skin.get_bind_bone(i)
		if bname == &"" and kb >= 0:
			bname = _kit_skel.get_bone_name(kb)
		var fb := skel.find_bone(String(bname))
		if fb < 0 or kb < 0:
			fb = maxi(fb, 0)
			kb = maxi(kb, 0)
		skin.add_named_bind(bname, _rest(skel, fb).affine_inverse() * line * k * _rest(_kit_skel, kb)
				* kit_skin.get_bind_pose(i))
	return skin
