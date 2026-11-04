class_name LiftCase
extends Case
## White on Giulio's blocks: a group lifts once at least half of it is white, with the house counting
## as extra weight when it stands on the group.


func run() -> void:
	half_white_lifts_a_group()
	a_lift_stops_under_the_ground_and_settles()
	a_lift_carries_a_kid()
	a_lift_wont_start_into_something()
	the_house_weighs_four_blocks()


## Flat ground all the way across, for trying rules away from any stop's puzzle.
static func flat() -> Dictionary:
	var map: Array[String] = []
	for y in Sim.H:
		map.append(("." if y < Sim.ROAD else "#").repeat(Sim.W))
	return {"name": "Flat", "house": 3.0, "goal": 46.0, "marta": 14.0, "giulio": 16.0, "map": map}


func row_of_planks(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		plank(x, y)


func whiten(x: int, y: int) -> void:
	sim.paint[y * Sim.W + x] = Sim.WHITE
	sim._dirty = true


func half_white_lifts_a_group() -> void:
	fresh(flat())
	row_of_planks(30, 33, 7)
	whiten(30, 7)
	bot.run(2)
	check(sim.cell(30, 7) == Sim.BLOCK and sim.bodies.is_empty(), "one white plank in four doesn't lift them")
	check(sim.strain.has(7 * Sim.W + 31), "it only makes them strain")
	whiten(31, 7)
	bot.run(2)
	check(sim.bodies.size() == 1 and sim.cell(30, 7) == Sim.AIR, "two in four do, and the group comes loose")
	if sim.bodies.is_empty():
		return
	var y := sim.bodies[0].pos.y
	bot.run(30)
	check(sim.bodies[0].pos.y < y - 0.9, "and it rises")
	bot.run(600)
	check(sim.bodies.is_empty() and count_blocks() == 0, "with nothing above it, it's gone")


func a_lift_stops_under_the_ground_and_settles() -> void:
	fresh(flat())
	for x in range(28, 36):
		sim.cells[2 * Sim.W + x] = Sim.EARTH
	row_of_planks(30, 33, 7)
	whiten(30, 7)
	whiten(31, 7)
	bot.run(240)
	check(sim.bodies.is_empty(), "a lift stops when it reaches the ground above")
	check(sim.cell(30, 3) == Sim.BLOCK and sim.cell(33, 3) == Sim.BLOCK, "and settles back into the grid right under it")
	check(sim.paint.get(3 * Sim.W + 30, Sim.PLAIN) == Sim.WHITE, "keeping its paint")


func a_lift_carries_a_kid() -> void:
	fresh(flat())
	row_of_planks(30, 33, 8)
	sim.marta.pos = Vector2(31.5, 8.0)
	bot.run(10)
	check(sim.marta.grounded, "she stands on the planks")
	whiten(30, 8)
	whiten(31, 8)
	bot.run(60)
	check(sim.marta.pos.y < 6.5, "and rides them up")


func a_lift_wont_start_into_something() -> void:
	fresh(flat())
	for x in range(28, 36):
		sim.cells[6 * Sim.W + x] = Sim.EARTH
	row_of_planks(30, 33, 7)
	whiten(30, 7)
	whiten(31, 7)
	bot.run(5)
	check(sim.bodies.is_empty() and sim.cell(30, 7) == Sim.BLOCK, "pressed against the ground, a white group stays put")


## Planks laid into the road under the house: it adds as much weight as 4 plain blocks.
func the_house_weighs_four_blocks() -> void:
	fresh(flat())
	for x in range(3, 13):
		plank(x, Sim.ROAD)
	for x in range(3, 9):
		whiten(x, Sim.ROAD)
	bot.run(5)
	check(sim.bodies.is_empty(), "six white of ten can't lift the house as well")
	whiten(9, Sim.ROAD)
	bot.run(5)
	check(sim.bodies.size() == 1, "seven can")
	bot.run(600)
	check(sim.house_y < 0.0 and sim.done, "and the house rides it up out of view")
	check(sim.house_stands(), "standing on it all the way")
