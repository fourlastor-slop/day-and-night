class_name Main
extends Control
## The game: one Sim, drawn once and seen through two cameras, with Marta's day on top and Giulio's
## night below. Both play at once, on gamepads or on the two sides of the keyboard. The menus sit on
## top, and the road is saved as it goes, down to the stop in play.

const SCREEN := Vector2(1920, 1080)
const HALF := Vector2i(1920, 540)
const ZOOM := 0.75
const PARALLAX := 0.5
const JOIN_Y := 530
const STRIP_AT := Vector2(14, 12)
const STRIP_KEY := Vector2(180, 18)
const AIM_AT := Vector2(252, 0)
const AIM_KEY := Vector2(84, 18)
const SWATCH_X: Array[float] = [16.0, 96.0, 176.0, 256.0, 336.0]
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
## How often the stop in play is saved, in ticks: every five seconds.
const SAVE_EVERY := 300
## How long a stop's name shows as it starts, and how long a finished stop's banner waits before the
## key to go on works, so a kid still pressing buttons doesn't skip it.
const NAME_TICKS := 240
const BANNER_WAIT := 60
const INK := Color("3d332c")
const PAPER := Color("f3ecdd")

## Set by the tests, which drive the sim themselves and skip the title.
var manual := false
## Where the road is saved. The tests point it somewhere else.
var save_path := "user://progress.cfg"
var progress: Progress
var menu: Menu
var stop := 0
## Whether the kids have played since the game started, so quitting from the title saves nothing.
var played := false
var since_save := 0
var banner_t := 0
var name_t := 0
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
var tool_strip: TextureRect
var colour_strip: TextureRect
var aim_strip: TextureRect
var colour_key: TextureRect
var tool_key: TextureRect
var aim_key: TextureRect
var sun: TextureRect
var moon: TextureRect
var banner: TextureRect
var banner_name: Label
var banner_hint: Label
var stop_name: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "licenses":
		_write_licenses(args[1])
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().quit()
		return
	size = SCREEN
	bind_keys()
	progress = Progress.new(save_path)
	apply_settings()
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
	menu = Menu.new()
	menu.progress = progress
	menu.chose.connect(_on_menu)
	add_child(menu)
	stop = progress.stop
	_start(progress.snapshot(stop))
	if not manual:
		menu.open("title" if progress.started() else "first")
		refresh()


## Builds the stop the road is on, afresh or as it was saved.
func _start(state := {}) -> void:
	if stage != null:
		stage.queue_free()
	sim = Sim.new(Stops.ROAD[stop])
	if not state.is_empty():
		sim.restore(state)
	stage = Stage.new(sim)
	world_view.add_child(stage)
	_lay_out_tools()
	menu.stop = stop
	since_save = 0
	banner_t = 0
	name_t = 0 if manual else NAME_TICKS
	stop_name.text = "%s  ·  %s" % [tr("Stop %d") % (stop + 1), tr(Stops.ROAD[stop].name)]
	_settle_pads()
	refresh()


## Lets go of whatever keys are down, so a key that picked something in a menu doesn't also act in the
## game: a pad only sees a press once the key has been let go.
func _settle_pads() -> void:
	sim.marta.pad.poll(KEYS_MARTA, _device(0))
	sim.giulio.pad.poll(KEYS_GIULIO, _device(1))
	sim.marta.pad.clear()
	sim.giulio.pad.clear()


## The strips grow with the colours and tools a stop offers, and the keys beside them move along.
func _lay_out_tools() -> void:
	var colours := sim.colours.size()
	colour_strip.texture = load("res://assets/gfx/strip_colours%s.png" % ("" if colours == 2 else "_%d" % colours))
	colour_key.position = STRIP_AT + STRIP_KEY + Vector2(colour_strip.texture.get_width() - 196.0, 0)
	var count := sim.tools.size()
	tool_strip.texture = load("res://assets/gfx/strip_tools%s.png" % ("" if count == 2 else "_%d" % count))
	var tools_at := STRIP_AT + Vector2(0, HALF.y + 18)
	var end := tool_strip.texture.get_width() - 196.0
	tool_key.position = tools_at + STRIP_KEY + Vector2(end, 0)
	aim_strip.position = tools_at + AIM_AT + Vector2(end, 0)
	aim_key.position = aim_strip.position + AIM_KEY


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
	key.region = Stage.cap_rect("E")
	r.texture = key
	# Sized to one key, or it keeps the whole sheet's width and stretches the key across it.
	r.size = Vector2(Stage.CAP_CELL, Stage.CAP_CELL)
	return r


func _hud() -> void:
	var tools_at := STRIP_AT + Vector2(0, HALF.y + 18)
	colour_strip = _image("res://assets/gfx/strip_colours.png", self, STRIP_AT)
	colour_ring = _image("res://assets/gfx/selected.png", self, Vector2.ZERO)
	colour_key = _key(STRIP_AT + STRIP_KEY)
	tool_strip = _image("res://assets/gfx/strip_tools.png", self, tools_at)
	tool_ring = _image("res://assets/gfx/selected.png", self, Vector2.ZERO)
	tool_key = _key(tools_at + STRIP_KEY)
	aim_strip = _image("res://assets/gfx/strip_aim.png", self, tools_at + AIM_AT)
	aim_key = _key(tools_at + AIM_AT + AIM_KEY)
	_image("res://assets/gfx/join.png", self, Vector2(0, JOIN_Y))
	sun = _image("res://assets/gfx/sun.png", self, Vector2.ZERO)
	moon = _image("res://assets/gfx/moon.png", self, Vector2.ZERO)
	banner = _image("res://assets/gfx/banner.png", self, (SCREEN - Vector2(520, 440)) / 2)
	banner_name = _label(banner, 50, Vector2(30, 34), Vector2(460, 80))
	banner_hint = _label(banner, 32, Vector2(30, 346), Vector2(460, 60))
	stop_name = _label(self, 44, Vector2(0, 26), Vector2(SCREEN.x, 70))
	stop_name.label_settings.outline_size = 14
	stop_name.label_settings.outline_color = PAPER


## The strips and keys in the corners, which the boot splash leaves out.
func show_hud(on: bool) -> void:
	for part: CanvasItem in [colour_strip, colour_ring, colour_key, tool_strip, tool_ring, tool_key, aim_strip, aim_key]:
		part.visible = on


func _label(parent: Control, font_size: int, at: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.label_settings = LabelSettings.new()
	label.label_settings.font = Menu.BOLD if font_size > 40 else Menu.SEMI
	label.label_settings.font_size = font_size
	label.label_settings.font_color = INK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.position = at
	label.size = box
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _physics_process(_delta: float) -> void:
	if manual or menu.active():
		return
	sim.marta.pad.poll(KEYS_MARTA, _device(0))
	sim.giulio.pad.poll(KEYS_GIULIO, _device(1))
	sim.tick()
	name_t = maxi(name_t - 1, 0)
	since_save += 1
	if sim.done and banner_t == 0:
		_finished()
	elif since_save >= SAVE_EVERY:
		_keep()
	banner_t = banner_t + 1 if sim.done else 0
	refresh()


## The house is through: the next stop opens up on the stops page, and the banner says where they were.
func _finished() -> void:
	progress.reached = maxi(progress.reached, mini(stop + 1, Stops.ROAD.size() - 1))
	_keep()


## Saves the stop in play.
func _keep() -> void:
	since_save = 0
	if not manual:
		progress.stop = stop
		progress.keep(stop, sim)


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


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pressed := key != null and key.is_pressed() and not key.is_echo()
	if pressed and key.physical_keycode == KEY_F11:
		progress.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		progress.save()
		apply_settings()
		return
	if menu.active() or manual:
		return
	if event.is_action_pressed("pause"):
		pause()
	elif sim.done and banner_t > BANNER_WAIT and event.is_action_pressed("ui_accept"):
		go_to(stop + 1)
	elif pressed:
		match key.physical_keycode:
			KEY_F5:
				progress.forget()
				_start()
			KEY_F6:
				go_to(stop - 1)
			KEY_F7:
				go_to(stop + 1)


func pause() -> void:
	_keep()
	menu.open("pause")
	refresh()


## Back to the game from a menu, with the stop's name up for a moment.
func play() -> void:
	menu.open("")
	played = true
	name_t = NAME_TICKS
	_settle_pads()
	_keep()
	refresh()


func _on_menu(what: String, value: int) -> void:
	match what:
		"play":
			play()
		"restart_road":
			progress.restart()
			stop = 0
			_start()
			play()
		"stop":
			# Picking the stop in play carries on with it: starting it again is the pause menu's job.
			if value != stop:
				go_to(value)
			play()
		"restart_stop":
			progress.forget()
			_start()
			play()
		"language":
			progress.language = "en" if TranslationServer.get_locale().begins_with("it") else "it"
			progress.save()
			apply_settings()
		"fullscreen":
			progress.fullscreen = not progress.fullscreen
			progress.save()
			apply_settings()
		"quit":
			if played:
				_keep()
			get_tree().quit()


## Closing the window saves the stop in play, like pausing does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and played and sim != null:
		_keep()


## Moves to another stop on the road and remembers it. Past the last stop built, the road starts again.
func go_to(index: int) -> void:
	stop = posmod(index, Stops.ROAD.size())
	progress.stop = stop
	progress.forget()
	progress.save()
	_start()


## The language the kids picked, or the computer's, and the window as they left it.
func apply_settings() -> void:
	var language := progress.language
	TranslationServer.set_locale(language if language != "" else OS.get_locale_language())
	if is_inside_tree():
		get_window().title = tr("Day & Night")
	if sim != null:
		stop_name.text = "%s  ·  %s" % [tr("Stop %d") % (stop + 1), tr(Stops.ROAD[stop].name)]
	if menu != null:
		menu.queue_redraw()
	if manual or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if progress.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Either kid can work the menus: the arrows or WASD to choose, Enter, Space, E or K to pick, Esc to
## go back, or any gamepad's stick, A and B. Esc or a gamepad's Start pauses the game.
static func bind_keys() -> void:
	var keys := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}
	for action: String in keys:
		_bind(action, _key_event(keys[action]))
	_bind("ui_accept", _key_event(KEY_E))
	_bind("ui_accept", _key_event(KEY_K))
	_bind("ui_accept", _button_event(JOY_BUTTON_A))
	_bind("ui_cancel", _button_event(JOY_BUTTON_B))
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	_bind("pause", _key_event(KEY_ESCAPE))
	_bind("pause", _button_event(JOY_BUTTON_START))


static func _bind(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e


## tools/export.sh runs the game with `-- licenses <path>` so the engine's notices ship beside it.
func _write_licenses(path: String) -> void:
	var out := "Day & Night is built with the Godot Engine.\n\n" + Engine.get_license_text() + "\n"
	for part: Dictionary in Engine.get_copyright_info():
		out += "\n%s\n" % part.name
		for p: Dictionary in part.parts:
			out += "  Files: %s\n" % ", ".join(p.files)
			out += "  Copyright: %s\n" % "; ".join(p.copyright)
			out += "  License: %s\n" % p.license
	var texts := Engine.get_license_info()
	for part: String in texts:
		out += "\n--- %s ---\n\n%s\n" % [part, texts[part]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)


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
	colour_ring.position = STRIP_AT + Vector2(SWATCH_X[sim.colours.find(sim.marta.colour)], 8)
	tool_ring.position = STRIP_AT + Vector2(SWATCH_X[sim.tools.find(sim.giulio.tool)], HALF.y + 18 + 8)
	# The sun and moon close in across the whole road, so each stop moves them a little.
	var start: float = Stops.ROAD[stop].house
	var here := clampf((sim.house_x - start) / (sim.goal - start), 0.0, 1.0)
	var gap := lerpf(FAR, NEAR, (stop + here) / Stops.ROAD_LENGTH)
	sun.position = Vector2(SCREEN.x / 2 - 60 - gap, HALF.y - 60)
	moon.position = Vector2(SCREEN.x / 2 - 60 + gap, HALF.y - 60)
	banner.visible = sim.done
	if sim.done:
		_fit(banner_name, tr(Stops.ROAD[stop].name), 50)
		var pads := not Input.get_connected_joypads().is_empty()
		_fit(banner_hint, tr("Press A or Enter to go on") if pads else tr("Press Enter to go on"), 32)
		banner_hint.modulate.a = 1.0 if banner_t > BANNER_WAIT or manual else 0.0
	stop_name.visible = name_t > 0 and not menu.active()
	stop_name.modulate.a = clampf(name_t / 60.0, 0.0, 1.0)


## Shows a line in a label, shrinking its font from the largest size until it fits on one line.
static func _fit(label: Label, text: String, largest: int) -> void:
	if label.text == text and label.label_settings.font_size <= largest:
		return
	label.text = text
	var font := label.label_settings.font
	var font_size := largest
	while font_size > 20 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 2
	label.label_settings.font_size = font_size
