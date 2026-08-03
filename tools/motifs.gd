extends Control

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), RomanStyle.STONE)
	var y := 180.0
	for s: float in [40.0, 70.0, 120.0, 200.0]:
		var x := 200.0 + (s - 40.0) * 3.4
		RomanStyle.aquila(self, Vector2(x, y), s, RomanStyle.GOLD)
		RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT, Vector2(x, y + 140), "aquila %d" % int(s), 20, RomanStyle.PARCHMENT)
	y = 560.0
	var xs := [160.0, 400.0, 760.0, 1400.0]
	var rs := [30.0, 70.0, 150.0, 420.0]
	for i in 4:
		RomanStyle.laurel(self, Vector2(xs[i], y), rs[i], RomanStyle.GOLD, 2.4)
		RomanStyle.text_centred(self, RomanStyle.DISPLAY_FONT, Vector2(xs[i], y + 20), "%d" % int(rs[i]), 22, RomanStyle.PARCHMENT)
	y = 940.0
	RomanStyle.laurel(self, Vector2(400, y), 60.0, RomanStyle.GOLD, 1.3)
	RomanStyle.laurel(self, Vector2(700, y), 60.0, RomanStyle.GOLD, 1.3)
	RomanStyle.tracked_centred(self, RomanStyle.DISPLAY_FONT, Vector2(550, y), "SPRIGS", 40, RomanStyle.PARCHMENT, 6.0)
	for i in 4:
		RomanStyle.coin(self, Vector2(1100 + i * 150, y), 14.0 + i * 18.0, RomanStyle.GOLD)
