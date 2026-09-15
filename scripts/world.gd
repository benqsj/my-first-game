class_name World
extends Node3D

## The level, and who is standing in it.
##
## The player used to be a node baked into this scene. It cannot be: there may
## be up to four of them, each a different character, and which ones exist is
## not known until people have connected. So the level carries the *places* a
## player can stand and the machinery to put one there, and the bodies arrive.
##
## **The host decides.** Spawning goes through a [MultiplayerSpawner], which
## means the host calls `spawn()` once and every peer — itself included — builds
## the same node with the same name under the same parent. The spawn data
## carries the character, which is the whole answer to "why does everyone look
## like the host": the profile is assigned *before* the body enters the tree, so
## `Player._spawn_character()` uses it instead of asking the local `Game`.
##
## Offline this is the same code path with one peer in it, so a solo game is a
## multiplayer game with nobody else in it rather than a second way of working.

## Where the spawned bodies live, and the marks they are put on.
@onready var _players: Node3D = $Players
@onready var _points: Node3D = $SpawnPoints
@onready var _spawner: MultiplayerSpawner = $PlayerSpawner

## peer id -> which spawn point they were given, so two people do not arrive on
## top of each other.
var _taken: Dictionary = {}


func _ready() -> void:
	_spawner.spawn_function = _build_player
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.connect("player_announced", _on_announced)
		net.connect("player_left", _on_left)

	# Only the host spawns anybody. Offline, `is_host()` is true and the roster
	# is empty, so this is also what starts a solo game.
	if net == null or net.call("is_host"):
		var game := get_node_or_null("/root/Game")
		var mine: StringName = net.call("character_of", 1) if net != null \
				else (game.call("character") if game != null else &"tariel")
		_spawn_for(1, mine)


#region Bodies
## The body this peer is driving, or null before it has been spawned. In a solo
## game that is the only one there is — which is what every test and every probe
## is asking for when it asks for "the player".
func player() -> Player:
	# `_ready()` may not have run: a script main loop adds the level to a root
	# that is not itself in the tree yet, so the node is queued rather than
	# entered. One frame is all it takes, and saying so beats a null crash.
	if _players == null:
		push_warning("World: asked for a player before the level was ready.")
		return null
	var net := get_node_or_null("/root/Net") if is_inside_tree() else null
	var mine: int = net.call("local_id") if net != null else 1
	var body := _players.get_node_or_null(str(mine)) as Player
	if body != null:
		return body
	# Before the local body exists, whatever is standing there is better than
	# nothing: a probe that wants *a* player should not have to know the order
	# things spawned in.
	return _players.get_child(0) as Player if _players.get_child_count() > 0 else null


## Everyone in the level, driven or not.
func players() -> Array[Player]:
	var all: Array[Player] = []
	for node in _players.get_children():
		var body := node as Player
		if body != null:
			all.append(body)
	return all


## Gives `peer` a body, once, on a mark nobody else is standing on.
func _spawn_for(peer: int, character: StringName) -> void:
	if _players.has_node(str(peer)):
		return
	_spawner.spawn({
		"peer": peer,
		"character": String(character),
		"point": _mark_for(peer),
	})


## Builds one player from what the host sent. Runs on **every** peer, which is
## why everything that decides what the body is has to be in `data` — the local
## `Game` knows what the local player picked and nothing about anyone else.
func _build_player(data: Variant) -> Node:
	var sent := data as Dictionary
	var peer := int(sent.get("peer", 1))
	var id := StringName(sent.get("character", ""))
	var body: Player = load("res://scenes/player/player.tscn").instantiate()
	# Named for the peer so `has_node(str(peer))` can find it and so the same
	# node has the same path everywhere — which is what makes RPCs land.
	body.name = str(peer)
	body.set_multiplayer_authority(peer)
	# Before the tree, and therefore before `_ready()`: `_spawn_character()`
	# only falls back to asking `/root/Game` when nothing has been handed to it.
	body.profile = _profile(id)
	body.position = _mark(int(sent.get("point", 0)))
	return body


## Takes a body away again. The host drops it and the spawner takes it off
## everyone else.
func _despawn(peer: int) -> void:
	_taken.erase(peer)
	var body := _players.get_node_or_null(str(peer))
	if body != null:
		body.queue_free()


func _on_announced(peer: int, character: StringName) -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.call("is_host"):
		_spawn_for(peer, character)


func _on_left(peer: int) -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.call("is_host"):
		_despawn(peer)
#endregion


## The resource for a character id. Asked of [Game], which is the one place
## that knows what ids there are — and left null when the id means nothing, so
## `Player._spawn_character()` falls back the way it always did.
func _profile(id: StringName) -> CharacterProfile:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return null
	var paths: Dictionary = game.get("CHARACTERS")
	if not paths.has(id):
		return null
	return load(String(paths[id])) as CharacterProfile


#region Where they stand
## Which mark `peer` gets. Handed out in order and remembered, so a peer that
## respawns lands where it was rather than shuffling everyone along.
func _mark_for(peer: int) -> int:
	if _taken.has(peer):
		return _taken[peer]
	var used := {}
	for key in _taken:
		used[_taken[key]] = true
	for slot in maxi(_points.get_child_count(), 1):
		if not used.has(slot):
			_taken[peer] = slot
			return slot
	_taken[peer] = 0
	return 0


## Where a mark is, in the level's own frame. Falls back to the origin rather
## than to nothing if the marks have been deleted.
func _mark(slot: int) -> Vector3:
	if _points == null or _points.get_child_count() == 0:
		return Vector3(0.0, 0.3, 0.0)
	var at := _points.get_child(clampi(slot, 0, _points.get_child_count() - 1)) as Node3D
	return at.position if at != null else Vector3(0.0, 0.3, 0.0)
#endregion
