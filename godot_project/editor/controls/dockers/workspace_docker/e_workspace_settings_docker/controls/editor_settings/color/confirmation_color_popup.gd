class_name ConfirmationColorPopup
extends PopupPanel

const SINGLE_COLOR_BUTTON := preload("./single_color_button.tscn")
const DEFAULT_COLOR: Color = Color.BLACK

@export var edit_alpha: bool = true:
	set = _set_edit_alpha

@onready var _apply_btn: Button = %ApplyBtn
@onready var _default_btn: Button = %DefaultBtn
@onready var _color_picker: ColorPicker = %ColorPicker
@onready var _preset_colors: HFlowContainer = %PresetColors

var _selected_color: Color
var _recent_colors: Array[Color]

signal color_selected(color: Color)
signal default_pressed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_color_picker.color = DEFAULT_COLOR
	
	_color_picker.color_changed.connect(_on_color_picker_color_changed)
	_apply_btn.pressed.connect(_on_apply_button_pressed)
	_default_btn.pressed.connect(_on_default_button_pressed)


func set_default_button_visible(in_visible: bool) -> void:
	_default_btn.visible = in_visible


func set_apply_button_visible(in_visible: bool) -> void:
	_apply_btn.visible = in_visible


func set_current_color(in_color: Color) -> void:
	_color_picker.color = in_color


func _on_color_picker_color_changed(in_color: Color) -> void:
	if not _apply_btn.visible:
		_selected_color = in_color
		color_selected.emit(_selected_color)


func _on_apply_button_pressed() -> void:
	_selected_color = _color_picker.color
	color_selected.emit(_selected_color)
	if not _selected_color in _recent_colors:
		_recent_colors.append(_selected_color)
		_update_recent_colors()
	hide()


func _on_default_button_pressed() -> void:
	_color_picker.color = DEFAULT_COLOR
	_selected_color = _color_picker.color
	
	default_pressed.emit()
	hide()


func _update_recent_colors() -> void:
	for child in _preset_colors.get_children():
		child.queue_free()
	
	for color: Color in _recent_colors:
		var color_button: SingleColorButton = SINGLE_COLOR_BUTTON.instantiate()
		_preset_colors.add_child(color_button)
		color_button.color = color
		color_button.pressed.connect(_on_recent_color_selected.bind(color))


func _set_edit_alpha(in_edit_alpha: bool) -> void:
	edit_alpha = in_edit_alpha
	if not is_node_ready():
		await ready
	_color_picker.edit_alpha = edit_alpha


func _on_recent_color_selected(in_color: Color) -> void:
	_color_picker.color = in_color
	_on_apply_button_pressed()
