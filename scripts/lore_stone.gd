class_name LoreStone
extends Node3D

## The palace's story, a little each run (the user's word, 2026-10-21: what
## makes a player come back): a stone with words cut in it stands in one of
## the places before the lord, glowing faintly; come up to it and the next
## piece of the story is read out. Which piece is [Game]'s `lore_read` — one
## more every run, till they are all read, then the last one again.

const NEAR := 3.2
const TALES := [
	"ეს სასახლე ოდესღაც მეფე როსტევანს ეკუთვნოდა. მის დარბაზებში სიმღერა ისმოდა, არა ორკების ღრიალი.",
	"ერთ ზამთარს მთებიდან ცეცხლი ჩამოვიდა. ღრაშაკმა, ორკების ბელადმა, კარიბჭე ერთ ღამეში შეამტვრია.",
	"მცველები აკლდამაში ჩაიკეტნენ. ამბობენ, მათი სანთლები დღემდე ანთია.",
	"ღრაშაკმა ტყვეები გალიებში ჩაყარა. ვინც ხმალი იცოდა — მჭედლად აქცია, ვინც ლოცვა — დაადუმა.",
	"ორკები ეშვებს სიკვდილის შემდეგაც არ კარგავენ. მჭედლები ამბობენ, მათში ძველი ძალა ზის.",
	"ცის კუნძული ორკებმა ჯადოქრობით ააგდეს ზეცაში, რომ მეფის ლაშქარი ვერ მისულიყო.",
	"ღრაშაკის შავი ხმალი ცეცხლში გამოჭედეს, სადაც ას ტყვეს ერთად სიკვდილი ეწერა.",
	"ამბობენ, როცა ღრაშაკი დაეცემა, სასახლეზე ისევ ამოვა მზე — და ტყვეები სახლში დაბრუნდებიან.",
]

var _read: bool = false
var _tale: String = ""
var _glow: OmniLight3D
var _label: Label3D
var _rune: MeshInstance3D


## A stone in `room`, at `at` (in the world), facing `yaw`.
static func put(room: Node3D, at: Vector3, yaw: float) -> LoreStone:
	var s := LoreStone.new()
	s.name = "LoreStone"
	room.add_child(s)
	s.global_position = at
	s.rotation.y = yaw
	return s


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 0.95
	var slab := BoxMesh.new()
	slab.size = Vector3(1.3, 2.1, 0.4)
	var m := MeshInstance3D.new()
	m.mesh = slab
	m.material_override = stone
	m.position = Vector3(0.0, 1.05, 0.0)
	m.rotation.z = 0.04
	add_child(m)
	var top := CylinderMesh.new()
	top.top_radius = 0.65
	top.bottom_radius = 0.65
	top.height = 0.4
	top.radial_segments = 14
	var tm := MeshInstance3D.new()
	tm.mesh = top
	tm.material_override = stone
	tm.rotation.z = PI * 0.5
	tm.rotation.y = PI * 0.5
	tm.position = Vector3(0.0, 2.1, 0.0)
	add_child(tm)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.5, 0.8, 1.0)
	glow.emission_energy_multiplier = 2.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rune := BoxMesh.new()
	rune.size = Vector3(0.7, 1.1, 0.02)
	_rune = MeshInstance3D.new()
	_rune.mesh = rune
	_rune.material_override = glow
	_rune.position = Vector3(0.0, 1.25, 0.21)
	add_child(_rune)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.5, 0.8, 1.0)
	_glow.light_energy = 1.2
	_glow.omni_range = 4.0
	_glow.position = Vector3(0.0, 1.4, 0.8)
	add_child(_glow)
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 2.4, 0.5)
	shape.shape = box
	shape.position = Vector3(0.0, 1.2, 0.0)
	solid.add_child(shape)
	add_child(solid)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 10
	_label.pixel_size = 0.008
	_label.width = 900
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.modulate = Color(0.85, 0.93, 1.0)
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 3.3, 0.0)
	_label.text = "ძველი ქვა — მიდი ახლოს"
	add_child(_label)


func _process(_delta: float) -> void:
	if _read:
		return
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and not hero.is_dead and hero.global_position.distance_to(global_position) < NEAR:
			read()
			return


## Its piece of the story read out (the next one in [Game]).
func read() -> void:
	if _read:
		return
	_read = true
	var game := get_node_or_null(^"/root/Game")
	var n := 0
	if game != null and game.get(&"lore_read") != null:
		n = int(game.get(&"lore_read"))
	_tale = TALES[mini(n, TALES.size() - 1)]
	if game != null and game.has_method(&"read_lore"):
		game.call(&"read_lore")
	_label.text = "%s\n(%d / %d)" % [_tale, mini(n + 1, TALES.size()), TALES.size()]
	_label.font_size = 30
	var tw := create_tween()
	tw.tween_property(_glow, "light_energy", 3.0, 0.3)
	tw.tween_property(_glow, "light_energy", 0.6, 1.5)
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, global_position + Vector3.UP * 1.4, Color(0.5, 0.8, 1.0), 40, Vector2(1.0, 3.0),
				Vector3.UP, 120.0, Vector2(0.04, 0.1), Vector3(0, 0.6, 0), 1.2)
