class_name ForceSlider
extends Control

## The crimson force bar: a stone track, a filled crimson channel, and a coin
## knob riding the fill edge.

signal power_changed(percent: float)

@export var value: float = 60.0:
	set(v):
		var clamped := clampf(v, 0.0, 100.0)
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

const TRACK_HEIGHT := 34.0
const KNOB_RADIUS := 21.0

func _ready() -> void:
	custom_minimum_size = Vector2(320, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _track() -> Rect2:
	var margin := KNOB_RADIUS + 6.0
	return Rect2(margin, size.y * 0.40 - TRACK_HEIGHT * 0.5,
		size.x - margin * 2.0, TRACK_HEIGHT)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_set_from_x(event.position.x)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()

func _set_from_x(x: float) -> void:
	var track := _track()
	var t := clampf((x - track.position.x) / track.size.x, 0.0, 1.0)
	var percent := t * 100.0
	if not is_equal_approx(percent, value):
		value = percent
		power_changed.emit(value)

func _draw() -> void:
	var track := _track()
	var t := value / 100.0

	# Channel
	draw_rect(track.grow(3.0), RomanStyle.STONE_DARK)
	draw_rect(track, RomanStyle.STONE_LIGHT)
	RomanStyle._rect_outline(self, track, RomanStyle.GOLD_DARK, 2.0)

	# Fill
	var fill := Rect2(track.position, Vector2(track.size.x * t, track.size.y))
	if fill.size.x > 1.0:
		draw_rect(fill, RomanStyle.CRIMSON)
		draw_rect(Rect2(fill.position + Vector2(0, 3), Vector2(fill.size.x, fill.size.y * 0.34)),
			RomanStyle.CRIMSON_BRIGHT)

	# Scale labels
	var label_y := track.end.y + 30.0
	for entry: Array in [[0.0, "0%"], [0.5, "50%"], [1.0, "100%"]]:
		var at := Vector2(track.position.x + track.size.x * entry[0], label_y)
		draw_line(Vector2(at.x, track.end.y + 4.0), Vector2(at.x, track.end.y + 11.0),
			RomanStyle.GOLD_DARK, 2.0)
		RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT, at, entry[1], 20,
			RomanStyle.GOLD)

	# Knob
	var knob := Vector2(track.position.x + track.size.x * t, track.get_center().y)
	RomanStyle.coin(self, knob, KNOB_RADIUS, RomanStyle.GOLD)

	# Readout
	RomanStyle.text_centred(self, RomanStyle.NUMERAL_FONT,
		Vector2(size.x * 0.5, size.y - 24.0), "%d%%" % int(round(value)), 46,
		RomanStyle.GOLD_BRIGHT)
