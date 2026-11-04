class_name LightCase
extends Case
## Caves are dark, yellow things light them through open space only, and Marta's yellow cloak lights
## her own half of the screen alone.


func run() -> void:
	caves_are_dark()
	yellow_lights_the_cave()
	light_stops_at_walls()
	a_hole_in_the_roof_lets_daylight_in()
	her_cloak_lights_only_her_half()
	the_meadow_has_no_dark()


## Flat ground with a thick roof over the middle, open underneath: a cave the road runs through.
static func cave() -> Dictionary:
	var map: Array[String] = []
	for y in Sim.H:
		var row := ""
		for x in Sim.W:
			row += "#" if y >= Sim.ROAD or (y < 4 and x >= 20 and x < 45) else "."
		map.append(row)
	return {"name": "Cave", "house": 3.0, "goal": 46.0, "marta": 14.0, "giulio": 16.0, "dark": true, "cloak": "yellow",
			"colours": ["white", "blue", "yellow"], "map": map}


func with_yellow_rock(at: Vector2) -> void:
	var r := Sim.Rock.new(at)
	r.colour = Sim.YELLOW
	sim.rocks.append(r)


func caves_are_dark() -> void:
	fresh(cave())
	bot.run(2)
	check(sim.light_at(10, 8) == 1.0, "outside the cave it's daylight")
	check(sim.light_at(32, 8) < 0.1, "deep inside it's dark")
	check(sim.light_at(21, 8) > sim.light_at(24, 8), "with a little daylight at the mouth")


func yellow_lights_the_cave() -> void:
	fresh(cave())
	with_yellow_rock(Vector2(31, 8))
	bot.run(2)
	check(sim.light_at(33, 8) > 0.5, "a yellow rock lights the cave around it")
	check(sim.light_at(38, 8) < 0.1, "out to about four squares")


func light_stops_at_walls() -> void:
	fresh(cave())
	for y in range(4, Sim.ROAD):
		sim.cells[y * Sim.W + 34] = Sim.EARTH
	sim._dirty = true
	with_yellow_rock(Vector2(31, 8))
	bot.run(2)
	check(sim.light_at(35, 8) < 0.1, "light doesn't pass through a wall")
	check(sim.light_at(34, 8) > 0.3, "though it lights the wall itself")


func a_hole_in_the_roof_lets_daylight_in() -> void:
	fresh(cave())
	for y in 4:
		sim.cells[y * Sim.W + 32] = Sim.AIR
	sim._dirty = true
	bot.run(2)
	check(sim.light_at(32, 8) == 1.0, "a hole dug through the roof lets daylight in below it")


func her_cloak_lights_only_her_half() -> void:
	fresh(cave())
	sim.marta.pos = Vector2(32.5, Sim.ROAD)
	bot.run(2)
	check(sim.marta_light_at(32, 8) > 0.5, "her yellow cloak lights her way")
	check(sim.light_at(32, 8) < 0.1, "but not his")


func the_meadow_has_no_dark() -> void:
	fresh(Stops.GULLY)
	bot.run(2)
	check(sim.light_at(50, 5) == 1.0, "under the Gully's shelf it's still daylight, because only caves are dark")
