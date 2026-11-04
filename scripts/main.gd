class_name Main
extends Control
## The prototype: one Sim, drawn once and seen through two cameras, with Marta's day on top and
## Giulio's night below. Both play at once, on gamepads or on the two sides of the keyboard.

const SCREEN := Vector2(1920, 1080)
const HALF := Vector2i(1920, 540)
const ZOOM := 0.75
const PARALLAX := 0.5
const JOIN_Y := 530
const STRIP_AT := Vector2(14, 12)
const STRIP_KEY := Vector2(180, 18)
const AIM_AT := Vector2(252, 0)
const AIM_KEY := Vector2(84, 18)
const SWATCH_X: Array[float] = [16.0, 96.0]
const FAR := 62.0
const NEAR := 10.0

const KEYS_MARTA := {
	"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "jump": KEY_W,
	"use": KEY_E, "alt": KEY_R, "next": KEY_Q, "interact": KEY_F,
}
const KEYS_GIULIO := {
	"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "jump": KEY_UP,
	"use": KEY_K, "alt": KEY_L, "next": KEY_J, "interact": KEY_I,
}
const BUTTONS := {"use": "X", "alt": "B", "next": "LB", "interact": "Y"}

## Set by the tests, which drive the sim themselves.
var manual := false
## Where the road remembers which stop the kids are on. The tests point it somewhere else.
var save_path := "user://progress.cfg"
var stop := 0
var sim: Sim
var stage: Stage
var day_cam: Camera2D
var night_cam: Camera2D
var top_cam: Camera2D
var day_sky: TextureRect
var night_sky: TextureRect
var world_view: SubViewport
var colour_ring: TextureRect
var tool_ring: TextureRect
var colour_key: TextureRect
var tool_key: TextureRect
var aim_key: TextureRect
var sun: TextureRect
var moon: TextureRect
var banner: TextureRect


func _ready() -> void:
	size = SCREEN
	day_sky = _sky("res://assets/gfx/backdrop_day.png", 0)
	night_sky = _sky("res://assets/gfx/backdrop_night.png", HALF.y)
	world_view = _view(0, Stage.SHARED | Stage.DAY, null)
	day_cam = world_view.get_child(0)
	var night := _view(HALF.y, Stage.SHARED, load("res://shaders/night.gdshader"))
	night.world_2d = world_view.world_2d
	night_cam = night.get_child(0)
	var top := _view(HALF.y, Stage.NIGHT_TOP, null)
	top.world_2d = world_view.world_2d
	top_cam = top.get_child(0)
	_hud()
	stop = _saved()
	_start()


func _start() -> void:
	if stage != null:
		stage.queue_free()
	sim = Sim.new(Stops.ROAD[stop])
	stage = Stage.new(sim)
	world_view.add_child(stage)
	banner.visible = false
	refresh()


func _view(y: int, mask: int, shader: Shader) -> SubViewport:
	var box := SubViewportContainer.new()
	box.position = Vector2(0, y)
	box.size = HALF
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shader != null:
		box.material = ShaderMaterial.new()
		box.material.shader = shader
	var vp := SubViewport.new()
	vp.size = HALF
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_cull_mask = mask
	box.add_child(vp)
	add_child(box)
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	vp.add_child(cam)
	return vp


func _sky(path: String, y: int) -> TextureRect:
	var clip := Control.new()
	clip.position = Vector2(0, y)
	clip.size = HALF
	clip.clip_contents = true
	add_child(clip)
	var sky := _image(path, clip, Vector2.ZERO)
	return sky


func _image(path: String, parent: Control, at: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.position = at
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _key(at: Vector2) -> TextureRect:
	var r := _image("res://assets/gfx/keys.png", self, at)
	var key := AtlasTexture.new()
	key.atlas = r.texture
	r.texture = key
	return r


func _hud() -> void:
	var tools_at := STRIP_AT + Vector2(0, HALF.y + 18)
	_image("res://assets/gfx/strip_colours.png", self, STRIP_AT)
	colour_ring = _image("res://assets/gfx/selected.png", self, Vector2.ZERO)
	colour_key = _key(STRIP_AT + STRIP_KEY)
	_image("res://assets/gfx/strip_tools.png", self, tools_at)
	tool_ring = _image("res://assets/gfx/selected.png", self, Vector2.ZERO)
	tool_key = _key(tools_at + STRIP_KEY)
	_image("res://assets/gfx/strip_aim.png", self, tools_at + AIM_AT)
	aim_key = _key(tools_at + AIM_AT + AIM_KEY)
	_image("res://assets/gfx/join.png", self, Vector2(0, JOIN_Y))
	sun = _image("res://assets/gfx/sun.png", self, Vector2.ZERO)
	moon = _image("res://assets/gfx/moon.png", self, Vector2.ZERO)
	banner = _image("res://assets/gfx/banner.png", self, (SCREEN - Vector2(420, 280)) / 2)


func _physics_process(_delta: float) -> void:
	if manual:
		return
	sim.marta.pad.poll(KEYS_MARTA, _device(0))
	sim.giulio.pad.poll(KEYS_GIULIO, _device(1))
	sim.tick()
	refresh()


## Two pads: one each. One pad: Giulio's, and Marta takes the keyboard.
func _device(player: int) -> int:
	var pads := Input.get_connected_joypads()
	if pads.size() >= 2:
		return pads[player]
	return pads[0] if pads.size() == 1 and player == 1 else -1


## What the cues should show: this player's gamepad, or their side of the keyboard.
static func caps(keys: Dictionary, device: int) -> Dictionary:
	if device >= 0:
		return BUTTONS
	var names := {}
	for action: String in BUTTONS:
		names[action] = OS.get_keycode_string(keys[action])
	return names


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_F5:
			_start()
		KEY_F6:
			go_to(stop - 1)
		KEY_F7:
			go_to(stop + 1)
		KEY_ENTER:
			if sim.done:
				go_to(stop + 1)


## Moves to another stop on the road and remembers it. Past the last stop built, the road starts again.
func go_to(index: int) -> void:
	stop = posmod(index, Stops.ROAD.size())
	var save := ConfigFile.new()
	save.set_value("road", "stop", stop)
	save.save(save_path)
	_start()


func _saved() -> int:
	var save := ConfigFile.new()
	if save.load(save_path) != OK:
		return 0
	return clampi(save.get_value("road", "stop", 0), 0, Stops.ROAD.size() - 1)


func refresh() -> void:
	stage.marta_keys = caps(KEYS_MARTA, _device(0))
	stage.giulio_keys = caps(KEYS_GIULIO, _device(1))
	stage.sync()
	(colour_key.texture as AtlasTexture).region = Stage.cap_rect(stage.marta_keys.next)
	(tool_key.texture as AtlasTexture).region = Stage.cap_rect(stage.giulio_keys.next)
	(aim_key.texture as AtlasTexture).region = Stage.cap_rect(stage.giulio_keys.alt)
	var half := Vector2(HALF) / ZOOM / 2.0
	var lo := half.x
	var hi := Sim.W * Stage.B - half.x
	var y := Sim.H * Stage.B / 2.0
	day_cam.position = Vector2(clampf(sim.marta.pos.x * Stage.B, lo, hi), y)
	night_cam.position = Vector2(clampf(sim.giulio.pos.x * Stage.B, lo, hi), y)
	top_cam.position = night_cam.position
	day_sky.position.x = -(day_cam.position.x - lo) * ZOOM * PARALLAX
	night_sky.position.x = -(night_cam.position.x - lo) * ZOOM * PARALLAX
	colour_ring.position = STRIP_AT + Vector2(SWATCH_X[sim.marta.colour - Sim.WHITE], 8)
	tool_ring.position = STRIP_AT + Vector2(SWATCH_X[sim.giulio.tool], HALF.y + 18 + 8)
	# The sun and moon close in across the whole road, so each stop moves them a little.
	var start: float = Stops.ROAD[stop].house
	var here := clampf((sim.house_x - start) / (sim.goal - start), 0.0, 1.0)
	var gap := lerpf(FAR, NEAR, (stop + here) / Stops.ROAD_LENGTH)
	sun.position = Vector2(SCREEN.x / 2 - 60 - gap, HALF.y - 60)
	moon.position = Vector2(SCREEN.x / 2 - 60 + gap, HALF.y - 60)
	banner.visible = sim.done
