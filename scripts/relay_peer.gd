class_name RelayPeer
extends MultiplayerPeerExtension

## A game played from different homes (the user's word, 2026-10-21): no port
## to open on anybody's router — every game keeps one WebSocket to the relay
## (`relay/server.py`), which passes the packets on. One game hosts a room and
## is given a short code; the others join with the code.
##
## To the engine this is a peer like ENet's: the host is the server (id 1) and
## sees the others, a joiner sees only the host and the engine relays the rest
## through it (`server_relay`). Binary frames: 4-byte peer id (target going
## out, sender coming in), channel, mode, payload; JSON text for the room.

signal hosted(code: String)
signal failed(why: String)

const MAX_PACKET := 1 << 20

var code: String = ""
var _ws := WebSocketPeer.new()
var _hello: Dictionary = {}
var _said_hello: bool = false
var _id: int = 0
var _server: bool = false
var _status: int = CONNECTION_DISCONNECTED
var _incoming: Array = []
var _target: int = 0
var _channel: int = 0
var _mode: int = TRANSFER_MODE_RELIABLE
var _refuse: bool = false
var _peers: Dictionary = {}


## Opens a room: `hosted` comes with its code.
func host(url: String, protocol: int) -> Error:
	return _open(url, {"op": "host", "proto": protocol})


## Into the room with `room_code`.
func join(url: String, room_code: String, protocol: int) -> Error:
	return _open(url, {"op": "join", "code": room_code.strip_edges().to_upper(), "proto": protocol})


func _open(url: String, hello: Dictionary) -> Error:
	_ws.inbound_buffer_size = 1 << 23
	_ws.outbound_buffer_size = 1 << 23
	_ws.max_queued_packets = 8192
	var err := _ws.connect_to_url(url)
	if err != OK:
		return err
	_hello = hello
	_said_hello = false
	_status = CONNECTION_CONNECTING
	return OK


func _poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _said_hello:
			_said_hello = true
			_ws.send_text(JSON.stringify(_hello))
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			if _ws.was_string_packet():
				_on_text(pkt.get_string_from_utf8())
			elif pkt.size() >= 6:
				_incoming.append([pkt.decode_s32(0), pkt[4], pkt[5], pkt.slice(6)])
	elif state == WebSocketPeer.STATE_CLOSED and _status != CONNECTION_DISCONNECTED:
		var was := _status
		_status = CONNECTION_DISCONNECTED
		if was == CONNECTION_CONNECTING:
			failed.emit("no_relay")
		elif _server:
			for peer: int in _peers.keys():
				peer_disconnected.emit(peer)
			_peers.clear()
		else:
			peer_disconnected.emit(1)


func _on_text(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	var msg := data as Dictionary
	match String(msg.get("op", "")):
		"hosted":
			code = String(msg["code"])
			_id = 1
			_server = true
			_status = CONNECTION_CONNECTED
			hosted.emit(code)
		"joined":
			code = String(msg.get("code", ""))
			_id = int(msg["id"])
			_server = false
			_status = CONNECTION_CONNECTED
			_peers[1] = true
			peer_connected.emit(1)
		"peer_in":
			if _server and not _refuse:
				var who := int(msg["id"])
				_peers[who] = true
				peer_connected.emit(who)
		"peer_out":
			var gone := int(msg["id"])
			if _peers.erase(gone):
				peer_disconnected.emit(gone)
		"closed":
			_ws.close()
		"error":
			failed.emit(String(msg.get("why", "error")))
			_status = CONNECTION_DISCONNECTED
			_ws.close()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(6)
	out.encode_s32(0, _target)
	out[4] = _channel & 0xff
	out[5] = _mode & 0xff
	out.append_array(buffer)
	return _ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return (_incoming.pop_front() as Array)[3]


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_max_packet_size() -> int:
	return MAX_PACKET


func _get_packet_peer() -> int:
	return int((_incoming[0] as Array)[0]) if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return int((_incoming[0] as Array)[1]) if not _incoming.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return int((_incoming[0] as Array)[2]) as TransferMode if not _incoming.is_empty() else TRANSFER_MODE_RELIABLE


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _server


func _is_server_relay_supported() -> bool:
	return true


func _get_connection_status() -> ConnectionStatus:
	return _status as ConnectionStatus


func _close() -> void:
	_ws.close()
	_status = CONNECTION_DISCONNECTED
	_incoming.clear()
	_peers.clear()


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _server:
		_ws.send_text(JSON.stringify({"op": "kick", "id": peer}))


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode as TransferMode


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse
