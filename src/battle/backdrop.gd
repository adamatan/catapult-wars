class_name Backdrop
extends Node2D

## The painted scene behind the battlefield.
##
## The reference mockups are flat renders, so only a narrow horizon band could
## be salvaged from them (see scripts/make_backdrops.py). Rather than stretch
## that band over the whole screen and watch it go soft, it sits at its own
## scale between a procedural sky above and a haze fade below, both tinted from
## colours sampled out of the plate itself. The seams disappear.

const PLATE_TOP := 96.0
const FIELD_WIDTH := Terrain.WIDTH
const FIELD_HEIGHT := 1080.0
## How far up from the plate's bottom edge it dissolves into the haze. Without
## this the crop's own bottom row lands as a hard horizontal rule across the
## screen, which is exactly what it looks like: a cut.
const PLATE_FADE := 92.0

var _sky := Sprite2D.new()
var _plate := Sprite2D.new()
var _plate_fade := Sprite2D.new()
var _haze := Sprite2D.new()

func _ready() -> void:
	for s in [_sky, _plate, _plate_fade, _haze]:
		s.centered = false
		add_child(s)

func set_field(field: FieldLibrary.Field) -> void:
	if field == null:
		return
	if not is_inside_tree():
		await ready

	var plate_height := FIELD_WIDTH * field.texture.get_height() / float(field.texture.get_width())

	_sky.texture = _vertical_gradient(field.sky_color.darkened(0.34), field.sky_color)
	_sky.position = Vector2.ZERO
	_sky.scale = Vector2(FIELD_WIDTH / 4.0, PLATE_TOP / 256.0)

	_plate.texture = field.texture
	_plate.position = Vector2(0, PLATE_TOP)
	_plate.scale = Vector2(FIELD_WIDTH / float(field.texture.get_width()),
		plate_height / float(field.texture.get_height()))

	var haze_top := PLATE_TOP + plate_height

	# Dissolve the bottom of the plate into the haze colour so the crop's edge
	# stops being a visible line.
	_plate_fade.texture = _vertical_gradient(
		Color(field.haze_color, 0.0), Color(field.haze_color, 1.0))
	_plate_fade.position = Vector2(0, haze_top - PLATE_FADE)
	_plate_fade.scale = Vector2(FIELD_WIDTH / 4.0, PLATE_FADE / 256.0)

	# The haze itself only has to cover the gap between the plate and the
	# terrain's lowest valleys, so it fades to the rock colour rather than
	# flooding the whole lower screen with flat brown.
	_haze.texture = _vertical_gradient(field.haze_color,
		field.haze_color.lerp(field.rock_color, 0.75).darkened(0.15))
	_haze.position = Vector2(0, haze_top)
	_haze.scale = Vector2(FIELD_WIDTH / 4.0, (Terrain.MAX_SURFACE_Y + 60.0 - haze_top) / 256.0)

func _vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex
