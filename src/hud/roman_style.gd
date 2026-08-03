class_name RomanStyle
extends RefCounted

## The shared visual language of the HUD: palette, fonts, and the handful of
## motifs that recur across every instrument in the reference mockups — coin
## knobs, laurel wreaths, the aquila, and the Greek-key frieze.
##
## Everything is drawn rather than sprited, so it stays crisp at any resolution
## and re-tints per player without a second set of assets.

const GOLD := Color("#c8a34a")
const GOLD_BRIGHT := Color("#f0d998")
const GOLD_DARK := Color("#7d6222")
const CRIMSON := Color("#8f1f22")
const CRIMSON_BRIGHT := Color("#c8353a")
const CRIMSON_DARK := Color("#5a1214")
const STONE := Color("#2a2622")
const STONE_LIGHT := Color("#3d3830")
const STONE_DARK := Color("#141210")
const PARCHMENT := Color("#ece0c4")
const INK := Color("#1a1613")

const DISPLAY_FONT := preload("res://assets/fonts/ArsenalSC-Regular.ttf")
const NUMERAL_FONT := preload("res://assets/fonts/CrimsonPro-Bold.ttf")

# --- text -------------------------------------------------------------------

## Centred text. `pos` is the centre of the text's baseline box.
static func text_centred(ci: CanvasItem, font: Font, centre: Vector2, text: String,
		size: int, colour: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ascent := font.get_ascent(size)
	ci.draw_string(font, centre - Vector2(w * 0.5, -ascent * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

## Centred text with letter spacing, for the wide-tracked labels the mockups
## use on ANGLE / FORCE / STEPS. draw_string has no tracking, so lay it out by
## hand one glyph at a time.
static func tracked_centred(ci: CanvasItem, font: Font, centre: Vector2, text: String,
		size: int, colour: Color, tracking: float) -> void:
	var widths: Array[float] = []
	var total := 0.0
	for i in text.length():
		var w := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w + tracking
	total -= tracking

	var ascent := font.get_ascent(size)
	var x := centre.x - total * 0.5
	var y := centre.y + ascent * 0.5
	for i in text.length():
		ci.draw_string(font, Vector2(x, y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += widths[i] + tracking

# --- panels -----------------------------------------------------------------

## A slab of dark stone with a bevelled gold edge — the base of every panel.
static func stone_panel(ci: CanvasItem, rect: Rect2, corner := 6.0, edge := GOLD_DARK) -> void:
	ci.draw_rect(rect, STONE)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), STONE_LIGHT)
	ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), STONE_DARK)
	_rect_outline(ci, rect, edge, 2.0)
	# corner is accepted for call-site readability; the outline is square by design
	if corner < 0.0:
		pass

static func _rect_outline(ci: CanvasItem, rect: Rect2, colour: Color, width: float) -> void:
	var p := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
		rect.position,
	])
	ci.draw_polyline(p, colour, width)

## The meander frieze that runs along the top edge of the HUD band.
static func greek_key(ci: CanvasItem, rect: Rect2, colour: Color) -> void:
	var unit := 15.0
	var w := 2.0
	var x := rect.position.x
	var top := rect.position.y + 3.0
	var bottom := rect.end.y - 3.0
	var mid := (top + bottom) * 0.5
	while x + unit < rect.end.x:
		ci.draw_line(Vector2(x, bottom), Vector2(x, top), colour, w)
		ci.draw_line(Vector2(x, top), Vector2(x + unit * 0.75, top), colour, w)
		ci.draw_line(Vector2(x + unit * 0.75, top), Vector2(x + unit * 0.75, mid), colour, w)
		ci.draw_line(Vector2(x + unit * 0.75, mid), Vector2(x + unit * 0.35, mid), colour, w)
		x += unit
	ci.draw_line(Vector2(rect.position.x, bottom), Vector2(rect.end.x, bottom), colour, w)

# --- motifs -----------------------------------------------------------------

## The coin that serves as every knob, marker and portrait in the mockups:
## a struck bronze disc with an emperor's profile.
static func coin(ci: CanvasItem, centre: Vector2, radius: float, tint := GOLD) -> void:
	ci.draw_circle(centre, radius, tint.darkened(0.45))
	ci.draw_circle(centre, radius - radius * 0.10, tint)
	ci.draw_circle(centre - Vector2(radius * 0.12, radius * 0.14), radius * 0.72, tint.lightened(0.18))
	ci.draw_arc(centre, radius - radius * 0.05, 0.0, TAU, 28, tint.darkened(0.3), maxf(1.0, radius * 0.08))

	# Emperor's bust in profile, facing left. Traced as an actual head outline —
	# brow, nose, lips, chin, jaw — because a blob silhouette reads as a blob at
	# every size, and this motif appears on every knob in the interface.
	var r := radius
	var bust := PackedVector2Array()
	for p: Vector2 in [
		Vector2(0.30, -0.44),   # back of the skull
		Vector2(0.04, -0.58),   # crown
		Vector2(-0.22, -0.42),  # forehead
		Vector2(-0.31, -0.18),  # brow
		Vector2(-0.44, 0.02),   # nose
		Vector2(-0.28, 0.09),   # under the nose
		Vector2(-0.31, 0.21),   # lips
		Vector2(-0.20, 0.31),   # chin
		Vector2(-0.06, 0.40),   # jaw
		Vector2(0.16, 0.46),    # neck
		Vector2(0.40, 0.34),    # shoulder
		Vector2(0.44, -0.12),   # back of the head
	]:
		bust.append(centre + p * r)
	ci.draw_colored_polygon(bust, tint.darkened(0.36))
	# Hairline and eye: the two marks that keep it legible when it is 12px wide.
	ci.draw_line(centre + Vector2(-0.20, -0.36) * r, centre + Vector2(0.26, -0.30) * r,
		tint.darkened(0.55), maxf(1.0, r * 0.07))
	ci.draw_circle(centre + Vector2(-0.20, -0.10) * r, maxf(1.0, r * 0.055),
		tint.lightened(0.4))

## A laurel wreath: two branches rising from the bottom and curving up either
## side, open at the top, the way a victor's crown is always drawn.
##
## `spread` is how far around the circle each branch reaches, in radians. About
## 2.4 closes it into a wreath; 1.2 leaves a short sprig for flanking text.
static func laurel(ci: CanvasItem, centre: Vector2, radius: float, colour: Color,
		spread := 2.4) -> void:
	# Leaf size is capped rather than scaled straight off the radius: a real
	# laurel has many modest leaves, so a big wreath needs *more* of them, not
	# bigger ones. Left proportional, a 400px wreath grows 160px leaves.
	var leaf_length := clampf(radius * 0.34, 14.0, 56.0)
	var leaf_width := leaf_length * 0.30
	# Then the count follows the arc, so the overlap between neighbours stays
	# the same whatever the size or how far round the branch reaches.
	var arc := radius * spread
	var leaves := clampi(int(round(arc / (leaf_length * 0.62))), 3, 24)
	for side: float in [-1.0, 1.0]:
		# Stem: an arc the leaves sit along.
		var stem := PackedVector2Array()
		for i in 17:
			var a := -PI * 0.5 + side * (float(i) / 16.0) * spread
			stem.append(centre + Vector2(cos(a), -sin(a)) * radius)
		ci.draw_polyline(stem, colour.darkened(0.32), maxf(1.5, radius * 0.028))

		for i in leaves:
			var t := (float(i) + 0.5) / float(leaves)
			var a := -PI * 0.5 + side * t * spread
			var at := centre + Vector2(cos(a), -sin(a)) * radius
			# Leaves splay outward from the stem, tilting further along it as
			# the branch rises.
			var along := Vector2(sin(a), cos(a)) * side
			var outward := (at - centre).normalized()
			var dir := (along * 0.62 + outward).normalized()
			_leaf(ci, at, dir, leaf_length * (0.80 + 0.20 * t), leaf_width,
				colour.lerp(Color.WHITE, 0.04 + 0.10 * t))

## One laurel leaf: a lens tapering to a point at both ends.
static func _leaf(ci: CanvasItem, root: Vector2, dir: Vector2, length: float,
		width: float, colour: Color) -> void:
	var perp := dir.orthogonal() * width
	var tip := root + dir * length
	var poly := PackedVector2Array([
		root,
		root + dir * (length * 0.32) + perp,
		root + dir * (length * 0.68) + perp * 0.72,
		tip,
		root + dir * (length * 0.68) - perp * 0.72,
		root + dir * (length * 0.32) - perp,
	])
	ci.draw_colored_polygon(poly, colour)
	ci.draw_line(root, tip, colour.darkened(0.28), maxf(1.0, width * 0.22))

## A stylised aquila — the legionary eagle that crowns the turn emblem and the
## fire button. Wings raised in a V rather than spread flat: it is the more
## distinctive silhouette and survives being drawn 30px tall.
static func aquila(ci: CanvasItem, centre: Vector2, size: float, colour: Color) -> void:
	var s := size * 0.5
	var dark := colour.darkened(0.34)

	for side: float in [-1.0, 1.0]:
		# Leading edge sweeps up and out; trailing edge steps back down in
		# three feathers, which is what makes it read as a bird and not a kite.
		var wing := PackedVector2Array()
		for p: Vector2 in [
			Vector2(0.10, 0.02), Vector2(0.40, -0.46), Vector2(0.72, -0.82),
			Vector2(1.00, -1.04), Vector2(0.86, -0.72), Vector2(0.94, -0.66),
			Vector2(0.72, -0.42), Vector2(0.80, -0.36), Vector2(0.54, -0.16),
			Vector2(0.60, -0.10), Vector2(0.30, 0.10),
		]:
			wing.append(centre + Vector2(p.x * side, p.y) * s)
		ci.draw_colored_polygon(wing, colour)
		ci.draw_polyline(wing + PackedVector2Array([wing[0]]), dark, maxf(1.0, s * 0.035))

	# Body tapering into a tail fan.
	var body := PackedVector2Array()
	for p: Vector2 in [
		Vector2(-0.17, -0.10), Vector2(0.17, -0.10), Vector2(0.13, 0.46),
		Vector2(0.28, 0.86), Vector2(0.0, 0.72), Vector2(-0.28, 0.86),
		Vector2(-0.13, 0.46),
	]:
		body.append(centre + p * s)
	ci.draw_colored_polygon(body, colour)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), dark, maxf(1.0, s * 0.035))

	# Head turned to the left, as on every standard in the reference art.
	var head := centre + Vector2(-0.04, -0.30) * s
	ci.draw_circle(head, 0.19 * s, colour)
	ci.draw_colored_polygon(PackedVector2Array([
		head + Vector2(-0.12, -0.08) * s,
		head + Vector2(-0.48, 0.02) * s,
		head + Vector2(-0.12, 0.12) * s,
	]), colour.lightened(0.12))
	ci.draw_circle(head + Vector2(-0.02, -0.04) * s, maxf(1.0, 0.055 * s), dark)

## A vertical alpha fade, drawn as a stack of thin strips. draw_rect has no
## gradient and building a GradientTexture per frame would be worse; fifty
## rectangles cost nothing and the banding is invisible.
static func fade_rect(ci: CanvasItem, rect: Rect2, colour: Color,
		alpha_top: float, alpha_bottom: float) -> void:
	# One strip every couple of pixels. A fixed step count banded visibly over
	# tall fades and wasted draws on short ones.
	var steps := clampi(int(rect.size.y * 0.5), 16, 260)
	for i in steps:
		# Snap to whole pixels and butt each strip against the next. Overlapping
		# them by a pixel double-blends the seam and stripes the whole fade.
		var y0 := floorf(rect.position.y + rect.size.y * float(i) / float(steps))
		var y1 := floorf(rect.position.y + rect.size.y * float(i + 1) / float(steps))
		if y1 <= y0:
			continue
		var t := float(i) / float(steps - 1)
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0),
			Color(colour.r, colour.g, colour.b, lerpf(alpha_top, alpha_bottom, t)))

## Soft outer glow, used to pick out the active player's banner.
static func glow(ci: CanvasItem, rect: Rect2, colour: Color, layers := 6) -> void:
	for i in range(layers, 0, -1):
		var grow := float(i) * 2.4
		var a := 0.16 * (1.0 - float(i) / float(layers + 1))
		_rect_outline(ci, rect.grow(grow), Color(colour.r, colour.g, colour.b, a), 3.0)
