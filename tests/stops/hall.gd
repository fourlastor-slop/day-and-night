extends Case
## The Sootling Hall twists the mines' tools: with no loose stones to paint, she keeps the sootlings
## off him by painting his own blocks yellow while he bridges the water with stone and a sunk pillar.


func run() -> void:
	the_bank_is_safe_but_the_dark_water_isnt()
	stone_without_a_pillar_breaks()
	yellow_blocks_keep_them_off_while_he_builds()
	mash(Stops.HALL, 4)


func caught() -> bool:
	for e in sim.events:
		if e.kind == "caught":
			return true
	return false


func the_bank_is_safe_but_the_dark_water_isnt() -> void:
	fresh(Stops.HALL)
	bot.walk(sim.giulio, 23.5)
	bot.run(300)
	check(not caught(), "at the water's edge he's too far off for them to notice")
	bot.build_deck(24, 35, Sim.CHISEL)
	check(caught(), "but bridging the water in the dark, a sootling catches him")


func stone_without_a_pillar_breaks() -> void:
	fresh(Stops.HALL)
	# Sent off to the far end, so they stay out of what's being tried here.
	for s in sim.soots:
		s.pos = Vector2(50.5, 5.5)
		s.home = s.pos
	bot.build_deck(24, 35, Sim.CHISEL)
	check(max_span() >= Sim.STONE_SPAN, "a line of stone twelve wide goes red in the middle")
	bot.drive()
	check(not sim.done and sim.house_x < 24.0, "and breaks under the house")


func yellow_blocks_keep_them_off_while_he_builds() -> void:
	fresh(Stops.HALL)
	var k := sim.giulio
	var m := sim.marta
	bot.hold(Sim.CHISEL)
	bot.brush(Sim.YELLOW)
	for x in range(24, 36):
		bot.walk(k, x - 0.5)
		k.facing = 1
		bot.run(2)
		bot.press(k, "use_p")
		if x == 29:
			bot.use_at(Vector2i(29, 13))
			bot.use_at(Vector2i(29, 13))
		if x % 2 == 0:
			bot.walk(m, x + 0.5)
			bot.run(2)
			check(m.pick_block == Vector2i(x, sim.road), "standing on his newest block, she picks it")
			bot.press(m, "use_p")
	check(not caught(), "with his new blocks painted yellow, no sootling reaches him")
	check(sim.cell(29, 14) == Sim.STONE and sim.cell(29, 13) == Sim.STONE, "a pillar of stone sunk under the middle")
	check(max_span() < Sim.STONE_SPAN, "holds the bridge up")
	bot.walk(k, 14.0)
	bot.walk(m, 14.0)
	bot.drive()
	check(sim.done, "and the house crosses the hall")
