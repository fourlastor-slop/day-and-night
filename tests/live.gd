extends Node
## Runs the real main scene for a moment with real key events, to prove the input reaches the game.


func _ready() -> void:
	var game: Main = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait(5)
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
	var ok := marta.pos.x > marta_x + 1.0 and giulio.pos.x > giulio_x + 1.0 and marta.colour == Sim.BLUE
	print("live: ", "ok" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
