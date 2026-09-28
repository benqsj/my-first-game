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

## How far a creature is still drawn, in metres. Zero draws all of them, always.
##
## This is the level's business rather than each creature's, because it is the
## level that got bigger. A creature is a hierarchy of rigid parts — some ninety
## draw calls once the sun has drawn each of them again per shadow cascade, and
## the six standing around the greybox core are 562 of the level's 2 106. There
## are thirteen of them now, spread over two hundred and forty metres, and the
## far ones are drawn through fog at a size nobody can make anything out of.
##
## This buys nothing at the spawn, where every creature is close: it is for
## everywhere else, and for however many more get added to a map this size.
##
## Ninety metres is chosen against the creatures themselves rather than against
## what looks far — a wolf notices the player at twenty and gives up at
## twenty-eight, so nothing this far out has any bearing on a fight. The last few
## metres are faded rather than cut.
@export var creature_draw_distance: float = 90.0

## How near a player a creature has to be before it thinks at all, in metres.
## Zero leaves every one of them thinking all the time.
##
## The measurement this exists for: with the wood grown and thirteen creatures in
## it, a physics tick out on the open ground cost 2.3 ms, and 1.9 ms of that was
## creatures — none of them within eighty metres of the knight, all of them
## running a wander, a step-up probe and a `move_and_slide` sixty times a second
## for nobody. Asleep they cost nothing, and the wolf that matters is the one you
## can see. A wolf notices a player at twenty metres, so seventy is a long way
## clear of anything that could be noticed being asleep.
@export var creature_think_distance: float = 70.0
## How often that is re-checked, in frames. Distances between things that walk do
## not change fast enough to be worth asking every frame.
@export var creature_think_interval: int = 15

## The bands of imps and puglins, and the ground each one holds: which
## creature, the middle of the camp (x, z), and how many stand there.
##
## Built here rather than placed in the scene so the numbers read as one table.
## Every peer builds the same bands with the same names from it in `_ready()`,
## before anything is synchronised, which is what a creature placed in the
## scene gets too. Each camp has a clearing cut for it in `Forest.CLEARINGS`.
const CAMPS: Array[Array] = [
	# Imps: twenty, in the wood, in bands of two, two, three, three.
	[&"imp", Vector2(-72.0, -58.0), 2],
	[&"imp", Vector2(-100.0, 76.0), 2],
	[&"imp", Vector2(-96.0, -8.0), 3],
	[&"imp", Vector2(-72.0, 96.0), 3],
	[&"imp", Vector2(-104.0, -50.0), 2],
	[&"imp", Vector2(-50.0, -100.0), 2],
	[&"imp", Vector2(-92.0, 50.0), 3],
	[&"imp", Vector2(-58.0, -36.0), 3],
	# Puglins: ten, out on the farmland, in bands of three, three and four.
	[&"puglin", Vector2(40.0, -70.0), 3],
	[&"puglin", Vector2(88.0, -68.0), 3],
	# (Out on the east fields: the hill behind the village is the wolves'.)
	[&"puglin", Vector2(82.0, -14.0), 4],
	# The orcs have taken the mist village for their den (the map's `mist`):
	# two with great axes in its yard and four standing guard round it. The
	# city's land gate opens when they are dead ([LandsPlaces]). They used to
	# wade in the bay off the pier.
	[&"orc_greataxe", Vector2(10.0, -190.0), 2],
	[&"orc_guard", Vector2(10.0, -190.0), 4],
	# And two Arkdevas, each alone in a lair cut into the wood with its webs:
	# the web ravine in the big wood's south-east corner, far from the tracks
	# and the imps (level 8), and the marsh lair east of the mere (level 9).
	[&"arkdeva", Vector2(-104.0, -118.0), 1],
	[&"arkdeva", Vector2(-80.0, -216.0), 1],
]
const CAMP_SCENES := {
	&"imp": "res://scenes/enemies/imp.tscn",
	&"puglin": "res://scenes/enemies/puglin.tscn",
	&"orc": "res://scenes/enemies/orc.tscn",
	&"orc_greataxe": "res://scenes/enemies/orc_greataxe.tscn",
	&"orc_guard": "res://scenes/enemies/orc.tscn",
	&"arkdeva": "res://scenes/enemies/arkdeva.tscn",
}
## Kinds whose bands are mixed: every second member is the other scene.
const ORC_MIX := {&"orc": &"orc_greataxe"}
## How far from the middle of its camp each member stands.
const CAMP_SPREAD := 2.6

## Where the spawned bodies live, and the marks they are put on.
@onready var _players: Node3D = $Players
@onready var _points: Node3D = $SpawnPoints
@onready var _spawner: MultiplayerSpawner = $PlayerSpawner

## peer id -> which spawn point they were given, so two people do not arrive on
## top of each other.
var _taken: Dictionary = {}

## Where the creatures live, and the ones this node has sent to sleep.
var _creatures: Node
var _dozing: Dictionary = {}
var _think_tick: int = 0
var _music_tick: int = 0
var _music_on: StringName = &""
## Until when the orcs' fight music keeps going after the last orc lets go.
var _fight_music_until: float = 0.0


func _ready() -> void:
	_dress_village()
	_build_camps()
	_cull_distant_creatures()
	_prewarm_effects()
	_add_marsh_song()
	_creatures = get_node_or_null("Enemies")
	_watch_kills()
	# Levels over the creatures, and what each blow took off them.
	var words := CombatText.new()
	words.name = "CombatText"
	add_child(words)
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
	if net != null:
		if net.call("is_online"):
			add_child(NetHud.new())
		# A client says who it is only now that there is a level to be put in.
		net.call("entered_world")


## Wakes the creatures near a player and puts the far ones back to sleep.
##
## Only ever re-wakes something this put to sleep. Whether a creature simulates
## at all is the host's business — `Wolf._decides()` turns `_physics_process` off
## on every peer that is not the host — and a distance check that switched it
## back on would have every client simulating its own private wolves.
func _process(_delta: float) -> void:
	_music_tick += 1
	if _music_tick >= 20:
		_music_tick = 0
		_play_music_in_village()
	if _creatures == null or creature_think_distance <= 0.0:
		return
	_think_tick += 1
	if _think_tick < maxi(creature_think_interval, 1):
		return
	_think_tick = 0

	var watchers: Array[Player] = players()
	var reach := creature_think_distance * creature_think_distance
	for node in _creatures.get_children():
		var creature := node as Node3D
		if creature == null:
			continue
		var near := false
		for who in watchers:
			if creature.global_position.distance_squared_to(who.global_position) <= reach:
				near = true
				break
		# A corpse is kept awake: its own `_physics_process` is what topples it,
		# sinks it and finally clears it away, and asleep it would lie there
		# until somebody wandered back.
		if near or creature.get("is_dead") == true:
			if _dozing.has(creature):
				creature.set_process(true)
				# Only physics this node switched off goes back on — on a client
				# it was never on (see above).
				if _dozing[creature]:
					creature.set_physics_process(true)
				_dozing.erase(creature)
		elif not _dozing.has(creature):
			# Asleep means asleep: the rig is posed from `_process`, so leaving
			# that running kept every far creature animating (and, holding its
			# last velocity, walking on the spot) for nobody to see.
			var was_thinking := creature.is_physics_processing()
			_dozing[creature] = was_thinking
			if was_thinking:
				creature.set_physics_process(false)
			creature.set_process(false)
			var body := creature as CharacterBody3D
			if body != null:
				body.velocity = Vector3.ZERO

	# Forget creatures that have been freed since they were put to sleep.
	for sleeper in _dozing.keys():
		if not is_instance_valid(sleeper):
			_dozing.erase(sleeper)


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
	# His level and experience, on every peer at the same path ([Leveling]).
	var book := Leveling.new()
	book.name = "Leveling"
	body.add_child(book)
	# Before the tree as well: the spawner decides who to tell about this body
	# the moment it arrives, and a peer still loading must not be one of them.
	NetSmooth.guard(body.get_node_or_null("Body") as MultiplayerSynchronizer)
	return body


## Every creature's death is experience for the heroes near it — handed out by
## the host alone ([Leveling]). Creatures added later (a camp, a respawn) are
## watched as they arrive.
func _watch_kills() -> void:
	if _creatures == null:
		return
	for node in _creatures.get_children():
		_watch_kill(node)
	_creatures.child_entered_tree.connect(_watch_kill)


func _watch_kill(node: Node) -> void:
	if node.has_signal(&"died") and not node.has_meta(&"xp_watched"):
		node.set_meta(&"xp_watched", true)
		node.connect(&"died", _on_creature_died.bind(node))


func _on_creature_died(creature: Node) -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and not net.call("is_host"):
		return
	if creature is Node3D:
		Leveling.share(creature as Node3D, players())


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
		if peer != 1:
			net_census.rpc_id(peer, _census())


## Which creatures are still here, and what each has lost. Somebody who joins
## late built every camp fresh — including the wolves that have since died and
## been cleared away, and whole wolves that are missing legs here.
func _census() -> Dictionary:
	var here := {}
	var creatures := get_node_or_null("Enemies")
	if creatures == null:
		return here
	for node in creatures.get_children():
		if node.get("is_dead") == null:
			continue
		here[String(node.name)] = node.call("net_census") if node.has_method("net_census") else []
	return here


## Sent by the host to a peer that has just arrived: makes its creatures match.
@rpc("authority", "call_remote", "reliable")
func net_census(here: Dictionary) -> void:
	var creatures := get_node_or_null("Enemies")
	if creatures == null:
		return
	for node in creatures.get_children():
		if node.get("is_dead") == null:
			continue
		var key := String(node.name)
		if not here.has(key):
			# Gone on the host — killed and cleared before we arrived.
			_dozing.erase(node)
			node.queue_free()
		elif node.has_method("net_restore"):
			node.call("net_restore", here[key])


func _on_left(peer: int) -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.call("is_host"):
		_despawn(peer)
#endregion


## Stops drawing the creatures that are too far off to matter, shadows included.
##
## Set on the meshes rather than by hiding the body: a hidden node stops being
## simulated as well, and a wolf that only exists while it is on screen is a
## different game. `visibility_range_end` is a *drawing* cull — the creature goes
## on prowling, it is simply not drawn, and it is not drawn into the sun's shadow
## map either, which is where most of the saving is.
## Puts every band from `CAMPS` into the level. Deterministic — no random
## numbers — so the same creature has the same name and place on every peer.
func _build_camps() -> void:
	var creatures := get_node_or_null("Enemies")
	if creatures == null:
		return
	for i in CAMPS.size():
		var camp: Array = CAMPS[i]
		var kind: StringName = camp[0]
		var centre: Vector2 = camp[1]
		var count: int = camp[2]
		var scene := load(CAMP_SCENES[kind]) as PackedScene
		if scene == null:
			continue
		var band := StringName("camp_%d" % i)
		var other: PackedScene = load(CAMP_SCENES[ORC_MIX[kind]]) if ORC_MIX.has(kind) else null
		for k in count:
			var body := (other if other != null and k % 2 == 1 else scene).instantiate()
			body.name = "%s_%d_%d" % [String(kind).capitalize(), i, k]
			var angle := TAU * float(k) / float(count) + float(i)
			# One alone stands in the middle of its ground.
			var spread := CAMP_SPREAD if count > 1 else 0.0
			var at := Vector3(centre.x + cos(angle) * spread, 0.2,
					centre.y + sin(angle) * spread)
			body.position = at
			# Facing out from the fire, each watching its own way in.
			body.rotation.y = atan2(-cos(angle), -sin(angle))
			body.set("band", band)
			body.set("camp_centre", Vector3(centre.x, 0.0, centre.y))
			body.set("skin", 1 + (i + k) % 3)
			creatures.add_child(body)


## Builds everything a blow in a fight would otherwise build in the middle of
## it: the blood spray's emitters and materials, the splat and dust-ring images
## (worked out a pixel at a time in script) and the ground wave's spikes.
## Measured at the orc camp, a blow that drew blood cost the physics step it
## landed in 10 to 37 ms; paid here, it is part of the load.
func _prewarm_effects() -> void:
	Blood.prewarm(self)
	ImpactFx.warm()
	DustRing.prewarm()
	GroundFx.prewarm()


## The woman's voice over the misty mere (see [MarshSong]).
func _add_marsh_song() -> void:
	var marsh := get_node_or_null("Marsh") as Marsh
	if marsh == null:
		return
	var song := MarshSong.new()
	song.name = "MarshSong"
	song.marsh = marsh
	add_child(song)


func _cull_distant_creatures() -> void:
	if creature_draw_distance <= 0.0:
		return
	var creatures := get_node_or_null("Enemies")
	if creatures == null:
		return
	for node in creatures.find_children("*", "GeometryInstance3D", true, false):
		# Trails are drawn in world space under a box round the whole level, so
		# the range would be measured from the middle of the map, not from them.
		if node is SwordTrail or node is BladeArc:
			continue
		var mesh := node as GeometryInstance3D
		mesh.visibility_range_end = creature_draw_distance
		mesh.visibility_range_end_margin = maxf(creature_draw_distance * 0.12, 3.0)
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


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


#region The village
## The ground the village stands on, inside its fence (x, z, width, depth).
## Grown to the north and south and out to the east, so the bigger houses have
## room round them; behind it, to the north, the wooded hill ([Forest.GROVE]).
const VILLAGE := Rect2(20.0, 6.0, 96.0, 72.0)
## Everything in the village is spread out from this line (x, from the gate
## towers) and from the street (z), this much: the lot grows with the houses.
const SPREAD_FROM := Vector2(30.0, 42.0)
const SPREAD := Vector2(1.12, 1.4)
## How much bigger each kind of building is made, across and up: taller than
## they are wider, so a hut stands two storeys against a man rather than a shed.
const GROWTH := {
	"Hut": Vector2(1.5, 1.9),
	"Barracks": Vector2(1.3, 1.6),
	"TownCentre": Vector2(1.3, 1.55),
	"Windmill": Vector2(1.3, 1.55),
	"WatchTower": Vector2(1.3, 1.5),
	"GateTower": Vector2(1.25, 1.45),
	"Wall": Vector2(1.25, 1.35),
}
## And each row of houses steps back off the street this far as it grows.
const ROW_STEP := 4.0
const FENCE_SCENE := "res://unverified/assets/area/HighLandsFantasyBuildings/MiscProps/SM_WoodFence.fbx"
## Where the gap in the fence is: the west side, between the gate towers, where
## the track comes in.
const GATE := Vector2(35.0, 50.0)
## And the gap at the back, on the far side from the gate (z from, to).
const BACK_GATE := Vector2(44.0, 57.0)
## Where the villagers walk: along the street between the rows and round the
## square (as the village stood before it was spread; spread with it).
const STREET := [
	Vector3(36, 0, 42), Vector3(46, 0, 41.5), Vector3(56, 0, 42.5), Vector3(66, 0, 42),
	Vector3(76, 0, 41.5), Vector3(84, 0, 43), Vector3(90, 0, 40), Vector3(90, 0, 47),
	Vector3(60, 0, 44), Vector3(50, 0, 43.5),
]
const VILLAGERS := 7


## Where a point of the village as it stands in the scene ends up once the
## village is spread.
static func spread(at: Vector3) -> Vector3:
	return Vector3(SPREAD_FROM.x + (at.x - SPREAD_FROM.x) * SPREAD.x, at.y,
			SPREAD_FROM.y + (at.z - SPREAD_FROM.y) * SPREAD.y)


## Bigger and taller houses, spread out over a bigger lot to make room for them;
## a fence round the lot with its gate where the track comes in; people.
func _dress_village() -> void:
	var village := get_node_or_null("Level/Village") as Node3D
	if village == null:
		return
	for child in village.get_children():
		var thing := child as Node3D
		if thing == null:
			continue
		var kind := String(thing.name)
		var at := spread(thing.position)
		var grow := Vector2.ONE
		for key: String in GROWTH:
			if kind.begins_with(key):
				grow = GROWTH[key]
				break
		if kind.begins_with("Hut") or kind == "Barracks":
			at.z += -ROW_STEP if thing.position.z < SPREAD_FROM.y else ROW_STEP
		thing.position = at
		if grow != Vector2.ONE:
			_grow_building(thing, Vector3(grow.x, grow.y, grow.x))
	_build_fence(village)
	_settle_villagers(village)


## Makes a [Building] bigger by `by` in its own frame: the model inside it
## scaled (it may be taller than it is wide), and the hulls it collides with
## scaled to match, point by point — so the body itself is never scaled unevenly,
## which the physics does not take well.
static func _grow_building(thing: Node3D, by: Vector3) -> void:
	for child in thing.get_children():
		var body := child as StaticBody3D
		if body != null:
			for node in body.get_children():
				var cs := node as CollisionShape3D
				var hull := cs.shape as ConvexPolygonShape3D if cs != null else null
				if hull == null:
					continue
				var points := hull.points
				for i in points.size():
					points[i] = (cs.transform * points[i]) * by
				hull.points = points
				cs.transform = Transform3D.IDENTITY
			continue
		var part := child as Node3D
		if part != null:
			part.transform = Transform3D(Basis.from_scale(by), Vector3.ZERO) * part.transform


func _build_fence(village: Node3D) -> void:
	var scene := load(FENCE_SCENE) as PackedScene
	if scene == null:
		return
	var probe := scene.instantiate() as Node3D
	var box := _bounds(probe)
	probe.free()
	# The fence piece runs along its longer side.
	var along_x := box.size.x >= box.size.z
	var length := maxf(box.size.x, box.size.z) * 1.9
	if length <= 0.1:
		return
	var fence := Node3D.new()
	fence.name = "Fence"
	village.add_child(fence)
	var body := StaticBody3D.new()
	body.name = "FenceBody"
	body.collision_layer = 1
	fence.add_child(body)
	var r := VILLAGE
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var span := a.distance_to(b)
		var dir := (b - a).normalized()
		var pieces := int(ceil(span / length))
		for k in pieces:
			var mid := a + dir * (length * (float(k) + 0.5))
			if (mid - a).length() > span:
				mid = a + dir * (span - length * 0.5)
			# The gate: the west side, between the towers.
			if side == 3 and mid.y > GATE.x and mid.y < GATE.y:
				continue
			# And a way out at the back, onto the west land's road (the old
			# gate of the lands round the core, [Lands]).
			if side == 1 and mid.y > BACK_GATE.x and mid.y < BACK_GATE.y:
				continue
			# In a [Building], as every piece of the kit is: it is what finds the
			# textures the .fbx only names, without which the fence is white.
			var piece := Building.new()
			piece.build_collision = false
			piece.add_child(scene.instantiate())
			fence.add_child(piece)
			var yaw := atan2(-dir.y, dir.x) + (0.0 if along_x else PI * 0.5)
			piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.9), Vector3(mid.x, Terrain.height_under(mid.x, mid.y, 0.5), mid.y))
			var shape := CollisionShape3D.new()
			var slab := BoxShape3D.new()
			slab.size = Vector3(length, 1.3, 0.25)
			shape.shape = slab
			shape.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(mid.x, 0.65, mid.y))
			body.add_child(shape)


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.transform * mesh.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _settle_villagers(village: Node3D) -> void:
	if not ResourceLoader.exists(Villager.MODEL):
		return
	var spots: Array[Vector3] = []
	for p: Vector3 in STREET:
		spots.append(spread(p))
	for i in VILLAGERS:
		var one := Villager.new()
		one.name = "Villager%d" % i
		one.variant = i
		one.spots = spots
		one.position = spots[(i * 3) % spots.size()] + Vector3(0.8 * (i % 2), 0.0, 0.6 * (i % 3))
		village.add_child(one)


## The music: the orcs' fight track while this peer's player is fighting an
## orc (and for a few seconds after), the village's while he is inside the
## fence, and nothing out in the wild.
func _play_music_in_village() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	var me: Node3D = null
	for who in players():
		if who.is_multiplayer_authority():
			me = who
	var want := &""
	if me != null:
		var now := Time.get_ticks_msec() / 1000.0
		if _orcs_on(me):
			_fight_music_until = now + 5.0
		if now < _fight_music_until:
			want = &"orc_fight"
		elif VILLAGE.grow(6.0).has_point(Vector2(me.global_position.x, me.global_position.z)):
			want = &"world"
	# Against what is actually on, not what this last asked for: the menu's
	# track is still playing when the level loads, and out in the wild "want
	# nothing" would otherwise equal "asked for nothing" and leave it on.
	if want == music.call("current_track"):
		return
	_music_on = want
	if want.is_empty():
		music.call("stop")
	else:
		music.call("play", want)


## True while an orc is after `me`: chasing or fighting, alive and near.
func _orcs_on(me: Node3D) -> bool:
	for node in get_tree().get_nodes_in_group("enemy"):
		var orc := node as OrcWarrior
		if orc == null or orc.is_dead:
			continue
		if orc.global_position.distance_to(me.global_position) > 35.0:
			continue
		if orc.mode == Brute.Mode.CHASE or orc.mode == Brute.Mode.FIGHT:
			return true
	return false
#endregion
