class_name NanoGroupPicker extends Button


signal nano_structure_clicked(structure_id: int)

@export var can_select_current: bool = true
var selected_id: int: set = _set_selected_id, get = _get_selected_id

var _nano_structure_picker_popup_panel: NanoGroupPickerPopupPanel

# Called when the node enters the scene tree for the first time.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_nano_structure_picker_popup_panel = $NanoGroupPickerPopupPanel as NanoGroupPickerPopupPanel
		_nano_structure_picker_popup_panel.can_select_current = can_select_current
		pressed.connect(_on_pressed)


func initialize(out_workspace_context: WorkspaceContext) -> void:
	_nano_structure_picker_popup_panel.initialize(out_workspace_context)
	text = _nano_structure_picker_popup_panel.get_selected_structure_name()
	_nano_structure_picker_popup_panel.nano_structure_clicked.connect(
		_on_nano_structure_picker_popup_panel_nano_structure_clicked)
	out_workspace_context.current_structure_context_changed.connect(
		_on_current_structure_context_changed)


func rebuild(in_workspace_context: WorkspaceContext) -> void:
	initialize(in_workspace_context)


func _set_selected_id(in_selected_id: int) -> void:
	_nano_structure_picker_popup_panel.selected_id = in_selected_id


func _get_selected_id() -> int:
	return _nano_structure_picker_popup_panel.selected_id


func _on_pressed() -> void:
	var self_rect: Rect2i = get_global_rect()
	var popup_position := self_rect.position + Vector2i(0, self_rect.size.y)
	var viewport_size: Vector2i = get_viewport_rect().size
	var min_popup_size: Vector2i = _nano_structure_picker_popup_panel.get_contents_minimum_size()
	if self_rect.position.x + min_popup_size.x > viewport_size.x:
		popup_position.x = self_rect.end.x - min_popup_size.x
		popup_position.x = max(popup_position.x, 0)
	if self_rect.end.y + min_popup_size.y > viewport_size.y:
		popup_position.y = self_rect.position.y - min_popup_size.y
		popup_position.y = max(popup_position.y, 0)
	_nano_structure_picker_popup_panel.popup(Rect2i(popup_position, min_popup_size))


func _on_nano_structure_picker_popup_panel_nano_structure_clicked(in_structure_id: int) -> void:
	text = _nano_structure_picker_popup_panel.get_selected_structure_name()
	nano_structure_clicked.emit(in_structure_id)


func _on_current_structure_context_changed(structure_context: StructureContext) -> void:
	var nano_structure: NanoStructure = structure_context.nano_structure
	if not is_instance_valid(nano_structure) or nano_structure is NanoShape:
		return
	selected_id = nano_structure.int_guid
