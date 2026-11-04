extends Case
## The river: the obvious plank bridge has to fail, and the two kids together have to get through.

const BANK_L := 28
const SURFACE := 11

func run() -> void:
	plank_line_breaks()
	two_white_rocks_hold()
	rock_blocks_the_road()
	marta_needs_giulio_to_reach()
	blue_freezes_but_wont_hold_the_house()
	lost_rock_comes_back()
	falling_wakes_you_at_the_house()
	falling_at_the_river_wakes_you_on_land()
	waking_on_planks_stands_on_them()
	the_bell_only_brings_back_what_is_lost()
	driving_works_where_the_bridge_starts()
	wood_cant_reach_a_sunken_rock()
	a_rock_wont_squash_its_rider()
	ice_forming_around_you_wakes_you()
	the_house_keeps_the_ground_under_it()
	the_house_keeps_the_planks_under_it()
	the_house_keeps_the_spot_it_rolls_back_to()
	a_raised_rock_frozen_in_still_holds()
	a_dug_road_can_be_filled_in()
	a_refusal_shows_what_stopped_the_house()
	mash(Stops.RIVER, 8)


func plank_line_breaks() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	check(bot.build_deck(28, 41), "he aims at each next plank")
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x < BANK_L, "the house backs onto the bank")
	check(not sim.done, "a bare plank line must not get the house across")
	check(count_blocks() < 14, "the overstretched planks fall")
	check(count_blocks() > 0, "the planks near the banks stay")


func two_white_rocks_hold() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.build_deck(28, 41)
	check(max_span() >= Sim.MAX_SPAN, "a bare deck is overstretched")
	check(bot.paint_rock_from(31.0, 0), "she picks the first rock")
	bot.run(90)
	check(absf(sim.rocks[0].pos.y - 11.0) < 0.06, "the white rock stops under the deck")
	check(bot.paint_rock_from(36.0, 1), "she picks the second rock")
	bot.run(90)
	check(max_span() < Sim.MAX_SPAN, "two rocks make every span safe")
	bot.drive()
	check(sim.done, "the house crosses and the stop is finished")


func rock_blocks_the_road() -> void:
	fresh(Stops.RIVER)
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x < sim.rocks[2].pos.x, "a rock on the road stops the house")
	bot.clear_road()
	bot.drive()
	check(sim.house_x + Sim.WHEELS[1] < BANK_L + 1, "the house stops at the river")


func marta_needs_giulio_to_reach() -> void:
	fresh(Stops.RIVER)
	bot.walk(sim.marta, BANK_L - 0.6)
	bot.run(2)
	check(sim.marta.pick_rock != sim.rocks[0], "she can't reach the river rock from the bank")
	bot.build_deck(28, 31)
	bot.walk(sim.marta, 31.0)
	bot.run(2)
	check(sim.marta.pick_rock == sim.rocks[0], "his planks get her within reach")


func blue_freezes_but_wont_hold_the_house() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.build_deck(28, 31)
	bot.walk(sim.marta, 31.0)
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(30)
	check(sim.rocks[0].colour == Sim.BLUE, "she can switch to blue")
	check(sim.frozen(33, SURFACE), "blue freezes the water around it")
	sim.marta.pos = Vector2(34.5, SURFACE - 0.5)
	bot.run(30)
	check(sim.marta.grounded and absf(sim.marta.pos.y - SURFACE) < 0.1, "the ice holds a kid")


func lost_rock_comes_back() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.run(240)
	check(sim.rocks[2].pos.y <= Sim.SKY + 0.5, "a white rock with nothing above it is gone")
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(30)
	check(sim.rocks[2].pos.is_equal_approx(sim.rocks[2].home), "the bell brings it back")
	check(sim.rocks[2].colour == Sim.PLAIN, "the bell brings it back unpainted")


func falling_wakes_you_at_the_house() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.walk(sim.giulio, BANK_L + 1.5)
	bot.run(60)
	check(sim.giulio.pos.x < BANK_L, "falling in the river wakes you at the house")
	check(sim.giulio.pos.y <= Sim.ROAD + 0.1, "you wake up on the road")


func falling_at_the_river_wakes_you_on_land() -> void:
	for i in 2:
		fresh(Stops.RIVER)
		bot.clear_road()
		bot.drive()
		var k: Sim.Kid = [sim.marta, sim.giulio][i]
		drop_in_river(k)
		check(k.grounded and k.pos.x < BANK_L, "with the house at the river you still wake on land")
		check(sim.near_house(k), "you wake up by the house")


func waking_on_planks_stands_on_them() -> void:
	fresh(Stops.RIVER)
	var k := sim.marta
	drop_in_river(k)
	var spot := floori(k.pos.x)
	k.pos.x -= 3.0
	for x in range(spot - 1, spot + 2):
		plank(x, Sim.ROAD - 1)
		plank(x, Sim.ROAD - 2)
	drop_in_river(k)
	check(k.grounded and k.pos.y < Sim.ROAD, "she wakes on top of what was built there")
	var x := k.pos.x
	bot.walk(k, x + 4.0)
	check(k.pos.x > x + 3.0, "and she can walk away")


func the_bell_only_brings_back_what_is_lost() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.drive()
	bot.build_deck(28, 35)
	check(bot.paint_rock_from(31.0, 0), "she picks the first rock")
	bot.run(90)
	check(bot.paint_rock_from(35.5, 1), "she picks the second rock too soon")
	bot.run(480)
	check(sim.rocks[1].pos.y <= Sim.SKY + 0.5, "with nothing above it, it floats off")
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(5)
	check(sim.rocks[1].pos.is_equal_approx(sim.rocks[1].home), "the bell brings back the rock that floated off")
	check(sim.rocks[0].colour == Sim.WHITE and absf(sim.rocks[0].pos.y - 11.0) < 0.06, "a rock holding up planks stays")
	check(sim.rocks[2].pos.y <= Sim.SKY + 0.5, "a rock the house has reached stays gone")
	bot.build_deck(36, 41)
	check(bot.paint_rock_from(36.0, 1), "she gets a second try")
	bot.run(90)
	bot.drive()
	check(sim.done, "the house still crosses after the bell")


func driving_works_where_the_bridge_starts() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.drive()
	bot.build_deck(28, 41)
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	bot.paint_rock_from(36.0, 1)
	bot.run(90)
	bot.walk(sim.giulio, BANK_L + 0.5)
	bot.press(sim.giulio, "interact_p")
	check(sim.house_state == Sim.DRIVING, "pressing drive at the start of the bridge drives")
	check(sim.rocks[0].colour == Sim.WHITE and sim.rocks[1].colour == Sim.WHITE, "and leaves her rocks alone")
	bot.run(1800)
	check(sim.done, "and the house crosses")


## Wood can't stand in water, so a rock under the surface gives him nothing to build on.
func wood_cant_reach_a_sunken_rock() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.build_deck(28, 41)
	for x: int in [32, 37]:
		bot.walk(sim.giulio, x + 0.5)
		check(bot.aim(Vector2i(x, Sim.ROAD + 1)), "he can aim under the deck")
		bot.press(sim.giulio, "use_p")
		sim.giulio.pad.clear()
		check(sim.cell(x, Sim.ROAD + 1) != Sim.BLOCK, "the river takes a plank aimed at a sunken rock")
	check(max_span() >= Sim.MAX_SPAN, "he can't hold the bridge up without her")
	bot.drive()
	check(not sim.done, "so the house can't cross on his planks alone")


func a_rock_wont_squash_its_rider() -> void:
	fresh(Stops.RIVER)
	var k := sim.giulio
	var rock := sim.rocks[2]
	plank(24, 4)
	k.pos = Vector2(24.0, rock.pos.y)
	bot.run(2)
	bot.walk(sim.marta, rock.pos.x - 0.6)
	bot.press(sim.marta, "use_p")
	bot.run(240)
	check(k.pos.y - k.height > 4.9, "his head stops under the plank")
	var x := k.pos.x
	bot.walk(k, x - 3.0)
	check(k.pos.x < x - 2.5, "and he can step off")
	bot.run(240)
	check(absf(rock.pos.y - 5.0) < 0.1, "then the rock rises until the plank stops it")


func ice_forming_around_you_wakes_you() -> void:
	fresh(Stops.RIVER)
	var k := sim.marta
	k.pos = Vector2(33.5, SURFACE + 0.1)
	sim.rocks[0].colour = Sim.BLUE
	bot.run(5)
	check(sim.near_house(k), "ice closing around her feet wakes her at the house")


## The house can't climb out of a hole, so what its wheels stand on stays. He can dig everywhere else.
func the_house_keeps_the_ground_under_it() -> void:
	fresh(Stops.RIVER)
	var k := sim.giulio
	bot.press(k, "next_p")
	for w in Sim.WHEELS:
		var x := floori(sim.house_x + w)
		bot.walk(k, x + 0.5)
		bot.press(k, "use_p")
		check(sim.cell(x, Sim.ROAD) == Sim.EARTH, "the pick leaves the ground under a wheel")
	var between := floori(sim.house_x + 4.5)
	bot.walk(k, between + 0.5)
	bot.press(k, "use_p")
	check(sim.cell(between, Sim.ROAD) == Sim.AIR, "and can still dig between the wheels")


func the_house_keeps_the_planks_under_it() -> void:
	park_on_the_deck()
	var k := sim.giulio
	var x := floori(sim.house_x + Sim.WHEELS[0])
	bot.walk(k, x + 0.5)
	check(bot.aim(Vector2i(x, Sim.ROAD)), "he can aim at the plank under a wheel")
	bot.press(k, "use_p")
	k.pad.clear()
	check(sim.cell(x, Sim.ROAD) == Sim.BLOCK, "the hammer leaves the plank under a wheel")


## A broken bridge sends the house back, so the ground waiting for it has to be there too.
func the_house_keeps_the_spot_it_rolls_back_to() -> void:
	park_on_the_deck()
	var k := sim.giulio
	bot.press(k, "next_p")
	for w in Sim.WHEELS:
		var x := floori(sim.house_safe + w)
		bot.walk(k, x + 0.5)
		bot.press(k, "use_p")
		check(sim.cell(x, Sim.ROAD) == Sim.EARTH, "the pick leaves the ground the house would roll back to")
	bot.walk(sim.marta, 31.0)
	sim.marta.facing = 1
	bot.run(2)
	bot.press(sim.marta, "alt_p")
	bot.run(90)
	check(sim.rocks[0].pos.y > 11.5, "she washes the rock and it sinks")
	plank(34, Sim.ROAD)
	bot.walk(k, sim.house_x + 3.0)
	bot.press(k, "interact_p")
	bot.run(600)
	check(sim.house_x == sim.house_safe, "with the rock washed off, the next plank breaks and the house rolls back")
	check(wheels_stand(), "and it lands on the ground")


## Nobody planned this way across, but it's physics: the ice closes around a raised rock and keeps it up.
func a_raised_rock_frozen_in_still_holds() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.drive()
	bot.build_deck(28, 41)
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	bot.paint_rock_from(36.0, 1)
	bot.run(90)
	bot.press(sim.marta, "next_p")
	check(bot.paint_rock_from(31.0, 0), "she picks the first rock again")
	check(bot.paint_rock_from(36.0, 1), "she picks the second rock again")
	bot.run(240)
	check(sim.rocks[0].colour == Sim.BLUE and sim.rocks[1].colour == Sim.BLUE, "she repaints both blue")
	check(max_span() < Sim.MAX_SPAN, "the ice keeps them under the deck")
	bot.drive()
	check(sim.done, "and the house crosses")


## A trench in the road only stops the house until he fills it in.
func a_dug_road_can_be_filled_in() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	for x in range(24, 28):
		sim.cells[Sim.ROAD * Sim.W + x] = Sim.AIR
	sim._dirty = true
	bot.drive()
	check(sim.house_x + Sim.WHEELS[1] < 24.0, "a trench stops the house")
	check(wheels_stand(), "with its wheels still on the road")
	check(bot.build_deck(24, 41), "he fills it in and carries on across the river")
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	bot.paint_rock_from(36.0, 1)
	bot.run(90)
	bot.drive()
	check(sim.done, "and the house crosses")


func a_refusal_shows_what_stopped_the_house() -> void:
	fresh(Stops.RIVER)
	bot.drive()
	check(refused_at() == sim.rocks[2].rect().get_center(), "the cue lands on a rock in the way")
	bot.clear_road()
	bot.run(240)
	plank(25, Sim.ROAD - 1)
	bot.drive()
	check(refused_at() == Vector2(25.5, Sim.ROAD - 0.5), "and on a plank in the way")
	sim.cells[(Sim.ROAD - 1) * Sim.W + 25] = Sim.AIR
	bot.drive()
	check(refused_at() == Vector2(BANK_L + 0.5, Sim.ROAD + 0.5), "and on the gap at the river")


## Parks the house on planks held up by one white rock, with the end of the deck stopping it.
func park_on_the_deck() -> void:
	fresh(Stops.RIVER)
	bot.clear_road()
	bot.drive()
	bot.build_deck(28, 33)
	check(bot.paint_rock_from(31.0, 0), "she picks the first rock")
	bot.run(90)
	bot.drive()
	check(sim.house_x + Sim.WHEELS[0] > BANK_L, "the house parks on the planks")


func drop_in_river(k: Sim.Kid) -> void:
	k.pos = Vector2(BANK_L + 1.5, SURFACE + 0.5)
	bot.run(30)
