class_name DownloadableTexture
extends AtlasTexture


static var _avatar_cache: Dictionary[String, DownloadableTexture]
static func create(url: String, fallback: Texture2D) -> DownloadableTexture:
	if not _avatar_cache.has(url):
		_avatar_cache[url] = DownloadableTexture.new()
		var size: Vector2i = Vector2i(64, 64) if fallback == null else Vector2i(fallback.get_size())
		_avatar_cache[url].atlas = get_loading_texture(size)
		var promise: Promise = MolecularEditorContext.msep_online.download_image(url)
		_handle_download_promise(url, _avatar_cache[url], promise, fallback)
	return _avatar_cache[url]


static func create_thumbnail(uuid: String, fallback: Texture2D) -> DownloadableTexture:
	var url: String = MsepOnline.get_base_url() + "v/%s/thumbnail" % uuid
	return create(url, fallback)


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
	var download_error: String = MsepOnline.get_response_error(promise)
	if not download_error.is_empty():
		push_warning("Failed to download image %s: %s" % [url, download_error])
		texture.atlas = fallback
		return
	var image: Image = image_from_response(url, promise.get_result().raw_body)
	var decoded: bool = image != null
	if decoded:
		texture.atlas = ImageTexture.create_from_image(image)
	else:
		texture.atlas = fallback


## Decodes a downloaded image based on the extension of its url, returns null for unknown formats.
static func image_from_response(in_url: String, in_raw_body: PackedByteArray) -> Image:
	var extension: String = in_url.split("?")[0].get_extension().to_lower()
	var image := Image.new()
	match extension:
		"png", "":
			# Empty extension is assumed to come from /v/:version_uuid/thumbnail endpoint
			image.load_png_from_buffer(in_raw_body)
		"jpg", "jpeg":
			image.load_jpg_from_buffer(in_raw_body)
		"bmp":
			image.load_bmp_from_buffer(in_raw_body)
		"svg":
			image.load_svg_from_buffer(in_raw_body)
		"webp":
			image.load_webp_from_buffer(in_raw_body)
		"tga":
			image.load_tga_from_buffer(in_raw_body)
		_:
			push_warning("Unknown image extension '%s'" % extension)
			return null
	return image
