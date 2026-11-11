extends Node
## Plays every stop with bots driving the real tick(), and fails on anything that breaks a puzzle: the
## obvious answer has to fail, and the two kids together have to get through.

const CASES := ["controls", "rules", "lifts", "ropes", "light", "stone", "carts", "soots", "brook", "gully", "river", "cliff", "mouth", "rails", "hall", "tunnel", "saving"]


func _ready() -> void:
	var failed := 0
	for name_: String in CASES:
		var case: Case = load("res://tests/stops/%s.gd" % name_).new()
		case.run()
		failed += case.failed
	print("stop: ", "FAILED %d" % failed if failed > 0 else "ok")
	get_tree().quit(1 if failed > 0 else 0)
