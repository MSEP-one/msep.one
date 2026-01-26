class_name DownloadableTexture
extends AtlasTexture


static var _avatar_cache: Dictionary[String, DownloadableTexture]
static func create(url: String, fallback: Texture2D) -> DownloadableTexture:
	if not _avatar_cache.has(url):
		_avatar_cache[url] = DownloadableTexture.new()
		var size: Vector2i = Vector2i(64, 64) if fallback == null else Vector2i(fallback.get_size())
		_avatar_cache[url].atlas = get_loading_texture(size)
		var promise: Promise = MolecularEditorContext.msep_online_service.download_image(url)
		_handle_download_promise(url, _avatar_cache[url], promise, fallback)
	return _avatar_cache[url]


static var _loading_texture_cache: Dictionary[Vector2i, Texture2D]
static var _loading_gradient: Gradient
static func get_loading_texture(size: Vector2i) -> Texture2D:
	
	if not _loading_texture_cache.has(size):
		_loading_texture_cache[size] = GradientTexture2D.new()
		_loading_texture_cache[size].width = size.x
		_loading_texture_cache[size].height = size.y
		if _loading_gradient == null:
			const LOADING_COLOR := Color8(129, 106, 176)
			_loading_gradient = Gradient.new()
			_loading_gradient.colors = [LOADING_COLOR, LOADING_COLOR]
			_loading_gradient.offsets = [0.0, 1.0]
		_loading_texture_cache[size].gradient = _loading_gradient
	return _loading_texture_cache[size]


static func _handle_download_promise(
		url: String,
		texture: DownloadableTexture,
		promise: Promise,
		fallback: Texture2D) -> void:
	await promise.wait_for_fulfill()
	if promise.has_error():
		push_error("Failed to download image: ", promise.get_error())
		texture.atlas = fallback
		return
	var extension: String = url.get_extension().to_lower()
	var image := Image.new()
	match extension:
		"png":
			image.load_png_from_buffer(promise.get_result().raw_body)
		"jpg", "jpeg":
			image.load_jpg_from_buffer(promise.get_result().raw_body)
		"bmp":
			image.load_bmp_from_buffer(promise.get_result().raw_body)
		"svg":
			image.load_svg_from_buffer(promise.get_result().raw_body)
		"webp":
			image.load_webp_from_buffer(promise.get_result().raw_body)
		"tga":
			image.load_tga_from_buffer(promise.get_result().raw_body)
		_:
			push_warning("Unknown image extension '%s'" % extension)
			texture.atlas = fallback
			return
	texture.atlas = ImageTexture.create_from_image(image)
