extends Node
## Dev tool: plays every stop with the bots in the real game and saves screenshots along the way.
## usage: tools/run_shots.sh out_dir

var out := ""
var game: Main
var bot: Bot


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	game.manual = true
	game.save_path = "user://shot_progress.cfg"
	add_child(game)
	await settle()
	await brook()
	await gully()
	await river()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	get_tree().quit()


func brook() -> void:
	var sim := begin(Stops.BROOK)
	await shot("brook-1-start")
	bot.drive()
	await shot("brook-2-refused", 20)
	bot.tunnel(18, 21)
	await shot("brook-3-tunnel")
	bot.walk(sim.marta, bot.road_rock().pos.x - 0.6)
	await shot("brook-4-rock-picked")
	bot.press(sim.marta, "use_p")
	bot.run(60)
	await shot("brook-5-rock-floats")
	for x in range(18, 22):
		bot.walk(sim.giulio, x + 0.5)
		bot.use_at(Vector2i(x, 7))
	bot.run(200)
	bot.build_deck(32, 35)
	await shot("brook-6-deck")
	bot.drive()
	await shot("brook-7-done")


func gully() -> void:
	var sim := begin(Stops.GULLY)
	await shot("gully-1-start")
	bot.build_deck(24, 30)
	await shot("gully-2-red")
	bot.drive()
	await shot("gully-3-broke")
	bot.build_deck(24, 30)
	bot.walk(sim.giulio, 27.5)
	bot.use_at(Vector2i(27, 12))
	bot.use_at(Vector2i(27, 11))
	await shot("gully-4-pillar")
	var boulder := sim.rocks[0]
	bot.walk(sim.marta, boulder.pos.x - 0.6)
	sim.marta.facing = 1
	paint(sim, Sim.WHITE)
	bot.run(240)
	bot.drive()
	await shot("gully-5-jammed", 20)
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(5)
	bot.walk(sim.marta, boulder.pos.x + 3.0)
	sim.marta.facing = -1
	paint(sim, Sim.BLUE)
	await shot("gully-6-blue")
	bot.walk(sim.marta, 43.0)
	bot.run(120)
	await shot("gully-7-slid-out")
	bot.walk(sim.marta, boulder.rect().end.x + 0.6)
	sim.marta.facing = -1
	paint(sim, Sim.WHITE)
	bot.run(400)
	bot.drive()
	await shot("gully-8-done")


func river() -> void:
	var sim := begin(Stops.RIVER)
	await shot("river-1-start")
	bot.walk(sim.marta, bot.road_rock().pos.x - 0.6)
	await shot("river-2-rock-picked")
	bot.press(sim.marta, "use_p")
	bot.run(40)
	await shot("river-3-rock-floats")
	bot.run(80)
	bot.drive()
	await shot("river-3b-refused", 20)
	for x in range(28, 42):
		bot.walk(sim.giulio, x - 0.5)
		sim.giulio.facing = 1
		bot.run(2)
		bot.press(sim.giulio, "use_p")
		if x == 34:
			await shot("river-4-building")
			sim.giulio.pad.alt = true
			bot.run(2)
			await shot("river-4b-aiming")
			sim.giulio.pad.clear()
	await shot("river-5-all-red")
	bot.drive()
	await shot("river-6-it-broke")
	bot.build_deck(30, 41)
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	await shot("river-7-first-rock")
	bot.walk(sim.marta, 36.0)
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(40)
	await shot("river-8-blue-ice")
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(90)
	await shot("river-9-all-green")
	bot.walk(sim.giulio, sim.house_x + 3.0)
	await shot("river-10-at-the-door")
	bot.press(sim.giulio, "interact_p")
	bot.run(200)
	await shot("river-11-crossing")
	var limit := 1800
	while not sim.done and limit > 0:
		sim.tick()
		limit -= 1
	await shot("river-12-done")


## Goes to a stop in the real game and gives the bots its sim.
func begin(stop: Dictionary) -> Sim:
	game.go_to(Stops.ROAD.find(stop))
	bot = Bot.new(game.sim)
	return game.sim


func paint(sim: Sim, colour: int) -> void:
	if sim.marta.colour != colour:
		bot.press(sim.marta, "next_p")
	bot.run(2)
	bot.press(sim.marta, "use_p")


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
