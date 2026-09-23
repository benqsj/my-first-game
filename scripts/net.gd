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

## Where a host calls out "there is a game here" on the local network, and what
## it says. Bump `PROTOCOL` whenever two builds could no longer play together —
## a joiner only lists hosts that speak the same one.
const DISCOVERY_PORT := 7778
const BEACON := "VEPXIS"
const PROTOCOL := 2
## How often a host calls out, and how long a joiner remembers a host that has
## gone quiet.
const BEACON_EVERY := 1.0
const FORGET_AFTER := 3.5

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
## The list of games heard on the local network changed.
signal games_changed()

## peer id -> character id, a key of `Game.CHARACTERS`. The host's own entry is
## written before the world loads; everyone else's arrives by `announce`.
var roster: Dictionary = {}

## Where the world is, so hosting and joining both end up in the same place.
const WORLD := "res://scenes/world/greybox_world.tscn"

## Set while a join is in flight, so the connection callbacks know whether the
## scene change is still owed.
var _joining_as: StringName = &""
## Who this client is playing, kept until the level has loaded and there is
## somewhere to be announced *into*.
var _announce_as: StringName = &""

## Host only: the peers that have finished loading the level. Nothing is sent to
## anyone else — no bodies, no wolves — because a peer still on the loading
## screen has nowhere to put them, and what it drops it never gets again.
var _in_world: Dictionary = {}

## Games heard on the local network: address -> { name, players, max, seen }.
var games: Dictionary = {}
var _beacon: PacketPeerUDP
var _beacon_in := 0.0
var _ear: PacketPeerUDP


func _ready() -> void:
	if multiplayer == null:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_host_lost)


func _process(delta: float) -> void:
	_call_out(delta)
	_listen()


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
	_in_world = {1: true}
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_in = 0.0
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
	_announce_as = &""
	roster.clear()
	_in_world.clear()
	stop_looking()
	if _beacon != null:
		_beacon.close()
		_beacon = null
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


## Called by the level once it has loaded. On a client this is the moment to say
## who we are: the host spawns us the instant it hears, and only now is there a
## level here for that body — and everyone else's — to arrive in.
func entered_world() -> void:
	if not is_online() or multiplayer.is_server() or _announce_as == &"":
		return
	announce.rpc_id(1, _announce_as)
	_announce_as = &""


## Whether `peer` should be sent anything about the level yet. Used as the
## visibility filter on every [MultiplayerSynchronizer] (see [NetSmooth]), so
## a peer still loading is sent nothing and a peer that has loaded is sent all
## of it — which is also how somebody who joins late gets everyone already
## there.
func sees(peer: int) -> bool:
	return peer == 1 or not is_online() or not multiplayer.is_server() \
			or _in_world.has(peer)


## How long a message takes to reach the host and come back, in milliseconds.
## Zero when that is not a question (offline, or hosting).
func ping_ms() -> int:
	if multiplayer == null:
		return 0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or multiplayer.is_server():
		return 0
	var host := enet.get_peer(1)
	if host == null:
		return 0
	return int(host.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## This machine's addresses on the local network — what somebody else types to
## join. Loopback and link-local addresses are left out: nobody can reach those.
static func lan_addresses() -> Array[String]:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") \
				or address.begins_with("169.254."):
			continue
		var parts := address.split(".")
		if parts.size() != 4:
			continue
		var a := int(parts[0])
		var b := int(parts[1])
		var private := a == 10 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31)
		if private and not found.has(address):
			found.append(address)
	# Some networks hand out addresses outside the usual private ranges. Better
	# to show one of those than nothing at all.
	if found.is_empty():
		for address in IP.get_local_addresses():
			if not address.contains(":") and not address.begins_with("127.") \
					and not address.begins_with("169.254.") and not found.has(address):
				found.append(address)
	return found
#endregion


#region Finding a game on the local network
## Starts listening for hosts on this network. The menu calls this while the
## join page is up; `games` fills in as they are heard.
func start_looking() -> void:
	if _ear != null:
		return
	_ear = PacketPeerUDP.new()
	var err := _ear.bind(DISCOVERY_PORT, "*")
	if err != OK:
		# Another copy of the game on this machine is already listening. Not
		# worth a complaint: typing the address still works.
		_ear = null
	games.clear()
	games_changed.emit()


func stop_looking() -> void:
	if _ear != null:
		_ear.close()
		_ear = null


## Host only: once a second, to everyone on the network, "a game is here".
## Sent to the general broadcast address and to each subnet's own, because some
## systems only pass one of the two.
func _call_out(delta: float) -> void:
	if _beacon == null or not is_online() or not multiplayer.is_server():
		return
	_beacon_in -= delta
	if _beacon_in > 0.0:
		return
	_beacon_in = BEACON_EVERY
	var who := String(roster.get(1, &"host")).capitalize()
	var line := "%s|%d|%s|%d|%d" % [BEACON, PROTOCOL, who, roster.size(), MAX_PLAYERS]
	var packet := line.to_utf8_buffer()
	var targets: Array[String] = ["255.255.255.255"]
	for address in lan_addresses():
		var parts := address.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for target in targets:
		_beacon.set_dest_address(target, DISCOVERY_PORT)
		_beacon.put_packet(packet)


func _listen() -> void:
	if _ear == null:
		return
	var changed := false
	var now := Time.get_ticks_msec() / 1000.0
	while _ear.get_available_packet_count() > 0:
		var packet := _ear.get_packet()
		var from := _ear.get_packet_ip()
		var parts := packet.get_string_from_utf8().split("|")
		if parts.size() < 5 or parts[0] != BEACON or from.is_empty():
			continue
		var fresh := not games.has(from)
		games[from] = {
			"name": parts[2],
			"players": int(parts[3]),
			"max": int(parts[4]),
			"same_version": int(parts[1]) == PROTOCOL,
			"seen": now,
		}
		changed = changed or fresh
	for address in games.keys():
		if now - float(games[address]["seen"]) > FORGET_AFTER:
			games.erase(address)
			changed = true
	if changed:
		games_changed.emit()
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
	# Announcing is only done from inside the level, so from now on this peer
	# can be sent the level's bodies.
	_in_world[who] = true
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
	_in_world.erase(who)
	if multiplayer.is_server():
		sync_roster.rpc(roster)
	player_left.emit(who)
	lobby_changed.emit()


func _on_connected() -> void:
	# Load first, announce second. The host spawns us the moment it hears who we
	# are, and sends everybody else's body at the same time; a client that was
	# still loading would have nowhere to put any of it. The level calls
	# `entered_world()` when it is ready.
	var going := _joining_as
	_joining_as = &""
	stop_looking()
	if going != &"":
		_announce_as = going
		get_tree().change_scene_to_file(WORLD)


func _on_connect_failed() -> void:
	join_failed.emit("No answer from that address.")
	leave()


func _on_host_lost() -> void:
	join_failed.emit("The host closed the game.")
	leave()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
#endregion
