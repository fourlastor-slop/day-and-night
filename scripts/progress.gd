class_name Progress
extends RefCounted
## Everything the game keeps between plays, in one file: the stop the road is on, the furthest stop
## the kids have reached, their settings, and the stop in play exactly as they left it.

## Bump it when what a saved stop holds changes, so an old one is set aside instead of loaded wrong.
const FORMAT := 1

var path: String
var _file := ConfigFile.new()

## The stop the road is on.
var stop: int:
	get:
		return _index("road", "stop")
	set(value):
		_file.set_value("road", "stop", value)

## The furthest stop the kids have got to, and so the last one they can pick from the stops.
var reached: int:
	get:
		return _index("road", "reached")
	set(value):
		_file.set_value("road", "reached", value)

## "it" or "en", or "" to follow the computer's language.
var language: String:
	get:
		var value: Variant = _file.get_value("settings", "language", "")
		return value if value is String and value in ["", "it", "en"] else ""
	set(value):
		_file.set_value("settings", "language", value)

var fullscreen: bool:
	get:
		return _file.get_value("settings", "fullscreen", false) == true
	set(value):
		_file.set_value("settings", "fullscreen", value)


func _init(at: String) -> void:
	path = at
	# A missing or unreadable file is a new road.
	if _file.load(path) != OK:
		_file = ConfigFile.new()


## Whether the kids have set off yet, so the title offers to carry on.
func started() -> bool:
	return _file.has_section("road") or _file.has_section("snapshot")


## The stop in play as the kids left it, if it's this stop and its map hasn't changed since: an
## update that reshapes a stop starts it afresh instead of loading the old one wrong.
func snapshot(index: int) -> Dictionary:
	var at: Variant = _file.get_value("snapshot", "stop", -1)
	if not (at is int) or at != index or _file.get_value("snapshot", "key", "") != _key(index):
		return {}
	var state: Variant = _file.get_value("snapshot", "state", {})
	return state if state is Dictionary else {}


## Saves the stop in play.
func keep(index: int, sim: Sim) -> void:
	_file.set_value("snapshot", "stop", index)
	_file.set_value("snapshot", "key", _key(index))
	_file.set_value("snapshot", "state", sim.to_save())
	save()


func forget() -> void:
	if _file.has_section("snapshot"):
		_file.erase_section("snapshot")


## A new journey: back to the first stop with nothing reached. The settings stay.
func restart() -> void:
	for section in ["road", "snapshot"]:
		if _file.has_section(section):
			_file.erase_section(section)
	stop = 0
	reached = 0
	save()


func save() -> void:
	_file.save(path)


func _index(section: String, key: String) -> int:
	var value: Variant = _file.get_value(section, key, 0)
	return clampi(value, 0, Stops.ROAD.size() - 1) if value is int else 0


func _key(index: int) -> String:
	return "%d:%d" % [FORMAT, var_to_str(Stops.ROAD[index]).hash()]
