extends Node
## Dev tool: plays the stop with the bots in the real game and saves screenshots along the way.
## usage: tools/run_shots.sh out_dir

var out := ""
var game: Main
var bot: Bot


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	game.manual = true
	add_child(game)
	await settle()
	bot = Bot.new(game.sim)
	var sim := game.sim
	await shot("1-start")
	bot.walk(sim.marta, sim.rocks[2].pos.x - 0.6)
	await shot("2-rock-picked")
	bot.press(sim.marta, "use_p")
	bot.run(40)
	await shot("3-rock-floats")
	bot.run(80)
	bot.drive()
	await shot("3b-refused", 20)
	for x in range(28, 42):
		bot.walk(sim.giulio, x - 0.5)
		sim.giulio.facing = 1
		bot.run(2)
		bot.press(sim.giulio, "use_p")
		if x == 34:
			await shot("4-building")
			sim.giulio.pad.alt = true
			bot.run(2)
			await shot("4b-aiming")
			sim.giulio.pad.clear()
	await shot("5-all-red")
	bot.drive()
	await shot("6-it-broke")
	bot.build_deck(30, 41)
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	await shot("7-first-rock")
	bot.walk(sim.marta, 36.0)
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(40)
	await shot("8-blue-ice")
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(90)
	await shot("9-all-green")
	bot.walk(sim.giulio, sim.house_x + 3.0)
	await shot("10-at-the-door")
	bot.press(sim.giulio, "interact_p")
	bot.run(200)
	await shot("11-crossing")
	var limit := 1800
	while not sim.done and limit > 0:
		sim.tick()
		limit -= 1
	await shot("12-done")
	get_tree().quit()


func settle() -> void:
	for i in 4:
		await get_tree().process_frame


func shot(name_: String, frames := Stage.FX_LIFE + 2) -> void:
	# The bots skip frames, so let anything still falling finish before the picture.
	for i in frames:
		game.stage.sync()
	game.refresh()
	await settle()
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name_])
	print("wrote ", name_)
