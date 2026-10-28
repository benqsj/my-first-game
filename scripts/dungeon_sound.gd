class_name DungeonSound
extends RefCounted

## A place's sound: its ambience loops, the sounds now and then, the echo bus
## the world's sounds go through while the dungeon stands. Taken out of
## dungeon.gd (2026-10-28); every function takes the dungeon as `dun`.

## The dungeon's sounds read in now too, and held: the first thunder over the
## rampart was read off the disk as it rolled (a 70 ms stall).
static func _load_sounds(dun: Dungeon) -> void:
	for file in ResourceLoader.list_directory(Dungeon.SND):
		if file.get_extension() == "wav":
			var stream := load(Dungeon.SND + file)
			if stream != null:
				dun._sounds.append(stream)
	# and the dungeon's music, the lord's too: read in as his court came up,
	# it was a stall just as the dark lifted there
	var music := dun.get_node_or_null("/root/Music")
	if music != null and music.get_script() != null:
		var tracks: Dictionary = (music.get_script() as Script).get_script_constant_map().get("TRACKS", {})
		for key: StringName in [&"dungeon", &"dungeon_boss"]:
			for path: String in tracks.get(key, []):
				if ResourceLoader.exists(path):
					dun._sounds.append(load(path))


#region Sounds
## The dungeon's own bus, its echo after the place (a hall rings, a cave
## more, the open air hardly), the world's sounds sent through it ([Sfx]).
static func _sound_bus(dun: Dungeon) -> void:
	dun._bus = AudioServer.get_bus_index(&"Dungeon")
	if dun._bus < 0:
		dun._bus = AudioServer.bus_count
		AudioServer.add_bus(dun._bus)
		AudioServer.set_bus_name(dun._bus, &"Dungeon")
		AudioServer.set_bus_send(dun._bus, &"Master")
		var echo := AudioEffectReverb.new()
		AudioServer.add_bus_effect(dun._bus, echo)
	Sfx.bus = &"Dungeon"


static func _echo(dun: Dungeon, kind: String) -> void:
	if dun._bus < 0 or AudioServer.get_bus_effect_count(dun._bus) == 0:
		return
	var echo := AudioServer.get_bus_effect(dun._bus, 0) as AudioEffectReverb
	if echo == null:
		return
	match kind:
		"hall", "gold_hall":
			echo.room_size = 0.85
			echo.damping = 0.35
			echo.wet = 0.26
		"cave", "crypt", "flood_crypt", "cell_cave", "twin_cave":
			echo.room_size = 0.95
			echo.damping = 0.25
			echo.wet = 0.38
		"court", "throne":
			echo.room_size = 0.5
			echo.damping = 0.6
			echo.wet = 0.1
		_:
			echo.room_size = 0.3
			echo.damping = 0.8
			echo.wet = 0.04
	echo.dry = 1.0


## A sound that goes round and round.
static func _loop(dun: Dungeon, file: String) -> AudioStream:
	var path := Dungeon.SND + file
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return stream


## The place's own sound (wind through the windows, the cave's breath, birds
## or by night nothing but the wind), and its echo.
static func _ambience(dun: Dungeon, i: int) -> void:
	for player in dun._amb:
		if is_instance_valid(player):
			player.queue_free()
	dun._amb.clear()
	var r := dun._room(i)
	var kind: String = r["kind"]
	DungeonSound._echo(dun, kind)
	var night := i >= 3
	var parts: Array = []
	match kind:
		"hall":
			# the orcs' drums somewhere deep in their palace
			parts = [["wind_loop.wav", -24.0], ["drums_far_loop.wav", -25.0]]
		"gold_hall":
			# the storm's wind in the open hall, the drums far off (the rain's
			# own sound comes with the rain, TerracePlaces)
			parts = [["wind_strong_loop.wav" if TerracePlaces.hall_mood == "storm" else "wind_loop.wav", -15.0],
					["drums_far_loop.wav", -28.0]]
		"court", "terrace":
			parts = [["wind_loop.wav", -15.0], ["drums_far_loop.wav", -30.0]]
		"throne":
			parts = [["wind_loop.wav", -15.0]]
		"cave", "twin_cave":
			parts = [["cave_loop.wav", -9.0], ["crystal_hum_loop.wav", -17.0]]
		"forest":
			# the dead wood: the wind in bare boughs, no bird sings in it
			parts = [["wind_loop.wav", -14.0]]
			if night:
				parts.append(["crickets_loop.wav", -18.0])
		"sky":
			parts = [["wind_strong_loop.wav", -10.0]]
		"crypt", "flood_crypt":
			parts = [["cave_loop.wav", -14.0]]
		"cell_cave":
			parts = [["cave_loop.wav", -12.0], ["drums_far_loop.wav", -30.0]]
		"holy_spring":
			# a still autumn wood: the wind in the leaves, faint
			parts = [["wind_loop.wav", -17.0]]
		"altar":
			# the pine wood at dusk: the wind, crickets
			parts = [["wind_loop.wav", -16.0], ["crickets_loop.wav", -20.0]]
		"swamp":
			parts = [["frogs_loop.wav", -11.0], ["wind_loop.wav", -26.0]]
			if SwampMere.raining:
				parts.append(["rain_loop.wav", -17.0])
			if night:
				parts.append(["crickets_loop.wav", -15.0])
		"mountain":
			parts = [["wind_strong_loop.wav", -8.0], ["rain_loop.wav", -9.0]]
		"rampart":
			parts = [["wind_loop.wav", -14.0], ["drums_far_loop.wav", -27.0]]
		"lake", "falls":
			parts = [["wind_loop.wav", -16.0]]
		"fort":
			parts = [["wind_loop.wav", -14.0], ["drums_far_loop.wav", -30.0]]
		"clouds":
			parts = [["wind_strong_loop.wav", -11.0]]
		"lord_court":
			parts = [["wind_loop.wav", -11.0], ["drums_far_loop.wav", -26.0]]
		"war_camp":
			parts = [["wind_loop.wav", -13.0], ["drums_far_loop.wav", -22.0]]
	for part: Array in parts:
		var stream := DungeonSound._loop(dun, String(part[0]))
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -60.0
		player.bus = &"Master"
		dun.add_child(player)
		player.play(dun._rng.randf_range(0.0, 8.0))
		dun.create_tween().tween_property(player, "volume_db", float(part[1]), 2.5)
		dun._amb.append(player)


## The sounds that come now and then: drips in the cave and the broken hall,
## thunder far off once the day goes, an owl in the forest at night.
static func _now_and_then(dun: Dungeon, delta: float, heroes: Array[Player]) -> void:
	if heroes.is_empty() or dun.current < 0 or dun.rooms.is_empty():
		return
	var r := dun._room(dun.current)
	var kind: String = r["kind"]
	var near := heroes[0].global_position
	dun._drip_in -= delta
	if dun._drip_in <= 0.0:
		dun._drip_in = dun._rng.randf_range(1.5, 5.0)
		if kind == "cave" or kind == "twin_cave" or kind == "crypt" or kind == "flood_crypt" or r.has("hole"):
			var at := near + Vector3(dun._rng.randf_range(-12.0, 12.0), 3.0, dun._rng.randf_range(-12.0, 12.0))
			Sfx.play(dun, Dungeon.SND + "drip_%d.wav" % dun._rng.randi_range(1, 3), null, at, 1.0, -4.0, 0.15)
	dun._thunder_in -= delta
	if dun._thunder_in <= 0.0:
		dun._thunder_in = dun._rng.randf_range(25.0, 50.0)
		if dun._phase >= 2.5 and kind != "cave" and kind != "twin_cave":
			Sfx.play_flat(dun, Dungeon.SND + "thunder.wav", dun._rng.randf_range(0.85, 1.1), -11.0)
	dun._creak_in -= delta
	if dun._creak_in <= 0.0:
		dun._creak_in = dun._rng.randf_range(7.0, 15.0)
		if not dun._creaks.is_empty():
			var at: Vector3 = dun._creaks[dun._rng.randi() % dun._creaks.size()]
			Sfx.play(dun, Dungeon.SND + "creak.wav", null, at, 1.0, 2.0, 0.12)
	dun._bats_in -= delta
	if dun._bats_in <= 0.0:
		dun._bats_in = dun._rng.randf_range(9.0, 20.0)
		if kind == "cave":
			var at := dun.centre(dun.current) + Vector3(dun._rng.randf_range(-15.0, 15.0), float(r["h"]) - 3.0,
					dun._rng.randf_range(-15.0, 15.0))
			Sfx.play(dun, Dungeon.SND + "bats.wav", null, at, 1.0, 2.0, 0.1)
			dun._bat_flock(at)
	dun._eagle_in -= delta
	if dun._eagle_in <= 0.0:
		dun._eagle_in = dun._rng.randf_range(12.0, 26.0)
		if kind in ["sky", "lake", "fort", "falls", "clouds", "lord_court", "war_camp"] and (kind == "sky" or dun._phase < 2.5):
			Sfx.play_flat(dun, Dungeon.SND + "eagle.wav", dun._rng.randf_range(0.92, 1.08), -9.0)
	dun._flap_in -= delta
	if dun._flap_in <= 0.0:
		dun._flap_in = dun._rng.randf_range(6.0, 13.0)
		if kind in ["court", "terrace", "throne", "sky", "rampart", "mountain", "lake", "fort", "falls", "clouds", "lord_court", "war_camp"]:
			var at := near + Vector3(dun._rng.randf_range(-14.0, 14.0), 4.0, dun._rng.randf_range(-14.0, 14.0))
			Sfx.play(dun, Dungeon.SND + "flap.wav", null, at, 1.0, -2.0, 0.15)
	dun._stones_in -= delta
	if dun._stones_in <= 0.0:
		dun._stones_in = dun._rng.randf_range(8.0, 16.0)
		# (not the golden hall: under its ceiling stones fell from nowhere;
		# dust trickles from its roof's broken edges, TerracePlaces)
		if kind in ["hall", "crypt"]:
			dun._falling_stones(near, float(r["h"]))
	dun._storm_in -= delta
	if dun._storm_in <= 0.0:
		dun._storm_in = dun._rng.randf_range(7.0, 15.0)
		if kind == "mountain":
			dun._lightning()
		elif kind == "gold_hall" and TerracePlaces.hall_mood == "storm":
			# more often over the palace hall (the user's word, 2026-10-24)
			dun._storm_in = dun._rng.randf_range(2.5, 6.0)
			dun._lightning()
	dun._owl_in -= delta
	if dun._owl_in <= 0.0:
		dun._owl_in = dun._rng.randf_range(14.0, 28.0)
		if kind == "forest" or (kind == "swamp" and dun._phase >= 2.8):
			var at := near + Vector3(dun._rng.randf_range(-25.0, 25.0), 8.0, dun._rng.randf_range(-25.0, 25.0))
			Sfx.play(dun, Dungeon.SND + "owl.wav", null, at, 1.0, 0.0, 0.08)


## A fire's crackle where it burns, heard close by.
static func _crackle(dun: Dungeon, holder: Node3D, at: Vector3) -> void:
	var stream := DungeonSound._loop(dun, "fire_loop.wav")
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -4.0
	player.unit_size = 2.2
	player.max_distance = 14.0
	player.bus = &"Dungeon"
	player.position = at
	holder.add_child(player)
	player.play(dun._rng.randf_range(0.0, 7.0))
#endregion
