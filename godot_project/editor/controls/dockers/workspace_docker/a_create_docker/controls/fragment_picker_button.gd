extends VBoxContainer


signal selected


@onready var _fragment_button: Button = %FragmentButton
@onready var _label: Label = %Label
@onready var _texture_rect: TextureRect = %TextureRect


func _ready() -> void:
	_fragment_button.pressed.connect(_on_fragment_button_pressed)


func set_text(text: String) -> void:
	if not _label:
		await ready
	_label.text = text


func set_thumbnail(texture_path: String) -> void:
	if not _texture_rect:
		await ready
	if not ResourceLoader.exists(texture_path):
		return
	_texture_rect.texture = load(texture_path)


func set_group(button_group: ButtonGroup) -> void:
	_fragment_button.button_group = button_group


func _on_fragment_button_pressed() -> void:
	selected.emit()
