class_name DungeonCrowd
extends RefCounted

## Who of a crowd has a turn at a hero and where the rest wait (the ones held
## back on rings round him, the orcs' turns). Taken out of dungeon.gd
## (2026-10-28); every function takes the dungeon as `dun`.

## Not all of them at once (the user's word, 2026-10-20: a band of puglins
## rolling together cannot be beaten; at most two at him, the rest throwing
## from off): `CROWD` a hero may be fought by at a time, an orc near him
## counting as one. The ones let at him keep their turn while they are near;
## the rest are held back ([member Fighter.held_back]): out of reach, throwing.
static func _hold_back_crowd(dun: Dungeon, heroes: Array[Player]) -> void:
	var standing: Array[Player] = []
	for hero in heroes:
		if not hero.is_dead:
			standing.append(hero)
	var small: Array = []
	var brutes: Array = []
	var shooters: Array = []
	var gunners: Array[Fighter] = []
	for body in dun._alive:
		if not is_instance_valid(body) or bool(body.get("is_dead")):
			continue
		if body is Flyer or Dungeon.SHOOTERS.has(String(body.scene_file_path)):
			shooters.append(body)
			# (they keep off by themselves: no place among those at him; but
			# each its own bearing round him, not all in a line)
			if not (body is Flyer):
				if body is Fighter:
					gunners.append(body)
				continue
		var gap := INF
		for hero in standing:
			gap = minf(gap, body.global_position.distance_to(hero.global_position))
		if body is PackBrute:
			if gap < 9.0 and not (body as PackBrute).held_back:
				brutes.append(body)
			continue
		# the shaman keeps back by itself ([FoeRoles]), and the flyers do
		if FoeRoles.role_of(body) == &"shaman" or body is Flyer:
			continue
		if "held_back" in body:
			small.append([gap, body])
	# Who has a turn at him now: by weight and the fight's pressure
	# ([CombatDirector]; the user's word, 2026-10-27: two at once, the one he
	# walks up to at once, now and then a third, one at most under fire).
	small.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var keep: Array[Node3D] = dun.director.choose(small, dun._holders, standing, shooters, brutes)
	dun._holders = keep
	var waiting: Array[Fighter] = []
	for pair: Array in small:
		var held: bool = not keep.has(pair[1])
		(pair[1] as Node).set("held_back", held)
		if held:
			waiting.append(pair[1])
	DungeonCrowd._spread(dun, waiting, standing)
	# the archers and mages: each its own side of him, some behind him
	for g in gunners:
		g.shoot_slot = true
	DungeonCrowd._spread(dun, gunners, standing, Dungeon.SHOOT_RINGS)


## The ones held back, round each hero on `HOLD_RINGS` at even bearings (the
## user's word: no more than three in a place), each kept to the side of him
## it is on so none crosses another.
static func _spread(dun: Dungeon, waiting: Array[Fighter], standing: Array[Player], rings: Array = Dungeon.HOLD_RINGS) -> void:
	if standing.is_empty():
		return
	var by_hero := {}
	for body in waiting:
		# round the hero it is after (with others it may turn to the other);
		# none, the nearest
		var best: Player = dun.director._whose(body, standing) if dun.director != null else standing[0]
		if not by_hero.has(best):
			by_hero[best] = []
		var off := body.global_position - best.global_position
		(by_hero[best] as Array).append([atan2(off.x, off.z), body])
	for hero: Player in by_hero:
		var list: Array = by_hero[hero]
		list.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var n := list.size()
		var start := float(list[0][0])
		for k in n:
			var body: Fighter = list[k][1]
			body.held_angle = start + TAU * float(k) / float(n)
			body.held_radius = float(rings[k % rings.size()])


## Two orcs (or more) at one lone hero take turns (the user's word): one at
## him, the other off, waiting; a blow on the waiting one brings it in and
## sends the other off, and every so often they change over by themselves.
## With more heroes they fight as they would.
static func _lead_orcs(dun: Dungeon, standing: Array[Player]) -> void:
	var orcs: Array[PackBrute] = []
	for body in dun._alive:
		if not is_instance_valid(body):
			continue
		var o := body as PackBrute
		if o != null and not o.is_dead:
			orcs.append(o)
	if orcs.size() < 2 or standing.size() != 1:
		for o in orcs:
			o.turn_led = false
			o.held_back = false
		dun._orc_on = null
		return
	var now := Time.get_ticks_msec() / 1000.0
	var on := dun._orc_on as PackBrute
	if on == null or not orcs.has(on):
		on = orcs[0]
		dun._orc_since = now
		dun._orc_hand_over = randf_range(14.0, 22.0)
	# A blow on one that waits: its turn now.
	for o in orcs:
		var was := float(dun._orc_health.get(o, o.health))
		if o != on and o.health < was - 0.01:
			on = o
			dun._orc_since = now
			dun._orc_hand_over = randf_range(14.0, 22.0)
		dun._orc_health[o] = o.health
	if now - dun._orc_since > dun._orc_hand_over and on.act == Fighter.Act.NONE:
		on = orcs[(orcs.find(on) + 1) % orcs.size()]
		dun._orc_since = now
		dun._orc_hand_over = randf_range(14.0, 22.0)
	dun._orc_on = on
	for o in orcs:
		o.turn_led = true
		o.held_back = o != on
