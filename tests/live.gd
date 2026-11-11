extends Node
## Runs the real main scene for a moment with real key events, to prove the input reaches the game and
## its menus, the road goes from stop to stop, the cues show the right keys, and a stop left halfway
## carries on exactly where it was.

const SAVE := "user://test_progress.cfg"

var failed := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game: Main = load("res://scenes/main.tscn").instantiate()
	game.save_path = SAVE
	add_child(game)
	TranslationServer.set_locale("en")
	await wait(5)
	check(game.menu.page == "first" and game.menu.items[0] == "Play", "a new game opens on the title, offering to play")
	check(game.sim.name == Stops.ROAD[0].name, "a new road starts at the first stop")
	var t := game.sim.t
	await wait(10)
	check(game.sim.t == t, "the road waits behind the title")
	await tap(KEY_ENTER)
	check(not game.menu.active() and game.sim.t > t, "Enter on Play starts it")
	game.sim.done = true
	await tap(KEY_ENTER)
	check(game.stop == 0, "a finished stop's banner waits a moment before Enter works")
	await wait(Main.BANNER_WAIT)
	check(game.banner.visible and game.banner_name.text == "The Brook", "the banner names the stop")
	await tap(KEY_ENTER)
	check(game.stop == 1 and game.sim.name == Stops.ROAD[1].name, "Enter goes on to the next stop")
	check(saved() == 1, "and the road remembers it")
	check(saved("reached") == 1, "and that it got there")
	await tap(KEY_F7)
	check(game.stop == 2, "F7 skips ahead")
	await tap(KEY_F6)
	check(game.stop == 1, "and F6 goes back")
	game.go_to(Stops.ROAD.size())
	check(game.stop == 0, "past the last stop the road starts again")
	game.go_to(Stops.ROAD.find(Stops.RIVER))
	await wait(3)
	var marta := game.sim.marta
	var giulio := game.sim.giulio
	var marta_x := marta.pos.x
	var giulio_x := giulio.pos.x
	key(KEY_D, true)
	key(KEY_RIGHT, true)
	await wait(30)
	key(KEY_D, false)
	key(KEY_RIGHT, false)
	key(KEY_Q, true)
	await wait(3)
	key(KEY_Q, false)
	check(marta.pos.x > marta_x + 1.0 and giulio.pos.x > giulio_x + 1.0, "the keys move both kids")
	check(marta.colour == Sim.BLUE, "Q changes her colour")
	var stage := game.stage
	check(stage.target.visible, "his target shows")
	giulio.pos = Vector2(20.5, Sim.ROAD)
	await wait(3)
	# A gamepad plugged in takes over Giulio's cues, so the keys expected are the ones each kid really has.
	var his: Dictionary = Main.caps(Main.KEYS_GIULIO, game._device(1))
	var hers: Dictionary = Main.caps(Main.KEYS_MARTA, game._device(0))
	check(shows(stage.giulio_cues.use, his.use), "his use key shows beside his target")
	var hidden := 0
	marta.pos.x = 14.0
	key(KEY_LEFT, true)
	for i in 30:
		await wait(1)
		hidden += 0 if stage.giulio_cues.use.visible else 1
	key(KEY_LEFT, false)
	check(hidden == 0, "his use key doesn't flicker while he walks (hidden for %d of 30 ticks)" % hidden)
	giulio.pos = Vector2(game.sim.house_x + Sim.WHEELS[0], Sim.ROAD)
	giulio.tool = Sim.PICK
	await wait(3)
	check(not stage.target.visible and not stage.giulio_cues.use.visible, "nothing lights up under a wheel")
	var cues := stage.marta_cues
	var rock := game.sim.rocks[2]
	marta.pos = Vector2(rock.pos.x - 0.6, Sim.ROAD)
	marta.facing = 1
	await wait(3)
	check(shows(cues.use, hers.use) and not cues.alt.visible, "her use key shows beside a plain rock")
	rock.colour = marta.colour
	await wait(3)
	check(shows(cues.alt, hers.alt) and not cues.use.visible, "her wash key shows beside a rock already that colour")
	marta.pos = Vector2(game.sim.house_x + 3.0, Sim.ROAD)
	await wait(3)
	check(cues.drive.visible and shows(cues.interact, hers.interact), "her drive key shows beside the drive bubble")
	key(KEY_F, true)
	await wait(2)
	key(KEY_F, false)
	await wait(240)
	check(game.sim.house_state == Sim.PARKED and game.sim.house_x > 10.0, "the rock stops the house")
	check(stage.stop.visible and stage.stop.position == rock.rect().get_center() * Stage.B, "the crossed wheel lands on it")
	var first := game.sim
	await tap(KEY_F5)
	check(game.sim != first and game.sim.name == first.name, "F5 starts the same stop again")
	await pausing(game)
	await options(game)
	await stops(game)
	# Something to remember: she's moved and painted a rock.
	game.sim.rocks[0].colour = Sim.BLUE
	await wait(20)
	await tap(KEY_ESCAPE)
	var left := var_to_str(game.sim.to_save())
	var at := game.stop
	game.queue_free()
	await wait(2)
	var again: Main = load("res://scenes/main.tscn").instantiate()
	again.save_path = SAVE
	add_child(again)
	await wait(5)
	check(again.menu.page == "title" and again.menu.items[0] == "Continue", "the next game's title offers to carry on")
	check(again.stop == at and var_to_str(again.sim.to_save()) == left, "with the stop exactly as it was left")
	await new_journey(again)
	again.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("live: ", "ok" if failed == 0 else "FAILED")
	get_tree().quit(0 if failed == 0 else 1)


## Esc pauses and saves, the road waits, and Esc again goes back to it.
func pausing(game: Main) -> void:
	await tap(KEY_ESCAPE)
	check(game.menu.page == "pause", "Esc pauses")
	var t := game.sim.t
	await wait(10)
	check(game.sim.t == t, "and the road waits")
	check(saved_at() == t, "pausing saves the stop in play")
	await tap(KEY_ESCAPE)
	await wait(3)
	check(not game.menu.active() and game.sim.t > t, "Esc goes back to it")


## Options from the pause menu: the language flips, everything shown flips with it, and the choice is saved.
func options(game: Main) -> void:
	await tap(KEY_ESCAPE)
	for i in game.menu.items.find("Options"):
		await tap(KEY_S)
	await tap(KEY_E)
	check(game.menu.page == "options", "S and E reach the options")
	await tap(KEY_ENTER)
	check(TranslationServer.get_locale() == "it", "Enter on the language switches it to Italian")
	check(game.stop_name.text.begins_with("Tappa"), "and the game's own words follow")
	check(saved("language", "settings") == "it", "and the choice is saved")
	await tap(KEY_RIGHT)
	check(TranslationServer.get_locale() == "en", "Right switches it back")
	await tap(KEY_ESCAPE)
	check(game.menu.page == "pause", "Esc goes back to the pause menu")
	await tap(KEY_ESCAPE)
	check(not game.menu.active(), "and again to the game")


## The stops page offers what's been reached, and picking one goes there.
func stops(game: Main) -> void:
	await tap(KEY_ESCAPE)
	for i in game.menu.items.find("Stops"):
		await tap(KEY_DOWN)
	await tap(KEY_K)
	check(game.menu.page == "stops" and game.menu.sel == game.stop, "the stops page opens on the stop in play")
	await tap(KEY_DOWN)
	check(game.menu.items[game.menu.sel] == "Back", "stops not reached yet can't be picked")
	await tap(KEY_UP)
	await tap(KEY_UP)
	await tap(KEY_ENTER)
	check(not game.menu.active() and game.stop == 1, "picking a stop goes there")


## A new journey asks first, and No keeps the road.
func new_journey(game: Main) -> void:
	var at := game.menu.items.find("New journey")
	for i in at:
		await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check(game.menu.page == "confirm" and game.menu.items[game.menu.sel] == "No", "a new journey asks first, on No")
	await tap(KEY_ENTER)
	check(game.menu.page == "title" and saved() == game.stop, "No keeps the road")
	for i in at:
		await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check(not game.menu.active() and game.stop == 0 and saved() == 0 and saved("reached") == 0, "Yes starts the road again")
	check(game.menu.progress.started(), "and it's under way")


func saved(key := "stop", section := "road") -> Variant:
	var save := ConfigFile.new()
	save.load(SAVE)
	return save.get_value(section, key, -1)


## The tick the saved stop in play was at.
func saved_at() -> int:
	var save := ConfigFile.new()
	save.load(SAVE)
	return save.get_value("snapshot", "state", {}).get("t", -1)


func shows(cue: Sprite2D, cap: String) -> bool:
	return cue.visible and cue.region_rect == Stage.cap_rect(cap)


func tap(code: Key) -> void:
	key(code, true)
	await wait(2)
	key(code, false)
	await wait(1)


func wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("  FAIL: ", what)
