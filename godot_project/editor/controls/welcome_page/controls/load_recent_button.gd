extends Button

signal context_menu_requested(button: Button, filepath: String)

var _thumbnail_texture_rect: TextureRect
var _workspace_name_label: Label
var _animation_player: AnimationPlayer


var _filepath: String


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_thumbnail_texture_rect = %ThumbnailTextureRect as TextureRect
		_workspace_name_label = %WorkspaceNameLabel as Label
		_animation_player = %AnimationPlayer as AnimationPlayer


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


func setup_for_activation() -> void:
	var workspace_name: String = _filepath.get_file().get_basename().capitalize()
	_workspace_name_label.text = tr("Go to '%s'") % workspace_name
	tooltip_text = tr("Activate %s" % [_filepath])


func _draw() -> void:
	if is_hovered():
		_animation_player.play(&"hover")
	else:
		_animation_player.play(&"normal")
