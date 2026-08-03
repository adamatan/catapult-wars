class_name FireButton
extends Button

## The crimson plaque with the eagle pediment. A real Button underneath, so it
## keeps focus, keyboard activation and disabled state; everything visible is
## drawn on top of a stripped theme.

## The word struck across the plaque. The title and game-over screens reuse the
## same plaque with different wording.
@export var label := "FIRE":
	set(v):
		label = v
		queue_redraw()

## Point size of that word; smaller for longer labels.
@export var label_size := 62:
	set(v):
		label_size = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(400, 250)
	focus_mode = Control.FOCUS_NONE
	text = ""
	for slot in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(slot, StyleBoxEmpty.new())

func _draw() -> void:
	var pediment_height := 46.0
	var plaque := Rect2(Vector2(8, pediment_height + 6),
		Vector2(size.x - 16, size.y - pediment_height - 34))

	var live := not disabled
	# Darken via modulate rather than multiplying every draw colour, which would
	# eat alpha and dissolve the plaque instead of greying it out.
	modulate = Color.WHITE if live else Color(0.46, 0.44, 0.42)
	var face := RomanStyle.CRIMSON
	if live and button_pressed:
		face = RomanStyle.CRIMSON_DARK
	elif live and is_hovered():
		face = RomanStyle.CRIMSON_BRIGHT

	# Pediment: a stone crown with the aquila, as on the mockups' fire plaque.
	var crown := Rect2(Vector2(plaque.position.x + 40, 4),
		Vector2(plaque.size.x - 80, pediment_height))
	draw_colored_polygon(PackedVector2Array([
		crown.position + Vector2(0, crown.size.y),
		crown.position + Vector2(crown.size.x * 0.5, 0),
		crown.end,
	]), RomanStyle.STONE_LIGHT)
	RomanStyle.aquila(self, crown.get_center() + Vector2(0, 6), 34.0,
		RomanStyle.GOLD_DARK.lightened(0.25))

	# Plaque
	draw_rect(plaque.grow(4.0), RomanStyle.GOLD_DARK)
	draw_rect(plaque, face)
	draw_rect(Rect2(plaque.position + Vector2(0, 4), Vector2(plaque.size.x, plaque.size.y * 0.28)),
		face.lightened(0.12))
	RomanStyle._rect_outline(self, plaque.grow(-6.0), RomanStyle.GOLD, 2.0)

	var centre := plaque.get_center()

	# Flanking laurels, but only when the word leaves room for them. A long
	# label like "NEW NAMES" otherwise runs straight through the leaves.
	var tracking := 8.0
	var text_width := RomanStyle.DISPLAY_FONT.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x + tracking * (label.length() - 1)
	var laurel_radius := 44.0
	var room := (plaque.size.x - text_width) * 0.5 - 26.0
	if room >= laurel_radius * 2.0:
		var offset := text_width * 0.5 + laurel_radius + 34.0
		RomanStyle.laurel(self, centre + Vector2(-offset, 0), laurel_radius, RomanStyle.GOLD, 2.4)
		RomanStyle.laurel(self, centre + Vector2(offset, 0), laurel_radius, RomanStyle.GOLD, 2.4)

	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, centre, label, label_size,
		RomanStyle.PARCHMENT, tracking)
