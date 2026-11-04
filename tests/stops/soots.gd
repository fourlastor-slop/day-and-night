extends Case
## Sootlings are shy shadows: they drift towards Giulio while he's in the dark, never go into light,
## leave it when it reaches them, and if one touches him in the dark he wakes up in the house.


func run() -> void:
	a_sootling_comes_for_him_in_the_dark()
	its_touch_wakes_him_in_the_house()
	it_wont_go_into_light()
	light_reaching_it_drives_it_off()
	the_map_places_them()


func cave_with_giulio() -> Sim.Soot:
	fresh(LightCase.cave())
	sim.giulio.pos = Vector2(31.5, Sim.ROAD)
	var soot := Sim.Soot.new(Vector2(36.5, 6.5))
	sim.soots.append(soot)
	return soot


func a_sootling_comes_for_him_in_the_dark() -> void:
	var soot := cave_with_giulio()
	var far := soot.pos.distance_to(sim.giulio.centre())
	bot.run(30)
	check(soot.pos.distance_to(sim.giulio.centre()) < far - 0.5, "in the dark a sootling drifts towards him")


func its_touch_wakes_him_in_the_house() -> void:
	cave_with_giulio()
	bot.run(300)
	check(sim.near_house(sim.giulio), "once it reaches him in the dark, he wakes up in the house")


func it_wont_go_into_light() -> void:
	var soot := cave_with_giulio()
	var lamp := Sim.Rock.new(Vector2(30, 8))
	lamp.colour = Sim.YELLOW
	sim.rocks.append(lamp)
	var caught := false
	for i in 600:
		sim.tick()
		caught = caught or sim.near_house(sim.giulio)
		check(sim.light_at(floori(soot.pos.x), floori(soot.pos.y)) <= Sim.SOOT_LIT or i == 0, "it never goes into light")
		if sim.light_at(floori(soot.pos.x), floori(soot.pos.y)) > Sim.SOOT_LIT and i > 0:
			break
	check(not caught, "so standing in the light keeps him safe")


func light_reaching_it_drives_it_off() -> void:
	var soot := cave_with_giulio()
	bot.run(20)
	var lamp := Sim.Rock.new(soot.pos.floor() - Vector2(1, 1))
	lamp.colour = Sim.YELLOW
	sim.rocks.append(lamp)
	bot.run(90)
	check(sim.light_at(floori(soot.pos.x), floori(soot.pos.y)) <= Sim.SOOT_LIT, "light that reaches it sends it back into the dark")


func the_map_places_them() -> void:
	var stop := LightCase.cave()
	var map: Array = stop.map.duplicate()
	map[6] = map[6].substr(0, 36) + "@" + map[6].substr(37)
	stop.map = map
	fresh(stop)
	check(sim.soots.size() == 1 and sim.soots[0].home == Vector2(36.5, 6.5), "an @ in a map is where a sootling lives")
