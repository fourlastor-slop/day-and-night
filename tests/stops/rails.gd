extends Case
## The Old Rails use wheels: the boulder is too heavy to shove, white only jams it against the roof, so
## he builds a cart under it, she drops it on and drives it off with a yellow block at the cart's front.


func run() -> void:
	white_only_jams_the_boulder()
	blue_wont_shove_it()
	a_cart_carries_it_off()
	mash(Stops.RAILS, 4)


func white_only_jams_the_boulder() -> void:
	fresh(Stops.RAILS)
	var boulder := sim.rocks[0]
	check(boulder.size == Vector2(3, 3), "the gallery has a boulder")
	bot.paint_rock(boulder, Sim.WHITE)
	bot.run(300)
	check(boulder.pos.y < 3.0, "white floats it up against the roof")
	bot.drive()
	check(not sim.done and refused_at().distance_to(boulder.rect().get_center()) < 0.1, "where it still stops the house")


func blue_wont_shove_it() -> void:
	fresh(Stops.RAILS)
	var boulder := sim.rocks[0]
	bot.paint_rock(boulder, Sim.BLUE)
	bot.walk(sim.marta, boulder.pos.x + 1.0)
	bot.run(60)
	check(boulder.pos == boulder.home, "it's too heavy to shove, even on blue")


func a_cart_carries_it_off() -> void:
	fresh(Stops.RAILS)
	var boulder := sim.rocks[0]
	bot.paint_rock(boulder, Sim.WHITE)
	bot.run(300)
	var k := sim.giulio
	bot.hold(Sim.WHEEL_TOOL)
	for x in [19, 23]:
		bot.walk(k, x - 1.5)
		check(bot.use_at(Vector2i(x, 11)), "he puts wheels on the road under the boulder")
	bot.hold(Sim.HAMMER)
	bot.walk(k, 18.5)
	for x in [19, 20, 21]:
		check(bot.use_at(Vector2i(x, 10)), "and planks across them")
	bot.walk(k, 24.5)
	for x in [23, 22]:
		check(bot.use_at(Vector2i(x, 10)), "and planks across them")
	bot.walk(k, 12.0)
	var m := sim.marta
	bot.walk(m, 23.2)
	check(m.pos.y < 10.1, "she climbs onto the front of the cart")
	m.facing = -1
	wash_from_a_jump(boulder)
	bot.run(120)
	check(absf(boulder.rect().end.y - 10.0) < 0.1, "washed, the boulder drops onto the cart behind her")
	m.facing = 1
	bot.brush(Sim.YELLOW)
	bot.run(2)
	check(m.pick_block == Vector2i(23, 10), "facing on, she picks the plank under her instead of the boulder")
	bot.press(m, "use_p")
	bot.run(900)
	check(boulder.pos.x >= Stops.RAILS.goal + Sim.HOUSE_W - 0.5, "the cart drives the boulder out past where the house stops")
	bot.drive()
	check(sim.done, "and the house gets through")


## Jumps from the cart and washes the boulder at the top of the jump, where it's in her reach.
func wash_from_a_jump(boulder: Sim.Rock) -> void:
	var m := sim.marta
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
	check(boulder.colour == Sim.PLAIN, "she washes it at the top of a jump")
