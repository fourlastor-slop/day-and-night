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
const SHUDDER := 30
const USE_HOLD := 10

## The keys on keys.png, in order.
const CAPS: Array[String] = ["E", "R", "Q", "F", "K", "L", "J", "I", "X", "B", "LB", "Y"]
const CAP_CELL := 64.0

const STRESS_CELL := Vector2(48, 16)
const BLOCK_CELL := 64.0
const EARTH_ROWS := 5
const EARTH_BASE := Color("937c63")


class Ground extends Node2D:
	var sim: Sim
	var earth: Texture2D = load("res://assets/gfx/earth.png")
	var grass: Texture2D = load("res://assets/gfx/grass.png")
	var block: Texture2D = load("res://assets/gfx/block.png")
	var stress: Texture2D = load("res://assets/gfx/stress.png")

	func _draw() -> void:
		for y in Sim.H:
			for x in Sim.W:
				if sim.cell(x, y) == Sim.EARTH:
					draw_rect(Rect2(x * B, y * B, B, B), EARTH_BASE)
		for y in Sim.H:
			for x in Sim.W:
				if sim.cell(x, y) == Sim.EARTH:
					var row := mini(y - Sim.ROAD, EARTH_ROWS - 1) if y >= Sim.ROAD else 0
					var col := (x * 7 + y * 3) % 5 % 3
					_cell(earth, x, y, Rect2(col * BLOCK_CELL, row * BLOCK_CELL, BLOCK_CELL, BLOCK_CELL))
		for y in Sim.H:
			for x in Sim.W:
				if sim.cell(x, y) == Sim.BLOCK:
					_block(x, y)
				elif sim.cell(x, y) == Sim.EARTH and sim.cell(x, y - 1) == Sim.AIR:
					draw_texture_rect_region(grass, Rect2(x * B - 12, y * B - 18, 72, 44), Rect2((x % 3) * 72, 0, 72, 44))

	func _block(x: int, y: int) -> void:
		var colour: int = sim.paint.get(y * Sim.W + x, Sim.PLAIN)
		_cell(block, x, y, Rect2(colour * BLOCK_CELL, 0, BLOCK_CELL, BLOCK_CELL))
		var n := sim.span_at(x, y)
		var level := 0 if n <= 1 else n - 1 if n < Sim.MAX_SPAN else 2 if n == Sim.MAX_SPAN else 3
		var from := Rect2(level * STRESS_CELL.x, 0, STRESS_CELL.x, STRESS_CELL.y)
		draw_texture_rect_region(stress, Rect2(x * B, y * B + B - STRESS_CELL.y, STRESS_CELL.x, STRESS_CELL.y), from)

	func _cell(tex: Texture2D, x: int, y: int, from: Rect2) -> void:
		draw_texture_rect_region(tex, Rect2(x * B - 8, y * B - 8, BLOCK_CELL, BLOCK_CELL), from)


class Frost extends Node2D:
	var sim: Sim
	var ice: Texture2D = load("res://assets/gfx/ice.png")

	func _draw() -> void:
		for x in Sim.W:
			if sim.frozen(x, Sim.SURFACE):
				draw_texture(ice, Vector2(x * B - 8, Sim.SURFACE * B - 8))


## One kid's cues, on that kid's half of the screen only, because their keys are different.
class Cues:
	var drive: Sprite2D
	var bell: Sprite2D
	var interact: Sprite2D
	var use: Sprite2D
	var alt: Sprite2D


var sim: Sim
var ground: Ground
var frost: Frost
var rocks: Array[Sprite2D] = []
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
var marta_cues: Cues
var giulio_cues: Cues
var marta_keys := {}
var giulio_keys := {}
var fx: Array[Dictionary] = []
var seen := -1

var rock_tex: Array[Texture2D] = [load("res://assets/gfx/rock_plain.png"), load("res://assets/gfx/rock_white.png"), load("res://assets/gfx/rock_blue.png")]
var brush_tex: Dictionary = {Sim.WHITE: load("res://assets/gfx/marta_white.png"), Sim.BLUE: load("res://assets/gfx/marta_blue.png")}
var tool_tex: Dictionary = {Sim.HAMMER: load("res://assets/gfx/giulio_hammer.png"), Sim.PICK: load("res://assets/gfx/giulio_pick.png")}


func _init(world: Sim) -> void:
	sim = world
	visibility_layer = EVERY
	ground = Ground.new()
	ground.sim = sim
	add_child(ground)
	for r in sim.rocks:
		wisps.append(_sprite("res://assets/gfx/wisp.png", 1))
		rocks.append(_sprite("res://assets/gfx/rock_plain.png", 1))
	var river := _sprite("res://assets/gfx/river.png", 2)
	river.centered = false
	river.position = Vector2(Sim.BANK_L * B, Sim.SURFACE * B)
	river.modulate.a = 0.62
	frost = Frost.new()
	frost.sim = sim
	frost.z_index = 3
	add_child(frost)
	for w in Sim.WHEELS:
		wheels.append(_sprite("res://assets/gfx/wheel.png", 4))
	house = _sprite("res://assets/gfx/house.png", 4)
	house.centered = false
	window = _sprite("res://assets/gfx/window.png", 5, NIGHT_TOP)
	marta_glow = _sprite("res://assets/gfx/glow.png", 6, NIGHT_TOP)
	marta_glow.modulate = Color(1.0, 0.85, 0.7, 0.55)
	giulio_glow = _sprite("res://assets/gfx/glow.png", 6, DAY)
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
		frost.queue_redraw()
	for i in rocks.size():
		var r: Sim.Rock = sim.rocks[i]
		rocks[i].texture = rock_tex[r.colour]
		rocks[i].position = r.rect().get_center() * B
		# Paint stays bright through the water.
		rocks[i].z_index = 1 if r.colour == Sim.PLAIN else 3
		wisps[i].z_index = rocks[i].z_index
		wisps[i].visible = r.colour == Sim.WHITE
		wisps[i].position = rocks[i].position + Vector2(0, B * 1.1)
	_sync_house()
	_sync_kid(marta, sim.marta)
	_sync_kid(giulio, sim.giulio)
	marta.texture = brush_tex[sim.marta.colour]
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
	house.position = Vector2(at - 60 + shake, Sim.ROAD * B - 520 + bump)
	window.position = Vector2(at + 2.9 * B + shake, (Sim.ROAD - 3.55) * B + bump)
	for i in wheels.size():
		wheels[i].position = Vector2(at + Sim.WHEELS[i] * B + shake, (Sim.ROAD - 1.02) * B)
		wheels[i].rotation = sim.house_x / 1.02
	_sync_hints(marta_cues, sim.marta, marta_keys)
	_sync_hints(giulio_cues, sim.giulio, giulio_keys)


func _sync_hints(c: Cues, k: Sim.Kid, keys: Dictionary) -> void:
	var at := sim.house_x * B
	var bell := sim.near_bell(k) and not sim.done
	var drive := sim.near_house(k) and not bell and sim.house_state == Sim.PARKED and not sim.done
	c.bell.visible = bell
	c.drive.visible = drive
	c.drive.position = Vector2(at + 5.9 * B, (Sim.ROAD - 6.2) * B)
	c.bell.position = Vector2(at + Sim.BELL * B, (Sim.ROAD - 5.6) * B)
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
