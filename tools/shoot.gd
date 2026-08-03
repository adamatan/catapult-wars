extends SceneTree

## Screenshot harness. Drives the game through a scripted sequence and writes
## PNGs, so the visuals can be reviewed without a human at a keyboard.
##
##   xvfb-run -s "-screen 0 1920x1080x24" .godot-bin/godot --path . \
##       --script tools/shoot.gd -- <shot> <output-dir>
##
## Shots: title, battle, aim, flight, impact, victory, all

const SETTLE_FRAMES := 12

var _out_dir := "build/shots"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := args[0] if args.size() > 0 else "all"
	if args.size() > 1:
		_out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Keep the editor from importing our own screenshots back into the project
	# and packing them into the export.
	var guard := FileAccess.open("build/.gdignore", FileAccess.WRITE)
	if guard != null:
		guard.close()

	if shot == "all":
		for name in ["title", "battle", "flight", "impact", "crater", "victory"]:
			await _shoot(name)
	else:
		await _shoot(shot)

	quit(0)

func _shoot(name: String) -> void:
	_clear()
	match name:
		"title":
			await _scene_title()
		"battle":
			await _scene_battle(false)
		"flight":
			await _scene_flight()
		"impact":
			await _scene_impact()
		"crater":
			await _scene_crater()
		"victory":
			await _scene_victory()
		_:
			push_error("unknown shot: %s" % name)
			return
	await _capture(name)

func _clear() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()

func _settle(frames := SETTLE_FRAMES) -> void:
	for i in frames:
		await process_frame

func _new_battle() -> Battlefield:
	seed(20250803)  # a fixed field, so shots are comparable between runs
	var battle := Battlefield.new()
	battle.configure([
		{"name": "Marcus", "colour": Color("#8f1f22")},
		{"name": "Victor", "colour": Color("#1f4e8f")},
	])
	root.add_child(battle)
	return battle

func _scene_title() -> void:
	var main: Node = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await _settle(30)

func _scene_battle(_unused: bool) -> void:
	var battle := _new_battle()
	await _settle(30)
	battle.game.current().angle = 63.0
	battle.game.current().power = 70.0
	battle.game.current().catapult.set_step_offset(2)
	battle._hud.refresh(battle.game)
	await _settle(20)

func _scene_flight() -> void:
	var battle := _new_battle()
	await _settle(20)
	battle.game.current().angle = 58.0
	battle.game.current().power = 72.0
	battle._hud.refresh(battle.game)
	await _settle(4)
	battle._on_fire_pressed()
	# Wait on the stone's own flight time rather than a frame count — under a
	# software renderer a fixed number of frames is well past the impact.
	var waited := 0
	while battle._projectile != null and battle._projectile.path.size() < 34 and waited < 600:
		await process_frame
		waited += 1

func _scene_impact() -> void:
	var battle := _new_battle()
	await _settle(20)
	battle.game.current().angle = 58.0
	battle.game.current().power = 72.0
	battle._hud.refresh(battle.game)
	await _settle(4)
	battle._on_fire_pressed()
	# Hold until the shot resolves, then catch the blast while it is still up.
	var waited := 0
	while battle.state == Battlefield.State.FIRING and waited < 600:
		await process_frame
		waited += 1
	# Catch the fireball while it is still bright; the blast only lasts 0.75s
	# and under a software renderer even a few frames eats most of it.
	await _settle(2)

## The battlefield after the blast has cleared, so the crater itself is visible
## rather than the fireball sitting on top of it.
func _scene_crater() -> void:
	await _scene_impact()
	await _settle(80)

func _scene_victory() -> void:
	var main: Node = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await _settle(4)
	main._start_match([
		{"name": "Marcus", "colour": Color("#8f1f22")},
		{"name": "Victor", "colour": Color("#1f4e8f")},
	])
	await _settle(20)
	main._show_result("Marcus", Color("#8f1f22"))
	await _settle(30)

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	var err := image.save_png(path)
	if err != OK:
		push_error("could not write %s (%d)" % [path, err])
	else:
		print("wrote %s  %dx%d" % [path, image.get_width(), image.get_height()])
