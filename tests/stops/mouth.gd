extends Case
## The Mine Mouth teaches yellow and stone: she lights his way with yellow stones, he digs the rubble
## that stops her, and only stone spans the pool. Then the stones float up out of the house's way.


func run() -> void:
	inside_its_dark_until_a_stone_is_yellow()
	the_rubble_stops_her()
	wood_breaks_over_the_pool()
	stone_holds_and_the_house_gets_through()
	mash(Stops.MOUTH, 4)


func inside_its_dark_until_a_stone_is_yellow() -> void:
	fresh(Stops.MOUTH)
	bot.run(2)
	check(sim.light_at(10, 10) == 1.0 and sim.light_at(28, 10) <= Sim.SOOT_LIT, "outside is daylight and the tunnel is dark")
	check(bot.paint_rock(sim.rocks[0], Sim.YELLOW), "she reaches the first stone")
	bot.run(2)
	check(sim.light_at(28, 10) > 0.3, "and painted yellow it lights the way to the rubble")


func the_rubble_stops_her() -> void:
	fresh(Stops.MOUTH)
	bot.walk(sim.marta, 33.0)
	check(sim.marta.pos.x < 29.0, "the rubble is too high for her to climb")
	bot.tunnel(29, 30)
	bot.walk(sim.marta, 33.0)
	check(sim.marta.pos.x > 32.5, "until he digs her a way through")


func wood_breaks_over_the_pool() -> void:
	clear_the_way()
	bot.build_deck(38, 43)
	check(max_span() >= Sim.MAX_SPAN, "a line of wood over the pool goes red")
	bot.drive()
	check(not sim.done and sim.house_x < 38.0, "and breaks under the house")


func stone_holds_and_the_house_gets_through() -> void:
	clear_the_way()
	check(bot.build_deck(38, 43, Sim.CHISEL), "he lays stone across the pool")
	check(max_span() < Sim.STONE_SPAN, "and it holds")
	bot.drive()
	check(not sim.done and sim.house_x < 20.0, "but the stones still stand in the house's way")
	for r in sim.rocks:
		bot.paint_rock(r, Sim.WHITE)
	bot.run(240)
	for r in sim.rocks:
		check(r.pos.y < 4.0, "white floats each stone up under the roof, over the house")
	bot.drive()
	check(sim.done, "and the house drives out the far end")


## Lights the tunnel, digs the rubble out from road to roof, and gets Marta to the second stone.
func clear_the_way() -> void:
	fresh(Stops.MOUTH)
	bot.paint_rock(sim.rocks[0], Sim.YELLOW)
	bot.tunnel(29, 30)
	for at: Vector2i in [Vector2i(29, 9), Vector2i(29, 8), Vector2i(30, 9), Vector2i(30, 8)]:
		check(bot.use_at(at), "he can reach the top of the rubble")
	bot.paint_rock(sim.rocks[1], Sim.YELLOW)
	bot.run(2)
	check(sim.light_at(38, 11) > 0.3, "the second stone lights the near side of the pool")
