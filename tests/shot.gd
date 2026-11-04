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
	await cliff()
	await mouth()
	await rails()
	await hall()
	await tunnel()
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


func cliff() -> void:
	var sim := begin(Stops.CLIFF)
	await shot("cliff-1-start")
	bot.build_deck(35, 45)
	await shot("cliff-2-red")
	var k := sim.giulio
	while k.tool != Sim.ROPE:
		bot.press(k, "next_p")
	bot.walk(k, 37.5)
	k.facing = 1
	bot.use_at(Vector2i(38, 9))
	await shot("cliff-3-rope-in-hand")
	bot.use_at(Vector2i(38, 10))
	bot.walk(k, 42.5)
	k.facing = 1
	bot.use_at(Vector2i(43, 9))
	bot.use_at(Vector2i(43, 10))
	await shot("cliff-4-tied")
	bot.drive()
	await shot("cliff-5-on-the-platform", 20)
	whiten(sim, 7)
	await shot("cliff-6-straining", 7)
	whiten(sim, 8)
	bot.run(90)
	await shot("cliff-7-lifting", 2)
	bot.run(400)
	await shot("cliff-8-done")


func mouth() -> void:
	var sim := begin(Stops.MOUTH)
	await shot("mouth-1-start")
	bot.paint_rock(sim.rocks[0], Sim.YELLOW)
	await shot("mouth-2-lit")
	bot.tunnel(29, 30)
	for at: Vector2i in [Vector2i(29, 9), Vector2i(29, 8), Vector2i(30, 9), Vector2i(30, 8)]:
		bot.use_at(at)
	bot.paint_rock(sim.rocks[1], Sim.YELLOW)
	bot.build_deck(38, 43, Sim.CHISEL)
	await shot("mouth-3-stone-over-the-pool")
	for r in sim.rocks:
		bot.paint_rock(r, Sim.WHITE)
	bot.run(240)
	await shot("mouth-4-stones-floated")
	bot.drive()
	await shot("mouth-5-done")


func rails() -> void:
	var sim := begin(Stops.RAILS)
	await shot("rails-1-start")
	var boulder := sim.rocks[0]
	bot.paint_rock(boulder, Sim.WHITE)
	bot.run(300)
	bot.drive()
	await shot("rails-2-jammed", 20)
	var k := sim.giulio
	bot.hold(Sim.WHEEL_TOOL)
	for x in [19, 23]:
		bot.walk(k, x - 1.5)
		bot.use_at(Vector2i(x, 11))
	bot.hold(Sim.HAMMER)
	bot.walk(k, 18.5)
	for x in [19, 20, 21]:
		bot.use_at(Vector2i(x, 10))
	bot.walk(k, 24.5)
	for x in [23, 22]:
		bot.use_at(Vector2i(x, 10))
	bot.walk(k, 12.0)
	await shot("rails-3-cart-under-it")
	var m := sim.marta
	bot.walk(m, 23.2)
	m.facing = -1
	m.pad.jump_p = true
	m.pad.jump = true
	sim.tick()
	m.pad.jump_p = false
	for i in 40:
		if m.pick_rock == boulder:
			m.pad.alt_p = true
			sim.tick()
			m.pad.alt_p = false
			break
		sim.tick()
	m.pad.clear()
	bot.run(120)
	m.facing = 1
	bot.brush(Sim.YELLOW)
	bot.run(2)
	bot.press(m, "use_p")
	bot.run(240)
	await shot("rails-4-carting", 2)
	bot.run(600)
	bot.drive()
	await shot("rails-5-done")


func hall() -> void:
	var sim := begin(Stops.HALL)
	await shot("hall-1-start")
	var k := sim.giulio
	var m := sim.marta
	bot.hold(Sim.CHISEL)
	bot.brush(Sim.YELLOW)
	for x in range(24, 36):
		bot.walk(k, x - 0.5)
		k.facing = 1
		bot.run(2)
		bot.press(k, "use_p")
		if x == 29:
			bot.use_at(Vector2i(29, 13))
			bot.use_at(Vector2i(29, 13))
		if x % 2 == 0:
			bot.walk(m, x + 0.5)
			bot.run(2)
			bot.press(m, "use_p")
		if x == 30:
			await shot("hall-2-yellow-blocks", 2)
	await shot("hall-3-bridged")
	bot.walk(k, 14.0)
	bot.walk(m, 14.0)
	bot.drive()
	await shot("hall-4-done")


func tunnel() -> void:
	var sim := begin(Stops.TUNNEL)
	await shot("tunnel-1-start")
	bot.paint_rock(sim.rocks[0], Sim.YELLOW)
	bot.tunnel(20, 21)
	for at: Vector2i in [Vector2i(20, 9), Vector2i(20, 8), Vector2i(21, 9), Vector2i(21, 8)]:
		bot.use_at(at)
	bot.build_deck(24, 29, Sim.CHISEL)
	bot.paint_rock(sim.rocks[1], Sim.YELLOW)
	await shot("tunnel-2-across-the-pool")
	var k := sim.giulio
	bot.hold(Sim.WHEEL_TOOL)
	bot.walk(k, 33.0)
	k.facing = 1
	for x in [34, 36]:
		bot.use_at(Vector2i(x, 11))
	bot.hold(Sim.HAMMER)
	for x in [34, 35, 36]:
		bot.use_at(Vector2i(x, 10))
	var m := sim.marta
	bot.walk(m, 36.2)
	m.facing = 1
	bot.brush(Sim.YELLOW)
	bot.run(2)
	bot.press(m, "use_p")
	for i in 120:
		var cart_x := sim.bodies[0].pos.x if not sim.bodies.is_empty() else 43.0
		k.pad.x = 1 if k.pos.x < cart_x - 0.6 else 0
		sim.tick()
	await shot("tunnel-3-lamp-cart", 2)
	for i in 120:
		var cart_x := sim.bodies[0].pos.x if not sim.bodies.is_empty() else 43.0
		k.pad.x = 1 if k.pos.x < cart_x - 0.6 else 0
		sim.tick()
	k.pad.clear()
	bot.walk(k, 44.5)
	bot.hold(Sim.PICK)
	for x in [46, 47]:
		for y in range(8, 12):
			bot.use_at(Vector2i(x, y))
	bot.run(600)
	for r in sim.rocks:
		bot.paint_rock(r, Sim.WHITE)
	bot.run(300)
	bot.drive()
	await shot("tunnel-4-done")


## Marta walks along the platform painting its blocks white until that many are.
func whiten(sim: Sim, count: int) -> void:
	var m := sim.marta
	if m.colour != Sim.WHITE:
		bot.press(m, "next_p")
	for x in range(35, 46):
		var n := 0
		for i in range(35, 46):
			n += 1 if sim.paint.get(Sim.ROAD * Sim.W + i, Sim.PLAIN) == Sim.WHITE else 0
		if n >= count:
			return
		if sim.paint.get(Sim.ROAD * Sim.W + x, Sim.PLAIN) == Sim.WHITE:
			continue
		bot.walk(m, x + 0.5)
		bot.run(2)
		if m.pick_block == Vector2i(x, Sim.ROAD):
			bot.press(m, "use_p")


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
