extends PopupPanel


@onready var _resize_handle: TextureRect = %ResizeHandle


var _resizing: bool = false

func _init() -> void:
	visible = Engine.is_editor_hint()


func _ready() -> void:
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	EditorSfx.register_window(self, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_ring_menu"):
		hide()
		var context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		WorkspaceUtils.forward_event(context, event)


func _on_resize_handle_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseButton and in_event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = in_event.pressed
	if in_event is InputEventMouseMotion and _resizing:
		size = get_mouse_position()
