extends Node
## Plays the river stop with bots driving the real tick(), and fails on anything that breaks the
## puzzle: the obvious plank bridge has to fail, and the two kids together have to get through.

const MASH_TICKS := 18000

var failed := 0
var sim: Sim
var bot: Bot


func _ready() -> void:
	plank_line_breaks()
	two_white_rocks_hold()
	rock_blocks_the_road()
	marta_needs_giulio_to_reach()
	blue_freezes_but_wont_hold_the_house()
	lost_rock_comes_back()
	falling_wakes_you_at_the_house()
	aiming_reaches_further()
	pick_digs_and_planks_fill()
	real_input_reaches_the_pads()
	falling_at_the_river_wakes_you_on_land()
	waking_on_planks_stands_on_them()
	the_bell_only_brings_back_what_is_lost()
	driving_works_where_the_bridge_starts()
	wood_cant_reach_a_sunken_rock()
	a_rock_wont_squash_its_rider()
	ice_forming_around_you_wakes_you()
	digging_stops_at_the_edge_of_the_world()
	mashing_buttons_never_buries_a_kid()
	print("stop: ", "FAILED %d" % failed if failed > 0 else "ok")
	get_tree().quit(1 if failed > 0 else 0)


func fresh() -> void:
	sim = Sim.new()
	bot = Bot.new(sim)


func plank_line_breaks() -> void:
	fresh()
	bot.clear_road()
	check(bot.build_deck(28, 41), "he aims at each next plank")
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x < Sim.BANK_L, "the house backs onto the bank")
	check(not sim.done, "a bare plank line must not get the house across")
	check(count_blocks() < 14, "the overstretched planks fall")
	check(count_blocks() > 0, "the planks near the banks stay")


func two_white_rocks_hold() -> void:
	fresh()
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
	fresh()
	bot.drive()
	check(sim.house_state == Sim.PARKED and sim.house_x < sim.rocks[2].pos.x, "a rock on the road stops the house")
	bot.clear_road()
	bot.drive()
	check(sim.house_x + Sim.WHEELS[1] < Sim.BANK_L + 1, "the house stops at the river")


func marta_needs_giulio_to_reach() -> void:
	fresh()
	bot.walk(sim.marta, Sim.BANK_L - 0.6)
	bot.run(2)
	check(sim.marta.pick_rock != sim.rocks[0], "she can't reach the river rock from the bank")
	bot.build_deck(28, 31)
	bot.walk(sim.marta, 31.0)
	bot.run(2)
	check(sim.marta.pick_rock == sim.rocks[0], "his planks get her within reach")


func blue_freezes_but_wont_hold_the_house() -> void:
	fresh()
	bot.clear_road()
	bot.build_deck(28, 31)
	bot.walk(sim.marta, 31.0)
	bot.press(sim.marta, "next_p")
	bot.press(sim.marta, "use_p")
	bot.run(30)
	check(sim.rocks[0].colour == Sim.BLUE, "she can switch to blue")
	check(sim.frozen(33, Sim.SURFACE), "blue freezes the water around it")
	sim.marta.pos = Vector2(34.5, Sim.SURFACE - 0.5)
	bot.run(30)
	check(sim.marta.grounded and absf(sim.marta.pos.y - Sim.SURFACE) < 0.1, "the ice holds a kid")


func lost_rock_comes_back() -> void:
	fresh()
	bot.clear_road()
	bot.run(240)
	check(sim.rocks[2].pos.y <= Sim.SKY + 0.5, "a white rock with nothing above it is gone")
	bot.walk(sim.giulio, sim.house_x + Sim.BELL)
	bot.press(sim.giulio, "interact_p")
	bot.run(30)
	check(sim.rocks[2].pos.is_equal_approx(sim.rocks[2].home), "the bell brings it back")
	check(sim.rocks[2].colour == Sim.PLAIN, "the bell brings it back unpainted")


func falling_wakes_you_at_the_house() -> void:
	fresh()
	bot.clear_road()
	bot.walk(sim.giulio, Sim.BANK_L + 1.5)
	bot.run(60)
	check(sim.giulio.pos.x < Sim.BANK_L, "falling in the river wakes you at the house")
	check(sim.giulio.pos.y <= Sim.ROAD + 0.1, "you wake up on the road")


func aiming_reaches_further() -> void:
	fresh()
	var k := sim.giulio
	k.pad.alt = true
	k.pad.alt_p = true
	sim.tick()
	k.pad.alt_p = false
	var start := k.target
	k.pad.dir_p = Vector2i.UP
	sim.tick()
	check(k.target == start + Vector2i.UP, "holding the button moves his target")
	bot.run(8)
	check(k.target.y == floori(k.pos.y - 0.01) - Sim.BUILD_REACH, "his target stops at his reach")
	k.pad.clear()


func pick_digs_and_planks_fill() -> void:
	fresh()
	var k := sim.giulio
	bot.press(k, "next_p")
	check(k.tool == Sim.PICK, "he can switch to the pick")
	var under := k.target
	check(under == Vector2i(floori(k.pos.x), Sim.ROAD), "the pick aims at the ground under him")
	bot.press(k, "use_p")
	check(sim.cell(under.x, under.y) == Sim.AIR, "the pick digs earth")
	bot.run(30)
	bot.press(k, "next_p")
	check(k.tool == Sim.HAMMER, "he can switch back to the hammer")


func real_input_reaches_the_pads() -> void:
	var pad := Pad.new()
	send_key(KEY_D, true)
	send_key(KEY_E, true)
	pad.poll(Main.KEYS_MARTA, -1)
	check(pad.x == 1 and pad.use_p, "keys reach Marta's pad")
	pad.poll(Main.KEYS_MARTA, -1)
	check(pad.x == 1 and not pad.use_p, "a held key only counts as pressed once")
	send_key(KEY_D, false)
	send_key(KEY_E, false)
	pad = Pad.new()
	var button := InputEventJoypadButton.new()
	button.device = 1
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	Input.parse_input_event(button)
	var stick := InputEventJoypadMotion.new()
	stick.device = 1
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	pad.poll(Main.KEYS_GIULIO, 1)
	check(pad.x == -1 and pad.use_p, "a gamepad reaches Giulio's pad")
	pad.poll(Main.KEYS_GIULIO, 0)
	check(pad.x == 0, "another gamepad doesn't move him")


func falling_at_the_river_wakes_you_on_land() -> void:
	for i in 2:
		fresh()
		bot.clear_road()
		bot.drive()
		var k: Sim.Kid = [sim.marta, sim.giulio][i]
		drop_in_river(k)
		check(k.grounded and k.pos.x < Sim.BANK_L, "with the house at the river you still wake on land")
		check(sim.near_house(k), "you wake up by the house")


func waking_on_planks_stands_on_them() -> void:
	fresh()
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
	fresh()
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
	fresh()
	bot.clear_road()
	bot.drive()
	bot.build_deck(28, 41)
	bot.paint_rock_from(31.0, 0)
	bot.run(90)
	bot.paint_rock_from(36.0, 1)
	bot.run(90)
	bot.walk(sim.giulio, Sim.BANK_L + 0.5)
	bot.press(sim.giulio, "interact_p")
	check(sim.house_state == Sim.DRIVING, "pressing drive at the start of the bridge drives")
	check(sim.rocks[0].colour == Sim.WHITE and sim.rocks[1].colour == Sim.WHITE, "and leaves her rocks alone")
	bot.run(1800)
	check(sim.done, "and the house crosses")


## Wood can't stand in water, so a rock under the surface gives him nothing to build on.
func wood_cant_reach_a_sunken_rock() -> void:
	fresh()
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
	fresh()
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
	fresh()
	var k := sim.marta
	k.pos = Vector2(33.5, Sim.SURFACE + 0.1)
	sim.rocks[0].colour = Sim.BLUE
	bot.run(5)
	check(sim.near_house(k), "ice closing around her feet wakes her at the house")


func digging_stops_at_the_edge_of_the_world() -> void:
	fresh()
	var k := sim.giulio
	k.pos = Vector2(Sim.W - 0.5, Sim.ROAD)
	bot.run(2)
	bot.press(k, "next_p")
	bot.press(k, "use_p")
	check(sim.cell(0, Sim.ROAD) == Sim.EARTH, "digging past the edge leaves the far side of the world alone")


func mashing_buttons_never_buries_a_kid() -> void:
	for s in 8:
		fresh()
		if s % 2 == 1:
			bot.clear_road()
			bot.drive()
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var buried := 0
		for i in MASH_TICKS:
			bot.mash(sim.marta, rng)
			bot.mash(sim.giulio, rng)
			sim.tick()
			for k: Sim.Kid in [sim.marta, sim.giulio]:
				if sim._tiles_hit(k.rect().grow(-0.05)):
					buried += 1
		check(buried == 0, "mashing never leaves a kid inside a block (seed %d: %d ticks)" % [s, buried])


func drop_in_river(k: Sim.Kid) -> void:
	k.pos = Vector2(Sim.BANK_L + 1.5, Sim.SURFACE + 0.5)
	bot.run(30)


func plank(x: int, y: int) -> void:
	sim.cells[y * Sim.W + x] = Sim.BLOCK
	sim._dirty = true


func send_key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func count_blocks() -> int:
	var n := 0
	for y in Sim.H:
		for x in Sim.W:
			if sim.cell(x, y) == Sim.BLOCK:
				n += 1
	return n


func max_span() -> int:
	var worst := 0
	for x in Sim.W:
		if sim.cell(x, Sim.ROAD) == Sim.BLOCK:
			worst = maxi(worst, sim.span_at(x, Sim.ROAD))
	return worst


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("  FAIL: ", what)
