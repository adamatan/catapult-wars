extends SceneTree

## Headless logic tests.
##   .godot-bin/godot --headless --path . --script tests/run_tests.gd
## Exits non-zero if anything fails, so it works as a CI gate.

var _failures := 0
var _checks := 0

func _init() -> void:
	_test_launch_velocity()
	_test_integrator_matches_closed_form()
	_test_damage_falloff()
	_test_terrain_generation()
	_test_crater()
	_test_turn_rotation()
	_test_manifest()

	for t in _terrains:
		t.free()
	_terrains.clear()

	print("")
	if _failures == 0:
		print("PASS  %d checks" % _checks)
		quit(0)
	else:
		print("FAIL  %d of %d checks failed" % [_failures, _checks])
		quit(1)

# --- tiny assertion helpers -------------------------------------------------

func check(label: String, condition: bool, detail := "") -> void:
	_checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s%s" % [label, ("  (%s)" % detail) if detail else ""])

func check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	check(label, absf(actual - expected) <= tolerance,
		"got %.3f, expected %.3f +/- %.3f" % [actual, expected, tolerance])

# --- ballistics -------------------------------------------------------------

func _test_launch_velocity() -> void:
	print("ballistics.launch_velocity")
	var up := Ballistics.launch_velocity(90.0, 100.0, 1)
	check_near("90 deg is straight up", up.x, 0.0, 0.001)
	check_near("90 deg at full power uses MAX_SPEED", up.y, -Ballistics.MAX_SPEED, 0.001)

	var flat := Ballistics.launch_velocity(0.0, 0.0, 1)
	check_near("0 deg is horizontal", flat.y, 0.0, 0.001)
	check_near("0% power uses MIN_SPEED", flat.x, Ballistics.MIN_SPEED, 0.001)

	var left := Ballistics.launch_velocity(45.0, 50.0, -1)
	var right := Ballistics.launch_velocity(45.0, 50.0, 1)
	check("facing mirrors horizontal velocity", is_equal_approx(left.x, -right.x))
	check("facing leaves vertical velocity alone", is_equal_approx(left.y, right.y))

func _test_integrator_matches_closed_form() -> void:
	print("ballistics.simulate vs closed form")
	# Fire over perfectly flat ground and compare the landing point with
	# R = v^2 * sin(2a) / g. If the integrator drifts, this catches it.
	var ground_y := 800.0
	var ground := func(_x: float) -> float: return ground_y
	var bounds := Rect2(0, 0, 100000, 100000)

	for angle: float in [30.0, 45.0, 63.0]:
		var start := Vector2(0.0, ground_y)
		var vel := Ballistics.launch_velocity(angle, 70.0, 1)
		var path := Ballistics.simulate(start, vel, 0.0, ground, bounds)
		var landed_x: float = path[path.size() - 1].x
		var expected := Ballistics.flat_ground_range(angle, 70.0)
		# One substep of slack: SUBSTEP * horizontal speed.
		check_near("range at %d deg" % int(angle), landed_x, expected, expected * 0.02 + 5.0)

	# 45 degrees must out-range both 30 and 60 at equal power.
	var r30 := Ballistics.flat_ground_range(30.0, 80.0)
	var r45 := Ballistics.flat_ground_range(45.0, 80.0)
	var r60 := Ballistics.flat_ground_range(60.0, 80.0)
	check("45 deg is the longest range", r45 > r30 and r45 > r60)
	check_near("30 and 60 deg are symmetric", r30, r60, 0.001)

	# Wind must push the shot downrange.
	var windless := Ballistics.simulate(
		Vector2(0, ground_y), Ballistics.launch_velocity(45.0, 70.0, 1), 0.0, ground, bounds)
	var windy := Ballistics.simulate(
		Vector2(0, ground_y), Ballistics.launch_velocity(45.0, 70.0, 1), 120.0, ground, bounds)
	check("tailwind extends the shot",
		windy[windy.size() - 1].x > windless[windless.size() - 1].x)

	# A shot must stop when it meets rising ground, not tunnel through it.
	var hill := func(x: float) -> float: return ground_y if x < 300.0 else 400.0
	var into_hill := Ballistics.simulate(
		Vector2(0, ground_y), Ballistics.launch_velocity(20.0, 60.0, 1), 0.0, hill, bounds)
	var impact: Vector2 = into_hill[into_hill.size() - 1]
	check("stops at the hillside", impact.x >= 300.0 and impact.y >= 395.0,
		"impact at %s" % impact)

# --- damage -----------------------------------------------------------------

func _test_damage_falloff() -> void:
	print("damage.at_distance")
	check("direct hit deals max damage",
		Damage.at_distance(0.0) == int(round(Damage.MAX_DAMAGE)))
	check("beyond the blast radius deals nothing",
		Damage.at_distance(Damage.BLAST_RADIUS) == 0)
	check("well outside deals nothing",
		Damage.at_distance(Damage.BLAST_RADIUS * 4.0) == 0)
	check("half radius deals about half",
		Damage.at_distance(Damage.BLAST_RADIUS * 0.5) == int(round(Damage.MAX_DAMAGE * 0.5)))
	check("falloff is monotonic",
		Damage.at_distance(10.0) > Damage.at_distance(50.0)
		and Damage.at_distance(50.0) > Damage.at_distance(90.0))

# --- terrain ----------------------------------------------------------------

## Terrain is a Node2D, so instances made outside the tree have to be freed by
## hand or the engine reports leaks on exit.
var _terrains: Array[Terrain] = []

func _new_terrain(rng_seed: int) -> Terrain:
	var t := Terrain.new()
	t.generate(rng_seed)
	_terrains.append(t)
	return t

func _make_terrain() -> Terrain:
	return _new_terrain(12345)

func _test_terrain_generation() -> void:
	print("terrain.generate")
	var t := _make_terrain()
	check("surface stays inside its band", _surface_in_band(t))

	# Same seed, same terrain — the field has to be reproducible.
	var a := _new_terrain(999)
	var b := _new_terrain(999)
	check("generation is deterministic for a seed", a.heights == b.heights)

	var c := _new_terrain(1000)
	check("a different seed gives different ground", a.heights != c.heights)

	# Spawn pads must be flat enough to stand a catapult on.
	for x: float in [Terrain.SPAWN_MARGIN, Terrain.WIDTH - Terrain.SPAWN_MARGIN]:
		var lo := t.height_at(x - 40.0)
		var hi := t.height_at(x + 40.0)
		check_near("spawn pad is level at x=%d" % int(x), lo, hi, 6.0)

	# Halfway between two samples must read as the average of the two.
	var i := 300
	var xa := float(i) * Terrain.COLUMN_STEP
	var xb := float(i + 1) * Terrain.COLUMN_STEP
	check_near("height_at lands on the samples", t.height_at(xa), t.heights[i], 0.01)
	check_near("height_at interpolates between samples",
		t.height_at((xa + xb) * 0.5), (t.heights[i] + t.heights[i + 1]) * 0.5, 0.01)
	check_near("height_at clamps past the right edge",
		t.height_at(Terrain.WIDTH + 500.0), t.heights[Terrain.COLUMNS - 1], 0.01)

func _surface_in_band(t: Terrain) -> bool:
	for h in t.heights:
		if h < Terrain.MIN_SURFACE_Y - 0.01 or h > Terrain.MAX_SURFACE_Y + 0.01:
			return false
	return true

func _test_crater() -> void:
	print("terrain.carve_crater")
	var t := _make_terrain()
	# Pick ground with room to fall, so the assertions aren't at the mercy of
	# where the seed happened to put bedrock.
	var x := 900.0
	for candidate in range(400, 1500, 20):
		if t.height_at(float(candidate)) < Terrain.MAX_SURFACE_Y - 80.0:
			x = float(candidate)
			break
	var before := t.height_at(x)
	check("test picked ground with room to fall", before < Terrain.MAX_SURFACE_Y - 80.0)

	# A blast right at the surface digs a hole.
	t.carve_crater(Vector2(x, before), 60.0)
	var after := t.height_at(x)
	check("ground drops at the impact point", after > before, "%.1f -> %.1f" % [before, after])
	check("the hole is roughly the blast depth", after - before <= 60.0 + 1.0)

	# Well outside the radius nothing moves.
	var far_before := t.height_at(x + 400.0)
	t.carve_crater(Vector2(x, before), 60.0)
	check("ground far from the blast is untouched",
		is_equal_approx(t.height_at(x + 400.0), far_before))

	# An airburst high above the ground leaves it alone.
	var t2 := _make_terrain()
	var untouched := t2.height_at(x)
	t2.carve_crater(Vector2(x, untouched - 400.0), 60.0)
	check("an airburst does not dig", is_equal_approx(t2.height_at(x), untouched))

	# Craters must not eat through the bottom of the world.
	var t3 := _make_terrain()
	for i in 40:
		t3.carve_crater(Vector2(x, t3.height_at(x)), 70.0)
	check("repeated blasts stop at bedrock", t3.height_at(x) <= Terrain.MAX_SURFACE_Y + 0.01)

# --- turn order -------------------------------------------------------------

func _test_turn_rotation() -> void:
	print("game_state turn rotation")
	var gs := GameState.new()
	gs.add_player("Marcus", Color.RED, 1)
	gs.add_player("Victor", Color.BLUE, -1)

	check("starts on the first player", gs.current().name == "Marcus")
	check("starts in round 1", gs.round_number == 1)
	check("a fresh match is not over", not gs.is_over())

	gs.advance_turn()
	check("turn passes to the second player", gs.current().name == "Victor")
	check("round does not tick mid-rotation", gs.round_number == 1)

	gs.advance_turn()
	check("turn wraps to the first player", gs.current().name == "Marcus")
	check("round ticks on wrap", gs.round_number == 2)

	# With a third player, a dead one must be skipped rather than given a turn.
	var gs3 := GameState.new()
	gs3.add_player("A", Color.RED, 1)
	gs3.add_player("B", Color.BLUE, -1)
	gs3.add_player("C", Color.GREEN, -1)
	gs3.players[1].hp = 0
	gs3.advance_turn()
	check("dead players are skipped", gs3.current().name == "C")
	check("a match with two alive is not over", not gs3.is_over())

	gs3.players[2].hp = 0
	check("match ends with one standing", gs3.is_over())
	check("the survivor wins", gs3.winner().name == "A")
	check("advancing a finished match is refused", not gs3.advance_turn())

func _test_manifest() -> void:
	print("fields manifest")
	var text := FileAccess.get_file_as_string(FieldLibrary.MANIFEST)
	var parsed: Variant = JSON.parse_string(text)
	check("manifest parses", typeof(parsed) == TYPE_ARRAY)
	check("manifest has four fields", (parsed as Array).size() == 4)
	for entry: Dictionary in parsed:
		check("plate exists: %s" % entry["slug"],
			ResourceLoader.exists(entry["texture"]), entry["texture"])
