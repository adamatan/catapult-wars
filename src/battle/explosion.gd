class_name Explosion
extends Node2D

## A short-lived blast: expanding shockwave, fireball, and a spray of debris.
## Frees itself when it finishes.

const DURATION := 0.75

var radius := Damage.BLAST_RADIUS

var _t := 0.0
var _sparks: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 22:
		var angle := rng.randf_range(-PI, 0.0)  # upward hemisphere
		var speed := rng.randf_range(90.0, 340.0)
		_sparks.append({
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"size": rng.randf_range(2.0, 5.0),
		})
	var tween := create_tween()
	tween.tween_method(_set_t, 0.0, 1.0, DURATION)
	tween.tween_callback(queue_free)

func _set_t(value: float) -> void:
	_t = value
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 - _t

	# Shockwave ring, racing out and thinning as it goes.
	var ring := radius * (0.25 + 1.05 * _t)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48,
		Color(1.0, 0.85, 0.55, fade * 0.45), maxf(1.0, 7.0 * fade), true)

	# Fireball. Built from many overlapping translucent discs rather than three
	# opaque ones — hard-edged concentric circles read as a target, not a blast.
	var core := radius * (0.78 - 0.30 * _t)
	var layers := 9
	for i in layers:
		var k := float(i) / float(layers - 1)          # 0 outside → 1 at the centre
		var r := core * (1.0 - k * 0.82)
		if r <= 0.0:
			continue
		# Smoke at the rim, through orange, to a white-hot centre.
		var tone := Color(0.32, 0.26, 0.22).lerp(Color(0.98, 0.52, 0.14), minf(1.0, k * 1.7))
		tone = tone.lerp(Color(1.0, 0.96, 0.80), maxf(0.0, (k - 0.62) / 0.38))
		draw_circle(Vector2.ZERO, r, Color(tone.r, tone.g, tone.b, fade * 0.30))

	# Debris, thrown up and pulled back down.
	var t_seconds := _t * DURATION
	for spark: Dictionary in _sparks:
		var v: Vector2 = spark["velocity"]
		var p := v * t_seconds + Vector2(0, 0.5 * Ballistics.GRAVITY * t_seconds * t_seconds)
		draw_circle(p, spark["size"] * fade, Color(0.28, 0.22, 0.17, fade))
