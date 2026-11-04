extends Case
## Rules that hold on every stop, each tried on whichever map shows it best.


func run() -> void:
	the_pick_tunnels_into_a_mound()
	rock_is_ground_the_pick_cant_dig()
	the_house_drives_on_rock()
	the_bell_brings_back_a_rock_the_house_is_waiting_at()


## Walking into a mound with the pick digs what's in front of him, feet first and then head, so he
## tunnels instead of digging a hole under himself.
func the_pick_tunnels_into_a_mound() -> void:
	fresh(Stops.BROOK)
	var k := sim.giulio
	bot.walk(k, 17.5)
	k.facing = 1
	bot.press(k, "next_p")
	check(k.target == Vector2i(18, 9), "the pick aims at the mound in front of his feet")
	bot.press(k, "use_p")
	check(k.target == Vector2i(18, 8), "then at the mound in front of his head")
	bot.press(k, "use_p")
	bot.walk(k, 18.5)
	check(k.pos.x > 18.3, "and he walks into the tunnel")


## Rock holds planks up the way earth does, but the pick can't dig it.
func rock_is_ground_the_pick_cant_dig() -> void:
	fresh(Stops.GULLY)
	plank(55, 5)
	sim.tick()
	check(sim.span_at(55, 5) == 1, "a plank against the cliff counts from it")
	var k := sim.giulio
	k.pos = Vector2(55.5, Sim.ROAD)
	k.facing = 1
	bot.press(k, "next_p")
	check(bot.aim(Vector2i(56, 9)), "he can aim at the cliff")
	bot.press(k, "use_p")
	k.pad.clear()
	check(sim.cell(56, 9) == Sim.ROCK, "the pick can't dig rock")


func the_house_drives_on_rock() -> void:
	fresh(Stops.RIVER)
	for x in range(10, 20):
		sim.cells[Sim.ROAD * Sim.W + x] = Sim.ROCK
	sim._dirty = true
	bot.drive()
	check(sim.house_x > 13.0, "the house rolls over rock until the rock on the road stops it")
	check(sim.house_safe > 13.0, "and counts rock as safe ground to roll back to")


## The bell leaves alone a rock whose place the house has reached, but not one the house is only
## waiting at, or a rock jammed in its way could never be put back.
func the_bell_brings_back_a_rock_the_house_is_waiting_at() -> void:
	fresh(Stops.RIVER)
	bot.drive()
	var rock := bot.road_rock()
	check(sim.house_x + Sim.HOUSE_W > rock.home.x, "the house waits right up against the rock")
	bot.clear_road()
	bot.run(240)
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(5)
	check(rock.pos.is_equal_approx(rock.home), "the bell brings it back")
