class_name Sim
extends RefCounted
## One stop of the road: the tile grid, the loose rocks, the two kids and the house. Everything is
## in blocks with y pointing down. tick() is deterministic and knows nothing about drawing, so the
## tests play exactly the game the window shows.

enum { AIR, EARTH, WATER, BLOCK, ROCK, STONE, WHEEL }
enum { PLAIN, WHITE, BLUE, YELLOW }
## The chisel lays stone where the hammer lays wood.
enum { HAMMER, PICK, ROPE, CHISEL, WHEEL_TOOL }
enum { PARKED, DRIVING, BACKING }

const W := 60
const H := 15
const ROAD := 10
const TERRAIN := {".": AIR, "#": EARTH, "%": ROCK, "~": WATER, "=": BLOCK}
## The tools a stop can offer him, by the names stops.gd uses.
const TOOLS := {"hammer": HAMMER, "pick": PICK, "rope": ROPE, "stone": CHISEL, "wheel": WHEEL_TOOL}
## The colours a stop can give her, by the names stops.gd uses.
const COLOURS := {"white": WHITE, "blue": BLUE, "yellow": YELLOW}

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
const STONE_SPAN := 5
const FREE := 99

const RISE := 2.2
const SHOVE := 5.0
const SLIDE_DRAG := 1.5
const FREEZE_R := 3
const SKY := -4.0

const HOUSE_W := 9.0
const HOUSE_H := 8.0
const WHEELS: Array[float] = [2.2, 6.8]
const TREAD := 0.6
const HOUSE_SPEED := 3.0
const BELL := 1.1
const HOUSE_LOAD := 4
const MAX_ROPE := 8.0
const CART_SPEED := 3.0
const SOOT_SPEED := 2.4
## How far a sootling sees him, how much light it won't go into, and how close counts as touching.
const SOOT_SEE := 8.0
const SOOT_LIT := 0.3
const SOOT_REACH := 0.7
const LIGHT_R := 4.0
const CLOAK_R := 3.0
## How far daylight reaches into a cave from its mouth.
const MOUTH_R := 3.0
## Once its wheels are above this row, the house has risen out of view and the stop is done.
const LIFTED := -1.0


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


## A shy shadow that lives in a cave's dark and drifts towards Giulio there.
class Soot:
	var home: Vector2
	var pos: Vector2

	func _init(at: Vector2) -> void:
		home = at
		pos = at


## A rope tied between two things, or hanging loose from a hook. An end on a block moves with it.
class Rope:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var a_block := false
	var b_block := false
	var hook := false
	var rest := Vector2.ZERO
	var tied := false


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
	var wake := 4.0

	var colour := WHITE
	var pick_rock: Rock = null
	var pick_block := Vector2i(-1, -1)

	var tool := HAMMER
	var rope: Rope = null
	var aim := Vector2i.ZERO
	var target := Vector2i(-1, -1)

	func _init(at: Vector2) -> void:
		pos = at

	func rect() -> Rect2:
		return Rect2(pos.x - half, pos.y - height, half * 2, height)

	func centre() -> Vector2:
		return pos - Vector2(0, height / 2)


## A group of blocks that came loose from the grid to rise as one.
class Body:
	var cells: Array[Vector2i] = []
	var paint := {}
	var pos := Vector2.ZERO
	var size := Vector2.ZERO
	var house := false
	## The ends of ropes tied to its blocks: the rope, which end, and where it is on the body.
	var ends: Array = []
	## What each of its squares is: wood, stone or a wheel.
	var kinds := {}
	## Which way each of its yellow blocks was painted facing.
	var dirs := {}
	## A cart drives the way its engine faces and falls when nothing holds it up. Anything else lifts.
	var cart := false
	var dir := 1
	var vy := 0.0

	func rect(c: Vector2i) -> Rect2:
		return Rect2(pos + Vector2(c), Vector2.ONE)

	func bounds() -> Rect2:
		return Rect2(pos, size)


var name := ""
var cells := PackedByteArray()
var ice := PackedByteArray()
var span := PackedInt32Array()
var surface := PackedInt32Array()
var paint := {}
var rocks: Array[Rock] = []
var bodies: Array[Body] = []
var ropes: Array[Rope] = []
var soots: Array[Soot] = []
var tools: Array = [HAMMER, PICK]
var colours: Array = [WHITE, BLUE]
## Her cloak's colour. Yellow lights her own way.
var cloak := PLAIN
## Which way Marta faced as she painted each block, which is the way a yellow engine drives.
var paint_dir := {}
## Whether this stop has caves, which are dark.
var dark := false
## How lit each square is, from 0 to 1, by daylight and yellow things. Marta also has her cloak's own
## glow, which cloak_light() adds.
var light := PackedFloat32Array()
var _light_key := 0
## For each column that passes through a cave, the row of its roof.
var _cave_cols := {}
## Pictures that belong to the stop but play no part in it, like the pulley's crane.
var decor: Array = []
## How close each block in a white group is to lifting it, from 0 to 1, for groups that can't yet.
var strain := {}
var marta: Kid
var giulio: Kid
var house_x := 3.0
## The row the road runs along at this stop, where the house's wheels and the kids' feet start.
var road := ROAD
var house_y := float(ROAD)
var house_safe := 3.0
var house_state := PARKED
var goal := 46.0
var done := false
var t := 0
var revision := 0
var events: Array[Dictionary] = []
var _dirty := true


## Builds a stop from one of the maps in Stops.
func _init(stop: Dictionary) -> void:
	name = stop.name
	cells.resize(W * H)
	ice.resize(W * H)
	span.resize(W * H)
	surface.resize(W)
	road = stop.get("road", ROAD)
	var map: Array = stop.map
	assert(map.size() == H, "%s needs %d rows" % [name, H])
	var tops := {}
	for y in H:
		var row: String = map[y]
		assert(row.length() == W, "%s row %d needs %d squares" % [name, y, W])
		for x in W:
			var c := row[x]
			if c == "|":
				cells[_i(x, y)] = AIR
				_hang(x)
			elif c == "@":
				cells[_i(x, y)] = AIR
				soots.append(Soot.new(Vector2(x + 0.5, y + 0.5)))
			elif TERRAIN.has(c):
				cells[_i(x, y)] = TERRAIN[c]
			else:
				cells[_i(x, y)] = WATER if _wet(row, x) else AIR
				if c == c.to_upper():
					tops[c] = Vector2(x, y)
	var letters := tops.keys()
	letters.sort()
	for c: String in letters:
		var r := Rock.new(tops[c])
		# A rock is as big as its letters: A with a to its right and below, 2 squares or a boulder's 3.
		var at: Vector2i = Vector2i(tops[c])
		var w := 1
		while at.x + w < W and map[at.y][at.x + w] == c.to_lower():
			w += 1
		var h := 1
		while at.y + h < H and map[at.y + h][at.x] == c.to_lower():
			h += 1
		r.size = Vector2(w, h)
		rocks.append(r)
	for x in W:
		surface[x] = -1
		for y in H:
			if cells[_i(x, y)] == WATER:
				surface[x] = y
				break
	decor = stop.get("decor", [])
	tools.clear()
	for t: String in stop.get("tools", ["hammer", "pick"]):
		tools.append(TOOLS[t])
	colours.clear()
	for c: String in stop.get("colours", ["white", "blue"]):
		colours.append(COLOURS[c])
	cloak = COLOURS.get(stop.get("cloak", ""), PLAIN)
	dark = stop.get("dark", false)
	light.resize(W * H)
	house_y = road
	house_x = stop.house
	house_safe = house_x
	goal = stop.goal
	marta = Kid.new(Vector2(stop.marta, road))
	giulio = Kid.new(Vector2(stop.giulio, road))
	giulio.height = 1.6
	giulio.jump_v = 14.4
	giulio.wake = 5.0


## A rope that hangs from a pulley above the top of the view, its free end loose at the road.
func _hang(x: int) -> void:
	var r := Rope.new()
	r.hook = true
	r.a = Vector2(x + 0.5, -1.0)
	r.rest = Vector2(x + 0.5, road - 0.5)
	r.b = r.rest
	ropes.append(r)


## A rock's own squares are water if the water carries on beside it, and air otherwise.
func _wet(row: String, x: int) -> bool:
	for step in [-1, 1]:
		var at: int = x + step
		while at >= 0 and at < W and not TERRAIN.has(row[at]):
			at += step
		if at >= 0 and at < W and row[at] == "~":
			return true
	return false


func tick() -> void:
	t += 1
	_tick_rocks()
	_tick_bodies()
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
		_lift()
		_stress()
	_tick_soots()
	_light()


func cell(x: int, y: int) -> int:
	if x < 0 or x >= W or y >= H:
		return EARTH
	return AIR if y < 0 else cells[_i(x, y)]


func frozen(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H and ice[_i(x, y)] == 1


func solid(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == EARTH or c == ROCK or c == BLOCK or c == STONE or c == WHEEL or (c == WATER and frozen(x, y))


## Something he placed: a wood or stone block, or a wheel.
func placed(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == BLOCK or c == STONE or c == WHEEL


## How far a run of this block can reach from a support before it breaks under the house.
func span_limit(x: int, y: int) -> int:
	return STONE_SPAN if cell(x, y) == STONE else MAX_SPAN


## Earth or rock: the ground itself, which holds up whatever stands on it.
func ground(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c == EARTH or c == ROCK


func span_at(x: int, y: int) -> int:
	return span[_i(x, y)]


func _i(x: int, y: int) -> int:
	return y * W + x


## Whether a rectangle overlaps anything solid: the grid, or a group of blocks on the move.
func _tiles_hit(r: Rect2, skip: Body = null) -> bool:
	for y in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			if solid(x, y):
				return true
	return _body_hit(r, skip) != null


func _body_hit(r: Rect2, skip: Body = null) -> Body:
	for b in bodies:
		if b != skip and b.bounds().intersects(r):
			for c in b.cells:
				if b.rect(c).intersects(r):
					return b
	return null


## The middle of the first solid square in a rectangle that has one.
func _first_tile(r: Rect2) -> Vector2:
	for y in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			if solid(x, y):
				return Vector2(x + 0.5, y + 0.5)
	return r.get_center()


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
			if r.pos.y > SKY and not _pinned(r):
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
			# A moving rock only matters to his blocks if it's up against one.
			if _near_blocks(r):
				_dirty = true
			_carry(r, before)


func _near_blocks(r: Rock) -> bool:
	var box := r.rect().grow(1.0)
	for y in range(floori(box.position.y), ceili(box.end.y)):
		for x in range(floori(box.position.x), ceili(box.end.x)):
			if placed(x, y):
				return true
	return false


func _rock_move(r: Rock, d: Vector2) -> bool:
	var n := maxi(ceili(d.length() / STEP), 1)
	var s := d / n
	for i in n:
		var to := Rect2(r.pos + s, r.size)
		if _tiles_hit(to) or _rock_hit(to, Rect2(), r) != null:
			return true
		r.pos += s
	return false


## A kid standing on a rock rides it, as long as there's room for them.
func _carry(r: Rock, before: Vector2) -> void:
	for k: Kid in [marta, giulio]:
		if _riding(k, r, before) and _room(k, r.pos - before):
			k.pos += r.pos - before


func _riding(k: Kid, r: Rock, at: Vector2) -> bool:
	var box := k.rect()
	return absf(k.pos.y - at.y) < 0.08 and box.end.x > at.x and box.position.x < at.x + r.size.x


func _room(k: Kid, d: Vector2) -> bool:
	return not _tiles_hit(Rect2(k.rect().position + d, k.rect().size))


## A rock waits under a kid it can't lift any further, so nobody gets pressed into the blocks.
func _pinned(r: Rock) -> bool:
	for k: Kid in [marta, giulio]:
		if _riding(k, r, r.pos) and not _room(k, Vector2(0, -RISE * DT)):
			return true
	return false


## Whether a shove sends this rock sliding. A boulder is too heavy to shove, even on blue.
func _slides(r: Rock) -> bool:
	if r.size.x > 2:
		return false
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
			_chill(next, int(r.rect().get_center().x))
	for key: int in paint:
		if paint[key] == BLUE:
			_chill(next, key % W)
	if next != ice:
		ice = next
		_dirty = true


func _chill(next: PackedByteArray, x0: int) -> void:
	for x in range(maxi(x0 - FREEZE_R, 0), mini(x0 + FREEZE_R + 1, W)):
		var y := surface[x]
		if y >= 0 and cell(x, y) == WATER:
			next[_i(x, y)] = 1


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
	var feet := Vector2i(floori(k.pos.x), floori(k.pos.y - 0.2))
	var wet := cell(feet.x, feet.y) == WATER and not frozen(feet.x, feet.y)
	if k.pos.y > H or wet or _tiles_hit(k.rect().grow(-0.05)):
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


## Falling or getting caught costs time, never progress: you wake up where the house last stood on
## solid ground, which is never over water, and on top of anything built there.
func _wake(k: Kid) -> void:
	k.pos = Vector2(house_safe + k.wake, road)
	while _tiles_hit(k.rect()):
		k.pos.y -= 1.0
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
			if not placed(x, y):
				continue
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c)
			if d <= best and (x + 0.5 - c.x) * k.facing >= -0.5:
				best = d
				k.pick_block = Vector2i(x, y)


func _paint() -> void:
	var k := marta
	if k.pad.next_p:
		k.colour = colours[(colours.find(k.colour) + 1) % colours.size()]
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
		var i := _i(k.pick_block.x, k.pick_block.y)
		if colour == PLAIN:
			paint.erase(i)
			paint_dir.erase(i)
		else:
			paint[i] = colour
			paint_dir[i] = k.facing
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
		for c: Vector2i in [front, front + Vector2i.UP]:
			if cell(c.x, c.y) == EARTH:
				return c
		return here + Vector2i(0, 1)
	var empty := cell(low.x, low.y) == AIR or (cell(low.x, low.y) == WATER and not frozen(low.x, low.y))
	return low if empty else front


func _use_tool() -> void:
	var k := giulio
	if k.pad.next_p:
		k.rope = null
		k.tool = tools[(tools.find(k.tool) + 1) % tools.size()]
	if not k.pad.use_p or not can_use():
		return
	var c := k.target
	var what := cell(c.x, c.y)
	if k.tool == ROPE:
		_rope_at(c)
	elif what == AIR:
		cells[_i(c.x, c.y)] = STONE if k.tool == CHISEL else WHEEL if k.tool == WHEEL_TOOL else BLOCK
		_dirty = true
	elif what == WATER and k.tool == CHISEL:
		_sink(c)
	elif what == WATER:
		events.append({"kind": "swept", "cell": c})
	else:
		# Any building tool takes out what it's aimed at: wood, stone or a wheel.
		cells[_i(c.x, c.y)] = AIR
		paint.erase(_i(c.x, c.y))
		paint_dir.erase(_i(c.x, c.y))
		_dirty = true


## Whether his tool would do anything at the square he's aiming at.
func can_use() -> bool:
	var c := giulio.target
	if c.x < 0 or c.x >= W or c.y < 0 or c.y >= H or bearing(c):
		return false
	var what := cell(c.x, c.y)
	if giulio.tool == PICK:
		return what == EARTH
	if giulio.tool == ROPE:
		if giulio.rope != null:
			return _ties_to(giulio.rope, c)
		return _hanging_at(c) != null or _rope_end_at(c) != null or placed(c.x, c.y) or ground(c.x, c.y)
	if what == AIR:
		return _touches(c) and not _occupied(c)
	return placed(c.x, c.y) or (what == WATER and not frozen(c.x, c.y))


## Stone dropped into water sinks until something stops it, and stays there.
func _sink(c: Vector2i) -> void:
	var y := c.y
	while cell(c.x, y + 1) == WATER and not frozen(c.x, y + 1):
		y += 1
	cells[_i(c.x, y)] = STONE
	_dirty = true


func _touches(c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if solid(c.x + d.x, c.y + d.y):
			return true
	var box := Rect2(c.x - 0.1, c.y - 0.1, 1.2, 1.2)
	return _rock_hit(box, Rect2()) != null


func _occupied(c: Vector2i) -> bool:
	var box := Rect2(c, Vector2.ONE)
	return marta.rect().intersects(box) or giulio.rect().intersects(box) or _rock_hit(box, Rect2()) != null \
			or _body_hit(box) != null


## How far each placed block is from what holds it. A block over the ground or over a rock is held,
## one against a bank counts from there, and the count grows along a run of blocks.
func _stress() -> void:
	_dirty = false
	revision += 1
	span.fill(FREE)
	# Only the placed blocks, from the bottom up, so the count settles in a few passes.
	var blocks: Array[Vector2i] = []
	for y in range(H - 1, -1, -1):
		for x in W:
			var c := cells[_i(x, y)]
			if c == BLOCK or c == STONE or c == WHEEL:
				blocks.append(Vector2i(x, y))
	for b in blocks:
		if _held(b.x, b.y):
			span[_i(b.x, b.y)] = 0
		elif ground(b.x - 1, b.y) or ground(b.x + 1, b.y):
			span[_i(b.x, b.y)] = 1
	var changed := true
	while changed:
		changed = false
		for b in blocks:
			var i := _i(b.x, b.y)
			var best := span[i]
			if placed(b.x - 1, b.y):
				best = mini(best, span[i - 1] + 1)
			if placed(b.x + 1, b.y):
				best = mini(best, span[i + 1] + 1)
			if placed(b.x, b.y + 1):
				best = mini(best, span[_i(b.x, b.y + 1)])
			if best < span[i]:
				span[i] = best
				changed = true


func _held(x: int, y: int) -> bool:
	for r in ropes:
		if _hangs(r, Vector2i(x, y)):
			return true
	var below := y + 1
	while placed(x, below):
		below += 1
	if ground(x, below):
		return true
	for r in rocks:
		if absf(r.pos.y - below) < 0.06 and r.pos.x < x + 1 and r.pos.x + r.size.x > x:
			return true
	return false


# ---- rope -----------------------------------------------------------------------------------


## The rope tool: picks up a hanging rope or starts a new one, ties the one in hand, or unties one.
func _rope_at(c: Vector2i) -> void:
	var k := giulio
	if k.rope != null:
		_finish(k.rope, c)
		k.rope = null
		return
	var loose := _hanging_at(c)
	if loose != null:
		k.rope = loose
		return
	var tied := _rope_end_at(c)
	if tied != null:
		untie(tied)
		return
	k.rope = Rope.new()
	k.rope.a = _centre(c)
	k.rope.a_block = placed(c.x, c.y)


## Ties a rope between two squares, each a block or the ground. Returns false if it can't go there.
func tie(from: Vector2i, to: Vector2i) -> bool:
	var r := Rope.new()
	r.a = _centre(from)
	r.a_block = placed(from.x, from.y)
	if (not r.a_block and not ground(from.x, from.y)) or not _ties_to(r, to):
		return false
	_finish(r, to)
	return true


func untie(r: Rope) -> void:
	if r.hook:
		r.tied = false
		r.b = r.rest
		r.b_block = false
	else:
		ropes.erase(r)
	_dirty = true


## Whether a rope's free end can be tied here: a block or the ground, in reach of the other end, with
## a block at one end at least.
func _ties_to(r: Rope, c: Vector2i) -> bool:
	var block := placed(c.x, c.y)
	if not block and not ground(c.x, c.y):
		return false
	if not (block or r.a_block) or Vector2i(r.a.floor()) == c:
		return false
	return r.hook or r.a.distance_to(_centre(c)) <= MAX_ROPE


func _finish(r: Rope, c: Vector2i) -> void:
	r.b = _centre(c)
	r.b_block = placed(c.x, c.y)
	r.tied = true
	if r not in ropes:
		ropes.append(r)
	_dirty = true


func _hanging_at(c: Vector2i) -> Rope:
	for r in ropes:
		if r.hook and not r.tied and Vector2i(r.rest.floor()) == c:
			return r
	return null


func _rope_end_at(c: Vector2i) -> Rope:
	for r in ropes:
		if r.tied and (Vector2i(r.b.floor()) == c or (not r.hook and Vector2i(r.a.floor()) == c)):
			return r
	return null


## A block hangs from a rope whose other end is fixed above it, so it counts as held up.
func _hangs(r: Rope, c: Vector2i) -> bool:
	if not r.tied:
		return false
	if r.b_block and Vector2i(r.b.floor()) == c and not r.a_block:
		return r.a.y < r.b.y - 0.5
	if r.a_block and Vector2i(r.a.floor()) == c and not r.b_block:
		return r.b.y < r.a.y - 0.5
	return false


## A group tied to fixed ground that isn't above it can't lift.
func _tethered(group: Array) -> bool:
	for r in ropes:
		if not r.tied or r.a_block == r.b_block:
			continue
		var block := r.a if r.a_block else r.b
		var fixed := r.b if r.a_block else r.a
		if Vector2i(block.floor()) in group and fixed.y >= block.y - 0.5:
			return true
	return false


func _centre(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


# ---- the house ------------------------------------------------------------------------------


func _interact(k: Kid) -> void:
	if not k.pad.interact_p or done:
		return
	if near_bell(k):
		_ring()
	elif near_house(k) and house_state == PARKED and not riding():
		house_state = DRIVING


func near_house(k: Kid) -> bool:
	return k.pos.x > house_x - 0.5 and k.pos.x < house_x + HOUSE_W + 0.5


func near_bell(k: Kid) -> bool:
	return absf(k.pos.x - (house_x + BELL)) < 1.2


## What the wheels rest on, here and where the house would roll back to. It stays put, because a house
## with nothing under it has no way back up.
func bearing(c: Vector2i) -> bool:
	for spot: Vector2 in [Vector2(house_x, house_y), Vector2(house_safe, road)]:
		if c.y != roundi(spot.y):
			continue
		for w in WHEELS:
			if c.x < spot.x + w + TREAD and c.x + 1 > spot.x + w - TREAD:
				return true
	return false


## Whether the house has something under both wheels: the ground, blocks, or a lift it's riding.
func house_stands() -> bool:
	if riding():
		return true
	var row := roundi(house_y)
	for w in WHEELS:
		var x := floori(house_x + w)
		if not placed(x, row) and not ground(x, row):
			return false
	return true


## Whether the house is riding a group of blocks that's on the move.
func riding() -> bool:
	for b in bodies:
		if b.house:
			return true
	return false


## Inset a little on every side, so a rock floated up against a roof just over it doesn't count as touching.
func _house_body(x: float) -> Rect2:
	return Rect2(x + 0.1, house_y - HOUSE_H + 0.1, HOUSE_W - 0.2, HOUSE_H - 0.2)


## The bell puts loose rocks back, so nothing can be lost for good. One holding up a plank is doing
## its job and stays, and so does one whose place the house has reached.
func _ring() -> void:
	for r in rocks:
		# Measured from the front of its body, so a rock the house is only waiting at, touching its
		# front, isn't reached.
		if _holding(r) or r.home.x < house_x + HOUSE_W - 0.15:
			continue
		r.pos = r.home
		r.colour = PLAIN
		r.vx = 0.0
		r.vy = 0.0
	_dirty = true
	events.append({"kind": "bell"})


func _holding(r: Rock) -> bool:
	for x in range(floori(r.pos.x), ceili(r.rect().end.x)):
		if placed(x, roundi(r.pos.y) - 1):
			return true
	return false


func _tick_house() -> void:
	if house_state == BACKING:
		house_x = move_toward(house_x, house_safe, HOUSE_SPEED * 1.6 * DT)
		if house_x <= house_safe:
			house_state = PARKED
	elif house_state == DRIVING:
		var next := house_x + HOUSE_SPEED * DT
		var row := roundi(house_y)
		var body := _house_body(next)
		var rock := _rock_hit(body, Rect2())
		if rock != null:
			_refuse(rock.rect().get_center())
			return
		if _tiles_hit(body):
			_refuse(_first_tile(body))
			return
		var on_ground := true
		for w in WHEELS:
			var x := floori(next + w + TREAD)
			var c := cell(x, row)
			if placed(x, row) and span_at(x, row) >= span_limit(x, row):
				_collapse(Vector2i(x, row))
				house_state = BACKING
				return
			if not placed(x, row) and not ground(x, row):
				_refuse(Vector2(x + 0.5, row + 0.5))
				return
			on_ground = on_ground and not placed(x, row)
		house_x = next
		if on_ground:
			house_safe = next
		if house_x >= goal:
			house_state = PARKED
			done = true


func _refuse(at: Vector2) -> void:
	house_state = PARKED
	events.append({"kind": "refuse", "at": at})
	# Where it waits now, its weight may be on a white group.
	_dirty = true


## Too much load: every overstretched block joined to this one goes at once.
func _collapse(start: Vector2i) -> void:
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if not placed(c.x, c.y) or span_at(c.x, c.y) < span_limit(c.x, c.y):
			continue
		cells[_i(c.x, c.y)] = AIR
		paint.erase(_i(c.x, c.y))
		events.append({"kind": "fell", "cell": c})
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(c + d)
	_dirty = true


# ---- lifts ----------------------------------------------------------------------------------


## A group of blocks comes loose and rises once at least half of it is white, counting the house as
## extra weight when it stands on the group. Too little white only makes the group strain.
func _lift() -> void:
	strain.clear()
	for group in _groups():
		var white := 0
		var heavy := 0
		for c: Vector2i in group:
			# Stone weighs double: a white stone still weighs one more block than it lifts.
			var weight := 2 if cell(c.x, c.y) == STONE else 1
			if paint.get(_i(c.x, c.y), PLAIN) == WHITE:
				white += 1
				weight -= 1
			heavy += weight
		var wheels := _wheels_on(group)
		heavy += HOUSE_LOAD if wheels > 0 else 0
		# With only one wheel on the group, the house's other wheel on the ground holds it down.
		if white > 0 and white >= heavy and wheels != 1 and not _tethered(group):
			_loosen(group, wheels == 2)
			continue
		if white > 0 and white < heavy:
			for c: Vector2i in group:
				strain[_i(c.x, c.y)] = float(white) / heavy
		var drive := _engine(group)
		if drive != 0 and wheels == 0 and not _tethered(group):
			_loosen(group, false, drive)


## Which way a group drives: a group with a wheel is a cart, and a yellow block in it is its engine,
## facing the way Marta did as she painted it. Returns 0 for a group that doesn't drive.
func _engine(group: Array) -> int:
	var wheel := false
	var engines := 0
	var facing := 0
	for c: Vector2i in group:
		wheel = wheel or cell(c.x, c.y) == WHEEL
		if paint.get(_i(c.x, c.y), PLAIN) == YELLOW:
			engines += 1
			facing += paint_dir.get(_i(c.x, c.y), 1)
	if not wheel or engines == 0:
		return 0
	return 1 if facing >= 0 else -1


## Blocks joined side to side, or tied together with rope, make one group.
func _groups() -> Array[Array]:
	var links := {}
	for r in ropes:
		if r.tied and r.a_block and r.b_block:
			var a := _i(floori(r.a.x), floori(r.a.y))
			var b := _i(floori(r.b.x), floori(r.b.y))
			links[a] = links.get(a, []) + [b]
			links[b] = links.get(b, []) + [a]
	var seen := PackedByteArray()
	seen.resize(W * H)
	var groups: Array[Array] = []
	for start in W * H:
		if seen[start] == 1 or not _placed_at(start):
			continue
		var group: Array[Vector2i] = []
		var todo: Array[int] = [start]
		seen[start] = 1
		while not todo.is_empty():
			var i: int = todo.pop_back()
			var x := i % W
			group.append(Vector2i(x, (i - x) / W))
			var next: Array = links.get(i, []).duplicate()
			if x > 0:
				next.append(i - 1)
			if x < W - 1:
				next.append(i + 1)
			if i >= W:
				next.append(i - W)
			if i < W * (H - 1):
				next.append(i + W)
			for n: int in next:
				if seen[n] == 0 and _placed_at(n):
					seen[n] = 1
					todo.append(n)
		groups.append(group)
	return groups


func _placed_at(i: int) -> bool:
	var c := cells[i]
	return c == BLOCK or c == STONE or c == WHEEL


func _wheels_on(group: Array) -> int:
	var n := 0
	for w in WHEELS:
		if Vector2i(floori(house_x + w), roundi(house_y)) in group:
			n += 1
	return n


## Takes a group out of the grid to rise, or to drive if it's a cart, unless something stops it
## straight away.
func _loosen(group: Array, rides: bool, drive := 0) -> void:
	var b := Body.new()
	var low := Vector2i(W, H)
	var high := Vector2i(-1, -1)
	for c: Vector2i in group:
		low = low.min(c)
		high = high.max(c)
	b.pos = Vector2(low)
	b.size = Vector2(high - low + Vector2i.ONE)
	b.house = rides
	b.cart = drive != 0
	b.dir = drive
	for c: Vector2i in group:
		b.cells.append(c - low)
		b.kinds[c - low] = cells[_i(c.x, c.y)]
		cells[_i(c.x, c.y)] = AIR
	var riders := _riders(b)
	var free := _can_move(b, Vector2(drive * CART_SPEED * DT, 0), riders) or _can_move(b, Vector2(0, STEP), riders) \
			if b.cart else _can_move(b, Vector2(0, -RISE * DT), riders)
	if not free:
		for c: Vector2i in group:
			cells[_i(c.x, c.y)] = b.kinds[c - low]
		return
	for c: Vector2i in group:
		if paint.has(_i(c.x, c.y)):
			b.paint[c - low] = paint[_i(c.x, c.y)]
			paint.erase(_i(c.x, c.y))
		if paint_dir.has(_i(c.x, c.y)):
			b.dirs[c - low] = paint_dir[_i(c.x, c.y)]
			paint_dir.erase(_i(c.x, c.y))
	for r in ropes:
		for end in ["a", "b"]:
			if r.get(end + "_block") and r.tied and Vector2i(r.get(end).floor()) in group:
				b.ends.append([r, end, r.get(end) - b.pos])
	bodies.append(b)
	_dirty = true


func _tick_bodies() -> void:
	for b: Body in bodies.duplicate():
		# Once the house is up out of view, its lift has done its job and waits there.
		if b.house and done:
			continue
		if b.cart:
			_roll(b)
			continue
		var riders := _riders(b)
		var d := Vector2(0, -RISE * DT)
		if not _can_move(b, d, riders):
			_settle(b)
			continue
		b.pos += d
		_move_ends(b)
		for o in riders:
			o.pos += d
		if b.house:
			house_y += d.y
			if house_y <= LIFTED:
				done = true
		if b.pos.y + b.size.y < SKY:
			for e in b.ends:
				untie(e[0])
			bodies.erase(b)
			_dirty = true


## A cart falls when nothing holds it up, and drives the way its engine faces until something stops it.
func _roll(b: Body) -> void:
	b.vy = minf(b.vy + GRAVITY * DT, MAX_FALL)
	var fell := _shift(b, Vector2(0, b.vy * DT))
	if not fell:
		b.vy = 0.0
	var drove := _shift(b, Vector2(b.dir * CART_SPEED * DT, 0))
	if not drove and not fell:
		_settle(b)


## Moves a body a short way in small steps, with its riders. Returns whether it moved at all.
func _shift(b: Body, d: Vector2) -> bool:
	var n := maxi(ceili(d.length() / STEP), 1)
	var moved := false
	for i in n:
		var riders := _riders(b)
		if not _can_move(b, d / n, riders):
			break
		b.pos += d / n
		for o in riders:
			o.pos += d / n
		_move_ends(b)
		moved = true
	return moved


## Kids and rocks standing on top of the body, who go up with it.
func _riders(b: Body) -> Array:
	var on := []
	for k: Kid in [marta, giulio]:
		if _on_top(k.rect(), b):
			on.append(k)
	for r in rocks:
		if _on_top(r.rect(), b):
			on.append(r)
	return on


func _on_top(box: Rect2, b: Body) -> bool:
	for c in b.cells:
		var top := b.rect(c)
		if absf(box.end.y - top.position.y) < 0.08 and box.end.x > top.position.x and box.position.x < top.end.x:
			return true
	return false


## Whether the body, everyone riding it and the house if it's aboard all have room to move.
func _can_move(b: Body, d: Vector2, riders: Array) -> bool:
	var boxes: Array[Rect2] = []
	for c in b.cells:
		boxes.append(b.rect(c))
	if not b.house:
		var house := _house_body(house_x)
		for box in boxes:
			if box.intersects(house.grow(-0.01)):
				return false
	for o in riders:
		boxes.append(o.rect())
	if b.house:
		boxes.append(_house_body(house_x))
	for box in boxes:
		box.position += d
		if _tiles_hit(box, b):
			return false
		for r in rocks:
			if r not in riders and r.rect().intersects(box):
				return false
		# It waits for a kid in its way rather than pushing into them.
		for k: Kid in [marta, giulio]:
			if k not in riders and k.rect().intersects(box):
				return false
	return true


## Something stopped the body, so it drops back into the grid on the nearest row it fits.
func _settle(b: Body) -> void:
	var drop := ceilf(b.pos.y - 0.01) - b.pos.y
	b.pos = Vector2(roundf(b.pos.x), b.pos.y + drop)
	for c in b.cells:
		var at := Vector2i(b.pos.round()) + c
		if at.x >= 0 and at.x < W and at.y >= 0 and at.y < H and cells[_i(at.x, at.y)] == AIR:
			cells[_i(at.x, at.y)] = b.kinds[c]
			if b.paint.has(c):
				paint[_i(at.x, at.y)] = b.paint[c]
			if b.dirs.has(c):
				paint_dir[_i(at.x, at.y)] = b.dirs[c]
	if b.house:
		house_y += drop
	_move_ends(b)
	bodies.erase(b)
	_dirty = true


func _move_ends(b: Body) -> void:
	for e in b.ends:
		e[0].set(e[1], b.pos + e[2])


# ---- light ----------------------------------------------------------------------------------


func light_at(x: int, y: int) -> float:
	return light[_i(x, y)] if x >= 0 and x < W and y >= 0 and y < H else 1.0


func marta_light_at(x: int, y: int) -> float:
	return cloak_light()[_i(x, y)] if x >= 0 and x < W and y >= 0 and y < H else 1.0


## What Marta sees by: the same light, with her yellow cloak's glow around her. Only her half of the
## screen needs it, so it's worked out when asked for rather than every tick.
## Whether an open square is inside a cave: in a stop with caves, under the roof of a column that
## passes through one. The view draws a back wall there.
func in_cave(x: int, y: int) -> bool:
	return dark and _cave_cols.has(x) and y > _cave_cols[x] and not solid(x, y)


func cloak_light() -> PackedFloat32Array:
	if not dark or cloak != YELLOW:
		return light
	var out := light.duplicate()
	_flood(out, marta.centre(), CLOAK_R)
	return out


## In a stop with caves, a column that passes through one is dark from its roof down, and the cave is
## lit only by daylight a little way in from its mouth and by yellow things, through open squares.
func _light() -> void:
	var key := [cells, ice, paint]
	for r in rocks:
		if r.colour == YELLOW:
			key.append(r.pos)
	for b in bodies:
		key.append(b.pos)
	# Worked out again only when the grid, a yellow rock or a moving group changes. Her cloak moves
	# with her, so it goes on top every tick.
	if hash(key) != _light_key:
		_light_key = hash(key)
		_light_up()


func _light_up() -> void:
	light.fill(1.0)
	if not dark:
		return
	for x in W:
		var roof := H
		for y in H:
			if ground(x, y):
				roof = y
				break
		var cave := false
		for y in range(roof + 1, H):
			cave = cave or not solid(x, y)
		_cave_cols.erase(x)
		if cave:
			_cave_cols[x] = roof
			for y in range(roof, H):
				light[_i(x, y)] = 0.0
	# Daylight reaches a few squares in from a cave's mouth, spreading from every lit open square
	# next to the dark at once.
	var reach := {}
	var todo: Array[Vector2i] = []
	for y in H:
		for x in W:
			if light[_i(x, y)] == 1.0 and not solid(x, y) and _beside_dark(x, y):
				reach[Vector2i(x, y)] = 0
				todo.append(Vector2i(x, y))
	var head := 0
	while head < todo.size():
		var c := todo[head]
		head += 1
		var d: int = reach[c]
		if d >= MOUTH_R:
			continue
		for n: Vector2i in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
			if n.x < 0 or n.x >= W or n.y < 0 or n.y >= H or reach.has(n) or light[_i(n.x, n.y)] == 1.0:
				continue
			reach[n] = d + 1
			light[_i(n.x, n.y)] = maxf(light[_i(n.x, n.y)], 1.0 - (d + 1) / (MOUTH_R + 1.0))
			if not solid(n.x, n.y):
				todo.append(n)
	for r in rocks:
		if r.colour == YELLOW:
			_flood(light, r.rect().get_center(), LIGHT_R)
	for key: int in paint:
		if paint[key] == YELLOW:
			_flood(light, _centre(Vector2i(key % W, floori(float(key) / W))), LIGHT_R)
	for b in bodies:
		for c in b.cells:
			if b.paint.get(c, PLAIN) == YELLOW:
				_flood(light, b.pos + Vector2(c) + Vector2(0.5, 0.5), LIGHT_R)


func _beside_dark(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
		var n := Vector2i(x, y) + d
		if n.x >= 0 and n.x < W and n.y >= 0 and n.y < H and light[_i(n.x, n.y)] < 1.0 and not solid(n.x, n.y):
			return true
	return false


## Light from one point, fading over r squares. It spreads only through open squares, lighting the
## walls it reaches but never passing through them.
func _flood(out: PackedFloat32Array, at: Vector2, r: float) -> void:
	var start := Vector2i(at.floor())
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c.x < 0 or c.x >= W or c.y < 0 or c.y >= H:
			continue
		var d := at.distance_to(_centre(c))
		if d > r:
			continue
		out[_i(c.x, c.y)] = maxf(out[_i(c.x, c.y)], 1.0 - d / (r + 1.0))
		if solid(c.x, c.y) and c != start:
			continue
		for n: Vector2i in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
			if not seen.has(n):
				seen[n] = true
				todo.append(n)


# ---- sootlings ------------------------------------------------------------------------------


func _tick_soots() -> void:
	var him := giulio.centre()
	var dark_him := _dim(him)
	for s in soots:
		var to := s.home
		if not _dim(s.pos):
			to = _darkest_near(s.pos)
		elif dark_him and s.pos.distance_to(him) <= SOOT_SEE:
			to = him
		_drift(s, to)
		if dark_him and s.pos.distance_to(him) < SOOT_REACH:
			_wake(giulio)
			events.append({"kind": "caught", "at": s.pos})


## Whether a point is dark enough for a sootling: only daylight and yellow things count, not her cloak.
func _dim(at: Vector2) -> bool:
	return light_at(floori(at.x), floori(at.y)) <= SOOT_LIT


## Moves towards a point through open, dark squares only, sliding along anything in the way.
func _drift(s: Soot, to: Vector2) -> void:
	var d := (to - s.pos).limit_length(SOOT_SPEED * DT)
	for step: Vector2 in [d, Vector2(d.x, 0), Vector2(0, d.y)]:
		var next := s.pos + step
		var lit_now := not _dim(s.pos)
		if not solid(floori(next.x), floori(next.y)) and (_dim(next) or lit_now):
			s.pos = next
			return


## The darkest open square around, for a sootling caught in light to retreat to.
func _darkest_near(at: Vector2) -> Vector2:
	var best := at
	var least := light_at(floori(at.x), floori(at.y))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(floori(at.x) + dx, floori(at.y) + dy)
			if solid(c.x, c.y) or c.y < 0 or c.y >= H or c.x < 0 or c.x >= W:
				continue
			if light_at(c.x, c.y) < least:
				least = light_at(c.x, c.y)
				best = _centre(c)
	return best
