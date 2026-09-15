class_name CharacterPortrait
extends SubViewportContainer

## The character themselves, on their card in the select screen.
##
## Picking who to play out of two paragraphs of statistics is picking a
## spreadsheet row. What a player actually chooses between is a hooded archer and
## an armoured knight, and neither of those is a number — so the card shows the
## model, lit and turning, rather than describing it.
##
## It is the **same model the game spawns**, driven by the **same rig**, with
## `animate()` called once a frame at a standstill. Nothing is authored twice:
## a change to the archer's stance, his bow, or the way he carries it shows up
## here without anything in this file knowing about it. A rendered portrait would
## be a second thing to keep in step, and it would be out of date the first time
## the model changed.
##
## Each portrait owns its own 3D world, so two of them side by side do not light
## or see each other, and none of it touches the world the game runs in.

## How fast the model turns, in radians a second. Slow: it is there to be looked
## at, not to spin.
@export var turn_speed: float = 0.42
## Which way it is facing when the page opens, in radians — three-quarters on, so
## the silhouette reads and the weapon is not hidden behind the body.
@export var start_angle: float = -0.55
## Where the camera looks and how far back it stands, in metres. Framed from
## about the shins up rather than head to toe: the card is wider than it is tall,
## and a whole standing figure in it is a thumbnail with air either side.
@export var eye_height: float = 1.05
@export var eye_back: float = 2.95

var _stand: Node3D
var _rig: Node3D


## Builds one for `profile` at `size` pixels. Hands back an empty container if
## the profile has no model, rather than a broken one.
static func of(profile: CharacterProfile, size: Vector2) -> CharacterPortrait:
	var portrait := CharacterPortrait.new()
	portrait.custom_minimum_size = size
	portrait.stretch = true
	# The card underneath is the button: a portrait that eats the click is a
	# character that cannot be picked by clicking on their own face.
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if profile == null or profile.visuals == null:
		return portrait

	var view := SubViewport.new()
	view.size = Vector2i(size)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# No shadows to cast and nothing behind to receive them; this is a figure on
	# a plain ground, and the lighting is the two lamps below.
	view.positional_shadow_atlas_size = 0
	portrait.add_child(view)

	# Half a turn, plus whatever angle it is being shown at. The `Visuals` scene
	# carries the model's own half turn — it faces +Z and the body it hangs off
	# faces Godot's -Z — so left alone in front of a camera it presents its back.
	# Turning the stand rather than the model leaves what the game spawns exactly
	# as the game spawns it.
	portrait._stand = Node3D.new()
	portrait._stand.name = "Stand"
	portrait._stand.rotation.y = PI + portrait.start_angle
	view.add_child(portrait._stand)

	portrait._rig = profile.visuals.instantiate() as Node3D
	portrait._stand.add_child(portrait._rig)

	view.add_child(portrait._lights())
	view.add_child(portrait._eye())
	return portrait


func _process(delta: float) -> void:
	if _stand == null:
		return
	_stand.rotation.y = wrapf(_stand.rotation.y + turn_speed * delta, -PI, PI)
	# Standing still, on the ground, not jumping, not rolling, not blocking. The
	# rig fills in the breathing, the weight on the feet and where the weapons
	# hang, which is most of what makes a model look alive rather than posed.
	if _rig != null and _rig.has_method("animate"):
		_rig.call("animate", delta, 0.0, 0.0, false, false, 0.0, false)


## A key light from the front and above, a dim fill from behind to lift the
## silhouette off the card, and enough ambient that the shadowed side is not a
## black hole.
func _lights() -> Node3D:
	var rig := Node3D.new()
	rig.name = "Lights"

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(38.0), 0.0)
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.95, 0.86)
	key.shadow_enabled = false
	rig.add_child(key)

	# Cool and weak. A warm fill as strong as the key turns anything broad — a
	# cape, a shield — into a flat gold slab with no shape left in it.
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(-150.0), 0.0)
	rim.light_energy = 0.4
	rim.light_color = Color(0.72, 0.79, 1.0)
	rim.shadow_enabled = false
	rig.add_child(rim)
	return rig


func _eye() -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.position = Vector3(0.0, eye_height + 0.14, eye_back)
	camera.look_at_from_position(camera.position, Vector3(0.0, eye_height, 0.0),
			Vector3.UP)
	camera.current = true

	var air := Environment.new()
	# Cleared rather than painted: the card's own panel is what shows through,
	# so the figure sits on the card instead of in a window cut into it.
	air.background_mode = Environment.BG_CLEAR_COLOR
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = MenuStyle.SLATE.lightened(0.35)
	air.ambient_light_energy = 0.9
	camera.environment = air
	return camera
