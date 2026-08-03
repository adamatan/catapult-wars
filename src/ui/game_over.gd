class_name GameOverScreen
extends Control

## Victory overlay, laid over the finished battlefield so the last crater stays
## visible behind it.

signal rematch_requested()
signal title_requested()

var winner_name := ""
var winner_colour := RomanStyle.CRIMSON

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var again := FireButton.new()
	again.label = "AGAIN"
	again.label_size = 46
	again.size = Vector2(440, 200)
	again.position = Vector2(960 - 480, 806)
	again.pressed.connect(func() -> void: rematch_requested.emit())
	add_child(again)

	var back := FireButton.new()
	back.label = "NEW NAMES"
	back.label_size = 38
	back.size = Vector2(440, 200)
	back.position = Vector2(960 + 40, 806)
	back.pressed.connect(func() -> void: title_requested.emit())
	add_child(back)

func show_result(name: String, colour: Color) -> void:
	winner_name = name
	winner_colour = colour
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.05, 0.04, 0.03, 0.78))

	var plate := Rect2(660, 370, 600, 150)

	# The wreath has to be wider than the plate it frames, or its branches
	# disappear behind the tablet and only stray leaves show.
	# Wide enough to frame the tablet, but the branches have to close above the
	# buttons — a wreath is drawn from the bottom up, so its densest part is
	# exactly where a button row wants to sit.
	RomanStyle.laurel(self, Vector2(960, 402), 350.0, RomanStyle.GOLD, 2.35)
	RomanStyle.aquila(self, Vector2(960, 210), 130.0, RomanStyle.GOLD)

	draw_rect(plate.grow(6.0), RomanStyle.GOLD_DARK)
	draw_rect(plate, winner_colour.darkened(0.15))
	draw_rect(Rect2(plate.position + Vector2(0, 4), Vector2(plate.size.x, plate.size.y * 0.3)),
		winner_colour.lightened(0.10))
	RomanStyle._rect_outline(self, plate.grow(-8.0), RomanStyle.GOLD, 2.0)

	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT,
		plate.get_center(), winner_name.to_upper(), 72, RomanStyle.PARCHMENT, 8.0)
	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT,
		Vector2(960, plate.end.y + 46), "TRIUMPHS", 34, RomanStyle.GOLD_BRIGHT, 10.0)
