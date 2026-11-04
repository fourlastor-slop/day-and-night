extends Case
## Wheels: a group of his blocks with a wheel in it is a cart, and a yellow block in a cart is its
## engine, which drives it the way Marta faced when she painted it, until something stops it.


func run() -> void:
	a_yellow_block_drives_the_cart()
	it_drives_the_way_she_faced()
	it_stops_at_a_wall_and_settles()
	it_falls_into_a_pit()
	it_carries_a_rock()
	without_a_wheel_nothing_drives()
	the_wheel_tool_lays_wheels()


## Two wheels on the road and three planks on top of them, with the middle one to be the engine.
func cart(x: int) -> void:
	for dx in [0, 2]:
		sim.cells[9 * Sim.W + x + dx] = Sim.WHEEL
	for dx in 3:
		plank(x + dx, 8)


## Marta stands beside the cart, facing along it, and paints whatever part of it she picks yellow.
func engine(x: int, facing: int) -> void:
	sim.marta.pos = Vector2(x + 0.5 - facing * 2.6, Sim.ROAD)
	sim.marta.facing = facing
	sim.marta.colour = Sim.YELLOW
	bot.run(2)
	var c := sim.marta.pick_block
	check(absi(c.x - x) <= 1 and (c.y == 8 or c.y == 9), "she picks part of the cart")
	bot.press(sim.marta, "use_p")


func a_yellow_block_drives_the_cart() -> void:
	fresh(LiftCase.flat())
	cart(30)
	engine(31, 1)
	bot.run(60)
	check(sim.bodies.size() == 1 and sim.bodies[0].pos.x > 32.0, "painted yellow, the plank drives the cart")


func it_drives_the_way_she_faced() -> void:
	fresh(LiftCase.flat())
	cart(30)
	engine(31, -1)
	bot.run(60)
	check(sim.bodies.size() == 1 and sim.bodies[0].pos.x < 28.0, "facing the other way, it drives the other way")


func it_stops_at_a_wall_and_settles() -> void:
	fresh(LiftCase.flat())
	for y in range(6, Sim.ROAD):
		sim.cells[y * Sim.W + 40] = Sim.EARTH
	cart(30)
	engine(31, 1)
	bot.run(400)
	check(sim.bodies.is_empty(), "a wall stops the cart")
	check(sim.cell(39, 8) == Sim.BLOCK and sim.cell(39, 9) == Sim.WHEEL, "and it settles right against it")


func it_falls_into_a_pit() -> void:
	fresh(LiftCase.flat())
	for x in range(36, 40):
		for y in range(Sim.ROAD, 13):
			dig(x, y)
	for y in range(6, 13):
		sim.cells[y * Sim.W + 40] = Sim.EARTH
	cart(30)
	engine(31, 1)
	bot.run(400)
	check(sim.cell(39, 12) == Sim.WHEEL and sim.cell(39, 11) == Sim.BLOCK, "a cart driven off the edge falls into the pit")


func it_carries_a_rock() -> void:
	fresh(LiftCase.flat())
	cart(30)
	var rock := Sim.Rock.new(Vector2(30, 6))
	sim.rocks.append(rock)
	bot.run(30)
	# Painted directly, because with the rock in reach she'd pick the rock instead.
	sim.paint[8 * Sim.W + 32] = Sim.YELLOW
	sim.paint_dir[8 * Sim.W + 32] = 1
	sim._dirty = true
	bot.run(60)
	check(rock.pos.x > 32.0 and absf(rock.pos.y - 6.0) < 0.1, "a rock resting on the cart goes with it")


func without_a_wheel_nothing_drives() -> void:
	fresh(LiftCase.flat())
	for x in range(30, 33):
		plank(x, 9)
	engine_without_wheels()
	bot.run(60)
	check(sim.bodies.is_empty() and sim.cell(30, 9) == Sim.BLOCK, "a yellow block without a wheel goes nowhere")


func engine_without_wheels() -> void:
	sim.paint[9 * Sim.W + 31] = Sim.YELLOW
	sim.paint_dir[9 * Sim.W + 31] = 1
	sim._dirty = true


func the_wheel_tool_lays_wheels() -> void:
	fresh(LiftCase.flat())
	sim.tools = [Sim.HAMMER, Sim.PICK, Sim.WHEEL_TOOL]
	bot.hold(Sim.WHEEL_TOOL)
	bot.run(2)
	var c := sim.giulio.target
	bot.press(sim.giulio, "use_p")
	check(sim.cell(c.x, c.y) == Sim.WHEEL, "the wheel tool puts a wheel where a block would go")
