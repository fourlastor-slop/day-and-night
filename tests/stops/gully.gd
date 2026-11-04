extends Case
## The Gully uses the tools: the deck needs a pillar, and the boulder under the shelf has to slide out
## before white can float it away.

const SHELF := 44
const CLIFF := 56


func run() -> void:
	a_plank_line_breaks_over_the_gully()
	marta_cant_cross_without_the_deck()
	white_jams_the_boulder_under_the_shelf()
	the_bell_frees_a_boulder_shoved_into_the_cliff()
	blue_slides_it_out_and_white_floats_it_away()
	mash(Stops.GULLY, 4)


func a_plank_line_breaks_over_the_gully() -> void:
	fresh(Stops.GULLY)
	bot.build_deck(24, 30)
	check(max_span() >= Sim.MAX_SPAN, "a plain line goes red over the gully")
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x < 24.0, "it breaks and the house rolls back")
	check(not sim.done and count_blocks() < 7, "and the middle falls")


func marta_cant_cross_without_the_deck() -> void:
	fresh(Stops.GULLY)
	bot.walk(sim.marta, 33.0)
	check(sim.marta.pos.x < 31.0 and sim.marta.pos.y > Sim.ROAD, "without his deck she ends up down in the gully")


func white_jams_the_boulder_under_the_shelf() -> void:
	bridge()
	var boulder := sim.rocks[0]
	bot.walk(sim.marta, boulder.pos.x - 0.6)
	sim.marta.facing = 1
	bot.press(sim.marta, "use_p")
	bot.run(240)
	check(absf(boulder.pos.y - 1.0) < 0.06, "white jams the boulder against the shelf")
	check(sim.marta.pick_rock == null, "where she can't reach it from the road")
	bot.drive()
	check(not sim.done and refused_at() == boulder.rect().get_center(), "and it's still in the house's way")
	ring()
	check(boulder.pos == boulder.home and boulder.colour == Sim.PLAIN, "the bell brings it back down")


## Shoved from the left it slides into the cliff, with no room behind it to shove it back.
func the_bell_frees_a_boulder_shoved_into_the_cliff() -> void:
	bridge()
	bot.drive()
	var boulder := sim.rocks[0]
	bot.walk(sim.marta, boulder.pos.x - 0.6)
	sim.marta.facing = 1
	paint(Sim.BLUE)
	bot.walk(sim.marta, boulder.pos.x + 1.0)
	bot.run(240)
	check(boulder.rect().end.x > CLIFF - 0.2, "a shove from the left slides it into the cliff")
	ring()
	check(boulder.pos == boulder.home and boulder.colour == Sim.PLAIN, "the bell brings it back for another try")


func blue_slides_it_out_and_white_floats_it_away() -> void:
	bridge()
	var boulder := sim.rocks[0]
	bot.walk(sim.marta, boulder.pos.x + 3.0)
	check(sim.marta.pos.x > boulder.rect().end.x, "she climbs over the boulder to its far side")
	sim.marta.facing = -1
	paint(Sim.BLUE)
	bot.walk(sim.marta, SHELF - 1.0)
	bot.run(240)
	check(boulder.rect().end.x < SHELF, "a shove from the right slides it out from under the shelf")
	bot.walk(sim.marta, boulder.rect().end.x + 0.6)
	sim.marta.facing = -1
	paint(Sim.WHITE)
	bot.run(400)
	check(boulder.pos.y <= Sim.SKY + 0.5, "then white floats it away")
	bot.drive()
	check(sim.done, "the house crosses and the stop is finished")


## The deck across the gully with a pillar under its middle, so the house and Marta can cross.
func bridge() -> void:
	fresh(Stops.GULLY)
	bot.build_deck(24, 30)
	bot.walk(sim.giulio, 27.5)
	check(bot.use_at(Vector2i(27, 12)), "he can aim down to the floor of the gully")
	check(bot.use_at(Vector2i(27, 11)), "and build the pillar up from it")
	check(max_span() < Sim.MAX_SPAN, "a pillar under the middle holds the deck")


## Switches her brush to a colour and paints whatever she has picked.
func paint(colour: int) -> void:
	if sim.marta.colour != colour:
		bot.press(sim.marta, "next_p")
	bot.run(2)
	bot.press(sim.marta, "use_p")


func ring() -> void:
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(5)
