class_name AngleDial
extends Control

## The brass elevation dial: a semicircular sweep from 0° on the left, through
## 45° at the top, to 90° on the right, with a coin hub and a needle.
##
## The sweep direction is taken straight from the mockups. It is not how a real
## quadrant reads, but it is what the reference shows and it is legible.

signal angle_changed(degrees: float)

const MIN_ANGLE := 0.0
const MAX_ANGLE := 90.0
const DANGER_FROM := 0.78  ## fraction of the sweep marked red

@export var value: float = 45.0:
	set(v):
		var clamped := clampf(v, MIN_ANGLE, MAX_ANGLE)
		if is_equal_approx(clamped, value):
			return
		value = clamped
		queue_redraw()

var interactive := true:
	set(v):
		interactive = v
		# Darken rather than fade: multiplying every draw colour by a factor
		# eats alpha too, and the panel dissolves instead of greying out.
		modulate = Color.WHITE if v else Color(0.5, 0.48, 0.45)
		queue_redraw()

var _dragging := false

func _ready() -> void:
	custom_minimum_size = Vector2(300, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _hub() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.66)

func _radius() -> float:
	return minf(size.x * 0.36, size.y * 0.44)

## Sweep position 0..1 for an aim in degrees.
func _sweep(degrees: float) -> float:
	return (degrees - MIN_ANGLE) / (MAX_ANGLE - MIN_ANGLE)

## Point on the dial face at sweep position u. u=0 is due left, u=1 due right.
func _point(u: float, radius: float) -> Vector2:
	var theta := PI * (1.0 - u)
	return _hub() + Vector2(cos(theta), -sin(theta)) * radius

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_aim_at(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_aim_at(event.position)
		accept_event()

func _aim_at(local: Vector2) -> void:
	var delta := local - _hub()
	# Below the hub the dial has no face; clamp to the nearer end rather than
	# letting the needle jump across the whole sweep.
	var theta := atan2(-delta.y, delta.x)
	if theta < 0.0:
		theta = 0.0 if delta.x > 0.0 else PI
	var u := 1.0 - theta / PI
	var degrees := MIN_ANGLE + u * (MAX_ANGLE - MIN_ANGLE)
	if not is_equal_approx(degrees, value):
		value = degrees
		angle_changed.emit(value)

func _draw() -> void:
	var hub := _hub()
	var r := _radius()

	# Face
	draw_arc(hub, r, PI, TAU, 64, RomanStyle.GOLD_DARK.darkened(0.3), 16.0, true)
	draw_arc(hub, r, PI, TAU, 64, RomanStyle.GOLD, 9.0, true)
	# Red band over the steep end of the sweep.
	draw_arc(hub, r, PI + DANGER_FROM * PI, TAU, 24, RomanStyle.CRIMSON_BRIGHT, 9.0, true)

	# Ticks every 15°, longer at 0/45/90.
	for i in 7:
		var u := float(i) / 6.0
		var major := i % 3 == 0
		var inner := _point(u, r - (16.0 if major else 10.0))
		var outer := _point(u, r + (10.0 if major else 5.0))
		draw_line(inner, outer, RomanStyle.GOLD_BRIGHT, 3.0 if major else 2.0)

	# End and apex labels
	RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT,
		_point(0.0, r + 34.0), "0°", 20, RomanStyle.GOLD)
	RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT,
		_point(1.0, r + 34.0), "90°", 20, RomanStyle.GOLD)
	RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT,
		_point(0.5, r + 26.0), "45°", 20, RomanStyle.GOLD)

	# Needle
	var tip := _point(_sweep(value), r - 2.0)
	var back := _point(_sweep(value), -r * 0.16)
	draw_line(back, tip, RomanStyle.STONE_DARK, 8.0)
	draw_line(back, tip, RomanStyle.GOLD_BRIGHT, 4.0)

	# Hub coin sits on top of the needle's tail
	RomanStyle.coin(self, hub, r * 0.30, RomanStyle.GOLD)

	# Readout
	RomanStyle.text_centred(self, RomanStyle.NUMERAL_FONT,
		Vector2(size.x * 0.5, size.y - 24.0), "%d°" % int(round(value)), 46,
		RomanStyle.GOLD_BRIGHT)
