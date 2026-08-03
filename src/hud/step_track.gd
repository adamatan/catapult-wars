class_name StepTrack
extends Control

## The repositioning track: a notched rule from -3 to +3 with a coin marker and
## a pair of stone arrow keys.
##
## The catapult moves as soon as the marker does, so the player can see the new
## firing position before committing — but the allowance is measured from where
## the turn began, so shuffling back and forth costs nothing and can't be used
## to walk across the map.

signal steps_changed(steps: int)

const MAX_STEPS := GameState.MAX_STEPS

@export var value: int = 0:
	set(v):
		var clamped := clampi(v, -MAX_STEPS, MAX_STEPS)
		if clamped == value:
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

var _hovered_button := 0  ## -1 left, +1 right, 0 none

func _ready() -> void:
	custom_minimum_size = Vector2(360, 250)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _rule() -> Rect2:
	var margin := 34.0
	return Rect2(margin, size.y * 0.34, size.x - margin * 2.0, 2.0)

func _notch_position(step: int) -> Vector2:
	var rule := _rule()
	var t := (float(step) + MAX_STEPS) / float(MAX_STEPS * 2)
	return Vector2(rule.position.x + rule.size.x * t, rule.position.y)

func _arrow_rect(direction: int) -> Rect2:
	var w := 78.0
	var h := 46.0
	var y := size.y - 108.0
	var x := size.x * 0.5 + (-w - 30.0 if direction < 0 else 30.0)
	return Rect2(x, y, w, h)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		var was := _hovered_button
		_hovered_button = 0
		for d in [-1, 1]:
			if _arrow_rect(d).has_point(event.position):
				_hovered_button = d
		if was != _hovered_button:
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for d in [-1, 1]:
			if _arrow_rect(d).has_point(event.position):
				_apply(value + d)
				accept_event()
				return
		# Clicking anywhere along the rule snaps to the nearest notch.
		var rule := _rule()
		if absf(event.position.y - rule.position.y) < 60.0:
			var t := clampf((event.position.x - rule.position.x) / rule.size.x, 0.0, 1.0)
			_apply(int(round(t * MAX_STEPS * 2)) - MAX_STEPS)
			accept_event()

func _apply(steps: int) -> void:
	var clamped := clampi(steps, -MAX_STEPS, MAX_STEPS)
	if clamped == value:
		return
	value = clamped
	steps_changed.emit(value)

func _caption() -> String:
	if value == 0:
		return "HOLD POSITION"
	var word := "STEP" if absi(value) == 1 else "STEPS"
	return "%s %d %s" % ["LEFT" if value < 0 else "RIGHT", absi(value), word]

func _draw() -> void:
	var rule := _rule()

	draw_line(rule.position, Vector2(rule.end.x, rule.position.y),
		RomanStyle.GOLD_DARK, 2.0)

	for step in range(-MAX_STEPS, MAX_STEPS + 1):
		var at := _notch_position(step)
		var major := step == 0 or absi(step) == MAX_STEPS
		draw_line(at - Vector2(0, 11.0 if major else 7.0), at + Vector2(0, 11.0 if major else 7.0),
			RomanStyle.GOLD, 2.0)
		RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT, at - Vector2(0, 34.0),
			str(step), 22, (RomanStyle.GOLD_BRIGHT if step == value else RomanStyle.GOLD))

	RomanStyle.coin(self, _notch_position(value), 19.0, RomanStyle.GOLD)

	for d in [-1, 1]:
		_draw_arrow_button(d)

	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT,
		Vector2(size.x * 0.5, size.y - 32.0), _caption(), 24,
		RomanStyle.GOLD_BRIGHT, 2.0)

func _draw_arrow_button(direction: int) -> void:
	var rect := _arrow_rect(direction)
	var at_limit := (direction < 0 and value <= -MAX_STEPS) or (direction > 0 and value >= MAX_STEPS)
	var face := RomanStyle.STONE_LIGHT
	if at_limit:
		face = RomanStyle.STONE
	elif _hovered_button == direction and interactive:
		face = RomanStyle.STONE_LIGHT.lightened(0.18)

	draw_rect(rect, face)
	RomanStyle._rect_outline(self, rect, RomanStyle.GOLD_DARK, 2.0)

	var tint := (RomanStyle.GOLD_DARK if at_limit else RomanStyle.GOLD_BRIGHT)
	# The arrow points the way the button moves the machine: tip on the side the
	# direction names, shaft trailing behind it.
	var c := rect.get_center()
	var s := 15.0
	var d := float(direction)
	var tip := c + Vector2(s * d, 0.0)
	var tail := c - Vector2(s * d, 0.0)
	draw_line(tail, tip, tint, 4.0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip - Vector2(s * d * 0.55, -9.0),
		tip - Vector2(s * d * 0.55, 9.0),
	]), tint)
