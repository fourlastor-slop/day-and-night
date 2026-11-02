class_name Pad
extends RefCounted
## One tick of one player's input. Polled from a gamepad or a side of the keyboard, or set directly
## by the test bots.

const DEADZONE := 0.45

var x := 0
var y := 0
var jump := false
var jump_p := false
var use_p := false
var alt := false
var alt_p := false
var next_p := false
var interact_p := false
var dir_p := Vector2i.ZERO

var _held := {}


func poll(keys: Dictionary, device: int) -> void:
	var left := _key(keys, "left") or _joy(device, JOY_BUTTON_DPAD_LEFT) or _axis(device, JOY_AXIS_LEFT_X) < -DEADZONE
	var right := _key(keys, "right") or _joy(device, JOY_BUTTON_DPAD_RIGHT) or _axis(device, JOY_AXIS_LEFT_X) > DEADZONE
	var up := _key(keys, "up") or _joy(device, JOY_BUTTON_DPAD_UP) or _axis(device, JOY_AXIS_LEFT_Y) < -DEADZONE
	var down := _key(keys, "down") or _joy(device, JOY_BUTTON_DPAD_DOWN) or _axis(device, JOY_AXIS_LEFT_Y) > DEADZONE
	x = int(right) - int(left)
	y = int(down) - int(up)
	dir_p = Vector2i(int(_edge("right", right)) - int(_edge("left", left)), int(_edge("down", down)) - int(_edge("up", up)))
	jump = _key(keys, "jump") or _joy(device, JOY_BUTTON_A)
	jump_p = _edge("jump", jump)
	use_p = _edge("use", _key(keys, "use") or _joy(device, JOY_BUTTON_X))
	alt = _key(keys, "alt") or _joy(device, JOY_BUTTON_B)
	alt_p = _edge("alt", alt)
	next_p = _edge("next", _key(keys, "next") or _joy(device, JOY_BUTTON_LEFT_SHOULDER) or _joy(device, JOY_BUTTON_RIGHT_SHOULDER))
	interact_p = _edge("interact", _key(keys, "interact") or _joy(device, JOY_BUTTON_Y))


func clear() -> void:
	x = 0
	y = 0
	jump = false
	jump_p = false
	use_p = false
	alt = false
	alt_p = false
	next_p = false
	interact_p = false
	dir_p = Vector2i.ZERO


func _key(keys: Dictionary, what: String) -> bool:
	return keys.has(what) and Input.is_physical_key_pressed(keys[what])


func _joy(device: int, button: JoyButton) -> bool:
	return device >= 0 and Input.is_joy_button_pressed(device, button)


func _axis(device: int, axis: JoyAxis) -> float:
	return Input.get_joy_axis(device, axis) if device >= 0 else 0.0


func _edge(what: String, now: bool) -> bool:
	var was: bool = _held.get(what, false)
	_held[what] = now
	return now and not was
