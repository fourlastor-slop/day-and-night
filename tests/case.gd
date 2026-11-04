class_name Case
extends RefCounted
## What every stop's tests share: a fresh Sim with bots on it, checks that count failures, and the
## things random input must never do to any stop.

const MASH_TICKS := 18000

var failed := 0
var sim: Sim
var bot: Bot


func run() -> void:
	pass


func fresh(stop: Dictionary) -> void:
	sim = Sim.new(stop)
	bot = Bot.new(sim)


## Both pads pressed at random, half the runs from the start and half from wherever the house first
## stops: no kid may end up inside a block, and the house may never stand over nothing.
func mash(stop: Dictionary, seeds: int) -> void:
	for s in seeds:
		fresh(stop)
		if s % 2 == 1:
			bot.clear_road()
			bot.drive()
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var buried := 0
		var hanging := 0
		for i in MASH_TICKS:
			bot.mash(sim.marta, rng)
			bot.mash(sim.giulio, rng)
			sim.tick()
			for k: Sim.Kid in [sim.marta, sim.giulio]:
				if sim._tiles_hit(k.rect().grow(-0.05)):
					buried += 1
			if sim.house_state == Sim.PARKED and not wheels_stand():
				hanging += 1
		check(buried == 0, "mashing never leaves a kid inside a block (seed %d: %d ticks)" % [s, buried])
		check(hanging == 0, "mashing never leaves the house hanging (seed %d: %d ticks)" % [s, hanging])


func refused_at() -> Vector2:
	for i in range(sim.events.size() - 1, -1, -1):
		if sim.events[i].kind == "refuse":
			return sim.events[i].get("at", Vector2(-1, -1))
	return Vector2(-1, -1)


func wheels_stand() -> bool:
	return sim.house_stands()


func plank(x: int, y: int) -> void:
	sim.cells[y * Sim.W + x] = Sim.BLOCK
	sim._dirty = true


func dig(x: int, y: int) -> void:
	sim.cells[y * Sim.W + x] = Sim.AIR
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
		if sim.placed(x, sim.road):
			worst = maxi(worst, sim.span_at(x, sim.road))
	return worst


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("  FAIL %s: %s" % [get_script().resource_path.get_file().get_basename(), what])
