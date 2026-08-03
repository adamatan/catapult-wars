class_name Ballistics
extends RefCounted

## Projectile motion, integrated by hand.
##
## Deliberately not RigidBody2D: a hand-rolled integrator is deterministic,
## replayable from (angle, power, wind), trivial to unit test, and lets us draw
## the exact arc the shot will take.

const GRAVITY := 560.0        ## px/s^2, downward (+y is down in Godot 2D)
const MIN_SPEED := 250.0      ## px/s at 0% force
const MAX_SPEED := 1000.0     ## px/s at 100% force
const SUBSTEP := 1.0 / 240.0  ## fixed integration step, independent of framerate

## Muzzle velocity for an aim.
##   angle_deg  0 = horizontal, 90 = straight up
##   power_pct  0..100
##   facing     +1 aims right, -1 aims left
static func launch_velocity(angle_deg: float, power_pct: float, facing: int) -> Vector2:
	var speed := MIN_SPEED + (MAX_SPEED - MIN_SPEED) * clampf(power_pct, 0.0, 100.0) / 100.0
	var a := deg_to_rad(clampf(angle_deg, 0.0, 90.0))
	return Vector2(cos(a) * speed * signf(facing), -sin(a) * speed)

## Advance one fixed substep. Wind is a constant horizontal acceleration.
static func step(pos: Vector2, vel: Vector2, wind: float, dt: float) -> Array:
	var next_vel := Vector2(vel.x + wind * dt, vel.y + GRAVITY * dt)
	var next_pos := pos + next_vel * dt
	return [next_pos, next_vel]

## Where a shot fired over flat ground at `from` lands, ignoring terrain.
## Used by the tests to pin the integrator against the closed-form solution.
static func flat_ground_range(angle_deg: float, power_pct: float) -> float:
	var speed := MIN_SPEED + (MAX_SPEED - MIN_SPEED) * clampf(power_pct, 0.0, 100.0) / 100.0
	var a := deg_to_rad(clampf(angle_deg, 0.0, 90.0))
	return speed * speed * sin(2.0 * a) / GRAVITY

## Simulate a whole flight without spawning nodes. Returns the list of points.
## `ground` is a Callable(x: float) -> float giving the terrain surface y.
## Stops on ground contact, on leaving the field sideways, or after `max_time`.
static func simulate(
	from: Vector2,
	vel: Vector2,
	wind: float,
	ground: Callable,
	bounds: Rect2,
	max_time := 20.0
) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var pos := from
	var v := vel
	var t := 0.0
	while t < max_time:
		var r := step(pos, v, wind, SUBSTEP)
		pos = r[0]
		v = r[1]
		t += SUBSTEP
		points.append(pos)
		if pos.x < bounds.position.x or pos.x > bounds.end.x:
			break
		# Above the field is fine — shots are allowed to arc off the top and return.
		if pos.y > bounds.end.y:
			break
		if pos.y >= ground.call(pos.x):
			break
	return points
