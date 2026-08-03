class_name Catapult
extends Node2D

## A Roman onager, drawn rather than sprited.
##
## The origin sits where the wheels meet the ground, so placing one is just
## "put it on the terrain surface at x". Horizontal mirroring is done with
## scale.x, which means every measurement below can assume it faces right.

const WHEEL_RADIUS := 20.0
const PIVOT := Vector2(-6.0, -54.0)
const ARM_LENGTH := 88.0
const HIT_RADIUS := 36.0     ## how close a shot must land to count as a direct hit
const FALL_SPEED := 320.0    ## px/s the machine drops when the ground goes away
const BODY_OFFSET := Vector2(0, -38)  ## middle of the machine, for blast distance

const WOOD := Color("#6b4a2a")
const WOOD_DARK := Color("#4a3119")
const WOOD_LIGHT := Color("#8a6338")
const WOOD_GLOW := Color("#c9924f")   ## grain highlight, catching the sky
const IRON := Color("#4c4a47")
const IRON_DARK := Color("#302f2c")
const IRON_LIGHT := Color("#8a8a86")  ## cold specular on iron, warm wood has none
const ROPE := Color("#9a8568")
const ROPE_DARK := Color("#6e5c46")
const LEATHER := Color("#5a3a28")
const LEATHER_DARK := Color("#3a2418")
const STONE_SHOT := Color("#8b8478")
const STONE_SHOT_DARK := Color("#5f594e")

var player: GameState.Player
var terrain: Terrain

var base_x: float = 0.0     ## where this turn started; steps are measured from here
var step_offset: int = 0    ## -MAX_STEPS..MAX_STEPS

var _recoil := 0.0          ## extra arm angle during the firing animation
var _ground_angle := 0.0

func setup(p: GameState.Player, t: Terrain, start_x: float) -> void:
	player = p
	terrain = t
	base_x = start_x
	position = Vector2(start_x, t.height_at(start_x))
	# Mirror before sampling the slope: the ground angle is negated for the
	# flipped machine, so reading it first starts it leaning the wrong way.
	scale.x = signf(p.facing)
	_ground_angle = _sample_ground_angle()
	rotation = _ground_angle

func _process(delta: float) -> void:
	if terrain == null:
		return
	# Follow the ground: fall into craters, but never sink through the surface.
	var target := terrain.height_at(position.x)
	if position.y < target:
		position.y = minf(target, position.y + FALL_SPEED * delta)
	else:
		position.y = target
	_ground_angle = lerpf(_ground_angle, _sample_ground_angle(), minf(1.0, delta * 8.0))
	rotation = _ground_angle
	queue_redraw()

func _sample_ground_angle() -> float:
	# Clamped so a machine on a cliff edge leans rather than capsizes.
	return clampf(terrain.slope_at(position.x), -0.45, 0.45) * signf(scale.x)

## The lean the machine currently sits at, signed for Ballistics.tilted_angle_deg:
## positive when the ground falls away in the direction this catapult fires.
## Same value as `rotation` — this just names it for the caller.
func ground_tilt() -> float:
	return _ground_angle

## Reposition within this turn's step allowance.
func set_step_offset(steps: int) -> void:
	step_offset = clampi(steps, -GameState.MAX_STEPS, GameState.MAX_STEPS)
	var x := base_x + float(step_offset) * GameState.STEP_PIXELS
	position.x = clampf(x, 70.0, Terrain.WIDTH - 70.0)

## Called at the end of a turn: wherever the machine ended up is the new home.
func commit_position() -> void:
	base_x = position.x
	step_offset = 0

## Tip of the throwing arm, in the battlefield's coordinate space.
##
## Battlefield space, not global: the battlefield node itself gets jogged about
## during screen shake, so anything mixing global positions with terrain and
## projectile coordinates would drift by the shake offset.
func muzzle() -> Vector2:
	return transform * _arm_tip()

## The point a blast is measured against — the middle of the machine rather
## than the patch of ground it stands on. Battlefield space, as above.
func body_centre() -> Vector2:
	return position + BODY_OFFSET

func _arm_tip() -> Vector2:
	var a := deg_to_rad(clampf(player.angle + _recoil, -20.0, 90.0))
	return PIVOT + Vector2(cos(a), -sin(a)) * ARM_LENGTH

## Snap the arm forward. Purely cosmetic — the shot has already left.
func play_fire() -> void:
	_recoil = -46.0
	var tween := create_tween()
	tween.tween_property(self, "_recoil", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if player == null:
		return

	var pennant := player.color

	# --- ground contact shadow, so the machine reads as sitting on the slope
	# rather than floating above it ---
	draw_set_transform(Vector2(-4, 2), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 58.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- legion standard planted behind the machine ---
	draw_line(Vector2(-62, 4), Vector2(-62, -146), WOOD_DARK, 5.0)
	draw_line(Vector2(-63, 4), Vector2(-63, -146), WOOD_GLOW, 1.0)
	RomanStyle.aquila(self, Vector2(-62, -156), 26.0, RomanStyle.GOLD)
	var cloth := PackedVector2Array([
		Vector2(-62, -138), Vector2(-14, -130), Vector2(-22, -108),
		Vector2(-14, -86), Vector2(-62, -80),
	])
	draw_colored_polygon(cloth, pennant)
	draw_polyline(cloth + PackedVector2Array([cloth[0]]), RomanStyle.GOLD_DARK, 2.0)
	RomanStyle.laurel(self, Vector2(-40, -109), 13.0, RomanStyle.GOLD, 2.4)

	# --- wheels ---
	for wheel_x: float in [-34.0, 34.0]:
		_draw_wheel(Vector2(wheel_x, -WHEEL_RADIUS))

	# --- frame: a heavy sled slung between the axles ---
	var frame := PackedVector2Array([
		Vector2(-52, -18), Vector2(52, -18), Vector2(40, -50), Vector2(-40, -50),
	])
	draw_colored_polygon(frame, WOOD)
	# Plank seams, so the sled reads as boards rather than a slab.
	draw_line(Vector2(-48, -30), Vector2(48, -30), WOOD_DARK, 1.5)
	draw_line(Vector2(-45, -40), Vector2(43, -40), WOOD_DARK, 1.5)
	draw_polyline(frame + PackedVector2Array([frame[0]]), WOOD_DARK, 3.0)
	draw_line(Vector2(-44, -34), Vector2(44, -34), WOOD_GLOW, 3.0)
	# Riveted iron corner brackets, not a bare diagonal strap.
	for strap_x: float in [-24.0, 0.0, 24.0]:
		var top := Vector2(strap_x * 0.82, -50)
		var bottom := Vector2(strap_x, -18)
		draw_line(bottom, top, IRON_DARK, 3.5)
		draw_line(bottom, top, IRON, 1.6)
		draw_circle(top, 2.2, IRON_LIGHT)
		draw_circle(bottom, 2.2, IRON_LIGHT)

	# --- the A-frame the arm swings against ---
	draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), WOOD_DARK, 10.0)
	draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), WOOD, 6.0)
	draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), WOOD_DARK, 10.0)
	draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), WOOD, 6.0)
	draw_line(Vector2(-20, -66), Vector2(18, -66), WOOD_DARK, 4.0)
	draw_line(Vector2(-20, -66), Vector2(18, -66), WOOD_GLOW, 1.2)

	# --- torsion bundle: the twisted rope that drives the arm ---
	var bundle_c := PIVOT + Vector2(8, 8)
	draw_circle(bundle_c, 13.0, ROPE_DARK)
	for i in 9:
		var a := PI * float(i) / 9.0
		var col := ROPE if i % 2 == 0 else ROPE_DARK
		draw_line(bundle_c + Vector2(cos(a), sin(a)) * 12.0,
			bundle_c - Vector2(cos(a), sin(a)) * 12.0, col, 2.0)
	draw_arc(bundle_c, 13.5, 0.0, TAU, 22, IRON_DARK, 2.5)
	draw_arc(bundle_c, 13.5, PI * 0.15, PI * 0.55, 6, IRON_LIGHT, 1.2)

	# --- throwing arm and sling ---
	_draw_arm()

## A wheel with a bit of depth: rim highlight, tapered spokes, riveted hub —
## the flat disc-and-spokes original read as a wagon icon rather than a wheel.
func _draw_wheel(c: Vector2) -> void:
	draw_circle(c, WHEEL_RADIUS, WOOD_DARK)
	draw_circle(c, WHEEL_RADIUS - 4.0, WOOD)
	draw_arc(c, WHEEL_RADIUS - 4.5, -PI * 0.75, -PI * 0.15, 10, WOOD_GLOW, 1.4)
	for spoke in 6:
		var a := TAU * spoke / 6.0
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		var poly := PackedVector2Array([
			c + side * 2.2, c + dir * (WHEEL_RADIUS - 5.0) + side * 1.0,
			c + dir * (WHEEL_RADIUS - 5.0) - side * 1.0, c - side * 2.2,
		])
		draw_colored_polygon(poly, WOOD_DARK)
	for spoke in 6:
		var a := TAU * spoke / 6.0 + 0.30
		draw_circle(c + Vector2(cos(a), sin(a)) * (WHEEL_RADIUS - 3.0), 1.3, IRON_DARK)
	draw_circle(c, 6.5, IRON_DARK)
	draw_circle(c, 5.0, IRON)
	draw_circle(c - Vector2(1.2, 1.2), 1.8, IRON_LIGHT)

## The throwing arm: a tapered shaft (wider at the pivot, narrower at the tip,
## which is what makes it read as a beam under load rather than a wire), iron
## collars binding it, and a leather sling cradling a stone — always shown
## loaded and ready, rather than an empty hook.
func _draw_arm() -> void:
	var tip := _arm_tip()
	var dir := (tip - PIVOT).normalized()
	var perp := dir.orthogonal()

	var shaft := PackedVector2Array([
		PIVOT + perp * 6.0, PIVOT - perp * 6.0, tip - perp * 3.0, tip + perp * 3.0,
	])
	draw_colored_polygon(shaft, WOOD_DARK)
	var inner := PackedVector2Array([
		PIVOT + perp * 4.0, PIVOT - perp * 4.0, tip - perp * 1.8, tip + perp * 1.8,
	])
	draw_colored_polygon(inner, WOOD)
	draw_line(PIVOT + perp * 1.5, tip + perp * 0.6, WOOD_GLOW, 1.4)

	for t in [0.35, 0.68]:
		var at := PIVOT.lerp(tip, t)
		var w := lerpf(5.2, 2.6, t)
		draw_line(at - perp * w, at + perp * w, IRON_DARK, 2.2)

	draw_circle(PIVOT, 7.0, IRON_DARK)
	draw_circle(PIVOT, 5.0, IRON)
	draw_circle(PIVOT - Vector2(1, 1), 1.6, IRON_LIGHT)

	# Sling: a leather cradle wrapped around the back of the stone — the side
	# toward the pivot — with two cords running from its ends to the arm.
	# Drawing the stone last, on top, is what makes the wrap read as a pouch
	# holding a load rather than a bracket floating beside it.
	var stone := tip + dir * 9.0
	var back := (-dir).angle()
	draw_arc(stone, 9.5, back - 1.9, back + 1.9, 14, LEATHER_DARK, 7.0)
	draw_arc(stone, 9.5, back - 1.7, back + 1.7, 12, LEATHER, 4.5)
	var cradle_a := stone + Vector2(cos(back - 1.9), sin(back - 1.9)) * 9.5
	var cradle_b := stone + Vector2(cos(back + 1.9), sin(back + 1.9)) * 9.5
	draw_line(PIVOT.lerp(tip, 0.6) - perp * 5.0, cradle_a, ROPE_DARK, 1.6)
	draw_line(PIVOT.lerp(tip, 0.6) + perp * 5.0, cradle_b, ROPE_DARK, 1.6)

	draw_circle(stone, 8.5, STONE_SHOT_DARK)
	draw_circle(stone, 7.2, STONE_SHOT)
	draw_circle(stone - dir * 2.0 - perp * 2.0, 3.0, STONE_SHOT_DARK)
	draw_circle(stone + perp * 2.5, 2.0, STONE_SHOT.lightened(0.15))
