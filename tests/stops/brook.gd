extends Case
## The Brook teaches: Giulio digs Marta a way through the mound, she floats the rock away, and a plain
## line of planks crosses the brook.


func run() -> void:
	the_mound_stops_the_house()
	the_mound_stops_marta_too()
	a_tunnel_lets_her_reach_the_rock()
	a_line_of_planks_crosses_the_brook()
	mash(Stops.BROOK, 4)


func the_mound_stops_the_house() -> void:
	fresh(Stops.BROOK)
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x + Sim.HOUSE_W < 18.2, "the mound stops the house")
	check(refused_at() == Vector2(18.5, 7.5), "and the crossed wheel lands on it")


func the_mound_stops_marta_too() -> void:
	fresh(Stops.BROOK)
	bot.walk(sim.marta, bot.road_rock().pos.x - 0.6)
	check(sim.marta.pos.x < 18.0, "she can't climb the mound")
	check(sim.marta.pick_rock == null, "so the rock is out of her reach")
	bot.walk(sim.giulio, 20.0)
	check(sim.giulio.pos.x < 18.0, "and neither can he")


func a_tunnel_lets_her_reach_the_rock() -> void:
	fresh(Stops.BROOK)
	bot.tunnel(18, 21)
	check(sim.giulio.pos.x > 21.0, "the pick takes him through the mound")
	var rock := bot.road_rock()
	bot.walk(sim.marta, rock.pos.x - 0.6)
	bot.run(2)
	check(sim.marta.pick_rock == rock, "and she follows him through to the rock")
	bot.drive()
	check(refused_at().y == 7.5, "the top of the mound still stops the house")


func a_line_of_planks_crosses_the_brook() -> void:
	fresh(Stops.BROOK)
	bot.tunnel(18, 21)
	for x in range(18, 22):
		bot.walk(sim.giulio, x + 0.5)
		check(bot.use_at(Vector2i(x, 7)), "he can reach the top of the mound from inside it")
	bot.clear_road()
	bot.run(240)
	check(bot.build_deck(32, 35), "he lays planks across the brook")
	check(max_span() < Sim.MAX_SPAN, "and a plain line holds")
	bot.drive()
	check(sim.done, "the house crosses and the stop is finished")
