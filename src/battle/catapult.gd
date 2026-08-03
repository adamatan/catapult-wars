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
const IRON := Color("#4c4a47")
const ROPE := Color("#9a8568")

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

	# --- legion standard planted behind the machine ---
	draw_line(Vector2(-62, 4), Vector2(-62, -146), WOOD_DARK, 5.0)
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
		var c := Vector2(wheel_x, -WHEEL_RADIUS)
		draw_circle(c, WHEEL_RADIUS, WOOD_DARK)
		draw_circle(c, WHEEL_RADIUS - 4.0, WOOD)
		for spoke in 6:
			var a := TAU * spoke / 6.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * (WHEEL_RADIUS - 5.0), WOOD_DARK, 2.5)
		draw_circle(c, 5.0, IRON)

	# --- frame: a heavy sled slung between the axles ---
	var frame := PackedVector2Array([
		Vector2(-52, -18), Vector2(52, -18), Vector2(40, -50), Vector2(-40, -50),
	])
	draw_colored_polygon(frame, WOOD)
	draw_polyline(frame + PackedVector2Array([frame[0]]), WOOD_DARK, 3.0)
	draw_line(Vector2(-44, -34), Vector2(44, -34), WOOD_LIGHT, 3.0)
	# Iron bracing straps across the frame.
	for strap_x: float in [-24.0, 0.0, 24.0]:
		draw_line(Vector2(strap_x, -18), Vector2(strap_x * 0.82, -50), IRON, 2.5)

	# --- the A-frame the arm swings against ---
	draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), WOOD, 9.0)
	draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), WOOD, 9.0)
	draw_line(Vector2(-20, -66), Vector2(18, -66), WOOD_DARK, 4.0)

	# --- torsion bundle: the twisted rope that drives the arm ---
	draw_circle(PIVOT + Vector2(8, 8), 13.0, ROPE)
	for i in 5:
		var a := PI * float(i) / 5.0
		draw_line(PIVOT + Vector2(8, 8) + Vector2(cos(a), sin(a)) * 12.0,
			PIVOT + Vector2(8, 8) - Vector2(cos(a), sin(a)) * 12.0, WOOD_DARK, 1.5)
	draw_arc(PIVOT + Vector2(8, 8), 13.0, 0.0, TAU, 20, WOOD_DARK, 2.5)

	# --- throwing arm and sling ---
	var tip := _arm_tip()
	draw_line(PIVOT, tip, WOOD_DARK, 12.0)
	draw_line(PIVOT, tip, WOOD, 7.0)
	var bucket_dir := (tip - PIVOT).normalized()
	var bucket := tip + bucket_dir * 6.0
	draw_circle(bucket, 11.0, IRON)
	draw_circle(bucket, 7.0, Color("#7d766c"))
	draw_arc(bucket, 12.0, 0.0, TAU, 18, Color("#2f2c28"), 2.5)
	draw_circle(PIVOT, 7.0, IRON)
