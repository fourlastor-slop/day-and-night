class_name Bot
extends RefCounted
## Plays the stop by setting Pad fields and calling the real tick(), so what the bots manage a kid
## can manage too.

var sim: Sim


func _init(world: Sim) -> void:
	sim = world


## She walks up to the rock on the road and floats it away.
func clear_road() -> void:
	walk(sim.marta, sim.rocks[2].pos.x - 0.6)
	press(sim.marta, "use_p")
	run(120)


## Lays planks along the road, one at a time. Returns false if he ever aims somewhere else.
func build_deck(from: int, to: int) -> bool:
	var ok := true
	for x in range(from, to + 1):
		walk(sim.giulio, x - 0.5)
		sim.giulio.facing = 1
		run(2)
		ok = ok and sim.giulio.target == Vector2i(x, Sim.ROAD)
		press(sim.giulio, "use_p")
	walk(sim.giulio, from - 2.0)
	return ok


## Walks out along the road and paints whatever is picked. Returns false if that isn't the rock.
func paint_rock_from(x: float, rock: int) -> bool:
	walk(sim.marta, x)
	sim.marta.facing = 1
	run(2)
	var ok := sim.marta.pick_rock == sim.rocks[rock]
	press(sim.marta, "use_p")
	return ok


func drive() -> void:
	walk(sim.giulio, sim.house_x + 3.0)
	press(sim.giulio, "interact_p")
	var limit := 1800
	run(2)
	while sim.house_state != Sim.PARKED and limit > 0:
		sim.tick()
		limit -= 1


## Walks along the road and jumps over whatever stops it.
func walk(k: Sim.Kid, x: float) -> void:
	var limit := 900
	while absf(k.pos.x - x) > 0.12 and limit > 0:
		k.pad.x = 1 if x > k.pos.x else -1
		var stuck := k.grounded and absf(k.vel.x) < 0.5 and limit < 880
		k.pad.jump_p = stuck
		k.pad.jump = stuck or k.vel.y < 0.0
		sim.tick()
		limit -= 1
	k.pad.clear()
	run(12)


func press(k: Sim.Kid, what: String) -> void:
	k.pad.set(what, true)
	sim.tick()
	k.pad.set(what, false)
	sim.tick()


func run(ticks: int) -> void:
	for i in ticks:
		sim.tick()
