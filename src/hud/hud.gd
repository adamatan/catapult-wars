class_name Hud
extends Control

## Assembles the interface and nothing else.
##
## The HUD never reads or writes game state. It emits what the player asked
## for and redraws what it is told; Battlefield decides what any of it means.

signal angle_changed(degrees: float)
signal power_changed(percent: float)
signal steps_changed(steps: int)
signal fire_pressed()

const BAND := Rect2(0, 722, 1920, 358)
const FRIEZE_HEIGHT := 26.0
const LABEL_BASELINE := 786.0

const SECTIONS := [
	{"label": "ANGLE", "rect": Rect2(24, 800, 372, 262), "divider": true},
	{"label": "FORCE", "rect": Rect2(412, 800, 380, 262), "divider": true},
	{"label": "STEPS (MOVE)", "rect": Rect2(808, 800, 430, 262), "divider": true},
]
const FIRE_RECT := Rect2(1264, 776, 630, 286)

var dial: AngleDial
var slider: ForceSlider
var track: StepTrack
var fire_button: FireButton
var emblem: TurnEmblem

var _banners: Array[PlayerBanner] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	dial = AngleDial.new()
	_place(dial, SECTIONS[0]["rect"])
	dial.angle_changed.connect(func(v: float) -> void: angle_changed.emit(v))

	slider = ForceSlider.new()
	_place(slider, SECTIONS[1]["rect"])
	slider.power_changed.connect(func(v: float) -> void: power_changed.emit(v))

	track = StepTrack.new()
	_place(track, SECTIONS[2]["rect"])
	track.steps_changed.connect(func(v: int) -> void: steps_changed.emit(v))

	fire_button = FireButton.new()
	_place(fire_button, FIRE_RECT)
	fire_button.pressed.connect(func() -> void: fire_pressed.emit())

	emblem = TurnEmblem.new()
	_place(emblem, Rect2(960 - TurnEmblem.BASE_SIZE.x * 0.5, 6,
		TurnEmblem.BASE_SIZE.x, TurnEmblem.BASE_SIZE.y))

func _place(control: Control, rect: Rect2) -> void:
	add_child(control)
	control.position = rect.position
	control.size = rect.size

## Build the top banner row. Players are split either side of the emblem, the
## way the mockups arrange four of them.
func build_banners(players: Array[GameState.Player]) -> void:
	for b in _banners:
		b.queue_free()
	_banners.clear()

	var half := int(ceil(players.size() / 2.0))
	for i in players.size():
		var banner := PlayerBanner.new()
		var on_left := i < half
		banner.point_right = on_left
		_banners.append(banner)
		add_child(banner)
		banner.bind(players[i])

		var slot := i if on_left else i - half
		var spacing := PlayerBanner.BASE_SIZE.x + 26.0
		var x := 36.0 + slot * spacing
		if not on_left:
			x = 1920.0 - 36.0 - PlayerBanner.BASE_SIZE.x - slot * spacing
		banner.position = Vector2(x, 18)
		banner.size = PlayerBanner.BASE_SIZE

## Push the whole match state into the widgets.
func refresh(state: GameState) -> void:
	var current := state.current()
	for i in _banners.size():
		_banners[i].active = (i == state.current_index)
		_banners[i].refresh()
	emblem.show_turn(current.name, state.round_number, current.color)
	dial.value = current.angle
	slider.value = current.power
	track.value = current.catapult.step_offset if current.catapult else 0

## Lock the controls while a shot is in the air or the match is over.
func set_interactive(enabled: bool) -> void:
	dial.interactive = enabled
	slider.interactive = enabled
	track.interactive = enabled
	fire_button.disabled = not enabled
	fire_button.queue_redraw()

func _draw() -> void:
	# Stone band
	draw_rect(BAND, RomanStyle.STONE)
	draw_rect(Rect2(BAND.position, Vector2(BAND.size.x, FRIEZE_HEIGHT)), RomanStyle.STONE_LIGHT)
	RomanStyle.greek_key(self,
		Rect2(BAND.position + Vector2(0, 3), Vector2(BAND.size.x, FRIEZE_HEIGHT - 6)),
		RomanStyle.GOLD_DARK)
	draw_line(BAND.position + Vector2(0, FRIEZE_HEIGHT),
		Vector2(BAND.end.x, BAND.position.y + FRIEZE_HEIGHT), RomanStyle.GOLD_DARK, 2.0)

	# Section labels and the hairlines between them
	for section: Dictionary in SECTIONS:
		var rect: Rect2 = section["rect"]
		RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT,
			Vector2(rect.get_center().x, LABEL_BASELINE), section["label"], 26,
			RomanStyle.PARCHMENT, 4.0)
		if section["divider"]:
			var x := rect.end.x + 8.0
			draw_line(Vector2(x, BAND.position.y + FRIEZE_HEIGHT + 14),
				Vector2(x, BAND.end.y - 14), RomanStyle.STONE_LIGHT, 2.0)
