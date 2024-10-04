class_name ViewportInput extends Node
##  Responsible for recognizing and propagating inputs received by WorkspaceEditorViewport

const DEFAULT_INPUT_HANDLERS_PATH = "res://editor/input_handlers/"


var _input_handlers: Array[InputHandlerBase] = []
var _workspace_context: WorkspaceContext = null
var _exclusive_input_consumer: InputHandlerBase = null


func init(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	load_input_handlers()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_input_handlers.clear()

func has_exclusive_input_consumer() -> bool:
	return is_instance_valid(_exclusive_input_consumer)

func forward_viewport_input(in_event: InputEvent, in_workspace_editor_viewport: WorkspaceEditorViewport,
			in_structure_context: StructureContext) -> void:
	if in_event is InputEventMouseButton and in_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		if in_event.is_pressed():
			EditorSfx.mouse_down()
		else:
			EditorSfx.mouse_up()
	if _on_exclusive_input_consumer(in_event, in_workspace_editor_viewport, in_structure_context):
		return
	
	if in_structure_context == null:
		return
	
	_serve_all_handlers(in_event, in_workspace_editor_viewport, in_structure_context)


func notify_input_omitted() -> void:
	_propagate_input_omitted(_input_handlers, -1)


func _on_exclusive_input_consumer(in_event: InputEvent, in_workspace_editor_viewport: WorkspaceEditorViewport,
			in_structure_context: StructureContext) -> bool:
	var camera_3d: Camera3D = in_workspace_editor_viewport.get_camera_3d()
	if is_instance_valid(_exclusive_input_consumer):
		if _exclusive_input_consumer.is_exclusive_input_consumer():
			if _exclusive_input_consumer.forward_input(in_event, camera_3d, in_structure_context):
				in_workspace_editor_viewport.set_input_as_handled()
			return true
		else:
			_exclusive_input_consumer = null
	return false


func _serve_empty_selection_handlers(in_event: InputEvent, in_workspace_editor_viewport: WorkspaceEditorViewport,
			in_structure_context: StructureContext) -> void:
	var camera_3d: Camera3D = in_workspace_editor_viewport.get_camera_3d()
	var handlers_handling_empty_selection: Array[InputHandlerBase] = _input_handlers.filter(_is_empty_selection_handler)
	var nmb_of_empty_selection_handlers: int = handlers_handling_empty_selection.size()
	for empty_selection_handler_idx in range(nmb_of_empty_selection_handlers):
		var empty_selection_handler: InputHandlerBase = handlers_handling_empty_selection[empty_selection_handler_idx]
		if empty_selection_handler.forward_input(in_event, camera_3d, in_structure_context):
			_propagate_input_omitted(handlers_handling_empty_selection, empty_selection_handler_idx)
			_exclusive_input_capture_check(empty_selection_handler)
			in_workspace_editor_viewport.set_input_as_handled()
			return


func _is_empty_selection_handler(in_handler: InputHandlerBase) -> bool:
	return in_handler.handles_empty_selection()


func _serve_all_handlers(in_event: InputEvent, in_workspace_editor_viewport: WorkspaceEditorViewport,
			in_structure_context: StructureContext) -> void:
	var camera_3d: Camera3D = in_workspace_editor_viewport.get_camera_3d()
	var nmb_of_input_handlers: int = _input_handlers.size()
	for handler_idx in range(nmb_of_input_handlers):
		var handler: InputHandlerBase = _input_handlers[handler_idx]
		if handler.handles_structure_context(in_structure_context):
			if handler.forward_input(in_event, camera_3d, in_structure_context) or handler.is_exclusive_input_consumer():
				_propagate_input_omitted(_input_handlers, handler_idx)
				_exclusive_input_capture_check(handler)
				in_workspace_editor_viewport.set_input_as_handled()
				break
	_propagate_input_served(_input_handlers)


func _propagate_input_omitted(in_handlers: Array[InputHandlerBase], in_handler_consuming_input_idx: int) -> void:
	var nmb_of_handlers: int = in_handlers.size()
	var first_unserved_handler_idx: int = in_handler_consuming_input_idx + 1
	for idx_omitted_handler in range(first_unserved_handler_idx, nmb_of_handlers):
		var omitted_handler: InputHandlerBase = in_handlers[idx_omitted_handler]
		omitted_handler.handle_input_omission()


func _propagate_input_served(in_handlers: Array[InputHandlerBase]) -> void:
	for handler: InputHandlerBase in in_handlers:
		handler.handle_input_served()


func _exclusive_input_capture_check(in_handler: InputHandlerBase) -> void:
	if in_handler.is_exclusive_input_consumer():
		_exclusive_input_consumer = in_handler
		_notify_handlers_about_exclusive_input_capture()


func _notify_handlers_about_exclusive_input_capture() -> void:
	for handler in _input_handlers:
		if handler != _exclusive_input_consumer:
			handler.handle_inputs_end()


#########
## Loading from files
func load_input_handlers(in_scan_path: String = DEFAULT_INPUT_HANDLERS_PATH) -> void:
	_recursive_load_input_handlers(in_scan_path, true)
	_input_handlers.sort_custom(_input_handlers_compare)


func _recursive_load_input_handlers(in_scan_path: String, in_recursive: bool = true) -> void:
	var dir: DirAccess = DirAccess.open(in_scan_path)
	if !dir:
		push_error("Invalid Path '%s'" % in_scan_path)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = in_scan_path.path_join(file_name)
		if file_name in [".", ".."]:
			pass # Nothing to do here
		elif dir.current_is_dir():
			if in_recursive:
				_recursive_load_input_handlers(full_path, in_recursive)
		else:
			if file_name.get_extension() in ["gd", "gdc"]:
				var script: Script = load(full_path) as Script
				if is_instance_valid(script) and not script in [InputHandlerBase, InputHandlerCreateObjectBase]:
					var s: Script = script
					while s.get_base_script():
						if s.get_base_script() == InputHandlerBase:
							# found a valid input handler
							# avoid double registration just in case
							if !_is_input_handler_registered(script):
								var input_handler: InputHandlerBase = script.new(_workspace_context)
								_input_handlers.push_back(input_handler)
								break
						s = s.get_base_script()
		file_name = dir.get_next()


func _is_input_handler_registered(input_handler_class: Script) -> bool:
	for ih in _input_handlers:
		if ih.get_script() == input_handler_class:
			return true
	return false


func _input_handlers_compare(a: InputHandlerBase, b: InputHandlerBase) -> bool:
	if a.get_priority() == b.get_priority():
		push_warning("input handlers '%s' and '%s' share the same priority %f, will be sort alphabetically by file path" %
		[a.get_script().resource_path, b.get_script().resource_path, a.get_priority()])
		return a.get_script().resource_path > b.get_script().resource_path
	return a.get_priority() > b.get_priority()
