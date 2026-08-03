class_name TitleScreen
extends Control

## Name the two commanders and start. Colours are fixed per side for v1 —
## crimson for the left, imperial blue for the right.

signal start_requested(entries: Array)

const SIDES := [
	{"default_name": "Marcus", "colour": Color("#8f1f22"), "label": "LEFT FLANK"},
	{"default_name": "Victor", "colour": Color("#1f4e8f"), "label": "RIGHT FLANK"},
]

var _fields: Array[LineEdit] = []
var _plate: Texture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var field := FieldLibrary.random_field()
	if field != null:
		_plate = field.texture

	for i in SIDES.size():
		var side: Dictionary = SIDES[i]
		var entry := LineEdit.new()
		entry.text = side["default_name"]
		entry.max_length = 12
		entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.size = Vector2(340, 62)
		entry.position = Vector2(960 - 380 + i * 420, 560)
		entry.add_theme_font_override("font", RomanStyle.DISPLAY_FONT)
		entry.add_theme_font_size_override("font_size", 34)
		entry.add_theme_color_override("font_color", RomanStyle.PARCHMENT)
		entry.add_theme_color_override("caret_color", RomanStyle.GOLD)
		var box := StyleBoxFlat.new()
		box.bg_color = side["colour"].darkened(0.3)
		box.border_color = RomanStyle.GOLD_DARK
		box.set_border_width_all(2)
		box.content_margin_left = 12
		box.content_margin_right = 12
		entry.add_theme_stylebox_override("normal", box)
		entry.add_theme_stylebox_override("focus", box)
		add_child(entry)
		_fields.append(entry)

	# The fire plaque again, relabelled — same motif, one less thing to draw.
	var start := FireButton.new()
	start.label = "ADVANCE"
	start.label_size = 46
	start.size = Vector2(520, 220)
	start.position = Vector2(960 - 260, 700)
	start.pressed.connect(_on_start)
	add_child(start)

func _on_start() -> void:
	var entries: Array = []
	for i in SIDES.size():
		var name := _fields[i].text.strip_edges()
		if name.is_empty():
			name = SIDES[i]["default_name"]
		entries.append({"name": name, "colour": SIDES[i]["colour"]})
	start_requested.emit(entries)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), RomanStyle.STONE_DARK)

	if _plate != null:
		var plate_height := 1920.0 * _plate.get_height() / float(_plate.get_width())
		var plate_rect := Rect2(0, 0, 1920, plate_height)
		draw_texture_rect(_plate, plate_rect, false, Color(1, 1, 1, 0.8))
		# Fade the plate into the stone at both ends so it reads as a backdrop
		# rather than a banner pasted across the top.
		RomanStyle.fade_rect(self, Rect2(0, plate_height * 0.35, 1920, plate_height * 0.65),
			RomanStyle.STONE_DARK, 0.0, 1.0)
		RomanStyle.fade_rect(self, Rect2(0, 0, 1920, 90), RomanStyle.STONE_DARK, 0.85, 0.0)

	# Wreath around the eagle, clear of the title beneath it.
	RomanStyle.laurel(self, Vector2(960, 168), 118.0, RomanStyle.GOLD, 2.35)
	RomanStyle.aquila(self, Vector2(960, 138), 132.0, RomanStyle.GOLD)
	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, Vector2(960, 330),
		"ROMAN CATAPULTS", 86, RomanStyle.GOLD_BRIGHT, 10.0)
	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, Vector2(960, 410),
		"TWO COMMANDERS · ONE VALLEY", 28, RomanStyle.PARCHMENT, 6.0)

	for i in SIDES.size():
		var side: Dictionary = SIDES[i]
		var centre := Vector2(960 - 380 + i * 420 + 170, 520)
		RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, centre,
			side["label"], 24, RomanStyle.GOLD, 4.0)

	var help := [
		"MOUSE  drag the dial, the force bar and the step rule",
		"UP / DOWN  elevation      LEFT / RIGHT  force",
		"A / D  reposition      SPACE  loose the stone",
	]
	for i in help.size():
		RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT,
			Vector2(960, 950 + i * 34), help[i], 24, RomanStyle.PARCHMENT.darkened(0.25))
