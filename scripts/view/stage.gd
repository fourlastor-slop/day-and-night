class_name Stage
extends Node2D
## Draws the Sim. It sits in one World2D that both cameras share, so there is only one copy of every
## sprite, and whatever only one kid should see goes on a visibility layer.

const B := 48.0
const SHARED := 1
const DAY := 2
const NIGHT_TOP := 4
const EVERY := SHARED | DAY | NIGHT_TOP
const FX_LIFE := 90
const STOP_LIFE := 150
const SMOOTH := 4
const SHUDDER := 30
const USE_HOLD := 10

## The keys on keys.png, in order.
const CAPS: Array[String] = ["E", "R", "Q", "F", "K", "L", "J", "I", "X", "B", "LB", "Y"]
const CAP_CELL := 64.0

const STRESS_CELL := Vector2(48, 16)
const BLOCK_CELL := 64.0
const EARTH_ROWS := 5
const EARTH_BASE := Color("937c63")
const ROCK_BASE := Color("8f8d86")
const CAVE_SHADE := Color(0.18, 0.15, 0.13, 0.55)
const ROPE_DARK := Color("6d5233")
const ROPE_LIGHT := Color("c9a066")


## The tile grid, from row top down to row bottom.
class Ground extends Node2D:
	var sim: Sim
	var top := 0
	var bottom := Sim.H
	var earth: Texture2D = load("res://assets/gfx/earth.png")
	var cliff: Texture2D = load("res://assets/gfx/cliff.png")
	var grass: Texture2D = load("res://assets/gfx/grass.png")
	var block: Texture2D = load("res://assets/gfx/block.png")
	var stone: Texture2D = load("res://assets/gfx/stone.png")
	var wheel: Texture2D = load("res://assets/gfx/cart_wheel.png")
	var stress: Texture2D = load("res://assets/gfx/stress.png")

	func _draw() -> void:
		for y in range(top, bottom):
			for x in Sim.W:
				var c := sim.cell(x, y)
				if c == Sim.EARTH or c == Sim.ROCK:
					draw_rect(Rect2(x * B, y * B, B, B), EARTH_BASE if c == Sim.EARTH else ROCK_BASE)
				elif sim.in_cave(x, y):
					# Inside the mountain the back of the cave shows, not the sky.
					_cell(cliff, x, y, Rect2(((x * 7 + y * 3) % 5 % 3) * BLOCK_CELL, 0, BLOCK_CELL, BLOCK_CELL))
					draw_rect(Rect2(x * B, y * B, B, B), CAVE_SHADE)
		for y in range(top, bottom):
			for x in Sim.W:
				var col := (x * 7 + y * 3) % 5 % 3
				if sim.cell(x, y) == Sim.EARTH:
					var row := mini(y - sim.road, EARTH_ROWS - 1) if y >= sim.road else 0
					_cell(earth, x, y, Rect2(col * BLOCK_CELL, row * BLOCK_CELL, BLOCK_CELL, BLOCK_CELL))
				elif sim.cell(x, y) == Sim.ROCK:
					_cell(cliff, x, y, Rect2(col * BLOCK_CELL, 0, BLOCK_CELL, BLOCK_CELL))
		for y in range(top, bottom):
			for x in Sim.W:
				if sim.placed(x, y):
					_block(x, y)
				elif sim.cell(x, y) == Sim.EARTH and sim.cell(x, y - 1) == Sim.AIR:
					draw_texture_rect_region(grass, Rect2(x * B - 12, y * B - 18, 72, 44), Rect2((x % 3) * 72, 0, 72, 44))

	func _block(x: int, y: int) -> void:
		var colour: int = sim.paint.get(y * Sim.W + x, Sim.PLAIN)
		# A straining block is drawn by Lifts, bobbing.
		if sim.cell(x, y) == Sim.WHEEL:
			_cell(wheel, x, y, Rect2(0, 0, BLOCK_CELL, BLOCK_CELL))
		elif not sim.strain.has(y * Sim.W + x):
			_cell(stone if sim.cell(x, y) == Sim.STONE else block, x, y, Rect2(colour * BLOCK_CELL, 0, BLOCK_CELL, BLOCK_CELL))
		# Green while well inside what this kind of block can span, then yellow, orange where the
		# house would break it, and red past that.
		var n := sim.span_at(x, y)
		var limit := sim.span_limit(x, y)
		var level := 0 if n <= limit - 2 else 1 if n == limit - 1 else 2 if n == limit else 3
		var from := Rect2(level * STRESS_CELL.x, 0, STRESS_CELL.x, STRESS_CELL.y)
		draw_texture_rect_region(stress, Rect2(x * B, y * B + B - STRESS_CELL.y, STRESS_CELL.x, STRESS_CELL.y), from)

	func _cell(tex: Texture2D, x: int, y: int, from: Rect2) -> void:
		draw_texture_rect_region(tex, Rect2(x * B - 8, y * B - 8, BLOCK_CELL, BLOCK_CELL), from)


class Frost extends Node2D:
	var sim: Sim
	var ice: Texture2D = load("res://assets/gfx/ice.png")

	func _draw() -> void:
		for y in Sim.H:
			for x in Sim.W:
				if sim.frozen(x, y):
					draw_texture(ice, Vector2(x * B - 8, y * B - 8))


## Every pool is cut from the same river painting, repeated along it if it's wider than that.
class Water extends Node2D:
	var sim: Sim
	var river: Texture2D = load("res://assets/gfx/river.png")

	func _draw() -> void:
		var x := 0
		while x < Sim.W:
			var top := sim.surface[x]
			var start := x
			x += 1
			while x < Sim.W and sim.surface[x] == top:
				x += 1
			if top >= 0:
				_pool(start, x, top)

	func _pool(x0: int, x1: int, top: int) -> void:
		var size := river.get_size()
		var at := x0 * B
		while at < x1 * B:
			var w := minf(size.x, x1 * B - at)
			draw_texture_rect_region(river, Rect2(at, top * B, w, size.y), Rect2(0, 0, w, size.y))
			at += w


## Groups of blocks on the move, and white groups bobbing as they strain to lift.
class Lifts extends Node2D:
	var sim: Sim
	var block: Texture2D = load("res://assets/gfx/block.png")
	var stone: Texture2D = load("res://assets/gfx/stone.png")
	var wheel: Texture2D = load("res://assets/gfx/cart_wheel.png")

	func _draw() -> void:
		for b in sim.bodies:
			for c in b.cells:
				var at := b.pos + Vector2(c)
				if b.kinds.get(c, Sim.BLOCK) == Sim.WHEEL:
					# A moving cart's wheels turn with it.
					draw_set_transform((at + Vector2(0.5, 0.5)) * B, b.pos.x * 1.9)
					draw_texture(wheel, -Vector2(BLOCK_CELL, BLOCK_CELL) / 2)
					draw_set_transform(Vector2.ZERO)
				else:
					_block(at, b.paint.get(c, Sim.PLAIN), 0.0, b.kinds.get(c, Sim.BLOCK))
		var bob := absf(sin(sim.t * 0.21)) * 3.0
		for key: int in sim.strain:
			var at := Vector2(key % Sim.W, floori(float(key) / Sim.W))
			_block(at, sim.paint.get(key, Sim.PLAIN), bob * sim.strain[key], sim.cell(int(at.x), int(at.y)))

	func _block(at: Vector2, colour: int, up: float, kind: int) -> void:
		var to := Rect2(at * B - Vector2(8, 8 + up), Vector2(BLOCK_CELL, BLOCK_CELL))
		draw_texture_rect_region(stone if kind == Sim.STONE else block, to, Rect2(colour * BLOCK_CELL, 0, BLOCK_CELL, BLOCK_CELL))


## Ropes, sagging a little unless something hangs from them, and the one Giulio is carrying.
class Ropes extends Node2D:
	var sim: Sim

	func _draw() -> void:
		var held := sim.giulio.rope
		for r in sim.ropes:
			if r != held:
				_rope(r.a, r.b, 0.0 if r.hook else 0.12)
		if held != null:
			_rope(held.a, sim.giulio.pos + Vector2(0.35 * sim.giulio.facing, -0.95), 0.12)

	func _rope(a: Vector2, b: Vector2, sag: float) -> void:
		var points := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			points.append((a.lerp(b, t) + Vector2(0, sag * a.distance_to(b) * 4.0 * t * (1.0 - t))) * B)
		draw_polyline(points, ROPE_DARK, 6.0, true)
		draw_polyline(points, ROPE_LIGHT, 3.0, true)


## Shades one half's caves from the sim's light: a tiny picture with one square of shade per block,
## stretched over the world and smoothed, so light fades out softly.
class Darkness extends Sprite2D:
	var sim: Sim
	var for_marta := false
	var shade := Color.BLACK
	var image := Image.create(Sim.W, Sim.H, false, Image.FORMAT_RGBA8)

	func _init() -> void:
		centered = false
		# Worked out per square, then smoothed up to four pixels a square so light fades round.
		scale = Vector2(B, B) / SMOOTH
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var big := image.duplicate()
		big.resize(Sim.W * SMOOTH, Sim.H * SMOOTH, Image.INTERPOLATE_CUBIC)
		texture = ImageTexture.create_from_image(big)

	func refresh() -> void:
		visible = sim.dark
		if not visible:
			return
		var lit := sim.cloak_light() if for_marta else sim.light
		for y in Sim.H:
			for x in Sim.W:
				image.set_pixel(x, y, Color(shade, (1.0 - lit[y * Sim.W + x]) * 0.94))
		var big := image.duplicate()
		big.resize(Sim.W * SMOOTH, Sim.H * SMOOTH, Image.INTERPOLATE_CUBIC)
		(texture as ImageTexture).update(big)


## One kid's cues, on that kid's half of the screen only, because their keys are different.
class Cues:
	var drive: Sprite2D
	var bell: Sprite2D
	var interact: Sprite2D
	var use: Sprite2D
	var alt: Sprite2D


var sim: Sim
var ground: Ground
var overhead: Ground
var frost: Frost
var rocks: Array[Sprite2D] = []
var ghosts: Array[Sprite2D] = []
var wisps: Array[Sprite2D] = []
var house: Sprite2D
var wheels: Array[Sprite2D] = []
var window: Sprite2D
var marta: Sprite2D
var giulio: Sprite2D
var marta_glow: Sprite2D
var giulio_glow: Sprite2D
var ring: Sprite2D
var target: Sprite2D
var aim: Sprite2D
var stop: Sprite2D
var stop_left := 0
var use_hold := 0
var lifts: Lifts
var ropes: Ropes
var marta_dark: Darkness
var giulio_dark: Darkness
## Each sootling is a shadow, which the dark hides, and a pair of eyes that shows through it.
var soot_bodies: Array[Sprite2D] = []
var soot_eyes: Array[Sprite2D] = []
var marta_cues: Cues
var giulio_cues: Cues
var marta_keys := {}
var giulio_keys := {}
var fx: Array[Dictionary] = []
var seen := -1

var rock_tex: Array[Texture2D] = [load("res://assets/gfx/rock_plain.png"), load("res://assets/gfx/rock_white.png"), load("res://assets/gfx/rock_blue.png"),
		load("res://assets/gfx/rock_yellow.png")]
## Her sprite by brush colour, with her red cloak or the yellow one she wears in the mines.
var brush_tex: Dictionary = {Sim.WHITE: load("res://assets/gfx/marta_white.png"), Sim.BLUE: load("res://assets/gfx/marta_blue.png"),
		Sim.YELLOW: load("res://assets/gfx/marta_yellow.png")}
var cloak_tex: Dictionary = {Sim.WHITE: load("res://assets/gfx/marta_cloak_white.png"),
		Sim.BLUE: load("res://assets/gfx/marta_cloak_blue.png"), Sim.YELLOW: load("res://assets/gfx/marta_cloak_yellow.png")}
var tool_tex: Dictionary = {Sim.HAMMER: load("res://assets/gfx/giulio_hammer.png"), Sim.PICK: load("res://assets/gfx/giulio_pick.png"),
		Sim.ROPE: load("res://assets/gfx/giulio_rope.png"), Sim.CHISEL: load("res://assets/gfx/giulio_stone.png"),
		Sim.WHEEL_TOOL: load("res://assets/gfx/giulio_wheel.png")}


func _init(world: Sim) -> void:
	sim = world
	visibility_layer = EVERY
	ground = Ground.new()
	ground.sim = sim
	# Ground above the top of the house's body draws in front of it, so its flag goes behind a shelf.
	var roof := sim.road - int(Sim.HOUSE_H)
	ground.top = roof
	add_child(ground)
	overhead = Ground.new()
	overhead.sim = sim
	overhead.bottom = roof
	overhead.z_index = 5
	add_child(overhead)
	for r in sim.rocks:
		wisps.append(_sprite("res://assets/gfx/wisp.png", 1))
		rocks.append(_sprite("res://assets/gfx/rock_plain.png", 1))
		# Paint shows faintly through a cave's dark, so a painted rock never just vanishes.
		var faint := _sprite("res://assets/gfx/rock_plain.png", 7, DAY | NIGHT_TOP)
		faint.modulate.a = 0.5
		ghosts.append(faint)
	var water := Water.new()
	water.sim = sim
	water.z_index = 2
	water.modulate.a = 0.62
	add_child(water)
	frost = Frost.new()
	frost.sim = sim
	frost.z_index = 3
	add_child(frost)
	lifts = Lifts.new()
	lifts.sim = sim
	add_child(lifts)
	ropes = Ropes.new()
	ropes.sim = sim
	ropes.z_index = 5
	add_child(ropes)
	marta_dark = _darkness(DAY, Color("140f0b"), true)
	giulio_dark = _darkness(NIGHT_TOP, Color("060a1a"), false)
	for s in sim.soots:
		soot_bodies.append(_sprite("res://assets/gfx/sootling.png", 3))
		soot_eyes.append(_sprite("res://assets/gfx/soot_eyes.png", 7, DAY | NIGHT_TOP))
	for d: Dictionary in sim.decor:
		var s := _sprite("res://assets/gfx/%s.png" % d.sprite, 1)
		s.centered = false
		s.position = d.at * B
	for w in Sim.WHEELS:
		wheels.append(_sprite("res://assets/gfx/wheel.png", 4))
	house = _sprite("res://assets/gfx/house.png", 4)
	house.centered = false
	window = _sprite("res://assets/gfx/window.png", 5, NIGHT_TOP)
	marta_glow = _sprite("res://assets/gfx/glow.png", 7, NIGHT_TOP)
	marta_glow.modulate = Color(1.0, 0.85, 0.7, 0.55)
	giulio_glow = _sprite("res://assets/gfx/glow.png", 7, DAY)
	giulio_glow.modulate = Color(1.0, 0.9, 0.65, 0.65)
	marta = _sprite("res://assets/gfx/marta_white.png", 7, DAY)
	marta.centered = false
	marta.offset = Vector2(-60, -116)
	giulio = _sprite("res://assets/gfx/giulio_hammer.png", 7, NIGHT_TOP)
	giulio.centered = false
	giulio.offset = Vector2(-56, -104)
	ring = _sprite("res://assets/gfx/ring.png", 8, DAY)
	target = _sprite("res://assets/gfx/target.png", 8, NIGHT_TOP)
	aim = _sprite("res://assets/gfx/aim_arrows.png", 8, NIGHT_TOP)
	stop = _sprite("res://assets/gfx/hint_stop.png", 9, DAY | NIGHT_TOP)
	stop.visible = false
	marta_cues = _cues(DAY)
	giulio_cues = _cues(NIGHT_TOP)


func _sprite(path: String, z: int, layer := SHARED) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.z_index = z
	s.visibility_layer = layer
	add_child(s)
	return s


## Drawn over everything in the world but the kids, their glows and the cues.
func _darkness(layer: int, shade: Color, for_marta: bool) -> Darkness:
	var d := Darkness.new()
	d.sim = sim
	d.shade = shade
	d.for_marta = for_marta
	d.visibility_layer = layer
	d.z_index = 6
	add_child(d)
	return d


func _cues(layer: int) -> Cues:
	var c := Cues.new()
	c.drive = _sprite("res://assets/gfx/hint_drive.png", 8, layer)
	c.bell = _sprite("res://assets/gfx/hint_bell.png", 8, layer)
	c.interact = _key(layer)
	c.use = _key(layer)
	c.alt = _key(layer)
	return c


func _key(layer: int) -> Sprite2D:
	var s := _sprite("res://assets/gfx/keys.png", 9, layer)
	s.region_enabled = true
	return s


static func cap_rect(key: String) -> Rect2:
	return Rect2(CAPS.find(key) * CAP_CELL, 0, CAP_CELL, CAP_CELL)


func _cue(s: Sprite2D, on: bool, key: String, at: Vector2) -> void:
	s.visible = on
	s.region_rect = cap_rect(key)
	s.position = at


func sync() -> void:
	if seen != sim.revision:
		seen = sim.revision
		ground.queue_redraw()
		overhead.queue_redraw()
		frost.queue_redraw()
	lifts.queue_redraw()
	ropes.queue_redraw()
	marta_dark.refresh()
	giulio_dark.refresh()
	for i in sim.soots.size():
		var bob := Vector2(0, sin(sim.t * 0.09 + i) * 4.0)
		soot_bodies[i].position = sim.soots[i].pos * B + bob
		soot_eyes[i].position = soot_bodies[i].position
	for i in rocks.size():
		var r: Sim.Rock = sim.rocks[i]
		rocks[i].texture = rock_tex[r.colour]
		rocks[i].position = r.rect().get_center() * B
		rocks[i].scale = Vector2.ONE * r.size.x / 2.0
		ghosts[i].visible = sim.dark and r.colour != Sim.PLAIN
		ghosts[i].texture = rocks[i].texture
		ghosts[i].position = rocks[i].position
		ghosts[i].scale = rocks[i].scale
		# Paint stays bright through the water.
		rocks[i].z_index = 1 if r.colour == Sim.PLAIN else 3
		wisps[i].z_index = rocks[i].z_index
		wisps[i].visible = r.colour == Sim.WHITE
		wisps[i].position = rocks[i].position + Vector2(0, B * 1.1)
	_sync_house()
	_sync_kid(marta, sim.marta)
	_sync_kid(giulio, sim.giulio)
	marta.texture = (cloak_tex if sim.cloak == Sim.YELLOW else brush_tex)[sim.marta.colour]
	giulio.texture = tool_tex[sim.giulio.tool]
	marta_glow.position = sim.marta.centre() * B
	giulio_glow.position = sim.giulio.centre() * B
	_sync_pick()
	for e in sim.events:
		_event(e)
	sim.events.clear()
	_tick_fx()
	_tick_stop()


func _sync_house() -> void:
	var at := sim.house_x * B
	var bump := sin(sim.t * 0.5) * 1.5 if sim.house_state != Sim.PARKED else 0.0
	var shake := sin(stop_left * 1.3) * maxi(stop_left - STOP_LIFE + SHUDDER, 0) * 0.3
	house.position = Vector2(at - 60 + shake, sim.house_y * B - 520 + bump)
	window.position = Vector2(at + 2.9 * B + shake, (sim.house_y - 3.55) * B + bump)
	for i in wheels.size():
		wheels[i].position = Vector2(at + Sim.WHEELS[i] * B + shake, (sim.house_y - 1.02) * B)
		wheels[i].rotation = sim.house_x / 1.02
	_sync_hints(marta_cues, sim.marta, marta_keys)
	_sync_hints(giulio_cues, sim.giulio, giulio_keys)


func _sync_hints(c: Cues, k: Sim.Kid, keys: Dictionary) -> void:
	var at := sim.house_x * B
	var bell := sim.near_bell(k) and not sim.done
	var drive := sim.near_house(k) and not bell and sim.house_state == Sim.PARKED and not sim.done
	c.bell.visible = bell
	c.drive.visible = drive
	c.drive.position = Vector2(at + 5.9 * B, (sim.house_y - 6.2) * B)
	c.bell.position = Vector2(at + Sim.BELL * B, (sim.house_y - 5.6) * B)
	var bubble := c.bell if bell else c.drive
	_cue(c.interact, bell or drive, keys.interact, bubble.position + Vector2(66, 0))


func _sync_kid(s: Sprite2D, k: Sim.Kid) -> void:
	var walking := k.grounded and absf(k.vel.x) > 0.5
	var phase := sim.t * 0.32
	s.position = k.pos * B + Vector2(0, -absf(sin(phase)) * 7.0 if walking else 0.0)
	s.rotation = sin(phase) * 0.07 if walking else 0.0
	s.scale.x = k.facing


func _sync_pick() -> void:
	var m := sim.marta
	ring.visible = m.pick_rock != null or m.pick_block.x >= 0
	var colour := Sim.PLAIN
	if m.pick_rock != null:
		ring.position = m.pick_rock.rect().get_center() * B
		ring.scale = Vector2.ONE * 0.72
		colour = m.pick_rock.colour
	elif m.pick_block.x >= 0:
		ring.position = (Vector2(m.pick_block) + Vector2(0.5, 0.5)) * B
		ring.scale = Vector2.ONE * 0.46
		colour = sim.paint.get(m.pick_block.y * Sim.W + m.pick_block.x, Sim.PLAIN)
	ring.rotation += 0.01
	var corner := ring.scale * 70.0
	_cue(marta_cues.use, ring.visible and colour != m.colour, marta_keys.use, ring.position + corner * Vector2(1, -1))
	_cue(marta_cues.alt, ring.visible and colour != Sim.PLAIN, marta_keys.alt, ring.position + corner * Vector2(-1, -1))
	var c := sim.giulio.target
	target.visible = c.x >= 0 and not sim.bearing(c)
	target.position = (Vector2(c) + Vector2(0.5, 0.5)) * B
	target.scale = Vector2.ONE * 0.9
	aim.visible = target.visible and sim.giulio.pad.alt
	aim.position = target.position
	# Walking, he overlaps the square ahead for part of every step, so the cue outlasts that.
	use_hold = USE_HOLD if sim.can_use() else maxi(use_hold - 1, 0)
	_cue(giulio_cues.use, target.visible and use_hold > 0, giulio_keys.use, target.position + Vector2(sim.giulio.facing * 48, -48))


func _event(e: Dictionary) -> void:
	match e.kind:
		"fell":
			_debris(Vector2(e.cell) + Vector2(0.5, 0.5), Vector2(randf_range(-40, 40), randf_range(-200, -60)), 900.0)
		"swept":
			_debris(Vector2(e.cell) + Vector2(0.5, 0.0), Vector2(120, 0), 0.0)
		"paint":
			var s := _sprite("res://assets/gfx/glow.png", 8)
			s.position = e.at * B
			s.modulate = Color(1, 1, 0.8, 0.8)
			fx.append({"node": s, "t": 0, "grow": true})
		"refuse":
			stop.position = e.at * B
			stop_left = STOP_LIFE


## The crossed wheel sits on whatever stopped the house, and goes once it moves again.
func _tick_stop() -> void:
	stop_left = 0 if sim.house_state != Sim.PARKED else maxi(stop_left - 1, 0)
	stop.visible = stop_left > 0
	stop.scale = Vector2.ONE * (1.0 + sin(stop_left * 0.25) * 0.1)
	stop.modulate.a = minf(stop_left / 20.0, 1.0)


func _debris(at: Vector2, vel: Vector2, gravity: float) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/gfx/block.png")
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, BLOCK_CELL, BLOCK_CELL)
	s.position = at * B
	s.z_index = 3
	add_child(s)
	fx.append({"node": s, "t": 0, "vel": vel, "gravity": gravity, "spin": randf_range(-4, 4)})


func _tick_fx() -> void:
	for i in range(fx.size() - 1, -1, -1):
		var f := fx[i]
		var s: Sprite2D = f.node
		f.t += 1
		if f.has("grow"):
			s.scale = Vector2.ONE * (1.0 + f.t * 0.05)
			s.modulate.a = maxf(0.8 - f.t * 0.04, 0.0)
		else:
			f.vel.y += f.gravity * Sim.DT
			s.position += f.vel * Sim.DT
			s.rotation += f.spin * Sim.DT
			s.modulate.a = 1.0 - float(f.t) / FX_LIFE
		if f.t > (20 if f.has("grow") else FX_LIFE):
			s.queue_free()
			fx.remove_at(i)
