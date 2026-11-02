class_name Sim
extends RefCounted
## One stop of the road: the tile grid, the loose rocks, the two kids and the house. Everything is
## in blocks with y pointing down. tick() is deterministic and knows nothing about drawing, so the
## tests play exactly the game the window shows.

enum { AIR, EARTH, WATER, BLOCK }
enum { PLAIN, WHITE, BLUE }
enum { HAMMER, PICK }
enum { PARKED, DRIVING, BACKING }

const W := 60
const H := 15
const ROAD := 10
const SURFACE := 12
const BANK_L := 28
const BANK_R := 42

const DT := 1.0 / 60.0
const STEP := 1.0 / 16.0

const RUN := 7.0
const ACCEL := 60.0
const FRICTION := 70.0
const GRAVITY := 46.0
const MAX_FALL := 20.0
const COYOTE := 6
const BUFFER := 7

const REACH := 3.5
const BUILD_REACH := 3
const MAX_SPAN := 3
const FREE := 99

const RISE := 2.2
const SHOVE := 5.0
const SLIDE_DRAG := 1.5
const FREEZE_R := 3
const SKY := -4.0

const HOUSE_W := 9.0
const HOUSE_H := 8.0
const WHEELS: Array[float] = [2.2, 6.8]
const HOUSE_SPEED := 3.0
const BELL := 7.6
const GOAL := 46.0


class Rock:
	var home: Vector2
	var pos: Vector2
	var size := Vector2(2, 2)
	var colour := PLAIN
	var vx := 0.0
	var vy := 0.0

	func _init(at: Vector2) -> void:
		home = at
		pos = at

	func rect() -> Rect2:
		return Rect2(pos, size)


class Kid:
	var pos: Vector2
	var vel := Vector2.ZERO
	var half := 0.4
	var height := 1.9
	var jump_v := 15.5
	var facing := 1
	var grounded := false
	var coyote := 0
	var buffer := 0
	var pad := Pad.new()
	var wake: Vector2

	var colour := WHITE
	var pick_rock: Rock = null
	var pick_block := Vector2i(-1, -1)

	var tool := HAMMER
	var aim := Vector2i.ZERO
	var target := Vector2i(-1, -1)

	func _init(at: Vector2) -> void:
		pos = at
		wake = at

	func rect() -> Rect2:
		return Rect2(pos.x - half, pos.y - height, half * 2, height)

	func centre() -> Vector2:
		return pos - Vector2(0, height / 2)


var cells := PackedByteArray()
var ice := PackedByteArray()
var span := PackedInt32Array()
var paint := {}
var rocks: Array[Rock] = []
var marta: Kid
var giulio: Kid
var house_x := 3.0
var house_safe := 3.0
var house_state := PARKED
var done := false
var t := 0
var revision := 0
var events: Array[Dictionary] = []
var _dirty := true


func _init() -> void:
	cells.resize(W * H)
	ice.resize(W * H)
	span.resize(W * H)
	for y in H:
		for x in W:
			var wet := x >= BANK_L and x < BANK_R
			if y >= SURFACE and wet:
				cells[_i(x, y)] = WATER
			elif y >= ROAD and not wet:
				cells[_i(x, y)] = EARTH
	# Sandbars that hold the two rocks a block below where a bridge would run.
	for x in [32, 33, 37, 38]:
		cells[_i(x, 14)] = EARTH
	rocks.append(Rock.new(Vector2(32, 12)))
	rocks.append(Rock.new(Vector2(37, 12)))
	# This one sits on the road, so it has to go before the house can leave.
	rocks.append(Rock.new(Vector2(23, 8)))
	marta = Kid.new(Vector2(14, ROAD))
	giulio = Kid.new(Vector2(16, ROAD))
	giulio.height = 1.6
	giulio.jump_v = 14.4


func tick() -> void:
	t += 1
	_tick_rocks()
	_freeze()
	_tick_kid(marta)
	_tick_kid(giulio)
	_pick()
	_paint()
	_aim()
	_use_tool()
	_interact(marta)
	_interact(giulio)
	_tick_house()
	if _dirty:
		_stress()


func cell(x: int, y: int) -> int:
	if x < 0 or x >= W or y >= H:
		return EARTH
	return AIR if y < 0 else cells[_i(x, y)]


func frozen(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H and ice[_i(x, y)] == 1


func solid(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == EARTH or c == BLOCK or (c == WATER and frozen(x, y))


func span_at(x: int, y: int) -> int:
	return span[_i(x, y)]


func _i(x: int, y: int) -> int:
	return y * W + x


func _tiles_hit(r: Rect2) -> bool:
	for y in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			if solid(x, y):
				return true
	return false


func _rock_hit(r: Rect2, skip: Rect2, not_this: Rock = null) -> Rock:
	for rock in rocks:
		if rock != not_this and rock.rect().intersects(r) and not rock.rect().intersects(skip):
			return rock
	return null


# ---- rocks ----------------------------------------------------------------------------------


func _tick_rocks() -> void:
	for r in rocks:
		var before := r.pos
		if r.colour == WHITE:
			if r.pos.y > SKY:
				_rock_move(r, Vector2(0, -RISE * DT))
		else:
			r.vy = minf(r.vy + GRAVITY * DT, MAX_FALL)
			if _rock_move(r, Vector2(0, r.vy * DT)):
				r.vy = 0.0
		if r.vx != 0.0:
			if _rock_move(r, Vector2(r.vx * DT, 0)):
				r.vx = 0.0
			else:
				r.vx = move_toward(r.vx, 0.0, (SLIDE_DRAG if _slides(r) else 40.0) * DT)
		if r.pos != before:
			_dirty = true
			_carry(r, before)


func _rock_move(r: Rock, d: Vector2) -> bool:
	var n := maxi(ceili(d.length() / STEP), 1)
	var s := d / n
	for i in n:
		var to := Rect2(r.pos + s, r.size)
		if _tiles_hit(to) or _rock_hit(to, Rect2(), r) != null:
			return true
		r.pos += s
	return false


## A kid standing on a rock rides it.
func _carry(r: Rock, before: Vector2) -> void:
	for k: Kid in [marta, giulio]:
		var box := k.rect()
		if absf(k.pos.y - before.y) < 0.08 and box.end.x > before.x and box.position.x < before.x + r.size.x:
			k.pos += r.pos - before


func _slides(r: Rock) -> bool:
	if r.colour == BLUE:
		return true
	var y := ceili(r.rect().end.y)
	for x in range(floori(r.pos.x), ceili(r.rect().end.x)):
		if frozen(x, y):
			return true
	return false


## Cold spreads from anything painted blue to the top of the water near it.
func _freeze() -> void:
	var next := PackedByteArray()
	next.resize(W * H)
	for r in rocks:
		if r.colour == BLUE:
			var c := r.rect().get_center()
			for x in range(int(c.x) - FREEZE_R, int(c.x) + FREEZE_R + 1):
				if cell(x, SURFACE) == WATER:
					next[_i(x, SURFACE)] = 1
	for key: int in paint:
		if paint[key] == BLUE:
			var x0 := key % W
			for x in range(x0 - FREEZE_R, x0 + FREEZE_R + 1):
				if cell(x, SURFACE) == WATER:
					next[_i(x, SURFACE)] = 1
	if next != ice:
		ice = next
		_dirty = true


# ---- kids -----------------------------------------------------------------------------------


func _tick_kid(k: Kid) -> void:
	var p := k.pad
	var aiming := k == giulio and p.alt
	var want := 0 if aiming else p.x
	k.vel.x = move_toward(k.vel.x, want * RUN, (ACCEL if want != 0 else FRICTION) * DT)
	if want != 0:
		k.facing = want
	k.vel.y = minf(k.vel.y + GRAVITY * DT, MAX_FALL)
	if k.vel.y < 0.0 and not p.jump:
		k.vel.y += GRAVITY * DT
	k.coyote = COYOTE if k.grounded else maxi(k.coyote - 1, 0)
	k.buffer = BUFFER if p.jump_p and not aiming else maxi(k.buffer - 1, 0)
	if k.buffer > 0 and k.coyote > 0:
		k.vel.y = -k.jump_v
		k.buffer = 0
		k.coyote = 0
	_kid_x(k, k.vel.x * DT)
	k.grounded = false
	_kid_y(k, k.vel.y * DT)
	if k.pos.y > H or cell(floori(k.pos.x), floori(k.pos.y - 0.2)) == WATER and not frozen(floori(k.pos.x), floori(k.pos.y - 0.2)):
		_wake(k)


func _kid_x(k: Kid, d: float) -> void:
	var n := maxi(ceili(absf(d) / STEP), 1)
	for i in n:
		var to := k.rect()
		to.position.x += d / n
		var rock := _rock_hit(to, k.rect())
		if _tiles_hit(to) or rock != null:
			if rock != null and _slides(rock):
				rock.vx = signf(d) * SHOVE
			k.vel.x = 0.0
			return
		k.pos.x += d / n


func _kid_y(k: Kid, d: float) -> void:
	var n := maxi(ceili(absf(d) / STEP), 1)
	for i in n:
		var to := k.rect()
		to.position.y += d / n
		if _tiles_hit(to) or _rock_hit(to, k.rect()) != null:
			k.grounded = d > 0.0
			k.vel.y = 0.0
			return
		k.pos.y += d / n


## Falling costs time, never progress: you wake up at the house.
func _wake(k: Kid) -> void:
	k.pos = Vector2(house_x + k.wake.x - 3.0, ROAD)
	k.vel = Vector2.ZERO
	events.append({"kind": "wake", "kid": k})


# ---- marta ----------------------------------------------------------------------------------


## The nearest thing she can reach, in the direction she's facing. Rocks win over blocks, so standing
## on a bridge doesn't hide the rock under it.
func _pick() -> void:
	var k := marta
	var c := k.centre()
	k.pick_rock = null
	k.pick_block = Vector2i(-1, -1)
	var best := REACH
	for r in rocks:
		var near := Vector2(clampf(c.x, r.pos.x, r.pos.x + r.size.x), clampf(c.y, r.pos.y, r.pos.y + r.size.y))
		var d := near.distance_to(c)
		if d <= best and (near.x - c.x) * k.facing >= -0.5:
			best = d
			k.pick_rock = r
	if k.pick_rock != null:
		return
	best = REACH
	for y in range(floori(c.y - REACH), ceili(c.y + REACH) + 1):
		for x in range(floori(c.x - REACH), ceili(c.x + REACH) + 1):
			if cell(x, y) != BLOCK:
				continue
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c)
			if d <= best and (x + 0.5 - c.x) * k.facing >= -0.5:
				best = d
				k.pick_block = Vector2i(x, y)


func _paint() -> void:
	var k := marta
	if k.pad.next_p:
		k.colour = BLUE if k.colour == WHITE else WHITE
	var colour := -1
	if k.pad.use_p:
		colour = k.colour
	elif k.pad.alt_p:
		colour = PLAIN
	if colour < 0:
		return
	if k.pick_rock != null:
		k.pick_rock.colour = colour
		k.pick_rock.vy = 0.0
		events.append({"kind": "paint", "at": k.pick_rock.rect().get_center()})
	elif k.pick_block.x >= 0:
		if colour == PLAIN:
			paint.erase(_i(k.pick_block.x, k.pick_block.y))
		else:
			paint[_i(k.pick_block.x, k.pick_block.y)] = colour
		events.append({"kind": "paint", "at": Vector2(k.pick_block) + Vector2(0.5, 0.5)})
	_dirty = true


# ---- giulio ---------------------------------------------------------------------------------


## The square he'd act on. Next to him by default, and movable while he holds the aim button.
func _aim() -> void:
	var k := giulio
	var here := Vector2i(floori(k.pos.x), floori(k.pos.y - 0.01))
	if k.pad.alt:
		if k.pad.alt_p:
			k.aim = _default_target(k, here) - here
		k.aim += k.pad.dir_p
		k.aim = k.aim.clamp(Vector2i(-BUILD_REACH, -BUILD_REACH), Vector2i(BUILD_REACH, BUILD_REACH))
		k.target = here + k.aim
	else:
		k.target = _default_target(k, here)


func _default_target(k: Kid, here: Vector2i) -> Vector2i:
	var front := here + Vector2i(k.facing, 0)
	var low := front + Vector2i(0, 1)
	if k.tool == PICK:
		return front if cell(front.x, front.y) == EARTH else here + Vector2i(0, 1)
	var empty := cell(low.x, low.y) == AIR or (cell(low.x, low.y) == WATER and not frozen(low.x, low.y))
	return low if empty else front


func _use_tool() -> void:
	var k := giulio
	if k.pad.next_p:
		k.tool = PICK if k.tool == HAMMER else HAMMER
	if not k.pad.use_p:
		return
	var c := k.target
	var what := cell(c.x, c.y)
	if k.tool == PICK:
		if what == EARTH and c.y < H:
			cells[_i(c.x, c.y)] = AIR
			_dirty = true
		return
	if what == BLOCK:
		cells[_i(c.x, c.y)] = AIR
		paint.erase(_i(c.x, c.y))
		_dirty = true
	elif what == WATER and not frozen(c.x, c.y):
		events.append({"kind": "swept", "cell": c})
	elif what == AIR and _touches(c) and not _occupied(c):
		cells[_i(c.x, c.y)] = BLOCK
		_dirty = true


func _touches(c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if solid(c.x + d.x, c.y + d.y):
			return true
	var box := Rect2(c.x - 0.1, c.y - 0.1, 1.2, 1.2)
	return _rock_hit(box, Rect2()) != null


func _occupied(c: Vector2i) -> bool:
	var box := Rect2(c, Vector2.ONE)
	return marta.rect().intersects(box) or giulio.rect().intersects(box) or _rock_hit(box, Rect2()) != null


## How far each placed block is from what holds it. A block over the ground or over a rock is held,
## one against a bank counts from there, and the count grows along a run of blocks.
func _stress() -> void:
	_dirty = false
	revision += 1
	span.fill(FREE)
	for y in H:
		for x in W:
			if cells[_i(x, y)] != BLOCK:
				continue
			if _held(x, y):
				span[_i(x, y)] = 0
			elif cell(x - 1, y) == EARTH or cell(x + 1, y) == EARTH:
				span[_i(x, y)] = 1
	var changed := true
	while changed:
		changed = false
		for y in range(H - 1, -1, -1):
			for x in W:
				if cells[_i(x, y)] != BLOCK:
					continue
				var best := span[_i(x, y)]
				for side in [-1, 1]:
					if cell(x + side, y) == BLOCK:
						best = mini(best, span[_i(x + side, y)] + 1)
				if cell(x, y + 1) == BLOCK:
					best = mini(best, span[_i(x, y + 1)])
				if best < span[_i(x, y)]:
					span[_i(x, y)] = best
					changed = true


func _held(x: int, y: int) -> bool:
	var below := y + 1
	while cell(x, below) == BLOCK:
		below += 1
	if cell(x, below) == EARTH:
		return true
	for r in rocks:
		if absf(r.pos.y - below) < 0.06 and r.pos.x < x + 1 and r.pos.x + r.size.x > x:
			return true
	return false


# ---- the house ------------------------------------------------------------------------------


func _interact(k: Kid) -> void:
	if not k.pad.interact_p or done:
		return
	if near_bell(k):
		_ring()
	elif near_house(k) and house_state == PARKED:
		house_state = DRIVING


func near_house(k: Kid) -> bool:
	return k.pos.x > house_x - 0.5 and k.pos.x < house_x + HOUSE_W + 0.5


func near_bell(k: Kid) -> bool:
	return absf(k.pos.x - (house_x + BELL)) < 1.2


## The bell puts every loose rock back, so nothing can be lost for good.
func _ring() -> void:
	for r in rocks:
		r.pos = r.home
		r.colour = PLAIN
		r.vx = 0.0
		r.vy = 0.0
	_dirty = true
	events.append({"kind": "bell"})


func _tick_house() -> void:
	if house_state == BACKING:
		house_x = move_toward(house_x, house_safe, HOUSE_SPEED * 1.6 * DT)
		if house_x <= house_safe:
			house_state = PARKED
	elif house_state == DRIVING:
		var next := house_x + HOUSE_SPEED * DT
		var body := Rect2(next + 0.1, ROAD - HOUSE_H, HOUSE_W - 0.2, HOUSE_H - 0.1)
		if _tiles_hit(body) or _rock_hit(body, Rect2()) != null:
			_refuse()
			return
		var ground := true
		for w in WHEELS:
			var x := floori(next + w + 0.6)
			var c := cell(x, ROAD)
			if c == BLOCK and span_at(x, ROAD) >= MAX_SPAN:
				_collapse(Vector2i(x, ROAD))
				house_state = BACKING
				return
			if c != BLOCK and c != EARTH:
				_refuse()
				return
			ground = ground and c == EARTH
		house_x = next
		if ground:
			house_safe = next
		if house_x >= GOAL:
			house_state = PARKED
			done = true


func _refuse() -> void:
	house_state = PARKED
	events.append({"kind": "refuse"})


## Too much load: every overstretched block joined to this one goes at once.
func _collapse(start: Vector2i) -> void:
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if cell(c.x, c.y) != BLOCK or span_at(c.x, c.y) < MAX_SPAN:
			continue
		cells[_i(c.x, c.y)] = AIR
		paint.erase(_i(c.x, c.y))
		events.append({"kind": "fell", "cell": c})
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(c + d)
	_dirty = true
