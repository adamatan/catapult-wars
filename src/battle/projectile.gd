class_name Projectile
extends Node2D

## A flying stone.
##
## Runs the same integrator as Ballistics.simulate, one fixed substep at a time,
## so what the player sees is exactly what the maths predicts. Collision is a
## heightmap lookup rather than a physics query — no bodies, no layers, no
## tunnelling through thin ground at high speed.

signal impacted(where: Vector2)
signal left_field()

const RADIUS := 7.0
const MAX_FLIGHT_TIME := 25.0
const TRAIL_LENGTH := 90

var terrain: Terrain
var wind := 0.0
var targets: Array[Catapult] = []

## The whole flight, thinned out. Kept so the battlefield can leave a ghost of
## the last shot on screen — the ranging aid Scorched Earth is built around.
var path := PackedVector2Array()

var _velocity := Vector2.ZERO
var _flight_time := 0.0
var _leftover := 0.0
var _spent := false
var _substeps := 0
var _trail := PackedVector2Array()

## Bounds are generous sideways and open at the top: a shot is allowed to arc
## off the top of the screen and come back down, which is half of Scorched
## Earth's charm.
var _bounds := Rect2(-260, -100000, Terrain.WIDTH + 520, 100000 + 1180)

func launch(from: Vector2, velocity: Vector2) -> void:
	position = from
	_velocity = velocity
	_trail = PackedVector2Array([from])
	path = PackedVector2Array([from])

func _physics_process(delta: float) -> void:
	if _spent:
		return
	_leftover += delta
	while _leftover >= Ballistics.SUBSTEP:
		_leftover -= Ballistics.SUBSTEP
		if _advance(Ballistics.SUBSTEP):
			return
	queue_redraw()

## One substep. Returns true if the flight ended.
func _advance(dt: float) -> bool:
	var result := Ballistics.step(position, _velocity, wind, dt)
	position = result[0]
	_velocity = result[1]
	_flight_time += dt

	_trail.append(position)
	if _trail.size() > TRAIL_LENGTH:
		_trail = _trail.slice(_trail.size() - TRAIL_LENGTH)

	_substeps += 1
	if _substeps % 6 == 0:
		path.append(position)

	# Give the stone a moment to clear the arm before it can hit anything,
	# so a machine never shoots itself at the instant of release.
	if _flight_time > 0.05:
		for target in targets:
			if not is_instance_valid(target):
				continue
			if position.distance_to(target.body_centre()) <= Catapult.HIT_RADIUS:
				return _finish(true)

	if terrain != null and position.y >= terrain.height_at(position.x):
		return _finish(true)

	if position.x < _bounds.position.x or position.x > _bounds.end.x:
		return _finish(false)
	if position.y > _bounds.end.y or _flight_time > MAX_FLIGHT_TIME:
		return _finish(false)

	return false

func _finish(hit: bool) -> bool:
	_spent = true
	path.append(position)
	if hit:
		impacted.emit(position)
	else:
		left_field.emit()
	return true

func _draw() -> void:
	if _trail.size() > 2:
		# Fade the smoke trail out behind the stone.
		for i in range(1, _trail.size()):
			var t := float(i) / float(_trail.size())
			var local_a := _trail[i - 1] - position
			var local_b := _trail[i] - position
			draw_line(local_a, local_b, Color(0.85, 0.82, 0.76, t * 0.55), 1.0 + t * 3.0)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.15, 0.13, 0.11, 0.75))
	draw_circle(Vector2.ZERO, RADIUS, Color("#7d766c"))
	draw_circle(Vector2(-2, -2), RADIUS * 0.42, Color("#9d968a"))
