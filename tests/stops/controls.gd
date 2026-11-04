extends Case
## The controls on their own: what the keys and pads do, and what Giulio can aim at.

func run() -> void:
	aiming_reaches_further()
	pick_digs_and_planks_fill()
	real_input_reaches_the_pads()
	digging_stops_at_the_edge_of_the_world()
	the_tool_cue_only_shows_when_it_can_act()
	the_cues_name_the_right_keys()


func aiming_reaches_further() -> void:
	fresh(Stops.RIVER)
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
	fresh(Stops.RIVER)
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


func digging_stops_at_the_edge_of_the_world() -> void:
	fresh(Stops.RIVER)
	var k := sim.giulio
	k.pos = Vector2(Sim.W - 0.5, Sim.ROAD)
	bot.run(2)
	bot.press(k, "next_p")
	bot.press(k, "use_p")
	check(sim.cell(0, Sim.ROAD) == Sim.EARTH, "digging past the edge leaves the far side of the world alone")


func the_tool_cue_only_shows_when_it_can_act() -> void:
	fresh(Stops.RIVER)
	var k := sim.giulio
	bot.run(2)
	check(sim.can_use(), "the hammer can lay a plank on the ground ahead")
	bot.walk(k, sim.house_x + Sim.WHEELS[0])
	bot.press(k, "next_p")
	bot.run(2)
	check(not sim.can_use(), "the pick can't dig under a wheel")
	k.pos.x += 3.0
	bot.run(2)
	check(sim.can_use(), "but it can dig next to one")
	bot.press(k, "next_p")
	bot.aim(k.target + Vector2i(0, -3))
	check(not sim.can_use(), "and the hammer can't lay a plank in thin air")
	k.pad.clear()


func the_cues_name_the_right_keys() -> void:
	var marta := Main.caps(Main.KEYS_MARTA, -1)
	check(marta == {"use": "E", "alt": "R", "next": "Q", "interact": "F"}, "Marta's cues show her keys")
	var giulio := Main.caps(Main.KEYS_GIULIO, -1)
	check(giulio == {"use": "K", "alt": "L", "next": "J", "interact": "I"}, "Giulio's cues show his keys")
	var pad := Main.caps(Main.KEYS_GIULIO, 0)
	check(pad == {"use": "X", "alt": "B", "next": "LB", "interact": "Y"}, "a gamepad's cues show its buttons")
	for names: Dictionary in [marta, giulio, pad]:
		for action: String in names:
			check(Stage.CAPS.has(names[action]), "the sheet has a key for %s" % names[action])
