class_name TurnEmblem
extends Control

## The centrepiece: an eagle-crowned tablet in a laurel wreath naming whose
## turn it is and which round the match is on.

const BASE_SIZE := Vector2(300, 150)

var title := ""
var subtitle := ""
var tint := RomanStyle.CRIMSON

func _ready() -> void:
	custom_minimum_size = BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_turn(player_name: String, round_number: int, colour: Color) -> void:
	title = player_name.to_upper()
	subtitle = "TURN %d" % round_number
	tint = colour
	queue_redraw()

func _draw() -> void:
	var plate := Rect2(Vector2(46, 34), Vector2(BASE_SIZE.x - 92, 62))

	# Wreath first, sized to frame the plate rather than sit under it.
	RomanStyle.laurel(self, plate.get_center() + Vector2(0, 2), 96.0, RomanStyle.GOLD, 2.2)
	RomanStyle.aquila(self, Vector2(BASE_SIZE.x * 0.5, 22), 46.0, RomanStyle.GOLD)

	draw_rect(plate.grow(4.0), RomanStyle.GOLD_DARK)
	draw_rect(plate, tint.darkened(0.15))
	draw_rect(Rect2(plate.position + Vector2(0, 3), Vector2(plate.size.x, plate.size.y * 0.3)),
		tint.lightened(0.10))
	RomanStyle._rect_outline(self, plate.grow(-5.0), RomanStyle.GOLD, 2.0)

	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, plate.get_center(),
		title, 38, RomanStyle.PARCHMENT, 3.0)

	var strip := Rect2(Vector2(BASE_SIZE.x * 0.5 - 62, plate.end.y + 6), Vector2(124, 32))
	draw_rect(strip, RomanStyle.STONE)
	RomanStyle._rect_outline(self, strip, RomanStyle.GOLD_DARK, 2.0)
	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, strip.get_center(),
		subtitle, 22, RomanStyle.PARCHMENT, 2.0)
