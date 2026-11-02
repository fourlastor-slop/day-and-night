extends Node
## Plays the river stop with bots driving the real tick(), and fails on anything that breaks the
## puzzle: the obvious plank bridge has to fail, and the two kids together have to get through.

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
