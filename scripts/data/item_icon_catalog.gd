extends RefCounted

static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/items/catalog.json"))
	return _catalog

static func path(id: String) -> String:
	var data := catalog()
	var key: String = data.aliases.get(id, id)
	return "res://" + data.icons[key].path if data.icons.has(key) else ""

static func texture(id: String) -> Texture2D:
	var asset := path(id)
	if asset.is_empty():
		return null
	if not _textures.has(asset):
		_textures[asset] = load(asset)
	return _textures[asset]

static func view(id: String, pixels: int = 24) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(id)
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
