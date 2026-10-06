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
## (the figure's bare body under it), headgear his hat and his hair. A skirt
## is worn over his own breeches and boots: of the kit's legs only what hangs
## from the hips is kept (its leggings and boots are cut for bone, not for a
## man's calves, and sank into his). Taken off from the bag, his own top or
## breeches leave the bare body (`bare_top`, `bare_bottom` in the look).

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
	"sk_archer_bottom": ["sk_bottom", "Skeleton_Archer_Bottom", "Bone Archer's Leggings", "Leggings",
			"Objects_SkelArcher", "Ragged leggings, bound at the knee."],
	"sk_warrior_boots": ["sk_feet", "Skeleton_Warrior_Bottom", "Barrow Boots", "Boots",
			"Objects_SkelWarrior", "Short boots of old leather off a barrow warrior."],
	"sk_archer_boots": ["sk_feet", "Skeleton_Archer_Bottom", "Bone Archer's Boots", "Tall boots",
			"Objects_SkelArcher", "Tall boots, cracked at the ankle."],
	"sk_mage_bottom": ["sk_bottom", "Skeleton_Mage_Bottom", "Grave Robe", "Robe",
			"Objects_SkelMage", "The long skirt of a mage's robe, frayed at the hem."],
}
const SLOTS := ["sk_head", "sk_top", "sk_bottom", "sk_feet"]

static var _kit: Node3D
static var _kit_skel: Skeleton3D
## Piece id -> its mesh with the cloth only.
static var _cloth: Dictionary = {}


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
	if look.get("bare_top", false):
		covered["sk_top"] = true
	if look.get("bare_bottom", false):
		covered["bare_bottom"] = true
	if covered.is_empty():
		return
	for key: String in on.keys():
		if covered.has("sk_top") and key.begins_with("top_"):
			on.erase(key)
		elif covered.has("bare_bottom") and key.begins_with("bottom_"):
			on.erase(key)
		elif covered.has("sk_head") and (key.begins_with("hat_") or key.begins_with("hair_")
				or key.begins_with("hairb_")):
			on.erase(key)
	if covered.has("sk_top"):
		on["topbody"] = true
	if covered.has("bare_bottom"):
		on["bottombody"] = true


## Puts what `look` wears on the figure's skeleton `skel` (and takes off what
## it no longer does).
static func wear(skel: Skeleton3D, look: Dictionary, figure: Node = null) -> void:
	if skel == null:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(TAG):
			skel.remove_child(child)
			child.queue_free()
	if figure != null:
		_legs_and_feet(figure, skel, look)
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
		mi.mesh = cloth_of(id)
		mi.skin = _skin_for(src.skin, skel)
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		var mat := PackCreature.material(String(piece[4]))
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)


## His legs and his feet worn apart (the user's word, 2026-10-07: shoes are
## a thing of their own): the figure's breeches (`bottom_<cls>`, or the bare
## body with `bare_bottom`) drawn without their feet, and the feet of
## `look.feet`'s breeches (his boots; "" bare; missing, the breeches' own)
## drawn alone, or nothing under a skeleton's boots. Each is cut from the
## figure's mesh by the bone each triangle hangs from most.
static func _legs_and_feet(figure: Node, skel: Skeleton3D, look: Dictionary) -> void:
	var meshes := {}
	for m: MeshInstance3D in figure.find_children("ps_bottom*", "MeshInstance3D", true, false):
		meshes[String(m.name)] = m
	var legs_name := "ps_bottombody" if look.get("bare_bottom", false) else "ps_bottom_" + String(look.get("bottom", ""))
	var feet_key := String(look.get("feet", look.get("bottom", "")))
	# sandals and wraps are made over the bare feet (UnderGarb.FOOTWEAR)
	var made_shoes := UnderGarb.FOOTWEAR.has(feet_key)
	var feet_name := "" if look.has("sk_feet") else ("ps_bottombody" if feet_key == "" or made_shoes \
			else "ps_bottom_" + feet_key)
	if not meshes.has(legs_name):
		return
	for m: MeshInstance3D in meshes.values():
		m.visible = false
	var parts := [[legs_name, "legs"], [feet_name, "feet"]]
	# breeches whose tall boots are off leave the shin bare: his own skin
	# there, unless the shoes worn go up it
	var legs_src: MeshInstance3D = meshes[legs_name]
	var shin_bare := bool(_part_of(legs_src.mesh, legs_src.skin, skel, "legs").get_meta(&"shaft", false))
	var feet_src: MeshInstance3D = meshes.get(feet_name)
	var tall: bool = false
	if feet_src != null and feet_src.mesh != null:
		tall = bool(_part_of(feet_src.mesh, feet_src.skin, skel, "feet").get_meta(&"shaft", false))
	elif look.has("sk_feet"):
		var boots := cloth_of(String(look.sk_feet))
		tall = boots != null and bool(boots.get_meta(&"shaft", false))
	if shin_bare and not tall and meshes.has("ps_bottombody"):
		parts.append(["ps_bottombody", "shin"])
	if made_shoes and not look.has("sk_feet") and meshes.has("ps_bottombody"):
		var body: MeshInstance3D = meshes["ps_bottombody"]
		var shoes := MeshInstance3D.new()
		shoes.name = TAG + "shoes"
		shoes.mesh = UnderGarb.footwear(body.mesh, body.skin, feet_key)
		shoes.skin = body.skin
		skel.add_child(shoes)
		shoes.skeleton = NodePath("..")
		var own := body.get_surface_override_material(0) as BaseMaterial3D
		if own != null and shoes.mesh.get_surface_count() > 0:
			own = own.duplicate() as BaseMaterial3D
			own.cull_mode = BaseMaterial3D.CULL_DISABLED
			shoes.set_surface_override_material(0, own)
	for pair: Array in parts:
		var src: MeshInstance3D = meshes.get(String(pair[0]))
		if src == null or src.mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = TAG + String(pair[1])
		mi.mesh = _part_of(src.mesh, src.skin, skel, String(pair[1]))
		# her underthings in the cut she wears (UnderGarb)
		var smalls := String(look.get("smalls", "shorts")) if String(look.get("g", "m")) == "f" else ""
		if String(pair[1]) == "legs" and String(pair[0]) == "ps_bottombody" and smalls != "":
			mi.mesh = UnderGarb.shorts(mi.mesh, src.skin)
			if smalls == "skirt":
				var skirt := MeshInstance3D.new()
				skirt.name = TAG + "skirt"
				skirt.mesh = UnderGarb.skirt(src.mesh, src.skin)
				skirt.skin = src.skin
				skel.add_child(skirt)
				skirt.skeleton = NodePath("..")
				var own := src.get_surface_override_material(0) as BaseMaterial3D
				if own != null:
					own = own.duplicate() as BaseMaterial3D
					own.cull_mode = BaseMaterial3D.CULL_DISABLED
					skirt.set_surface_override_material(0, own)
		mi.skin = src.skin
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		# a cut drops the surfaces left empty: each kept one says whose it was
		var from: PackedInt32Array = mi.mesh.get_meta(&"from", PackedInt32Array())
		for k in from.size():
			if from[k] < src.get_surface_override_material_count():
				mi.set_surface_override_material(k, src.get_surface_override_material(from[k]))
		if src.material_override != null:
			mi.material_override = src.material_override


static var _parts: Dictionary = {}
## Whether the boots `_kept` last cut go up the shin.
static var _shaft_seen := false


## A figure mesh's shoes alone (`part` "feet": up to the knee where they go
## so high), the rest of it without them ("legs"), or the shins alone
## ("shin", of the bare body, under breeches whose boots are off). The mesh
## says (meta "shaft") whether its shoes go up the shin.
static func _part_of(mesh: Mesh, skin: Skin, skel: Skeleton3D, part: String) -> Mesh:
	var key := "%d|%s" % [mesh.get_instance_id(), part]
	if _parts.has(key):
		return _parts[key]
	var names := PackedStringArray()
	if skin != null:
		for k in skin.get_bind_count():
			var n := String(skin.get_bind_name(k))
			if n == "" and skin.get_bind_bone(k) >= 0:
				n = skel.get_bone_name(skin.get_bind_bone(k))
			names.append(n)
	var out := ArrayMesh.new()
	var from := PackedInt32Array()
	var shaft := false
	for sidx in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(sidx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if verts.is_empty() or bones.is_empty() or index.is_empty():
			continue
		var per := floori(float(bones.size()) / float(verts.size()))
		var kinds := _bone_kinds(bones, weights, per, names, verts.size())
		var shoe := _shoe_tris(verts, index, kinds)
		if shoe.size() > 0 and shoe[shoe.size() - 1] == 2:
			shaft = true
		var kept := PackedInt32Array()
		for t in floori(index.size() / 3.0):
			var take := false
			if part == "feet":
				take = shoe[t] != 0
			elif part == "legs":
				take = shoe[t] == 0
			else:
				var n := 0
				for q in 3:
					n += 1 if kinds[index[t * 3 + q]] == SHIN else 0
				take = n >= 2
			if take:
				kept.append(index[t * 3])
				kept.append(index[t * 3 + 1])
				kept.append(index[t * 3 + 2])
		if kept.is_empty():
			continue
		var cut := arrays.duplicate()
		cut[Mesh.ARRAY_INDEX] = kept
		var flags: int = mesh.surface_get_format(sidx) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cut, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(sidx))
		from.append(sidx)
	out.set_meta(&"from", from)
	out.set_meta(&"shaft", shaft)
	_parts[key] = out
	return out


## The piece's mesh without the bones the kit models into it (a coat carries
## the skeleton's arm bones, a skirt its leg bones: the pack swaps the bare
## bones for them): its "Objects" surfaces only, the cloth and the iron.
static func cloth_of(id: String) -> Mesh:
	if _cloth.has(id):
		return _cloth[id]
	if not PIECES.has(id) or not _load_kit():
		return null
	var src := _kit.find_child(String(PIECES[id][1]), true, false) as MeshInstance3D
	if src == null or src.mesh == null:
		return null
	var out := ArrayMesh.new()
	_shaft_seen = false
	for s in src.mesh.get_surface_count():
		var was := src.mesh.surface_get_material(s)
		if was == null or not was.resource_name.contains("Objects"):
			continue
		var flags: int = src.mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var arrays := _kept(src.mesh.surface_get_arrays(s), src.skin, String(PIECES[id][0]))
		if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, was)
	# boots up the shin cover it: no bare shin is wanted under them
	out.set_meta(&"shaft", _shaft_seen)
	_cloth[id] = out
	return out


## Of a piece's triangles, those worth wearing on a man, by the bone each
## hangs from most: a coat without the bony hands the kit gives it (wrists
## and fingers), a skirt only what hangs from the hips and thighs (not its
## leggings and boots).
static func _kept(arrays: Array, skin: Skin, slot: String) -> Array:
	if slot == "sk_head":
		return arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if verts.is_empty() or bones.is_empty() or index.is_empty():
		return arrays
	var per := floori(float(bones.size()) / float(verts.size()))
	var names := PackedStringArray()
	for k in skin.get_bind_count():
		var n := String(skin.get_bind_name(k))
		if n == "" and _kit_skel != null and skin.get_bind_bone(k) >= 0:
			n = _kit_skel.get_bone_name(skin.get_bind_bone(k))
		names.append(n)
	if slot == "sk_bottom" or slot == "sk_feet":
		var shoe := _shoe_tris(verts, index, _bone_kinds(bones, weights, per, names, verts.size()))
		if slot == "sk_feet" and shoe[shoe.size() - 1] == 2:
			_shaft_seen = true
		var mine := PackedInt32Array()
		for t in floori(index.size() / 3.0):
			if (shoe[t] != 0) == (slot == "sk_feet"):
				mine.append(index[t * 3])
				mine.append(index[t * 3 + 1])
				mine.append(index[t * 3 + 2])
		var cut := arrays.duplicate()
		cut[Mesh.ARRAY_INDEX] = mine
		cut[Mesh.ARRAY_VERTEX] = _fitted(verts, bones, weights, per, names, skin)
		return cut
	var keep_vert := PackedByteArray()
	keep_vert.resize(verts.size())
	for v in verts.size():
		var best := -1.0
		var bone := ""
		for j in per:
			var w := weights[v * per + j]
			var k := bones[v * per + j]
			if w > best and k < names.size():
				best = w
				bone = names[k]
		var keep := true
		if slot == "sk_top":
			keep = not (bone.contains("wrist") or bone.contains("Finger"))
		elif slot == "sk_bottom":
			keep = not is_foot(bone)
		elif slot == "sk_feet":
			keep = is_foot(bone)
		keep_vert[v] = 1 if keep else 0
	var kept := PackedInt32Array()
	for t in floori(index.size() / 3.0):
		var a := index[t * 3]
		var b := index[t * 3 + 1]
		var c := index[t * 3 + 2]
		if keep_vert[a] == 1 and keep_vert[b] == 1 and keep_vert[c] == 1:
			kept.append(a)
			kept.append(b)
			kept.append(c)
	var out := arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = kept
	out[Mesh.ARRAY_VERTEX] = _fitted(verts, bones, weights, per, names, skin)
	return out


## A foot's bone: the ankle, the ball, the toe.
static func is_foot(bone: String) -> bool:
	return bone.contains("ankle") or bone.contains("ball") or bone.contains("toe")


const FOOT := 0
const SHIN := 1
const UPPER := 2


## Each corner's kind by the bone it hangs from most: FOOT, SHIN (the
## "knee" bone runs from the knee to the ankle) or UPPER (anything above).
static func _bone_kinds(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, names: PackedStringArray,
		count: int) -> PackedByteArray:
	var kinds := PackedByteArray()
	kinds.resize(count)
	for v in count:
		var best := -1.0
		var bone := ""
		for j in per:
			var k := bones[v * per + j]
			if weights[v * per + j] > best and k < names.size():
				best = weights[v * per + j]
				bone = names[k]
		kinds[v] = FOOT if is_foot(bone) else (SHIN if bone.contains("knee") else UPPER)
	return kinds


## Which triangles are shoes (the user's word, 2026-10-07: what is below the
## knee is the shoe, above it the breeches; but breeches down to the ankle
## stay breeches, the shoes under them shoes alone). A boot is its own shell
## of the mesh: a shell holding a foot and (all but) nothing above the knee is
## a shoe up to wherever it goes. Shells welded to the breeches are cut at the
## ankle, a triangle with the foot if most of its corners are. Per triangle
## 1 (a shoe), 0 (not); one more entry at the end, 2 if a shoe went up the
## shin, else 0.
static func _shoe_tris(verts: PackedVector3Array, index: PackedInt32Array, kinds: PackedByteArray) -> PackedByteArray:
	var n := verts.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	for v in n:
		parent[v] = v
	# corners at one place are one (the seams split them for the texture)
	var at := {}
	for v in n:
		var p := verts[v]
		var key := Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))
		if at.has(key):
			_join(parent, v, int(at[key]))
		else:
			at[key] = v
	var tris := floori(index.size() / 3.0)
	for t in tris:
		_join(parent, index[t * 3], index[t * 3 + 1])
		_join(parent, index[t * 3], index[t * 3 + 2])
	# the knee: as high as anything hangs from the shin's bone
	var knee := -INF
	for v in n:
		if kinds[v] == SHIN:
			knee = maxf(knee, verts[v].y)
	var low := {}
	var top := {}
	for v in n:
		var r := _root_of(parent, v)
		if kinds[v] != UPPER:
			low[r] = true
		top[r] = maxf(float(top.get(r, -INF)), verts[v].y)
	var out := PackedByteArray()
	out.resize(tris + 1)
	var shaft := false
	for t in tris:
		var r := _root_of(parent, index[t * 3])
		# a shell of its own on the foot or the shin and no higher than the
		# knee: a boot, a greave, a wrap, a strap by the ankle
		var boot: bool = low.has(r) and knee > -INF and float(top[r]) <= knee + 0.05
		if boot:
			out[t] = 1
			# up the shin to near the knee: it covers the shin
			shaft = shaft or float(top[r]) > knee - 0.12
		else:
			var f := 0
			for q in 3:
				f += 1 if kinds[index[t * 3 + q]] == FOOT else 0
			out[t] = 1 if f >= 2 else 0
	out[tris] = 2 if shaft else 0
	return out


static func _root_of(parent: PackedInt32Array, v: int) -> int:
	var r := v
	while parent[r] != r:
		r = parent[r]
	while parent[v] != r:
		var next := parent[v]
		parent[v] = r
		v = next
	return r


static func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root_of(parent, a)
	var rb := _root_of(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


## How far out (metres) what hangs from each limb's bone is set, to sit on
## a man's flesh rather than on bare bone (the kit's bracers, leggings and
## boots were cut round the bone: on him they were bracelets sunk into his
## arm, and boots inside his feet).
const FLESH := {"shoulder": 0.03, "elbow": 0.026, "thigh": 0.05, "knee": 0.04, "ankle": 0.03, "ball": 0.022}
## Each limb bone's next one down, the limb's line.
const LIMB_NEXT := {"shoulder": "elbow", "elbow": "wrist", "thigh": "knee", "knee": "ankle", "ankle": "ball",
		"ball": "toe"}


## The corners hung from a limb bone set out from the limb's line by its
## FLESH, in the mesh's own (rest) space.
static func _fitted(verts: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int,
		names: PackedStringArray, skin: Skin) -> PackedVector3Array:
	var out := verts.duplicate()
	if _kit_skel == null:
		return out
	for v in verts.size():
		var best := -1.0
		var k_best := -1
		for j in per:
			if weights[v * per + j] > best:
				best = weights[v * per + j]
				k_best = bones[v * per + j]
		if k_best < 0 or k_best >= names.size():
			continue
		var name := names[k_best]
		var part := ""
		for key: String in FLESH:
			if name.contains(key + "_joint") or name.contains(key + "Joint"):
				part = key
		if part == "":
			continue
		var b := _kit_skel.find_bone(name)
		var next := _kit_skel.find_bone(name.replace(part, String(LIMB_NEXT[part])))
		if b < 0 or next < 0:
			continue
		var to_skel := _rest(_kit_skel, b) * skin.get_bind_pose(k_best)
		var p := to_skel * verts[v]
		var a := _rest(_kit_skel, b).origin
		var c := _rest(_kit_skel, next).origin
		var on := Geometry3D.get_closest_point_to_segment(p, a, c)
		var away := p - on
		if away.length() < 0.0005:
			continue
		out[v] = to_skel.affine_inverse() * (p + away.normalized() * float(FLESH[part]))
	return out


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
