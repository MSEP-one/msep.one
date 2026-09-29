extends Button

signal context_menu_requested(button: Button, filepath: String)
signal selection_toggled(button: Button, filepath: String, selected: bool)

var _thumbnail_texture_rect: TextureRect
var _workspace_name_label: Label
var _animation_player: AnimationPlayer
var _select_check_box: CheckBox


var _filepath: String


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_thumbnail_texture_rect = %ThumbnailTextureRect as TextureRect
		_workspace_name_label = %WorkspaceNameLabel as Label
		_animation_player = %AnimationPlayer as AnimationPlayer
		_select_check_box = %SelectCheckBox as CheckBox
		_select_check_box.toggled.connect(_on_select_check_box_toggled)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		get_viewport().set_input_as_handled()
		context_menu_requested.emit(self, _filepath)


func set_workspace_path(in_filepath: String) -> void:
	_filepath = in_filepath
	var thumbnail: Texture2D = WorkspaceUtils.extract_embedded_thumbnail(_filepath)
	if thumbnail != null:
		_thumbnail_texture_rect.texture = thumbnail
	var workspace_name: String = _filepath.get_file().get_basename().capitalize()
	_workspace_name_label.text = workspace_name
	tooltip_text = _filepath


func is_selected() -> bool:
	return _select_check_box.button_pressed


func set_selected(in_selected: bool) -> void:
	_select_check_box.button_pressed = in_selected


func _on_select_check_box_toggled(in_toggled_on: bool) -> void:
	selection_toggled.emit(self, _filepath, in_toggled_on)


func setup_for_activation() -> void:
	var workspace_name: String = _filepath.get_file().get_basename().capitalize()
	_workspace_name_label.text = tr("Go to '%s'") % workspace_name
	tooltip_text = tr("Activate %s" % [_filepath])


func _draw() -> void:
	if is_hovered():
		_animation_player.play(&"hover")
	else:
		_animation_player.play(&"normal")
