extends RefCounted

## Puts Tariel back on the procedural rig for the length of a test run.
##
## Tariel plays on the skinned rig now (`tariel_rigged_visuals.tscn`). The tests
## that call this check the procedural rig's own workings — named joints like
## `boot_l`, the UAL2 clips — which Avtandil still uses and which have to keep
## working. Profiles are cached resources, so changing the loaded one here is
## what `Game.profile()` hands the level; nothing on disk changes.
static func use() -> void:
	var tariel := load("res://scenes/player/tariel.tres") as CharacterProfile
	tariel.visuals = load("res://scenes/player/tariel_visuals.tscn")
	# Held on to for the rest of the run: once nothing references the profile
	# it drops out of the cache, and the next load() reads the file again.
	Engine.set_meta(&"procedural_tariel", tariel)
