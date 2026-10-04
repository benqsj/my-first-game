class_name Controls
extends RefCounted

## The keys that depend on the machine, set when the game starts.
##
## * **The evade** is on the thumb: **Command** on a Mac, **Control**
##   everywhere else. Walking, which Control used to do off a Mac, goes to
##   Alt there; on a Mac it stays on Control.
## * **The sprint** is on **Shift** (held; it costs stamina). With nothing
##   held he jogs.
## * **The skills** are on **1, 2, 3, 4** (`skill_1`..`skill_4`), the four
##   squares at the bottom of the screen.
##
## Only keyboard keys are touched; the gamepad's buttons stay as the project
## has them.

const SKILL_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]


static func is_mac() -> bool:
	return OS.get_name() == "macOS"


## The key the evade is on here.
static func dodge_key() -> Key:
	return KEY_META if is_mac() else KEY_CTRL


static func walk_key() -> Key:
	return KEY_CTRL if is_mac() else KEY_ALT


static func sprint_key() -> Key:
	return KEY_SHIFT


## Puts the machine's keys in the input map. Safe to call more than once.
static func apply() -> void:
	_keys(&"dash", [dodge_key()])
	_keys(&"walk", [walk_key()])
	_keys(&"sprint", [sprint_key()])
	for i in SKILL_KEYS.size():
		var action := StringName("skill_%d" % (i + 1))
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_keys(action, [SKILL_KEYS[i]])


## Replaces the keyboard keys on `action`, leaving anything else on it.
static func _keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for key: Key in keys:
		var press := InputEventKey.new()
		press.physical_keycode = key
		InputMap.action_add_event(action, press)


## What to call the evade's key on screen.
static func dodge_name() -> String:
	return "Command" if is_mac() else "Ctrl"
