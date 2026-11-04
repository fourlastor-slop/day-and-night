class_name Bot
extends RefCounted
## Plays the stop by setting Pad fields and calling the real tick(), so what the bots manage a kid
## can manage too.

var sim: Sim


func _init(world: Sim) -> void:
	sim = world


## She walks up to the rock on the road and floats it away, if the stop has one.
func clear_road() -> void:
	if road_rock() == null:
		return
	walk(sim.marta, road_rock().pos.x - 0.6)
	press(sim.marta, "use_p")
	run(120)


## The first rock that starts out sitting on the road.
func road_rock() -> Sim.Rock:
	for r in sim.rocks:
		if is_equal_approx(r.home.y + r.size.y, Sim.ROAD):
			return r
	return null


## Lays planks along the road, one at a time. Returns false if he ever aims somewhere else.
func build_deck(from: int, to: int) -> bool:
	if sim.giulio.tool != Sim.HAMMER:
		press(sim.giulio, "next_p")
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


## Holds his aim button and steps the target onto a square. Returns false if it can't get there.
func aim(at: Vector2i) -> bool:
	var k := sim.giulio
	k.pad.alt = true
	k.pad.alt_p = true
	sim.tick()
	k.pad.alt_p = false
	for i in 12:
		var d := at - k.target
		if d == Vector2i.ZERO:
			return true
		k.pad.dir_p = Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y))
		sim.tick()
		k.pad.dir_p = Vector2i.ZERO
	return false


## Digs a way into a mound with the pick, at his feet and then at his head, one square at a time.
func tunnel(from: int, to: int) -> void:
	var k := sim.giulio
	if k.tool != Sim.PICK:
		press(k, "next_p")
	for x in range(from, to + 1):
		walk(k, x - 0.5)
		k.facing = 1
		run(2)
		press(k, "use_p")
		press(k, "use_p")
	walk(k, to + 0.5)


## Aims at a square and uses whatever tool he's holding there. Returns false if he can't aim at it.
func use_at(at: Vector2i) -> bool:
	var ok := aim(at)
	press(sim.giulio, "use_p")
	sim.giulio.pad.clear()
	return ok


func press(k: Sim.Kid, what: String) -> void:
	k.pad.set(what, true)
	sim.tick()
	k.pad.set(what, false)
	sim.tick()


## One tick of pressing everything at random, the way nobody plans for.
func mash(k: Sim.Kid, rng: RandomNumberGenerator) -> void:
	var p := k.pad
	if rng.randf() < 0.1:
		p.x = rng.randi_range(-1, 1)
		p.alt = rng.randf() < 0.15
		p.jump = rng.randf() < 0.4
	p.jump_p = rng.randf() < 0.04
	p.use_p = rng.randf() < 0.1
	p.alt_p = rng.randf() < 0.02
	p.next_p = rng.randf() < 0.01
	p.interact_p = rng.randf() < 0.01
	p.dir_p = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)) if rng.randf() < 0.1 else Vector2i.ZERO


func run(ticks: int) -> void:
	for i in ticks:
		sim.tick()
