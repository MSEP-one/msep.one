class_name VirtualAnchorRenderer extends VirtualAnchorModel


var _anchor_id: int
var _is_built: bool = false
var _workspace_context: WorkspaceContext


func build(in_workspace_context: WorkspaceContext, in_anchor: NanoVirtualAnchor) -> void:
	assert(not _is_built, "Renderer can only by built once")
	_is_built = true
	_anchor_id = in_anchor.get_int_guid()
	_workspace_context = in_workspace_context
	in_anchor.position_changed.connect(_on_virtual_anchor_position_changed)
	in_anchor.visibility_changed.connect(_on_virtual_anchor_visibility_changed)
	global_position = in_anchor.get_position()
	self.visible = in_anchor.get_visible()


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	var editor_viewport: SubViewport = get_viewport()
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if workspace_context and workspace_context.hovered_structure_context_changed.is_connected(_on_workspace_context_hovered_structure_context_changed):
		workspace_context.hovered_structure_context_changed.disconnect(_on_workspace_context_hovered_structure_context_changed)
		const NOT_HOVERED = 0
		_set_shader_uniform(&"is_hovered", NOT_HOVERED)


func get_anchor() -> NanoVirtualAnchor:
	return _workspace_context.workspace.get_structure_by_int_guid(_anchor_id) as NanoVirtualAnchor


func transform_by_external_transform(in_selection_initial_pos: Vector3, in_initial_nano_struct_transform: Transform3D,
			in_external_transform: Transform3D) -> void:
	var delta_pos: Vector3 = in_initial_nano_struct_transform.origin - in_selection_initial_pos
	var new_pos: Vector3 = in_external_transform.origin + in_external_transform.basis * delta_pos
	global_position = new_pos


func _on_virtual_anchor_position_changed(in_position: Vector3) -> void:
	global_transform.origin = in_position


func _on_virtual_anchor_visibility_changed(in_visible: bool) -> void:
	self.visible = in_visible


func _enter_tree() -> void:
	var editor_viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
	if not is_instance_valid(editor_viewport):
		return
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if is_instance_valid(workspace_context) and not workspace_context.hovered_structure_context_changed.is_connected(
					_on_workspace_context_hovered_structure_context_changed):
		workspace_context.hovered_structure_context_changed.connect(_on_workspace_context_hovered_structure_context_changed)
		workspace_context.editable_structure_context_list_changed.connect(_on_workspace_context_editable_structure_context_list_changed)
		workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)


func _on_workspace_context_hovered_structure_context_changed(
			in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext,
			_in_atom_id: int, _in_bond_id: int, _in_spring_id: int) -> void:
	var anchor: NanoVirtualAnchor = get_anchor()
	if not is_instance_valid(anchor):
		# This renderer is no longer valid
		return
	var is_anchor_hovered: bool = false
	if is_instance_valid(in_toplevel_hovered_structure_context) and \
			_workspace_context.workspace.is_a_ancestor_of_b(in_toplevel_hovered_structure_context.nano_structure, anchor):
		is_anchor_hovered = true
	else:
		is_anchor_hovered = is_instance_valid(in_hovered_structure_context) \
			and in_hovered_structure_context.nano_structure == get_anchor()
	const HOVERED_VALUE: float = 1.0
	const UNHOVERED_VALUE: float = 0.0
	_set_shader_uniform(&"is_hovered", HOVERED_VALUE if is_anchor_hovered else UNHOVERED_VALUE)


func _on_workspace_context_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	if not is_instance_valid(get_anchor()):
		# This renderer is no longer valid
		return
	var this_anchor_found: bool = false
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.nano_structure == get_anchor():
			this_anchor_found = true
			break
	const SELECTABLE_VALUE: float = 1.0
	const UNSELECTABLE_VALUE: float = 0.0
	_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if this_anchor_found else UNSELECTABLE_VALUE)


func _on_workspace_context_selection_in_structures_changed(out_structure_contexts: Array[StructureContext]) -> void:
	if not _workspace_context.workspace.has_structure_with_int_guid(_anchor_id):
		# This renderer is no longer valid
		return
	for context: StructureContext in out_structure_contexts:
		var is_this_anchor: bool = context.nano_structure == get_anchor()
		if is_this_anchor:
			const SELECTED_VALUE: float = 1.0
			const UNSELECTED_VALUE: float = 0.0
			var is_selected: bool = context.is_anchor_selected()
			_set_shader_uniform(&"is_selected",SELECTED_VALUE if is_selected else UNSELECTED_VALUE)
			return


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_anchor_id"] = _anchor_id
	snapshot["_is_built"] = _is_built
	snapshot["visible"] = visible
	snapshot["material_selected"] = _get_shader_uniform(&"is_selected")
	snapshot["material_selectable"] = _get_shader_uniform(&"is_selectable")
	snapshot["global_transform"] = global_transform
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_workspace_context = in_snapshot["_workspace_context"]
	_anchor_id = in_snapshot["_anchor_id"]
	_is_built = in_snapshot["_is_built"]
	visible = in_snapshot["visible"]
	_set_shader_uniform(&"is_selected", in_snapshot["material_selected"])
	_set_shader_uniform(&"is_selectable", in_snapshot["material_selectable"])
	global_transform = in_snapshot["global_transform"]
