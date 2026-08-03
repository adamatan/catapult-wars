extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var c := Control.new()
	c.set_script(load("res://tools/motifs.gd"))
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("build/shots")
	root.get_texture().get_image().save_png("build/shots/motifs.png")
	print("wrote build/shots/motifs.png")
	quit(0)
