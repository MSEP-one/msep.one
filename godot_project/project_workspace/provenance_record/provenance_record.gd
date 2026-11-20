class_name ProvenanceRecord extends Resource
## Holds the snapshot of one online project version that a workspace was built from.

@export_storage var version_uuid: String = ""
@export_storage var project_name: String = ""
@export_storage var project_namespace: String = ""
@export_storage var creator: String = ""
@export_storage var organization: String = ""
@export_storage var description: String = ""
@export_storage var keywords: PackedStringArray = []
@export_storage var upload_date: String = ""
@export_storage var image_webp: PackedByteArray = []
@export_storage var link: String = ""
@export_storage var children: Array[ProvenanceRecord] = []

var _image_cache: Texture2D = null


func duplicate_tree() -> ProvenanceRecord:
	var copy: ProvenanceRecord = duplicate() as ProvenanceRecord
	copy.children = []
	for child: ProvenanceRecord in children:
		copy.children.push_back(child.duplicate_tree())
	return copy


func has_image() -> bool:
	return not image_webp.is_empty()


func get_image() -> Texture2D:
	if not has_image():
		return null
	if _image_cache == null:
		var image := Image.new()
		var load_error: Error = image.load_webp_from_buffer(image_webp)
		if load_error != OK:
			return null
		_image_cache = ImageTexture.create_from_image(image)
	return _image_cache


func set_image_from_png(in_png_bytes: PackedByteArray) -> void:
	_image_cache = null
	if in_png_bytes.is_empty():
		image_webp = []
		return
	var image := Image.new()
	var load_error: Error = image.load_png_from_buffer(in_png_bytes)
	if load_error != OK:
		image_webp = []
		return
	const LOSSY: bool = true
	const QUALITY: float = 0.8
	image_webp = image.save_webp_to_buffer(LOSSY, QUALITY)
