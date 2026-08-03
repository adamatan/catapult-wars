class_name PlayerBanner
extends Control

## One player's chip along the top of the screen: portrait coin, name plate,
## and a pip for each life left. The player whose turn it is grows slightly
## and picks up a gold glow, exactly as the active chip does in the mockups.

const BASE_SIZE := Vector2(250, 96)

var player: GameState.Player
var active := false:
	set(v):
		if active == v:
			return
		active = v
		_animate_scale()
		queue_redraw()

## Points to the left or the right; mirrors the plate's notch.
var point_right := true

var _scale := 1.0:
	set(v):
		_scale = v
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = BASE_SIZE * 0.5

func bind(p: GameState.Player) -> void:
	player = p
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _animate_scale() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_scale", 1.10 if active else 1.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Mirror a local point for banners on the right of the screen. The layout is
## authored once facing right and flipped here — drawing two hand-built
## variants is how the right-hand chip ended up overlapping its own coin.
func _m(v: Vector2) -> Vector2:
	return Vector2(v.x if point_right else -v.x, v.y)

func _draw() -> void:
	if player == null:
		return

	draw_set_transform(BASE_SIZE * 0.5, 0.0, Vector2.ONE * _scale)

	var dead := not player.is_alive()
	var tint := player.color if not dead else player.color.darkened(0.55)
	var ink := RomanStyle.PARCHMENT if not dead else RomanStyle.PARCHMENT.darkened(0.4)
	var edge := RomanStyle.GOLD if active else RomanStyle.GOLD_DARK

	# Authored facing right: coin on the outside, plate running inward, notch
	# on the inner end pointing at the centre of the screen.
	var coin_at := _m(Vector2(-90, -8))
	var plate_left := -62.0
	var plate_right := 106.0
	var plate_centre := _m(Vector2((plate_left + plate_right) * 0.5, -8))

	if active:
		var glow_rect := Rect2(_m(Vector2(plate_left, -30)), Vector2(168, 44))
		if not point_right:
			glow_rect.position.x -= 168
		RomanStyle.glow(self, glow_rect, RomanStyle.GOLD_BRIGHT)

	var body := PackedVector2Array()
	for p: Vector2 in [
		Vector2(plate_left, -30),
		Vector2(plate_right, -30),
		Vector2(plate_right + 14, -8),   # notch
		Vector2(plate_right, 14),
		Vector2(plate_left, 14),
	]:
		body.append(_m(p))

	draw_colored_polygon(body, tint.darkened(0.3))
	draw_colored_polygon(_inset(body, 3.0), tint)
	draw_polyline(body + PackedVector2Array([body[0]]), edge, 2.5)

	RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT, plate_centre,
		player.name.to_upper(), 30, ink)

	# Lives below the plate, as struck-coin pips rather than a number — with
	# only a few to lose, "ASHES" versus "one left" reads faster as shapes than
	# as digits, and it survives the eventual four-player match without a
	# redesign, since it makes no assumption about MAX_LIVES beyond drawing one
	# pip per life.
	var lives_at := plate_centre + Vector2(0, 34)
	if dead:
		RomanStyle.text_centred(self, RomanStyle.NUMERAL_FONT, lives_at, "ASHES", 26,
			RomanStyle.CRIMSON_BRIGHT)
	else:
		_draw_lives(lives_at)

	# Portrait coin, overlapping the plate's outer edge.
	var coin_radius := 30.0
	RomanStyle.coin(self, coin_at, coin_radius,
		RomanStyle.GOLD if not dead else RomanStyle.GOLD.darkened(0.5))
	draw_arc(coin_at, coin_radius + 3.0, 0.0, TAU, 32,
		RomanStyle.GOLD_BRIGHT if active else RomanStyle.GOLD_DARK, 3.0)

## A row of small coins centred on `at`: filled gold for a life still held,
## dark and hollow for one already lost.
func _draw_lives(at: Vector2) -> void:
	var radius := 9.0
	var spacing := 24.0
	var total := GameState.MAX_LIVES
	var start_x := -spacing * float(total - 1) * 0.5
	for i in total:
		var pip := at + Vector2(start_x + float(i) * spacing, 0)
		var lost := i >= player.lives
		RomanStyle.coin(self, pip, radius, RomanStyle.STONE_LIGHT if lost else RomanStyle.GOLD)
		if lost:
			draw_arc(pip, radius + 2.0, 0.0, TAU, 16, RomanStyle.STONE_DARK, 1.5)

## Shrink a convex-ish polygon toward its centroid, for the inner bevel.
func _inset(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= float(poly.size())
	var out := PackedVector2Array()
	for p in poly:
		var dir := (p - centroid)
		var length := dir.length()
		out.append(centroid + dir * maxf(0.0, length - amount) / maxf(length, 0.001))
	return out
