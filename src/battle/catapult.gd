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

## Burnt-wreck palette: wood pushed toward black-brown char, iron toward
## rust and soot instead of its usual cold steel.
const CHAR_WOOD := Color("#1c140f")
const CHAR_WOOD_DARK := Color("#0c0805")
const RUST := Color("#7a4425")
const RUST_LIGHT := Color("#a8683a")
const SOOT := Color("#241f1c")

const EMBER := Color("#ff7a2e")
const FLAME_CORE := Color("#fff2b0")
const FLAME_MID := Color("#ffb347")
const FLAME_OUTER := Color("#ff5a1f")
const SMOKE_COLOR := Color(0.30, 0.28, 0.26)

## Direction the light travels — upper-left toward lower-right, the same low
## golden-hour sun Terrain.LIGHT_DIR shades the ground with, so the machine
## and the ground it stands on agree about where the sun is.
const WORLD_LIGHT := Vector2(-0.62, -0.72)

var player: GameState.Player
var terrain: Terrain

var base_x: float = 0.0     ## where this turn started; steps are measured from here
var step_offset: int = 0    ## -MAX_STEPS..MAX_STEPS

var _recoil := 0.0          ## extra arm angle during the firing animation
var _ground_angle := 0.0

## Working palette for the current _draw() call — pristine by default,
## pulled toward CHAR_WOOD/RUST/SOOT once the machine is destroyed. Set once
## at the top of _draw() and read by it and its drawing helpers, so one
## switch recolours the whole machine instead of every draw call needing to
## ask "am I burnt?" on its own.
var _p_wood := WOOD
var _p_wood_dark := WOOD_DARK
var _p_wood_glow := WOOD_GLOW
var _p_iron := IRON
var _p_iron_dark := IRON_DARK
var _p_iron_light := IRON_LIGHT

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

## Shove the machine sideways by dx, from a nearby blast. Shoves from the
## machine's current position, not base_x — if the shooter has already
## repositioned this turn, position.x holds that stepped spot while base_x
## still holds where the turn started, so pushing from base_x would silently
## throw the step away. Folds the result straight into base_x and clears
## step_offset, the same pair commit_position() sets, so the HUD's step
## readout does not go stale for the rest of the turn. Same clamp bounds as
## set_step_offset(), so a knocked catapult can't be pushed off the field.
func nudge(dx: float) -> void:
	position.x = clampf(position.x + dx, 70.0, Terrain.WIDTH - 70.0)
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

	# Keyed off lives LOST rather than a literal life count, so it stays
	# correct however many lives a match starts with. Burnt is checked before
	# the fire tiers and on its own condition (lives <= 0, not lost == MAX)
	# so it always wins even if MAX_LIVES changes again.
	var lost := GameState.MAX_LIVES - player.lives
	var burnt := player.lives <= 0
	var t := Time.get_ticks_msec() / 1000.0

	_p_wood = WOOD
	_p_wood_dark = WOOD_DARK
	_p_wood_glow = WOOD_GLOW
	_p_iron = IRON
	_p_iron_dark = IRON_DARK
	_p_iron_light = IRON_LIGHT
	if burnt:
		_p_wood = CHAR_WOOD
		_p_wood_dark = CHAR_WOOD_DARK
		_p_wood_glow = EMBER.darkened(0.55)
		_p_iron = RUST.darkened(0.25)
		_p_iron_dark = SOOT
		_p_iron_light = RUST_LIGHT.darkened(0.10)

	var pennant := player.color
	if burnt:
		pennant = pennant.darkened(0.5).lerp(Color("#2a231d"), 0.55)

	# Local direction toward the light with the node's own tilt and mirror
	# unwound, so the warm rim lands on whichever side actually faces the
	# sun in world space rather than whichever side is -x in local space.
	var local_light := WORLD_LIGHT.rotated(-rotation)
	local_light.x *= scale.x
	local_light = local_light.normalized()
	var lit_right := local_light.x >= 0.0

	# --- ground contact shadow, so the machine reads as sitting on the slope
	# rather than floating above it ---
	draw_set_transform(Vector2(-4, 2), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 58.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- legion standard planted behind the machine ---
	draw_line(Vector2(-62, 4), Vector2(-62, -146), _p_wood_dark, 5.0)
	draw_line(Vector2(-63, 4), Vector2(-63, -146), _p_wood_glow, 1.0)
	var eagle_gold := RomanStyle.GOLD if not burnt else RomanStyle.GOLD_DARK.darkened(0.25)
	RomanStyle.aquila(self, Vector2(-62, -156), 26.0, eagle_gold)
	var cloth_pts := [
		Vector2(-62, -138), Vector2(-14, -130), Vector2(-22, -108),
		Vector2(-14, -86), Vector2(-62, -80),
	]
	if burnt:
		# Scorched and drooped rather than standing square in the wind.
		cloth_pts[1] += Vector2(-5, 12)
		cloth_pts[2] += Vector2(-9, 20)
		cloth_pts[3] += Vector2(-5, 11)
	var cloth := PackedVector2Array(cloth_pts)
	draw_colored_polygon(cloth, pennant)
	draw_polyline(cloth + PackedVector2Array([cloth[0]]), RomanStyle.GOLD_DARK, 2.0)
	RomanStyle.laurel(self, Vector2(-40, -109), 13.0, RomanStyle.GOLD, 2.4)

	# --- wheels ---
	for wheel_x: float in [-34.0, 34.0]:
		_draw_wheel(Vector2(wheel_x, -WHEEL_RADIUS), local_light)

	# --- frame: a heavy sled slung between the axles ---
	var frame := PackedVector2Array([
		Vector2(-52, -18), Vector2(52, -18), Vector2(40, -50), Vector2(-40, -50),
	])
	draw_colored_polygon(frame, _p_wood)
	# A soft shadow on the side turned away from the light, a warm glow on
	# the side facing it — the flat fill on its own reads as unlit cardboard.
	var half_shadow: PackedVector2Array
	var half_glow: PackedVector2Array
	if lit_right:
		half_shadow = PackedVector2Array([
			Vector2(0, -50), Vector2(-40, -50), Vector2(-52, -18), Vector2(0, -18),
		])
		half_glow = PackedVector2Array([
			Vector2(0, -50), Vector2(40, -50), Vector2(52, -18), Vector2(0, -18),
		])
	else:
		half_shadow = PackedVector2Array([
			Vector2(0, -50), Vector2(40, -50), Vector2(52, -18), Vector2(0, -18),
		])
		half_glow = PackedVector2Array([
			Vector2(0, -50), Vector2(-40, -50), Vector2(-52, -18), Vector2(0, -18),
		])
	draw_colored_polygon(half_shadow, Color(0, 0, 0, 0.26))
	draw_colored_polygon(half_glow, Color(_p_wood_glow.r, _p_wood_glow.g, _p_wood_glow.b, 0.20))
	# Plank seams, so the sled reads as boards rather than a slab.
	draw_line(Vector2(-48, -30), Vector2(48, -30), _p_wood_dark, 1.5)
	draw_line(Vector2(-45, -40), Vector2(43, -40), _p_wood_dark, 1.5)
	draw_polyline(frame + PackedVector2Array([frame[0]]), _p_wood_dark, 3.0)
	draw_line(Vector2(-44, -34), Vector2(44, -34), _p_wood_glow, 3.0)
	# Grain: a few short wavy strokes across the planks, quieter than the
	# seams so they read as texture on the wood rather than more structure.
	var grain_col := _p_wood_dark.darkened(0.12)
	for gx in [-34.0, -8.0, 18.0, 40.0]:
		var gy := -25.0 if gx < 5.0 else -44.0
		draw_polyline(PackedVector2Array([
			Vector2(gx - 7, gy), Vector2(gx - 1, gy + 1.4), Vector2(gx + 6, gy - 1.0),
		]), grain_col, 1.0, true)
	# Riveted iron corner brackets, not a bare diagonal strap — pitted and
	# chipped rather than fresh off the forge.
	for strap_x: float in [-24.0, 0.0, 24.0]:
		var top := Vector2(strap_x * 0.82, -50)
		var bottom := Vector2(strap_x, -18)
		draw_line(bottom, top, _p_iron_dark, 3.5)
		draw_line(bottom, top, _p_iron, 1.6)
		draw_circle(top, 2.2, _p_iron_light)
		draw_circle(bottom, 2.2, _p_iron_light)
		draw_circle(bottom + Vector2(1.1, -1.6), 0.9, _p_iron_dark.darkened(0.3))

	# --- the A-frame the arm swings against ---
	draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), _p_wood_dark, 10.0)
	draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), _p_wood, 6.0)
	draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), _p_wood_dark, 10.0)
	draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), _p_wood, 6.0)
	draw_line(Vector2(-20, -66), Vector2(18, -66), _p_wood_dark, 4.0)
	draw_line(Vector2(-20, -66), Vector2(18, -66), _p_wood_glow, 1.2)
	# The leg nearer the light gets a warm edge; the far leg sinks into shadow.
	if lit_right:
		draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), _p_wood_glow, 1.4)
		draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), Color(0, 0, 0, 0.18), 2.0)
	else:
		draw_line(Vector2(-26, -46), PIVOT + Vector2(0, 6), _p_wood_glow, 1.4)
		draw_line(Vector2(22, -46), PIVOT + Vector2(0, 6), Color(0, 0, 0, 0.18), 2.0)

	# --- torsion bundle: the twisted rope that drives the arm ---
	var bundle_c := PIVOT + Vector2(8, 8)
	draw_circle(bundle_c, 13.0, ROPE_DARK.darkened(0.4) if burnt else ROPE_DARK)
	for i in 9:
		var a := PI * float(i) / 9.0
		var col := ROPE if i % 2 == 0 else ROPE_DARK
		if burnt:
			col = col.darkened(0.45)
		draw_line(bundle_c + Vector2(cos(a), sin(a)) * 12.0,
			bundle_c - Vector2(cos(a), sin(a)) * 12.0, col, 2.0)
	draw_arc(bundle_c, 13.5, 0.0, TAU, 22, _p_iron_dark, 2.5)
	draw_arc(bundle_c, 13.5, PI * 0.15, PI * 0.55, 6, _p_iron_light, 1.2)

	# --- throwing arm and sling ---
	_draw_arm()

	# --- fire, smoke and embers, keyed off lives lost so it stays correct
	# whatever MAX_LIVES is set to. draw_set_transform below cancels the
	# node's own rotation and mirror (rotation by -rotation*scale.x, which is
	# what actually cancels it for both facings — plain -rotation only works
	# when scale.x is +1), so a plume rises straight up in world space on
	# both facings and on a sloped stance, rather than leaning with the
	# chassis. ---
	var cancel_rot := -rotation * scale.x
	var cancel_scale := Vector2(scale.x, 1.0)
	if burnt:
		draw_set_transform(PIVOT + Vector2(10, 4), cancel_rot, cancel_scale)
		_draw_embers(t)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif lost >= 2:
		# Ablaze: two fire sources, heavier flame, thicker smoke — clearly
		# worse than the single-life "singed" tier below.
		draw_set_transform(Vector2(-6, -44), cancel_rot, cancel_scale)
		_draw_smoke(t, 0.0, 1.0)
		_draw_flame(t, 0.0, 24.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_set_transform(Vector2(20, -38), cancel_rot, cancel_scale)
		_draw_smoke(t, 1.6, 0.7)
		_draw_flame(t, 2.1, 16.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif lost >= 1:
		# Singed: injured but still fighting — smoke and a small flame both,
		# not smoke alone.
		draw_set_transform(Vector2(6, -42), cancel_rot, cancel_scale)
		_draw_smoke(t, 0.0, 0.45)
		_draw_flame(t, 0.0, 13.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A wheel with a bit of depth: rim highlight, tapered spokes, riveted hub —
## the flat disc-and-spokes original read as a wagon icon rather than a
## wheel. The highlight and its opposing shadow are centred on `local_light`
## rather than a fixed angle, so the rim brightens on whichever side the sun
## is actually on.
func _draw_wheel(c: Vector2, local_light: Vector2) -> void:
	draw_circle(c, WHEEL_RADIUS, _p_wood_dark)
	draw_circle(c, WHEEL_RADIUS - 4.0, _p_wood)
	var light_angle := local_light.angle()
	draw_arc(c, WHEEL_RADIUS - 4.5, light_angle - 0.55, light_angle + 0.55, 10, _p_wood_glow, 1.4)
	draw_arc(c, WHEEL_RADIUS - 3.2, light_angle + PI - 0.45, light_angle + PI + 0.45, 8,
		Color(0, 0, 0, 0.22), 2.2)
	for spoke in 6:
		var a := TAU * spoke / 6.0
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		var poly := PackedVector2Array([
			c + side * 2.2, c + dir * (WHEEL_RADIUS - 5.0) + side * 1.0,
			c + dir * (WHEEL_RADIUS - 5.0) - side * 1.0, c - side * 2.2,
		])
		draw_colored_polygon(poly, _p_wood_dark)
	for spoke in 6:
		var a := TAU * spoke / 6.0 + 0.30
		draw_circle(c + Vector2(cos(a), sin(a)) * (WHEEL_RADIUS - 3.0), 1.3, _p_iron_dark)
	draw_circle(c, 6.5, _p_iron_dark)
	draw_circle(c, 5.0, _p_iron)
	draw_circle(c - Vector2(1.2, 1.2), 1.8, _p_iron_light)
	# A chip out of the felloe — nothing on a siege engine stays pristine.
	var chip := c + Vector2(cos(light_angle + 2.1), sin(light_angle + 2.1)) * (WHEEL_RADIUS - 2.0)
	draw_circle(chip, 1.6, _p_wood_dark.darkened(0.3))

## The throwing arm: a tapered shaft (wider at the pivot, narrower at the tip,
## which is what makes it read as a beam under load rather than a wire), iron
## collars binding it, and a leather sling cradling a stone — always shown
## loaded and ready, rather than an empty hook.
func _draw_arm() -> void:
	var tip := _arm_tip()
	var dir := (tip - PIVOT).normalized()
	var perp := dir.orthogonal()
	var burnt := player.lives <= 0

	var shaft := PackedVector2Array([
		PIVOT + perp * 6.0, PIVOT - perp * 6.0, tip - perp * 3.0, tip + perp * 3.0,
	])
	draw_colored_polygon(shaft, _p_wood_dark)
	var inner := PackedVector2Array([
		PIVOT + perp * 4.0, PIVOT - perp * 4.0, tip - perp * 1.8, tip + perp * 1.8,
	])
	draw_colored_polygon(inner, _p_wood)
	draw_line(PIVOT + perp * 1.5, tip + perp * 0.6, _p_wood_glow, 1.4)
	# Grain along the beam: a couple of thin strokes parallel to the shaft.
	var shaft_grain := _p_wood_dark.darkened(0.15)
	for gt in [0.22, 0.52, 0.80]:
		var ga := PIVOT.lerp(tip, gt)
		draw_line(ga - dir * 6.0 - perp * 0.8, ga + dir * 6.0 - perp * 0.8, shaft_grain, 0.8)

	for at_t in [0.35, 0.68]:
		var at := PIVOT.lerp(tip, at_t)
		var w := lerpf(5.2, 2.6, at_t)
		draw_line(at - perp * w, at + perp * w, _p_iron_dark, 2.2)

	draw_circle(PIVOT, 7.0, _p_iron_dark)
	draw_circle(PIVOT, 5.0, _p_iron)
	draw_circle(PIVOT - Vector2(1, 1), 1.6, _p_iron_light)

	# Sling: a leather cradle wrapped around the back of the stone — the side
	# toward the pivot — with two cords running from its ends to the arm.
	# Drawing the stone last, on top, is what makes the wrap read as a pouch
	# holding a load rather than a bracket floating beside it.
	var leather := LEATHER.darkened(0.45) if burnt else LEATHER
	var leather_dark := LEATHER_DARK.darkened(0.45) if burnt else LEATHER_DARK
	var rope_dark := ROPE_DARK.darkened(0.4) if burnt else ROPE_DARK
	var stone := tip + dir * 9.0
	var back := (-dir).angle()
	draw_arc(stone, 9.5, back - 1.9, back + 1.9, 14, leather_dark, 7.0)
	draw_arc(stone, 9.5, back - 1.7, back + 1.7, 12, leather, 4.5)
	var cradle_a := stone + Vector2(cos(back - 1.9), sin(back - 1.9)) * 9.5
	var cradle_b := stone + Vector2(cos(back + 1.9), sin(back + 1.9)) * 9.5
	draw_line(PIVOT.lerp(tip, 0.6) - perp * 5.0, cradle_a, rope_dark, 1.6)
	draw_line(PIVOT.lerp(tip, 0.6) + perp * 5.0, cradle_b, rope_dark, 1.6)

	draw_circle(stone, 8.5, STONE_SHOT_DARK)
	draw_circle(stone, 7.2, STONE_SHOT)
	draw_circle(stone - dir * 2.0 - perp * 2.0, 3.0, STONE_SHOT_DARK)
	draw_circle(stone + perp * 2.5, 2.0, STONE_SHOT.lightened(0.15))

## A small flickering flame. Drawn by the caller inside a draw_set_transform
## that has already cancelled the node's rotation and mirror, so "up" here
## (-y) is genuinely up in world space — this function never needs to know
## which way the machine faces or how steep the ground is.
func _draw_flame(t: float, phase: float, size: float) -> void:
	var flicker := 0.82 + 0.18 * sin(t * 13.0 + phase)
	var sway := sin(t * 7.0 + phase * 1.7) * size * 0.20
	var h := size * flicker
	var tip := Vector2(sway, -h)
	var mid_l := Vector2(-size * 0.30, -h * 0.55)
	var mid_r := Vector2(size * 0.30, -h * 0.55)
	var base_l := Vector2(-size * 0.42, 1.0)
	var base_r := Vector2(size * 0.42, 1.0)
	draw_colored_polygon(PackedVector2Array([base_l, mid_l, tip, mid_r, base_r]), FLAME_OUTER)
	var tip2 := Vector2(sway * 0.75, -h * 0.72)
	draw_colored_polygon(PackedVector2Array([
		base_l * 0.55, mid_l * 0.55, tip2, mid_r * 0.55, base_r * 0.55,
	]), FLAME_MID)
	var tip3 := Vector2(sway * 0.5, -h * 0.40)
	draw_colored_polygon(PackedVector2Array([base_l * 0.26, tip3, base_r * 0.26]), FLAME_CORE)

## Wisps that rise and loop rather than one static puff, faded in and out
## across the loop (`sin(rise * PI)`) so nothing visibly pops when a puff
## restarts at the bottom.
func _draw_smoke(t: float, phase: float, intensity: float) -> void:
	var puffs := 5 if intensity > 0.75 else 3
	for i in puffs:
		var local_phase := t * 0.55 + phase + float(i) * 1.9
		var rise := fmod(local_phase, 3.4) / 3.4
		var wobble := sin(local_phase * 2.1 + float(i)) * (7.0 + 9.0 * rise)
		var pos := Vector2(wobble, -rise * (50.0 + 30.0 * intensity) - 8.0)
		var r := lerpf(5.0, 15.0, rise) * (0.6 + 0.5 * intensity)
		var fade := sin(rise * PI)
		var alpha := fade * (0.20 + 0.20 * intensity)
		draw_circle(pos, r, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, alpha))

## A dying, guttering glow rather than an active flame — what is left once
## the machine has burnt down to a wreck.
func _draw_embers(t: float) -> void:
	for i in 4:
		var phase := float(i) * 1.7
		var glow := 0.5 + 0.5 * sin(t * 1.8 + phase)
		var pos := Vector2(sin(phase) * 15.0, -(5.0 + cos(phase * 1.3) * 5.0 + 5.0))
		draw_circle(pos, 1.4 + glow * 1.3, Color(EMBER.r, EMBER.g, EMBER.b, 0.20 + 0.30 * glow))
