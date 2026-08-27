extends VBoxContainer


@onready var _fragment_button: Button = %FragmentButton
@onready var _label: Label = %Label
@onready var _texture_rect: TextureRect = %TextureRect


func set_text(text: String) -> void:
	if not is_node_ready():
		await ready
	_label.text = text


func set_path(file_path: String) -> void:
	if not is_node_ready():
		await ready
	_fragment_button.set_meta(&"fragment_path", file_path)


func set_thumbnail(texture_path: String) -> void:
	if not is_node_ready():
		await ready
	if not ResourceLoader.exists(texture_path):
		return
	_texture_rect.texture = load(texture_path)


func set_group(button_group: ButtonGroup) -> void:
	if not is_node_ready():
		await ready
	_fragment_button.button_group = button_group
