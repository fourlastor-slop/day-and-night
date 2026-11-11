class_name Menu
extends Control
## The title, pause, stops, controls, options and are-you-sure pages, painted on a card over the
## frozen road. Either kid can work it: the arrows or WASD to choose, Enter, Space, E or K to pick,
## and Esc to go back, or a gamepad's stick, A and B. Main sets these keys up in bind_keys().

## Asks Main to act: play, restart_road, stop (with the stop's index), restart_stop, language,
## fullscreen or quit.
signal chose(what: String, value: int)

const SCREEN := Vector2(1920, 1080)
const INK := Color("3d332c")
const SOFT := Color(0.239, 0.2, 0.173, 0.66)
const FAINT := Color(0.239, 0.2, 0.173, 0.28)
const VEIL := Color(0.09, 0.08, 0.1, 0.42)
const BOLD := preload("res://assets/fonts/Fredoka-Bold.ttf")
const SEMI := preload("res://assets/fonts/Fredoka-SemiBold.ttf")
const TITLE_SIZE := 104
const HEAD_SIZE := 60
const ITEM_SIZE := 48
const STOP_SIZE := 40
const SMALL_SIZE := 32
const ROW := 80.0
const PICK_H := 84.0
## How wide each page's card is, which the Italian has to fit inside too.
const WIDTH := {"splash": 1000.0, "first": 1000.0, "title": 1000.0, "pause": 1100.0, "stops": 1560.0, "options": 1000.0,
	"controls": 1640.0, "confirm": 1300.0}
## Room left for words inside a card's painted edge, and the stops page's two columns.
const MARGIN := 90.0
const COLUMN := 700.0
## Where a stop's name starts in its column, after its number.
const STOP_NAME_X := 96.0

## What each page offers. "first" is the title of a road not yet begun.
const PAGES := {
	"first": ["Play", "Controls", "Options", "Quit"],
	"title": ["Continue", "Stops", "Controls", "Options", "New journey", "Quit"],
	"pause": ["Continue", "Restart this stop", "Stops", "Controls", "Options", "Quit"],
	"options": ["Language", "Fullscreen", "Back"],
	"controls": ["Back"],
	"confirm": ["No", "Yes, start again"],
}

## Set by Main: the road and its settings, to show where the kids are.
var progress: Progress
var stop := 0
var page := ""
var items: Array = []
var sel := 0
## The page that opened the stops, controls or options, which Back returns to.
var came_from := "title"
var t := 0
var card := StyleBoxTexture.new()
var pick := StyleBoxTexture.new()
var sun: Texture2D = preload("res://assets/gfx/sun.png")
var moon: Texture2D = preload("res://assets/gfx/moon.png")
var keys: Texture2D = preload("res://assets/gfx/keys.png")


func _init() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	card.texture = preload("res://assets/gfx/menu_card.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		card.set_texture_margin(side, 64)
	pick.texture = preload("res://assets/gfx/menu_pick.png")
	pick.set_texture_margin(SIDE_LEFT, 46)
	pick.set_texture_margin(SIDE_RIGHT, 46)
	pick.set_texture_margin(SIDE_TOP, 30)
	pick.set_texture_margin(SIDE_BOTTOM, 30)


## Shows a page, or hides the menu with "".
func open(which: String) -> void:
	page = which
	t = 0
	sel = 0
	visible = page != ""
	if page == "stops":
		items = []
		for i in Stops.ROAD.size():
			items.append("stop:%d" % i)
		items.append("Back")
		sel = mini(stop, last_stop())
	else:
		items = PAGES.get(page, [])
	queue_redraw()


func active() -> bool:
	return page != ""


## The last stop the kids can pick: the furthest they've reached, or the one they're on.
func last_stop() -> int:
	return maxi(progress.reached, stop) if progress != null else stop


func _process(_delta: float) -> void:
	if page == "":
		return
	t += 1
	if t < 3 or items.is_empty():
		return  # the press that opened this page must not also act on it
	var dy := int(Input.is_action_just_pressed("ui_down")) - int(Input.is_action_just_pressed("ui_up"))
	var dx := int(Input.is_action_just_pressed("ui_right")) - int(Input.is_action_just_pressed("ui_left"))
	if dy != 0:
		_move(dy)
	elif dx != 0:
		_side(dx)
	elif Input.is_action_just_pressed("ui_accept"):
		choose(items[sel])
	elif Input.is_action_just_pressed("ui_cancel") or (page == "pause" and Input.is_action_just_pressed("pause")):
		back()


func _move(d: int) -> void:
	var at := sel
	for i in items.size():
		at = posmod(at + d, items.size())
		if _open_item(at):
			break
	sel = at
	queue_redraw()


## Left and right flip a setting, or cross between the stops page's two lands.
func _side(d: int) -> void:
	var item: String = items[sel]
	if item == "Language" or item == "Fullscreen":
		choose(item)
	elif item.begins_with("stop:"):
		var at := sel + d * (Stops.LANDS[0][1] as int)
		if at >= 0 and at < Stops.ROAD.size() and _open_item(at):
			sel = at
			queue_redraw()


func _open_item(at: int) -> bool:
	var item: String = items[at]
	return not item.begins_with("stop:") or int(item.substr(5)) <= last_stop()


func choose(item: String) -> void:
	if item.begins_with("stop:"):
		chose.emit("stop", int(item.substr(5)))
		return
	match item:
		"Play", "Continue":
			chose.emit("play", 0)
		"New journey":
			open("confirm")
		"Yes, start again":
			chose.emit("restart_road", 0)
		"No":
			open("title")
		"Stops", "Controls", "Options":
			came_from = page
			open(item.to_lower())
		"Back":
			open(came_from)
		"Restart this stop":
			chose.emit("restart_stop", 0)
		"Language":
			chose.emit("language", 0)
			queue_redraw()
		"Fullscreen":
			chose.emit("fullscreen", 0)
			queue_redraw()
		"Quit":
			chose.emit("quit", 0)


## Esc, or a gamepad's B: the pause menu goes back to the game, a page within it goes back to it.
func back() -> void:
	match page:
		"pause":
			chose.emit("play", 0)
		"stops", "controls", "options":
			open(came_from)
		"confirm":
			open("title")


# ---- painting -----------------------------------------------------------------------------------


func _draw() -> void:
	if page == "":
		return
	if page != "splash":
		draw_rect(Rect2(Vector2.ZERO, SCREEN), VEIL)
	match page:
		"first", "title", "splash":
			_draw_title()
		"pause":
			_draw_pause()
		"stops":
			_draw_stops()
		"options":
			_draw_options()
		"controls":
			_draw_controls()
		"confirm":
			_draw_confirm()


## The title, and below it what the title page offers. The boot splash is the same card with nothing below.
func _draw_title() -> void:
	var box := _card(330.0 + items.size() * ROW - (60.0 if items.is_empty() else 0.0))
	_text(BOLD, TITLE_SIZE, tr("Day & Night"), box.get_center().x, box.position.y + 150, INK)
	_text(SEMI, SMALL_SIZE, tr("They have never been awake at the same time."), box.get_center().x, box.position.y + 218, SOFT)
	draw_texture_rect(sun, Rect2(box.position + Vector2(-34, -34), Vector2(112, 112)), false)
	draw_texture_rect(moon, Rect2(box.end.x - 78, box.position.y - 34, 112, 112), false)
	_list(box, box.position.y + 270)


func _draw_pause() -> void:
	var box := _card(250.0 + items.size() * ROW)
	_text(SEMI, SMALL_SIZE, tr("Stop %d") % (stop + 1), box.get_center().x, box.position.y + 86, SOFT)
	_text(BOLD, HEAD_SIZE, tr(Stops.ROAD[stop].name), box.get_center().x, box.position.y + 158, INK)
	_list(box, box.position.y + 200)


func _draw_stops() -> void:
	var rows: int = Stops.LANDS[0][1]
	var box := _card(246.0 + rows * 76.0 + 30.0 + ROW + 40.0)
	_text(BOLD, HEAD_SIZE, tr("Stops"), box.get_center().x, box.position.y + 108, INK)
	var first := 0
	for land in Stops.LANDS.size():
		var left := box.get_center().x + (land - 0.5) * (COLUMN + 20) - COLUMN / 2.0
		_text(SEMI, SMALL_SIZE, tr(Stops.LANDS[land][0]), left + COLUMN / 2.0, box.position.y + 186, SOFT)
		var count: int = Stops.LANDS[land][1]
		for row in count:
			var i := first + row
			var mid := box.position.y + 246 + row * 76.0
			var open_stop := i <= last_stop()
			if i == sel:
				draw_style_box(pick, Rect2(left, mid - PICK_H / 2, COLUMN, PICK_H))
			var colour := INK if i == sel else (SOFT if open_stop else FAINT)
			var y := _baseline(SEMI, STOP_SIZE, mid)
			_text(SEMI, STOP_SIZE, str(i + 1), left + 50, y, colour)
			var label: String = tr(Stops.ROAD[i].name) if open_stop else "· · ·"
			draw_string(SEMI, Vector2(left + STOP_NAME_X, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, STOP_SIZE, colour)
		first += count
	_item(items.size() - 1, box.get_center().x, box.position.y + 246 + rows * 76.0 + 30.0)


func _draw_options() -> void:
	var box := _card(220.0 + items.size() * ROW)
	_text(BOLD, HEAD_SIZE, tr("Options"), box.get_center().x, box.position.y + 108, INK)
	var left := box.position.x + MARGIN
	var right := box.end.x - MARGIN
	for i in items.size():
		var mid := box.position.y + 170 + i * ROW + ROW / 2
		var item: String = items[i]
		if item == "Back":
			_item(i, box.get_center().x, mid - ROW / 2)
			continue
		if i == sel:
			draw_style_box(pick, Rect2(left - 30, mid - PICK_H / 2, right - left + 60, PICK_H))
		var colour := INK if i == sel else SOFT
		var y := _baseline(SEMI, ITEM_SIZE, mid)
		draw_string(SEMI, Vector2(left, y), tr(item), HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_SIZE, colour)
		var value := setting(item)
		if i == sel:
			value = "‹  %s  ›" % value
		draw_string(SEMI, Vector2(right - _width(SEMI, ITEM_SIZE, value), y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_SIZE, colour)


## What a setting is set to, as the options page shows it. Languages go by their own names.
func setting(item: String) -> String:
	if item == "Language":
		return "Italiano" if TranslationServer.get_locale().begins_with("it") else "English"
	return tr("On") if progress != null and progress.fullscreen else tr("Off")


## The controls page's lines: what it does, then Marta's keys, Giulio's keys and a gamepad's. One key
## that has a painted cap shows as the cap.
func control_rows() -> Array:
	return [
		[tr("Move"), "A  D", tr("Left  Right"), tr("Stick or D-pad")],
		[tr("Jump"), "W", tr("Up"), "A"],
		[tr("Paint, or use a tool"), "E", "K", "X"],
		[tr("Wash, or aim"), "R", "L", "B"],
		[tr("Next colour or tool"), "Q", "J", "LB"],
		[tr("Drive the house, ring its bell"), "F", "I", "Y"],
		[tr("Pause"), "Esc", "Esc", "Start"],
	]


## Where the controls page's columns sit, from the card's left edge: the first is where the
## descriptions start, and the rest are the middles of the key columns.
const CONTROL_X: Array[float] = [MARGIN, 900.0, 1140.0, 1410.0]
const CONTROL_ROW := 66.0


func _draw_controls() -> void:
	var rows := control_rows()
	var box := _card(230.0 + rows.size() * CONTROL_ROW + 30.0 + ROW + 30.0)
	_text(BOLD, HEAD_SIZE, tr("Controls"), box.get_center().x, box.position.y + 108, INK)
	var heads := ["", "Marta", "Giulio", tr("Gamepad")]
	for c in range(1, 4):
		_text(SEMI, SMALL_SIZE, heads[c], box.position.x + CONTROL_X[c], box.position.y + 180, SOFT)
	for r in rows.size():
		var mid := box.position.y + 236 + r * CONTROL_ROW
		var y := _baseline(SEMI, SMALL_SIZE + 4, mid)
		draw_string(SEMI, Vector2(box.position.x + CONTROL_X[0], y), rows[r][0], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE + 4, INK)
		for c in range(1, 4):
			var cell: String = rows[r][c]
			var x := box.position.x + CONTROL_X[c]
			if cell in Stage.CAPS:
				var cap := Stage.cap_rect(cell)
				draw_texture_rect_region(keys, Rect2(x - 29, mid - 29, 58, 58), cap)
			else:
				_text(SEMI, SMALL_SIZE, cell, x, y, INK)
	_item(0, box.get_center().x, box.position.y + 236 + rows.size() * CONTROL_ROW - CONTROL_ROW / 2 + 30.0)


func _draw_confirm() -> void:
	var question := tr("Start the journey again from the first stop?")
	var width: float = WIDTH[page] - 2 * MARGIN
	var lines := 1 if _width(BOLD, 52, question) <= width else 2
	var note := 110.0 + 66.0 * lines + 20.0
	var box := _card(note + 50.0 + items.size() * ROW + 40.0)
	draw_multiline_string(BOLD, Vector2(box.position.x + MARGIN, box.position.y + 120), question,
			HORIZONTAL_ALIGNMENT_CENTER, width, 52, 2, INK)
	_text(SEMI, SMALL_SIZE, tr("The stops you have reached will be locked again."), box.get_center().x, box.position.y + note, SOFT)
	_list(box, box.position.y + note + 40.0)


## The card, centred, as tall as the page needs.
func _card(height: float) -> Rect2:
	var width: float = WIDTH[page]
	var box := Rect2((SCREEN.x - width) / 2.0, (SCREEN.y - height) / 2.0, width, height)
	draw_style_box(card, box)
	return box


func _list(box: Rect2, top: float) -> void:
	for i in items.size():
		_item(i, box.get_center().x, top + i * ROW)


## One line of a list, centred, with the yellow stroke behind it when it's chosen.
func _item(i: int, x: float, top: float) -> void:
	var text := tr(items[i])
	var mid := top + ROW / 2
	if i == sel:
		var w := maxf(_width(SEMI, ITEM_SIZE, text) + 110.0, 380.0)
		draw_style_box(pick, Rect2(x - w / 2, mid - PICK_H / 2, w, PICK_H))
	_text(SEMI, ITEM_SIZE, text, x, _baseline(SEMI, ITEM_SIZE, mid), INK if i == sel else SOFT)


func _text(font: Font, size: int, text: String, x: float, baseline: float, colour: Color) -> void:
	draw_string(font, Vector2(x - _width(font, size, text) / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


static func _width(font: Font, size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## The baseline that puts a line's capitals in the middle of a row.
static func _baseline(font: Font, size: int, mid: float) -> float:
	return mid + (font.get_ascent(size) - font.get_descent(size)) / 2.0 - size * 0.06
