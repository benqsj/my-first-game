extends SceneTree

## The skeletons wear mixed outfits off the pack's all-in-one kit
## ([PackDress]): eight of a kind called up are not all dressed alike, each
## holds its own arms, wears one head at most, and the same name dresses the
## same way every time (so every peer sees the same).
##
##   godot --headless --path . --script res://tests/skeleton_dress_test.gd

const ARMS := {
	"skeleton": [],
	"skeleton_warrior": ["Skeleton_Warrior_Sword", "Skeleton_Warrior_Shield"],
	"skeleton_archer": ["Skeleton_Archer_Bow"],
	"skeleton_mage": ["Skeleton_Mage_Staff"],
}
const HEADS := ["Skeleton_Warrior_Helm", "Skeleton_Archer_Hat", "SkeletonMage_Hood"]

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _dress_of(kind: String, body_name: String) -> PackedStringArray:
	var body := (load("res://scenes/enemies/pack/%s.tscn" % kind) as PackedScene).instantiate() as Node3D
	body.name = body_name
	root.add_child(body)
	var dress := body.find_child("Dress", true, false) as PackDress
	var worn := dress.worn.duplicate()
	body.free()
	return worn


func _run() -> void:
	await process_frame
	for kind: String in ARMS:
		var looks := {}
		var ok_arms := true
		var ok_heads := true
		for i in 8:
			var worn := _dress_of(kind, "%s_%d" % [kind, i])
			looks[",".join(worn)] = true
			for arm: String in ARMS[kind]:
				ok_arms = ok_arms and worn.has(arm)
			var heads := 0
			for h: String in HEADS:
				heads += 1 if worn.has(h) else 0
			ok_heads = ok_heads and heads <= 1 and worn.has("Skeleton_Head")
		_check("%s: eight are not all dressed alike" % kind, looks.size() >= 3, "%d looks" % looks.size())
		_check("%s: each holds its own arms, one head at most" % kind, ok_arms and ok_heads)
		_check("%s: the same name, the same dress" % kind,
				_dress_of(kind, "x_7") == _dress_of(kind, "x_7"))
	print("skeleton_dress_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
