extends VBoxContainer

const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
const ICON_SIZE := 20
const MATERIAL_IDS := ["copper", "iron", "crystal", "silica", "cobalt",
	"structural_component", "electronic_component", "copper_ingot", "glass",
	"water", "acid", "oil", "gas"]
const ALIASES := {
	"cristalli": "crystal", "quarzi": "silica",
	"componenti strutturali": "structural_component",
	"strutturale": "structural_component", "strutturali": "structural_component",
	"componenti elettronici": "electronic_component",
	"elettronico": "electronic_component", "elettronici": "electronic_component",
	"lingotti di rame": "copper_ingot", "lingotto rame": "copper_ingot",
	"lingotti rame": "copper_ingot", "lingotto": "copper_ingot", "lingotti": "copper_ingot",
}
static var _matcher: RegEx
static var _names: Dictionary = {}

var rich_text := RichTextLabel.new()
# Keep the editable source separate from RichTextLabel's inline image document.
var text := "":
	set(value):
		if text == value:
			return
		text = value
		_render()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich_text.bbcode_enabled = false
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_text.custom_minimum_size = Vector2(300, 0)
	rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich_text.add_theme_font_size_override("normal_font_size", 16)
	rich_text.add_theme_color_override("default_color", Color("223933"))
	add_child(rich_text)

static func material_spans(source: String) -> Array[Dictionary]:
	if _matcher == null:
		_names = ALIASES.duplicate()
		for id: String in MATERIAL_IDS:
			_names[ItemIcons.catalog().icons[id].name.to_lower()] = id
		var names := _names.keys()
		names.sort_custom(func(a: String, b: String): return a.length() > b.length())
		var alternatives: PackedStringArray = []
		for name: String in names:
			alternatives.append("\\Q" + name + "\\E")
		_matcher = RegEx.new()
		_matcher.compile("(?i)(?<![\\p{L}\\p{N}_])(?:" + "|".join(alternatives) + ")(?![\\p{L}\\p{N}_])")
	var result: Array[Dictionary] = []
	for matched: RegExMatch in _matcher.search_all(source):
		result.append({"start": matched.get_start(), "end": matched.get_end(),
			"item_id": _names[matched.get_string().to_lower()]})
	return result

func _render() -> void:
	rich_text.clear()
	var cursor := 0
	for span: Dictionary in material_spans(text):
		rich_text.add_text(text.substr(cursor, span.end - cursor))
		var icon := ItemIcons.texture(span.item_id)
		if icon != null:
			rich_text.add_text(" ")
			rich_text.add_image(icon, ICON_SIZE, ICON_SIZE, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		cursor = span.end
	rich_text.add_text(text.substr(cursor))
