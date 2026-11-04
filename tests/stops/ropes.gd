extends Case
## Rope: a block tied to something solid above it is held up, a group tied to the ground beside or
## below it can't lift, and groups tied to each other lift as one.


func run() -> void:
	the_rope_tool_hangs_a_deck()
	a_rope_to_the_ground_holds_a_group_down()
	tied_groups_lift_as_one()
	untying_lets_go()


## The gully's deck goes red in the middle, until he ties it to a lump of earth above it.
func the_rope_tool_hangs_a_deck() -> void:
	fresh(Stops.GULLY)
	sim.tools.append(Sim.ROPE)
	bot.build_deck(24, 30)
	sim.cells[6 * Sim.W + 27] = Sim.EARTH
	sim._dirty = true
	check(max_span() >= Sim.MAX_SPAN, "a bare deck over the gully is red")
	var k := sim.giulio
	bot.walk(k, 27.5)
	while k.tool != Sim.ROPE:
		bot.press(k, "next_p")
	check(bot.use_at(Vector2i(27, 6)), "he can aim the rope at the earth above")
	check(k.rope != null, "and picks up one end there")
	check(bot.use_at(Vector2i(27, 10)), "then aims at the plank under him")
	check(k.rope == null and sim.ropes.size() == 1, "and ties the other end to it")
	bot.run(2)
	check(sim.span_at(27, 10) == 0 and max_span() < Sim.MAX_SPAN, "hanging from the rope, the deck holds")


func a_rope_to_the_ground_holds_a_group_down() -> void:
	fresh(LiftCase.flat())
	for x in range(30, 34):
		plank(x, 7)
	check(sim.tie(Vector2i(30, 7), Vector2i(29, 10)), "a block can be tied to the ground beside it")
	for x in [30, 31]:
		sim.paint[7 * Sim.W + x] = Sim.WHITE
	sim._dirty = true
	bot.run(5)
	check(sim.bodies.is_empty(), "tied to the ground, a white group can't lift")


func tied_groups_lift_as_one() -> void:
	fresh(LiftCase.flat())
	for x in [20, 21, 24, 25]:
		plank(x, 7)
	check(sim.tie(Vector2i(21, 7), Vector2i(24, 7)), "two groups can be tied together")
	for x in [20, 21]:
		sim.paint[7 * Sim.W + x] = Sim.WHITE
	sim._dirty = true
	bot.run(5)
	check(sim.bodies.size() == 1 and sim.bodies[0].cells.size() == 4, "and lift as one")
	bot.run(30)
	check(sim.ropes[0].b.y < 7.0, "taking the rope up with them")


func untying_lets_go() -> void:
	fresh(LiftCase.flat())
	for x in range(30, 34):
		plank(x, 7)
	sim.tie(Vector2i(30, 7), Vector2i(29, 10))
	for x in [30, 31]:
		sim.paint[7 * Sim.W + x] = Sim.WHITE
	sim._dirty = true
	bot.run(5)
	sim.untie(sim.ropes[0])
	bot.run(5)
	check(sim.ropes.is_empty() and sim.bodies.size() == 1, "untied, the group lifts")
