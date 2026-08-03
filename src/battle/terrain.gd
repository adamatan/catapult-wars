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

## Direction the light travels, upper-left toward lower-right — the low,
## raking sun in the reference paintings. Only ever used to pick which
## slopes get lighter and which get darker; the actual colour always comes
## from `_rock_color`/`_crust_color`, so a cold field stays cold and a warm
## field stays warm — this is shading, not a second palette.
const LIGHT_DIR := Vector2(0.62, 0.72)

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

## Cheap deterministic noise keyed off a column (or column-derived) index —
## the same input always gives the same output, so rubble, cracks and
## weathering sit still between redraws instead of re-rolling and jittering
## every time a crater triggers a repaint. Integer hashing (Thomas Wang),
## masked positive so a wrapped-negative int never reads as a black blob.
static func _hash01(n: int) -> float:
	var x := n
	x = (x ^ 61) ^ (x >> 16)
	x = x + (x << 3)
	x = x ^ (x >> 4)
	x = x * 0x27d4eb2d
	x = x ^ (x >> 15)
	return float(x & 0x7fffffff) / float(0x7fffffff)

## How directly column `i`'s surface faces the light: +1 square into it,
## -1 turned away, 0 side-on. Used only to pick a lighter or darker shade of
## the field's own colours, never a hardcoded warm tone — that is what keeps
## a snowy field reading cold instead of picking up a fake sunset.
func _light_factor(i: int, surface: PackedVector2Array) -> float:
	var i0 := maxi(i - 1, 0)
	var i1 := mini(i + 1, COLUMNS - 1)
	var tangent := surface[i1] - surface[i0]
	if tangent.length() < 0.0001:
		return 0.0
	tangent = tangent.normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	if normal.y > 0.0:
		normal = -normal
	return normal.dot(-LIGHT_DIR)

func _draw() -> void:
	if heights.is_empty():
		return

	var surface := PackedVector2Array()
	surface.resize(COLUMNS)
	for i in COLUMNS:
		surface[i] = Vector2(float(i) * COLUMN_STEP, heights[i])

	var light := PackedFloat32Array()
	light.resize(COLUMNS)
	for i in COLUMNS:
		light[i] = _light_factor(i, surface)

	# Body: the surface line closed off against the bottom of the screen.
	var body := PackedVector2Array(surface)
	body.append(Vector2(WIDTH, 1200.0))
	body.append(Vector2(0.0, 1200.0))
	draw_colored_polygon(body, _rock_color)

	# Strata following the surface, so a large flat expanse of rock has some
	# depth to it. Bands rather than horizontal lines: they curve with the
	# ground and stay correct after a crater reshapes it. Four bands rather
	# than two, and each band wobbles a little (the same jitter on its top
	# and bottom edge, so its thickness holds) so the layers read as
	# weathered sediment rather than perfectly parallel cartoon stripes.
	var bands: Array = [
		[10.0, 24.0, 0.12], [34.0, 62.0, 0.06], [96.0, 138.0, -0.05], [150.0, 205.0, -0.11],
	]
	for band_index in bands.size():
		var band: Array = bands[band_index]
		var top_off: float = band[0]
		var bot_off: float = band[1]
		var shade: float = band[2]
		var wobble_seed := band_index * 9973 + 401
		var strip := PackedVector2Array()
		for i in COLUMNS:
			var wobble := (_hash01(i + wobble_seed) - 0.5) * 7.0
			strip.append(surface[i] + Vector2(0, top_off + wobble))
		for i in range(COLUMNS - 1, -1, -1):
			var wobble := (_hash01(i + wobble_seed) - 0.5) * 7.0
			strip.append(surface[i] + Vector2(0, bot_off + wobble))
		draw_colored_polygon(strip,
			_rock_color.lightened(shade) if shade > 0.0 else _rock_color.darkened(-shade))

	_draw_weathering(surface)
	_draw_cracks(surface)

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

	_draw_rim_light(surface, light)
	_draw_rubble(surface)

## Ridges that square up to the light get a brighter glint along their crust
## edge; slopes turned away get a touch more shadow — the directional light
## the flat original had none of. Grouped into runs of same-signed columns
## rather than one draw call per segment, so a field costs a handful of
## polylines instead of a thousand, and there is no per-vertex-coloured fill
## polygon near the crater walls for a steep edge to make degenerate.
func _draw_rim_light(surface: PackedVector2Array, light: PackedFloat32Array) -> void:
	const LIT_THRESHOLD := 0.30
	const SHADE_THRESHOLD := -0.30
	var lit_color := _crust_color.lightened(0.5)
	var shade_color := _crust_color.darkened(0.3)

	var run := PackedVector2Array()
	var run_lit := false
	for i in COLUMNS:
		var lit: bool = light[i] > LIT_THRESHOLD
		var shaded: bool = light[i] < SHADE_THRESHOLD
		var active := lit or shaded
		if active and run.size() > 0 and lit == run_lit:
			run.append(surface[i])
		else:
			if run.size() > 1:
				draw_polyline(run, lit_color if run_lit else shade_color, 2.2 if run_lit else 1.6, true)
			run = PackedVector2Array([surface[i]]) if active else PackedVector2Array()
			run_lit = lit
	if run.size() > 1:
		draw_polyline(run, lit_color if run_lit else shade_color, 2.2 if run_lit else 1.6, true)

## Weather stains: soft dark blotches sunk a little into the rock body,
## sparse and irregular, so a broad stretch of strata does not read as clean
## as a fresh coat of paint.
func _draw_weathering(surface: PackedVector2Array) -> void:
	var i := 3
	while i < COLUMNS - 3:
		var roll := _hash01(i * 92837 + 11)
		if roll < 0.16:
			var depth := 26.0 + _hash01(i * 3109 + 3) * 120.0
			var jitter := (_hash01(i * 5237 + 7) - 0.5) * 26.0
			var pos := surface[i] + Vector2(jitter, depth)
			var r := 9.0 + _hash01(i * 7159 + 2) * 20.0
			var col := _rock_color.darkened(0.10 + _hash01(i * 613 + 5) * 0.20)
			col.a = 0.28
			draw_circle(pos, r, col)
		i += 5 + int(_hash01(i * 401 + 9) * 14.0)

## Short jagged cracks reaching down from the crust seam into the rock —
## weathering the two flat shaded bands could not suggest on their own.
func _draw_cracks(surface: PackedVector2Array) -> void:
	var col := _rock_color.darkened(0.42)
	var i := 6
	while i < COLUMNS - 6:
		var roll := _hash01(i * 60013 + 17)
		if roll < 0.14:
			var start := surface[i] + Vector2(0, CRUST_DEPTH + 1.0)
			var pts := PackedVector2Array([start])
			var cur := start
			var segs := 3 + int(_hash01(i * 149 + 9) * 3.0)
			var drift := (_hash01(i * 271 + 1) - 0.5) * 10.0
			for s in segs:
				var dx := drift + (_hash01(i * 331 + s * 13 + 2) - 0.5) * 12.0
				var dy := 8.0 + _hash01(i * 431 + s * 7 + 4) * 14.0
				cur += Vector2(dx, dy)
				pts.append(cur)
			draw_polyline(pts, col, 1.3, true)
		i += 9 + int(_hash01(i * 811 + 3) * 20.0)

## Scattered rubble and debris sitting on the crust — small, squashed,
## irregular stones rather than a flat line, so the ground has grit on it
## instead of a single smooth painted edge.
func _draw_rubble(surface: PackedVector2Array) -> void:
	var i := 4
	while i < COLUMNS - 4:
		var roll := _hash01(i * 104729 + 19)
		if roll < 0.20:
			var size := 3.0 + _hash01(i * 211 + 3) * 6.0
			var jitter_x := (_hash01(i * 307 + 9) - 0.5) * 8.0
			var base := surface[i] + Vector2(jitter_x, -0.5)
			var rot := _hash01(i * 401 + 5) * TAU
			var verts := 4 + int(_hash01(i * 503 + 7) * 3.0)
			var poly := PackedVector2Array()
			for v in verts:
				var a := TAU * float(v) / float(verts) + rot
				var rad := size * (0.7 + _hash01(i * 601 + v * 3) * 0.5)
				poly.append(base + Vector2(cos(a), sin(a) * 0.6) * rad)
			var tone := _rock_color.lerp(_crust_color, 0.2).darkened(0.05 + _hash01(i * 701 + 1) * 0.25)
			draw_colored_polygon(poly, tone)
			draw_polyline(poly + PackedVector2Array([poly[0]]), _rock_color.darkened(0.5), 1.0, true)
		i += 6 + int(_hash01(i * 977 + 4) * 24.0)
