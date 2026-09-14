extends Node

## What the game knows before a level loads: who is being played.
##
## An autoload rather than something passed in, because the choice is made on a
## screen that is gone by the time the world exists. The world simply asks.
##
## The character can also be named on the command line, which is how a test — or
## anyone who has not built the menu yet — plays somebody other than the default:
##
##     godot --path . -- avtandil

const CHARACTERS := {
	&"tariel": "res://scenes/player/tariel.tres",
	&"avtandil": "res://scenes/player/avtandil.tres",
}
const DEFAULT := &"tariel"

## Where the settings live between runs.
const SETTINGS := "user://settings.cfg"

## Emitted when the choice changes, so a menu can show it without polling.
signal character_changed(id: StringName)
signal graphics_changed(level: Graphics.Level)

var _chosen: StringName = DEFAULT
var _graphics: Graphics.Level = Graphics.Level.HIGH


func _ready() -> void:
	_load_settings()
	for word in OS.get_cmdline_user_args():
		var id := StringName(word.to_lower())
		if CHARACTERS.has(id):
			_chosen = id
			break
	Graphics.apply(get_tree(), _graphics)


## Who is being played, as an id.
func character() -> StringName:
	return _chosen


## And everything that is known about them. Never null: an id that has lost its
## resource falls back to the default rather than handing back nothing.
func profile() -> CharacterProfile:
	var found := load(CHARACTERS.get(_chosen, CHARACTERS[DEFAULT])) as CharacterProfile
	if found == null:
		push_error("Game: '%s' has no usable profile." % _chosen)
		found = load(CHARACTERS[DEFAULT]) as CharacterProfile
	return found


## Picks a character. Takes effect the next time a level is loaded, which is
## what a menu wants: choosing is not the same as spawning.
func choose(id: StringName) -> void:
	if not CHARACTERS.has(id) or id == _chosen:
		return
	_chosen = id
	character_changed.emit(id)


## Every character there is, in the order they should be offered.
func roster() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in CHARACTERS:
		ids.append(id)
	return ids


#region Settings
## Which graphics setting is in force.
func graphics() -> Graphics.Level:
	return _graphics


## Changes it, applies it to whatever is loaded, and remembers it. Applying and
## storing together, because a setting that takes effect but is forgotten by the
## next run is a setting the player has to find twice.
func set_graphics(level: Graphics.Level) -> void:
	_graphics = level
	Graphics.apply(get_tree(), _graphics)
	_save_settings()
	graphics_changed.emit(_graphics)


## Puts the current setting onto a level that has just loaded. The world does
## not know about any of this; whoever spawns into it asks for it.
func apply_graphics() -> void:
	Graphics.apply(get_tree(), _graphics)


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS) != OK:
		return
	var level := int(file.get_value("video", "graphics", Graphics.Level.HIGH))
	_graphics = Graphics.Level.LOW if level == Graphics.Level.LOW else Graphics.Level.HIGH


func _save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("video", "graphics", int(_graphics))
	file.save(SETTINGS)
#endregion
