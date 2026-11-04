extends Case
## The Cliff Lift ends the Meadow: he ties his platform to the old pulley's ropes so it holds the house,
## and she paints enough of it white to lift the house up the cliff.


func run() -> void:
	a_bare_platform_breaks_under_the_house()
	the_pulley_ropes_hold_it()
	seven_white_strain_but_eight_lift_the_house()
	white_too_early_floats_the_platform_off()
	mash(Stops.CLIFF, 4)


func a_bare_platform_breaks_under_the_house() -> void:
	fresh(Stops.CLIFF)
	bot.build_deck(35, 45)
	check(max_span() >= Sim.MAX_SPAN, "a platform across the shaft goes red")
	bot.drive()
	check(sim.house_x < 35.0 and not sim.done, "and breaks under the house")


func the_pulley_ropes_hold_it() -> void:
	platform()
	check(max_span() < Sim.MAX_SPAN, "tied to the pulley's ropes, the platform holds")
	bot.drive()
	check(sim.house_x + Sim.WHEELS[0] > 35.0 and sim.house_state == Sim.PARKED, "the house drives on and stops at the cliff")
	check(refused_at().x >= 46.0, "and the crossed wheel shows the cliff")


func seven_white_strain_but_eight_lift_the_house() -> void:
	platform()
	bot.drive()
	paint_platform(7)
	bot.run(10)
	check(sim.bodies.is_empty() and not sim.strain.is_empty(), "with the house on, seven white of eleven only strain")
	paint_platform(8)
	bot.run(10)
	check(sim.riding(), "the eighth lifts the platform and the house with it")
	bot.run(600)
	check(sim.done and sim.house_y <= Sim.LIFTED, "up the cliff and out of view")


func white_too_early_floats_the_platform_off() -> void:
	platform()
	paint_platform(6)
	bot.run(10)
	check(sim.bodies.size() == 1 and not sim.riding(), "without the house, six of eleven float the platform off")
	bot.run(600)
	check(sim.bodies.is_empty() and count_blocks() == 0, "and it's gone")
	var hanging := 0
	for r in sim.ropes:
		hanging += 1 if r.hook and not r.tied else 0
	check(hanging == 2, "leaving the pulley's ropes hanging for the next one")


## Lays the platform across the shaft and ties it to both of the pulley's ropes.
func platform() -> void:
	fresh(Stops.CLIFF)
	bot.build_deck(35, 45)
	var k := sim.giulio
	while k.tool != Sim.ROPE:
		bot.press(k, "next_p")
	for x in [38, 43]:
		bot.walk(k, x - 0.5)
		k.facing = 1
		check(bot.use_at(Vector2i(x, 9)), "he takes the end of a pulley rope")
		check(bot.use_at(Vector2i(x, 10)), "and ties it to the platform")


## Marta walks along the platform painting its blocks white until that many are.
func paint_platform(count: int) -> void:
	var m := sim.marta
	if m.colour != Sim.WHITE:
		bot.press(m, "next_p")
	for x in range(35, 46):
		if whites() >= count:
			return
		if sim.paint.get(Sim.ROAD * Sim.W + x, Sim.PLAIN) == Sim.WHITE:
			continue
		bot.walk(m, x + 0.5)
		bot.run(2)
		if m.pick_block == Vector2i(x, Sim.ROAD):
			bot.press(m, "use_p")


func whites() -> int:
	var n := 0
	for x in range(35, 46):
		n += 1 if sim.paint.get(Sim.ROAD * Sim.W + x, Sim.PLAIN) == Sim.WHITE else 0
	return n
