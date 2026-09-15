extends Node

## Who is in the game, and how they got here.
##
## An autoload beside [Game], for the same reason: the connection is made on a
## screen that is gone by the time the world exists, and the world simply asks.
##
## The model is a **listen server** — the host is a player, peer id `1`, and
## also the authority on everything that is not somebody's own body. There is no
## dedicated server, no matchmaking and no lobby browser; two to four people who
## know an address is the whole of it.
##
## What lives here is the *connection* and the *roster*. Spawning bodies into a
## level is the level's job ([World]), because only it knows where the ground is
## — but it cannot spawn anyone until their character is known, which is why the
## roster is here and why a client announces its choice the moment it connects.

## Where to listen, and how many may be in at once.
const PORT := 7777
const MAX_PLAYERS := 4

## A peer joined, left, or announced what they are playing.
signal lobby_changed()
## Something went wrong, with a line fit to put on a menu.
signal hosting_failed(why: String)
signal join_failed(why: String)
## A peer said what they are playing. The world listens for this rather than for
## `peer_connected`, because only now is there enough to spawn.
signal player_announced(peer: int, character: StringName)
## A peer went away and their body has to go with them.
signal player_left(peer: int)

## peer id -> character id, a key of `Game.CHARACTERS`. The host's own entry is
## written before the world loads; everyone else's arrives by `announce`.
var roster: Dictionary = {}

## Where the world is, so hosting and joining both end up in the same place.
const WORLD := "res://scenes/world/greybox_world.tscn"

## Set while a join is in flight, so the connection callbacks know whether the
## scene change is still owed.
var _joining_as: StringName = &""


func _ready() -> void:
	if multiplayer == null:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_lost)


#region Getting in and out
## Opens the game to others and loads the world. `character` is what the host
## will be playing; it goes straight into the roster because there is nobody to
## announce it to yet.
func host(character: StringName) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		hosting_failed.emit("Could not open port %d (error %d)." % [PORT, err])
		return false
	if not _open(peer):
		hosting_failed.emit("There is no multiplayer to host with yet.")
		return false
	roster = {1: character}
	lobby_changed.emit()
	get_tree().change_scene_to_file(WORLD)
	return true


## Connects to a host. The world is not loaded here: it waits for
## `connected_to_server`, because a client that changes scene before the
## handshake has nothing to be in the world *with*.
func join(address: String, character: StringName) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), PORT)
	if err != OK:
		join_failed.emit("Could not reach %s (error %d)." % [address, err])
		return false
	if not _open(peer):
		join_failed.emit("There is no multiplayer to join with yet.")
		return false
	_joining_as = character
	return true


## Hangs up. Safe to call when there is nothing to hang up, which is what makes
## it the right first line of `host()`, `join()` and starting a solo game.
##
## Put back to an `OfflineMultiplayerPeer` rather than to null. A tree with *no*
## peer at all is not "not networked", it is broken: `MultiplayerSpawner.spawn()`
## refuses to run without one, so a solo game would load a level with nobody in
## it. Offline is a peer whose only member is you, which is exactly what a solo
## game is.
func leave() -> void:
	_joining_as = &""
	roster.clear()
	if multiplayer == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	lobby_changed.emit()


## True while there are other people to consider. An offline peer does not
## count: it says "connected" because it is connected to itself.
func is_online() -> bool:
	if multiplayer == null:
		return false
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
			and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


## True when this peer is the one that decides things: the wolves, the hits, the
## spawns. The host is also playing, so this is not "is a server".
func is_host() -> bool:
	return not is_online() or multiplayer.is_server()


## True when the connection is in a state to be used at all. A script main loop
## has no tree under its root for the first frame, and `multiplayer` is null
## until it has.
func is_ready() -> bool:
	return multiplayer != null


## This peer's id. `1` when hosting, and `1` when offline — so code that keys on
## it works the same in a solo game.
func local_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func _open(peer: MultiplayerPeer) -> bool:
	if multiplayer == null:
		return false
	multiplayer.multiplayer_peer = peer
	return true


## What `who` is playing, or whatever the local player last picked if they have
## not said yet — which is the right answer offline, where the only peer is you.
func character_of(peer: int) -> StringName:
	var game := get_node_or_null("/root/Game")
	var fallback: StringName = game.call("character") if game != null else &"tariel"
	return roster.get(peer, fallback) as StringName
#endregion


#region The roster
## Sent by a client the moment it is connected: this is who I am playing. The
## host writes it down and pushes the whole roster back out, which is also the
## signal the world waits on before giving that peer a body — a player with no
## character is a player with nothing to spawn.
@rpc("any_peer", "call_local", "reliable")
func announce(character: StringName) -> void:
	if not multiplayer.is_server():
		return
	var who := multiplayer.get_remote_sender_id()
	if who == 0:
		who = 1
	roster[who] = character
	sync_roster.rpc(roster)
	lobby_changed.emit()
	player_announced.emit(who, character)


## The host's copy of the roster, sent to everyone whenever it changes.
@rpc("authority", "call_local", "reliable")
func sync_roster(sent: Dictionary) -> void:
	roster = sent.duplicate()
	lobby_changed.emit()

#endregion


#region Connection callbacks
func _on_peer_connected(_who: int) -> void:
	lobby_changed.emit()


func _on_peer_disconnected(who: int) -> void:
	roster.erase(who)
	if multiplayer.is_server():
		sync_roster.rpc(roster)
	player_left.emit(who)
	lobby_changed.emit()


func _on_connected() -> void:
	# Announce first, load second: the host has to know what to spawn before the
	# client is anywhere to see it.
	announce.rpc_id(1, _joining_as)
	var going := _joining_as
	_joining_as = &""
	if going != &"":
		get_tree().change_scene_to_file(WORLD)


func _on_connect_failed() -> void:
	join_failed.emit("No answer from that address.")
	leave()


func _on_host_lost() -> void:
	join_failed.emit("The host closed the game.")
	leave()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
#endregion
