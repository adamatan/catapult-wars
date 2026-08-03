class_name Terrain
extends Node2D

## Destructible ground, stored as a heightmap.
##
## One surface sample every COLUMN_STEP pixels. Craters lower samples; nothing
## can overhang or tunnel, which is the price of a heightmap and a price worth
## paying — collision becomes a single array lookup instead of a physics query.

const WIDTH := 1920.0
## 2^10 + 1 samples, so midpoint displacement subdivides evenly.
const COLUMNS := 1025
const COLUMN_STEP := WIDTH / float(COLUMNS - 1)

const MIN_SURFACE_Y := 392.0   ## highest a peak may reach
const MAX_SURFACE_Y := 694.0   ## bedrock: craters never dig past this
const ROUGHNESS := 0.54        ## <0.5 smooth rolling hills, >0.6 jagged
const SMOOTHING_PASSES := 3    ## knocks off per-pixel jitter the eye reads as noise
const CRUST_DEPTH := 15.0      ## thickness of the snow/sand/turf layer on top

const SPAWN_MARGIN := 190.0          ## how far in from the edge a catapult starts
const SPAWN_PAD_HALF_WIDTH := 58.0   ## flattened landing pad around each spawn

var heights := PackedFloat32Array()

var _rock_color := Color("#5b5342")
var _crust_color := Color("#9aa06a")

func set_palette(rock: Color, crust: Color) -> void:
	_rock_color = rock
	_crust_color = crust
	_redraw()

## Build a fresh battlefield. The same seed always produces the same ground.
func generate(rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var raw := PackedFloat32Array()
	raw.resize(COLUMNS)
	raw[0] = rng.randf()
	raw[COLUMNS - 1] = rng.randf()

	# Midpoint displacement: repeatedly split each span and jitter its centre by
	# an amount that shrinks each pass, which is what gives natural-looking ridges.
	var step := COLUMNS - 1
	var scale := 1.0
	while step > 1:
		var half := step / 2
		var i := half
		while i < COLUMNS:
			raw[i] = (raw[i - half] + raw[i + half]) * 0.5 + rng.randf_range(-scale, scale)
			i += step
		step = half
		scale *= ROUGHNESS

	heights = _rescale_into_band(_smooth(raw))
	_flatten_spawn_pads()
	_redraw()

## Midpoint displacement jitters every sample independently, including the
## final pass at one-sample resolution, which leaves a fuzz the eye reads as
## noise rather than rock. A few averaging passes turn it back into landscape.
func _smooth(values: PackedFloat32Array) -> PackedFloat32Array:
	var current := values
	for pass_index in SMOOTHING_PASSES:
		var next := PackedFloat32Array(current)
		for i in range(1, COLUMNS - 1):
			next[i] = (current[i - 1] + current[i] * 2.0 + current[i + 1]) * 0.25
		current = next
	return current

## Map arbitrary noise onto the playable band, so every field uses its full
## vertical range instead of clipping against the limits.
func _rescale_into_band(raw: PackedFloat32Array) -> PackedFloat32Array:
	var lo := raw[0]
	var hi := raw[0]
	for v in raw:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)

	var out := PackedFloat32Array()
	out.resize(COLUMNS)
	for i in COLUMNS:
		var t := (raw[i] - lo) / span
		out[i] = MIN_SURFACE_Y + t * (MAX_SURFACE_Y - MIN_SURFACE_Y)
	return out

## Level the ground under each starting position. Catapults sitting on a steep
## slope look broken and make the opening shots a lottery.
func _flatten_spawn_pads() -> void:
	for centre_x: float in [SPAWN_MARGIN, WIDTH - SPAWN_MARGIN]:
		var centre_i := _column_of(centre_x)
		var level := heights[centre_i]
		var pad := int(SPAWN_PAD_HALF_WIDTH / COLUMN_STEP)
		var blend := pad / 2  # ease back into the natural ground either side
		for offset in range(-pad - blend, pad + blend + 1):
			var i := clampi(centre_i + offset, 0, COLUMNS - 1)
			var over := absi(offset) - pad
			if over <= 0:
				heights[i] = level
			else:
				var t := float(over) / float(blend)
				heights[i] = lerpf(level, heights[i], smoothstep(0.0, 1.0, t))

func _column_of(x: float) -> int:
	return clampi(int(round(x / COLUMN_STEP)), 0, COLUMNS - 1)

## Surface y at any x, interpolated between the two nearest samples.
func height_at(x: float) -> float:
	var fx := clampf(x, 0.0, WIDTH) / COLUMN_STEP
	var i := int(floor(fx))
	if i >= COLUMNS - 1:
		return heights[COLUMNS - 1]
	return lerpf(heights[i], heights[i + 1], fx - float(i))

## Surface direction at x, for standing a catapult level with the slope.
func slope_at(x: float) -> float:
	var span := 18.0
	var left := height_at(x - span)
	var right := height_at(x + span)
	return atan2(right - left, span * 2.0)

## Blow a circular bite out of the ground.
##
## Only ground that the blast sphere actually intersects moves: a shot that
## detonates in mid-air leaves the field alone, and one that lands buried deep
## can't hollow out a cave the heightmap has no way to represent.
func carve_crater(centre: Vector2, radius: float) -> void:
	var first := clampi(_column_of(centre.x - radius) - 1, 0, COLUMNS - 1)
	var last := clampi(_column_of(centre.x + radius) + 1, 0, COLUMNS - 1)
	for i in range(first, last + 1):
		var dx := float(i) * COLUMN_STEP - centre.x
		if absf(dx) >= radius:
			continue
		var dy := sqrt(radius * radius - dx * dx)
		var sphere_top := centre.y - dy
		var sphere_bottom := centre.y + dy
		var surface := heights[i]
		if surface > sphere_top and surface < sphere_bottom:
			heights[i] = minf(sphere_bottom, MAX_SURFACE_Y)
	_redraw()

func _redraw() -> void:
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	if heights.is_empty():
		return

	var surface := PackedVector2Array()
	surface.resize(COLUMNS)
	for i in COLUMNS:
		surface[i] = Vector2(float(i) * COLUMN_STEP, heights[i])

	# Body: the surface line closed off against the bottom of the screen.
	var body := PackedVector2Array(surface)
	body.append(Vector2(WIDTH, 1200.0))
	body.append(Vector2(0.0, 1200.0))
	draw_colored_polygon(body, _rock_color)

	# Strata following the surface, so a large flat expanse of rock has some
	# depth to it. Bands rather than horizontal lines: they curve with the
	# ground and stay correct after a crater reshapes it.
	for band: Array in [[34.0, 62.0, 0.06], [96.0, 138.0, -0.05]]:
		var strip := PackedVector2Array()
		for i in COLUMNS:
			strip.append(surface[i] + Vector2(0, band[0]))
		for i in range(COLUMNS - 1, -1, -1):
			strip.append(surface[i] + Vector2(0, band[1]))
		var shade: float = band[2]
		draw_colored_polygon(strip,
			_rock_color.lightened(shade) if shade > 0.0 else _rock_color.darkened(-shade))

	# Crust — snow, sand or turf depending on the field — as a filled band
	# following the surface. A stroked line reads as a squiggle laid over the
	# ground; a band reads as a layer of it.
	var crust := PackedVector2Array(surface)
	for i in range(COLUMNS - 1, -1, -1):
		crust.append(surface[i] + Vector2(0, CRUST_DEPTH))
	draw_colored_polygon(crust, _crust_color)

	# A darker seam where the crust meets the rock, and a highlight along the
	# very top edge, which is what gives the ground its sense of thickness.
	var seam := PackedVector2Array()
	for i in COLUMNS:
		seam.append(surface[i] + Vector2(0, CRUST_DEPTH))
	draw_polyline(seam, _rock_color.darkened(0.25), 3.0, true)
	draw_polyline(surface, _crust_color.lightened(0.25), 2.0, true)
