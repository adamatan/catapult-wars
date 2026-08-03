extends Node

## Scene flow: title → battle → victory overlay → battle or title.
##
## One persistent root that swaps children, rather than change_scene_to_file,
## so the chosen names survive a rematch without a global to stash them in.

var _entries: Array = []
var _current: Node = null
var _overlay: Node = null

func _ready() -> void:
	_show_title()

func _clear() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	if _current != null:
		_current.queue_free()
		_current = null

func _show_title() -> void:
	_clear()
	var title := TitleScreen.new()
	title.start_requested.connect(_start_match)
	_current = title
	add_child(title)

func _start_match(entries: Array) -> void:
	_entries = entries
	_clear()
	var battle := Battlefield.new()
	battle.configure(_entries)
	battle.match_over.connect(_show_result)
	_current = battle
	add_child(battle)

func _show_result(winner_name: String, winner_colour: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var screen := GameOverScreen.new()
	screen.rematch_requested.connect(func() -> void: _start_match(_entries))
	screen.title_requested.connect(_show_title)
	layer.add_child(screen)
	_overlay = layer
	add_child(layer)
	screen.show_result(winner_name, winner_colour)
