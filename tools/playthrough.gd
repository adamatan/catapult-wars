extends SceneTree

## Plays whole matches to a conclusion, headlessly, and checks the turn machine
## holds up over hundreds of shots.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" .godot-bin/godot --path . \
##       --script tools/playthrough.gd -- [matches]
##
## The logic tests in tests/run_tests.gd cover the pieces in isolation; this
## covers the thing they cannot — that a real match, with real terrain, real
## craters and real damage, actually terminates with a winner and never lets a
## second shot into the air while the first is still flying.

const MAX_TURNS := 400

var _matches := 6
var _failures := 0
## Signal results land here rather than in a local: GDScript lambdas capture
## locals by value, so a callback assigning to one writes to its own copy.
var _winner_name := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_matches = int(args[0])

	for i in _matches:
		await _play_one(i)

	print("")
	if _failures == 0:
		print("PASS  %d matches played to a finish" % _matches)
		quit(0)
	else:
		print("FAIL  %d of %d matches had problems" % [_failures, _matches])
		quit(1)

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _play_one(index: int) -> void:
	seed(1000 + index * 77)

	var battle := Battlefield.new()
	battle.configure([
		{"name": "Marcus", "colour": Color("#8f1f22")},
		{"name": "Victor", "colour": Color("#1f4e8f")},
	])
	root.add_child(battle)
	await process_frame

	_winner_name = ""
	battle.match_over.connect(_on_match_over)

	var turns := 0
	var shots := 0
	var starting_total := _total_hp(battle)

	while battle.state != Battlefield.State.GAME_OVER and turns < MAX_TURNS:
		if battle.state != Battlefield.State.AIM:
			await process_frame
			continue

		_aim_at_opponent(battle)
		var before_state := battle.state
		battle._on_fire_pressed()
		shots += 1

		if before_state == Battlefield.State.AIM and battle.state == Battlefield.State.AIM:
			_fail("match %d: firing did not leave the AIM state" % index)
			break

		# A second fire while the stone is in the air must be refused outright.
		var flying_state := battle.state
		battle._on_fire_pressed()
		if battle.state != flying_state:
			_fail("match %d: a second shot was accepted mid-flight" % index)
			break

		# Let the shot resolve.
		var waited := 0
		while battle.state != Battlefield.State.AIM \
				and battle.state != Battlefield.State.GAME_OVER and waited < 2000:
			await process_frame
			waited += 1
		if waited >= 2000:
			_fail("match %d: a shot never resolved" % index)
			break
		turns += 1

	var ending_total := _total_hp(battle)

	if battle.state != Battlefield.State.GAME_OVER:
		_fail("match %d: no winner after %d turns" % [index, turns])
	elif _winner_name.is_empty():
		_fail("match %d: finished without emitting a winner" % index)
	elif ending_total >= starting_total:
		_fail("match %d: nobody took any damage" % index)
	else:
		var loser_hp := 0
		for p in battle.game.players:
			if p.name != _winner_name:
				loser_hp = p.hp
		if loser_hp != 0:
			_fail("match %d: winner declared while the loser still had %d hp" % [index, loser_hp])
		else:
			print("  ok    match %d: %s wins after %d turns (%d shots)"
				% [index, _winner_name, turns, shots])

	root.remove_child(battle)
	battle.free()

func _on_match_over(name: String, _colour: Color) -> void:
	_winner_name = name

func _total_hp(battle: Battlefield) -> int:
	var total := 0
	for p in battle.game.players:
		total += p.hp
	return total

## Fire roughly at the opponent, with enough scatter that shots land all over
## the field — the point is to exercise craters, misses and near-misses, not to
## play well.
func _aim_at_opponent(battle: Battlefield) -> void:
	var me := battle.game.current()
	var target: GameState.Player = null
	for p in battle.game.players:
		if p != me and p.is_alive():
			target = p
	if target == null:
		return

	var distance: float = absf(target.catapult.position.x - me.catapult.position.x)
	# Invert the flat-ground range equation at 45 degrees to get a power that
	# roughly covers the gap, then jitter it so the match actually progresses
	# through misses rather than landing every shot.
	var speed := sqrt(maxf(distance, 1.0) * Ballistics.GRAVITY)
	var power := (speed - Ballistics.MIN_SPEED) / (Ballistics.MAX_SPEED - Ballistics.MIN_SPEED) * 100.0
	me.angle = clampf(45.0 + randf_range(-8.0, 8.0), 5.0, 85.0)
	me.power = clampf(power + randf_range(-6.0, 6.0), 5.0, 100.0)
