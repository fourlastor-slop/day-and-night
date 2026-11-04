extends Case
## Stone is his heavier block: a run of it reaches 5 squares from a support where wood reaches 3, it
## sinks to the bottom of water and stays there, and it weighs double when a group lifts.


func run() -> void:
	stone_crosses_where_wood_breaks()
	stone_sinks_to_the_bottom()
	a_stone_pillar_holds_a_plank_over_water()
	stone_weighs_double_in_a_lift()
	the_hammer_takes_stone_out()


func mines_tools() -> void:
	sim.tools = [Sim.HAMMER, Sim.CHISEL, Sim.PICK, Sim.ROPE]


func stone_crosses_where_wood_breaks() -> void:
	fresh(Stops.GULLY)
	mines_tools()
	check(bot.build_deck(24, 30, Sim.CHISEL), "he lays a line of stone across the gully")
	check(max_span() < Sim.STONE_SPAN, "and it holds where wood went red")
	bot.drive()
	check(sim.house_x > 24.0, "so the house crosses it")


func stone_sinks_to_the_bottom() -> void:
	fresh(Stops.RIVER)
	mines_tools()
	var k := sim.giulio
	bot.hold(Sim.CHISEL)
	bot.walk(k, 27.5)
	k.facing = 1
	check(bot.use_at(Vector2i(29, 11)), "he can aim a stone at the water")
	check(sim.cell(29, 14) == Sim.STONE and sim.cell(29, 11) == Sim.WATER, "and it sinks to the riverbed")
	bot.use_at(Vector2i(29, 11))
	check(sim.cell(29, 13) == Sim.STONE, "the next one lands on top of it")


func a_stone_pillar_holds_a_plank_over_water() -> void:
	fresh(Stops.RIVER)
	mines_tools()
	var k := sim.giulio
	bot.hold(Sim.CHISEL)
	bot.walk(k, 27.5)
	k.facing = 1
	for i in 4:
		bot.use_at(Vector2i(29, 11))
	check(sim.cell(29, 11) == Sim.STONE, "four stones fill the river up to its surface")
	bot.hold(Sim.HAMMER)
	bot.use_at(Vector2i(29, 10))
	bot.run(2)
	check(sim.span_at(29, 10) == 0, "and a plank on top of them is held up")


func stone_weighs_double_in_a_lift() -> void:
	fresh(LiftCase.flat())
	for x in [30, 31, 32]:
		plank(x, 7)
	sim.cells[7 * Sim.W + 33] = Sim.STONE
	for x in [30, 31]:
		sim.paint[7 * Sim.W + x] = Sim.WHITE
	sim._dirty = true
	bot.run(5)
	check(sim.bodies.is_empty(), "two white can't lift a plank and a stone")
	sim.paint[7 * Sim.W + 32] = Sim.WHITE
	sim._dirty = true
	bot.run(5)
	check(sim.bodies.size() == 1, "three can")


func the_hammer_takes_stone_out() -> void:
	fresh(LiftCase.flat())
	mines_tools()
	var k := sim.giulio
	bot.hold(Sim.CHISEL)
	bot.run(2)
	var c := k.target
	bot.press(k, "use_p")
	check(sim.cell(c.x, c.y) == Sim.STONE, "he lays a stone on the ground")
	bot.hold(Sim.HAMMER)
	bot.run(2)
	bot.press(k, "use_p")
	check(sim.cell(c.x, c.y) == Sim.AIR, "and the hammer takes it out again")
