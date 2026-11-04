extends Case
## The Long Tunnel ends the Mines with everything they taught: lamp stones, rubble, a pool only stone
## spans, and sootlings in the dark beyond, where a cart with a yellow engine lights the way through.


func run() -> void:
	the_far_dark_is_the_sootlings()
	a_lamp_cart_takes_them_through()
	mash(Stops.TUNNEL, 4)


func caught() -> bool:
	for e in sim.events:
		if e.kind == "caught":
			return true
	return false


## Gets them across the pool with the first two stones lit and the first rubble dug.
func to_the_far_side() -> void:
	fresh(Stops.TUNNEL)
	check(bot.paint_rock(sim.rocks[0], Sim.YELLOW), "she lights the first stone")
	bot.tunnel(20, 21)
	for at: Vector2i in [Vector2i(20, 9), Vector2i(20, 8), Vector2i(21, 9), Vector2i(21, 8)]:
		check(bot.use_at(at), "he digs the first rubble out to the roof")
	check(bot.build_deck(24, 29, Sim.CHISEL), "and lays stone across the pool")
	check(bot.paint_rock(sim.rocks[1], Sim.YELLOW), "she crosses and lights the second stone")


func the_far_dark_is_the_sootlings() -> void:
	to_the_far_side()
	check(not caught(), "so far the sootlings haven't noticed him")
	bot.walk(sim.giulio, 44.5)
	bot.run(120)
	check(caught(), "but walking on into the dark, they catch him")


func a_lamp_cart_takes_them_through() -> void:
	to_the_far_side()
	var k := sim.giulio
	bot.hold(Sim.WHEEL_TOOL)
	bot.walk(k, 33.0)
	k.facing = 1
	for x in [34, 36]:
		bot.use_at(Vector2i(x, 11))
		check(sim.cell(x, 11) == Sim.WHEEL, "he puts two wheels on the road")
	bot.hold(Sim.HAMMER)
	for x in [34, 35, 36]:
		bot.use_at(Vector2i(x, 10))
		check(sim.cell(x, 10) == Sim.BLOCK, "and planks across them")
	var m := sim.marta
	bot.walk(m, 36.2)
	m.facing = 1
	bot.brush(Sim.YELLOW)
	bot.run(2)
	check(m.pick_block == Vector2i(36, 10), "on the cart's front she picks its last plank")
	bot.press(m, "use_p")
	for i in 240:
		var cart_x := sim.bodies[0].pos.x if not sim.bodies.is_empty() else 43.0
		k.pad.x = 1 if k.pos.x < cart_x - 0.6 else 0
		sim.tick()
	k.pad.clear()
	check(not caught(), "walking behind the lit cart, the sootlings keep away")
	check(sim.cell(43, 11) == Sim.WHEEL and sim.cell(45, 11) == Sim.WHEEL, "the cart waits against the far rubble")
	bot.walk(k, 44.5)
	bot.hold(Sim.PICK)
	for x in [46, 47]:
		for y in range(8, 12):
			check(bot.use_at(Vector2i(x, y)), "from on the cart he digs the far rubble")
	bot.run(600)
	check(not caught(), "still in the cart's light")
	check(sim.cell(57, 11) == Sim.WHEEL, "with the rubble gone, the cart rolls on to the far end")
	for r in sim.rocks:
		bot.paint_rock(r, Sim.WHITE)
	bot.run(300)
	bot.drive()
	check(sim.done, "with the stones floated up, the house drives out into the daylight")
