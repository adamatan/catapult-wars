class_name FieldLibrary
extends RefCounted

## The battlefield table, loaded from the generated manifest.
##
## assets/backdrops/backdrops.json is written by scripts/make_backdrops.py and
## is the single source of truth for a field: its horizon plate plus the sky,
## haze and terrain colours that blend into it.
##
## Deliberately static rather than an autoload. Autoloads are not reliably
## registered when the engine is driven by `--script`, which is how both the
## test runner and the screenshot harness run, and a table of four constants
## does not need a node in the tree.

const MANIFEST := "res://assets/backdrops/backdrops.json"

class Field extends RefCounted:
	var slug: String
	var title: String
	var texture: Texture2D
	var sky_color: Color
	var haze_color: Color
	var rock_color: Color
	var crust_color: Color

static var _fields: Array[Field] = []
static var _loaded := false

static func all() -> Array[Field]:
	if not _loaded:
		_load()
	return _fields

static func random_field() -> Field:
	var fields := all()
	if fields.is_empty():
		return null
	return fields[randi() % fields.size()]

static func by_slug(slug: String) -> Field:
	for f in all():
		if f.slug == slug:
			return f
	return null

static func _load() -> void:
	_loaded = true
	var text := FileAccess.get_file_as_string(MANIFEST)
	if text.is_empty():
		push_error("FieldLibrary: could not read %s — run scripts/make_backdrops.py" % MANIFEST)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("FieldLibrary: %s is not a JSON array" % MANIFEST)
		return
	for entry: Dictionary in parsed:
		var f := Field.new()
		f.slug = entry["slug"]
		f.title = entry["title"]
		f.texture = load(entry["texture"])
		f.sky_color = _rgb(entry["sky_color"])
		f.haze_color = _rgb(entry["haze_color"])
		f.rock_color = Color(entry["rock_color"])
		f.crust_color = Color(entry["crust_color"])
		_fields.append(f)

static func _rgb(triple: Array) -> Color:
	# Not Color8: it is compatibility-only, so it vanishes from an engine built
	# with deprecated=no — which is exactly how the shipped web template is built.
	return Color(int(triple[0]) / 255.0, int(triple[1]) / 255.0, int(triple[2]) / 255.0)
