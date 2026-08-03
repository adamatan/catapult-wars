class_name Battlefield
extends Node2D

## Runs a match.
##
## The turn state machine is explicit and input is only accepted in AIM. That
## single rule is what keeps the classic artillery-game bug — a second shot
## queued while the first is still in the air — from ever being reachable.

signal match_over(winner_name: String, winner_colour: Color)

enum State { AIM, FIRING, IMPACT, TURN_END, GAME_OVER }

const RESOLVE_PAUSE := 0.95   ## seconds to admire the crater before the next turn
const MISS_PAUSE := 0.3
const ANGLE_RATE := 42.0      ## degrees per second on the keyboard
const POWER_RATE := 46.0      ## percent per second on the keyboard

var state := State.AIM
var game: GameState

var _terrain: Terrain
var _backdrop: Backdrop
var _hud: Hud
var _projectile: Projectile
var _ghost_arc: Line2D
var _catapults: Array[Catapult] = []

var _shake := 0.0
var _entries: Array = [
	{"name": "Marcus", "colour": Color("#8f1f22")},
	{"name": "Victor", "colour": Color("#1f4e8f")},
]

## Called before the scene enters the tree.
func configure(entries: Array) -> void:
	_entries = entries

func _ready() -> void:
	var field := FieldLibrary.random_field()

	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_backdrop.set_field(field)

	_terrain = Terrain.new()
	add_child(_terrain)
	_terrain.generate(randi())
	if field != null:
		_terrain.set_palette(field.rock_color, field.crust_color)

	_ghost_arc = Line2D.new()
	_ghost_arc.width = 2.0
	_ghost_arc.default_color = Color(1.0, 0.95, 0.8, 0.20)
	_ghost_arc.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(_ghost_arc)

	game = GameState.new()
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		# First half of the roster starts on the left aiming right, rest mirror it.
		var facing := 1 if i < int(ceil(_entries.size() / 2.0)) else -1
		var player := game.add_player(entry["name"], entry["colour"], facing)
		player.angle = 55.0
		player.power = 65.0

		var spawn_x := Terrain.SPAWN_MARGIN if facing > 0 else Terrain.WIDTH - Terrain.SPAWN_MARGIN
		var catapult := Catapult.new()
		add_child(catapult)
		catapult.setup(player, _terrain, spawn_x)
		player.catapult = catapult
		_catapults.append(catapult)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	_hud.build_banners(game.players)
	_hud.angle_changed.connect(_on_angle_changed)
	_hud.power_changed.connect(_on_power_changed)
	_hud.steps_changed.connect(_on_steps_changed)
	_hud.fire_pressed.connect(_on_fire_pressed)

	_begin_turn()

# --- input ------------------------------------------------------------------

func _on_angle_changed(degrees: float) -> void:
	if state != State.AIM:
		return
	game.current().angle = degrees

func _on_power_changed(percent: float) -> void:
	if state != State.AIM:
		return
	game.current().power = percent

func _on_steps_changed(steps: int) -> void:
	if state != State.AIM:
		return
	game.current().catapult.set_step_offset(steps)

func _process(delta: float) -> void:
	_apply_shake(delta)
	if state != State.AIM:
		return

	var player := game.current()

	var elevation := Input.get_action_strength("aim_up") - Input.get_action_strength("aim_down")
	if not is_zero_approx(elevation):
		player.angle = clampf(player.angle + elevation * ANGLE_RATE * delta, 0.0, 90.0)
		_hud.dial.value = player.angle

	var force := Input.get_action_strength("power_up") - Input.get_action_strength("power_down")
	if not is_zero_approx(force):
		player.power = clampf(player.power + force * POWER_RATE * delta, 0.0, 100.0)
		_hud.slider.value = player.power

func _unhandled_input(event: InputEvent) -> void:
	if state != State.AIM:
		return
	if event.is_action_pressed("fire"):
		_on_fire_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("step_left") or event.is_action_pressed("step_right"):
		var direction := -1 if event.is_action_pressed("step_left") else 1
		var catapult := game.current().catapult
		catapult.set_step_offset(catapult.step_offset + direction)
		_hud.track.value = catapult.step_offset
		get_viewport().set_input_as_handled()

# --- turn cycle -------------------------------------------------------------

func _begin_turn() -> void:
	state = State.AIM
	_hud.refresh(game)
	_hud.set_interactive(true)

func _on_fire_pressed() -> void:
	if state != State.AIM:
		return
	state = State.FIRING
	_hud.set_interactive(false)

	var player := game.current()
	player.catapult.play_fire()

	_projectile = Projectile.new()
	_projectile.terrain = _terrain
	_projectile.targets = _catapults
	_projectile.wind = 0.0  # implemented in the integrator, disabled for v1
	add_child(_projectile)
	_projectile.launch(player.catapult.muzzle(),
		Ballistics.launch_velocity(player.angle, player.power, player.facing,
			player.catapult.ground_tilt()))
	_projectile.impacted.connect(_on_impact)
	_projectile.left_field.connect(_on_left_field)

func _on_impact(where: Vector2) -> void:
	state = State.IMPACT
	_remember_arc()

	_terrain.carve_crater(where, Damage.CRATER_RADIUS)

	var blast := Explosion.new()
	blast.position = where
	add_child(blast)
	_shake = 14.0

	for player in game.players:
		if not player.is_alive():
			continue
		if Damage.is_hit(where.distance_to(player.catapult.body_centre())):
			player.lives = maxi(0, player.lives - 1)
	_hud.refresh(game)

	await get_tree().create_timer(RESOLVE_PAUSE).timeout
	_end_turn()

func _on_left_field() -> void:
	state = State.IMPACT
	_remember_arc()
	await get_tree().create_timer(MISS_PAUSE).timeout
	_end_turn()

func _remember_arc() -> void:
	if _projectile == null:
		return
	_ghost_arc.points = _projectile.path
	_projectile.queue_free()
	_projectile = null

func _end_turn() -> void:
	state = State.TURN_END
	game.current().catapult.commit_position()

	if game.is_over():
		state = State.GAME_OVER
		_hud.set_interactive(false)
		var winner := game.winner()
		if winner != null:
			match_over.emit(winner.name, winner.color)
		else:
			match_over.emit("NO ONE", RomanStyle.STONE_LIGHT)
		return

	game.advance_turn()
	_begin_turn()

# --- feel -------------------------------------------------------------------

func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 34.0)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
