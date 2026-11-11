extends Node
## Every line the kids can read has an Italian version that fits where it's drawn, and English stays
## English. The lines are gathered from the source, the menus and the stops, so a new one can't be
## forgotten, and every line in the Italian file has to still be in use.
## run: godot --headless --path . res://tests/lang.tscn

const TR := "tr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)"
const PO := "res://data/lang/it.po"
## Lines that are the same in Italian.
const SAME := ["No"]

var fails := 0


func _ready() -> void:
	var ids := {}
	for path in scripts("res://scripts/"):
		gather(path, ids)
	for page: String in Menu.PAGES:
		for item: String in Menu.PAGES[page]:
			ids[item] = true
	for stop: Dictionary in Stops.ROAD:
		ids[stop.name] = true
	for land: Array in Stops.LANDS:
		ids[land[0]] = true
	for locale in ["en", "it"]:
		TranslationServer.set_locale(locale)
		translated(ids, locale == "it")
		fits(locale)
	unused(ids)
	TranslationServer.set_locale("en")
	print("lang: %d lines %s" % [ids.size(), "FAILED: %d" % fails if fails > 0 else "ok"])
	get_tree().quit(1 if fails > 0 else 0)


func scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(scripts(dir + d + "/"))
	return out


func gather(path: String, ids: Dictionary) -> void:
	var rx := RegEx.create_from_string(TR)
	for m in rx.search_all(FileAccess.get_file_as_string(path)):
		ids[m.get_string(1).replace("\\n", "\n").replace("\\\"", "\"")] = true


func translated(ids: Dictionary, italian: bool) -> void:
	for id: String in ids:
		var text := tr(id)
		if not italian and text != id:
			fail("English changed", id)
		elif italian and text == id and id not in SAME:
			fail("no Italian", id)
		elif italian and placeholders(id) != placeholders(text):
			fail("placeholders differ", id)


## Every line in the Italian file is one the game still shows.
func unused(ids: Dictionary) -> void:
	var rx := RegEx.create_from_string("(?m)^msgid \"(.+)\"$")
	for m in rx.search_all(FileAccess.get_file_as_string(PO)):
		if not ids.has(m.get_string(1)):
			fail("in it.po but not used", m.get_string(1))


func placeholders(s: String) -> Array[String]:
	var out: Array[String] = []
	for m in RegEx.create_from_string("%0?\\d*[ds]").search_all(s):
		out.append(m.get_string())
	return out


## Measured with the fonts and sizes the menus and the banner draw them in.
func fits(locale: String) -> void:
	var menu := Menu.new()
	for page: String in Menu.PAGES:
		for item: String in Menu.PAGES[page]:
			room(menu.tr(item), Menu.SEMI, Menu.ITEM_SIZE, Menu.WIDTH[page] - 2 * Menu.MARGIN, "%s menu" % page, locale)
	var inner: float = Menu.WIDTH["title"] - 2 * Menu.MARGIN
	room(menu.tr("Day & Night"), Menu.BOLD, Menu.TITLE_SIZE, inner, "title", locale)
	room(menu.tr("They have never been awake at the same time."), Menu.SEMI, Menu.SMALL_SIZE, inner, "title", locale)
	for i in Stops.ROAD.size():
		var name := menu.tr(Stops.ROAD[i].name)
		room(name, Menu.BOLD, Menu.HEAD_SIZE, Menu.WIDTH["pause"] - 2 * Menu.MARGIN, "pause header", locale)
		room(name, Menu.SEMI, Menu.STOP_SIZE, Menu.COLUMN - Menu.STOP_NAME_X - 30.0, "stops column", locale)
		# The banner shrinks its font to fit, but not below this.
		room(name, Menu.BOLD, 34, 460.0, "banner", locale)
		room("%s  ·  %s" % [menu.tr("Stop %d") % (i + 1), name], Menu.BOLD, 44, 1500.0, "stop's name", locale)
	room(menu.tr("Press A or Enter to go on"), Menu.SEMI, 28, 460.0, "banner", locale)
	for land: Array in Stops.LANDS:
		room(menu.tr(land[0]), Menu.SEMI, Menu.SMALL_SIZE, Menu.COLUMN, "stops column", locale)
	var confirm: float = Menu.WIDTH["confirm"] - 2 * Menu.MARGIN
	room(menu.tr("Start the journey again from the first stop?"), Menu.BOLD, 52, 2 * confirm * 0.85, "confirm, on two lines", locale)
	room(menu.tr("The stops you have reached will be locked again."), Menu.SEMI, Menu.SMALL_SIZE, confirm, "confirm", locale)
	# The options' rows: the setting's name on the left and its value, with the arrows, on the right.
	var options: float = Menu.WIDTH["options"] - 2 * Menu.MARGIN
	for item in ["Language", "Fullscreen"]:
		var both := "%s      ‹  %s  ›" % [menu.tr(item), "Italiano"]
		room(both, Menu.SEMI, Menu.ITEM_SIZE, options, "options", locale)
	# The controls' columns: the description up to the first key column, and each key column between
	# the middles of its neighbours.
	var x := Menu.CONTROL_X
	var ends := [x[1] - 60.0, (x[2] - x[1]) * 0.95, (x[2] - x[1]) * 0.95, (Menu.WIDTH["controls"] - Menu.MARGIN - x[3]) * 2.0]
	for row: Array in menu.control_rows():
		room(row[0], Menu.SEMI, Menu.SMALL_SIZE + 4, ends[0] - x[0], "controls", locale)
		for c in range(1, 4):
			if row[c] not in Stage.CAPS:
				room(row[c], Menu.SEMI, Menu.SMALL_SIZE, ends[c], "controls", locale)
	menu.free()


func room(text: String, font: Font, size: int, width: float, where: String, locale: String) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w <= 0.0:
		fail("not measured", text)
	elif w > width:
		fail("too wide for the %s in %s (%d of %d)" % [where, locale, w, width], text)


func fail(why: String, id: String) -> void:
	fails += 1
	print("  FAIL %s: %s" % [why, id.c_escape()])
