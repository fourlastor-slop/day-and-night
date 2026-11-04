extends Node
## Runs the real main scene for a moment with real key events, to prove the input reaches the game,
## the road goes from stop to stop, and the cues show the right keys.

const SAVE := "user://test_progress.cfg"

var failed := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game: Main = load("res://scenes/main.tscn").instantiate()
	game.save_path = SAVE
	add_child(game)
	await wait(5)
	check(game.sim.name == Stops.ROAD[0].name, "a new road starts at the first stop")
	game.sim.done = true
	await tap(KEY_ENTER)
	check(game.stop == 1 and game.sim.name == Stops.ROAD[1].name, "Enter goes on to the next stop")
	check(saved() == 1, "and the road remembers it")
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
	check(shows(stage.giulio_cues.use, "K"), "K shows beside his target")
	var hidden := 0
	marta.pos.x = 14.0
	key(KEY_LEFT, true)
	for i in 30:
		await wait(1)
		hidden += 0 if stage.giulio_cues.use.visible else 1
	key(KEY_LEFT, false)
	check(hidden == 0, "K doesn't flicker while he walks (hidden for %d of 30 ticks)" % hidden)
	giulio.pos = Vector2(game.sim.house_x + Sim.WHEELS[0], Sim.ROAD)
	giulio.tool = Sim.PICK
	await wait(3)
	check(not stage.target.visible and not stage.giulio_cues.use.visible, "nothing lights up under a wheel")
	var cues := stage.marta_cues
	var rock := game.sim.rocks[2]
	marta.pos = Vector2(rock.pos.x - 0.6, Sim.ROAD)
	marta.facing = 1
	await wait(3)
	check(shows(cues.use, "E") and not cues.alt.visible, "E shows beside a plain rock")
	rock.colour = marta.colour
	await wait(3)
	check(shows(cues.alt, "R") and not cues.use.visible, "R shows beside a rock already that colour")
	marta.pos = Vector2(game.sim.house_x + 3.0, Sim.ROAD)
	await wait(3)
	check(cues.drive.visible and shows(cues.interact, "F"), "F shows beside the drive bubble")
	key(KEY_F, true)
	await wait(2)
	key(KEY_F, false)
	await wait(240)
	check(game.sim.house_state == Sim.PARKED and game.sim.house_x > 10.0, "the rock stops the house")
	check(stage.stop.visible and stage.stop.position == rock.rect().get_center() * Stage.B, "the crossed wheel lands on it")
	var first := game.sim
	await tap(KEY_F5)
	check(game.sim != first and game.sim.name == first.name, "F5 starts the same stop again")
	var again: Main = load("res://scenes/main.tscn").instantiate()
	again.save_path = SAVE
	again.manual = true
	add_child(again)
	await wait(2)
	check(again.stop == game.stop, "a new game carries on from the saved stop")
	again.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("live: ", "ok" if failed == 0 else "FAILED")
	get_tree().quit(0 if failed == 0 else 1)


func saved() -> int:
	var save := ConfigFile.new()
	save.load(SAVE)
	return save.get_value("road", "stop", -1)


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
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("  FAIL: ", what)
