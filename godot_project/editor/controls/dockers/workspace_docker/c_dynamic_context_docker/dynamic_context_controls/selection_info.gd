extends DynamicContextControl

const _MAX_VALUE = 9223372036854775807
const _VERTICAL_SCROLLBAR_INTERNAL_NODE_INDEX: int = 3
const _RESERVED_TITLE_SPACE: float = 36

@onready var _tree_info: Tree = %TreeInfo
var _custom_editors: Dictionary = Dictionary()#[TreeItem,Control]
var _workspace_context: WorkspaceContext = null


func _ready() -> void:
	_tree_info.item_collapsed.connect(_on_tree_item_collapsed)
	var vertical_scrollbar: VScrollBar = _tree_info.get_child(
		_VERTICAL_SCROLLBAR_INTERNAL_NODE_INDEX, true
	)
	assert(vertical_scrollbar, "Could not find the vertical scrollbar as child of tree view")
	vertical_scrollbar.value_changed.connect(_on_vertical_scrollbar_value_changed)


func _get_minimum_size() -> Vector2:
	if _tree_info != null:
		return _tree_info.get_combined_minimum_size()
	return Vector2.ZERO


func should_show(in_workspace_context: WorkspaceContext)-> bool:
	assert(in_workspace_context != null)
	if _workspace_context == null:
		_workspace_context = in_workspace_context
		in_workspace_context.history_snapshot_applied.connect(_on_workspace_context_history_snapshot_applied)
		in_workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		in_workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove)
	return in_workspace_context.get_structure_contexts_with_selection().size() > 0


func _on_workspace_context_history_snapshot_applied() -> void:
	ScriptUtils.call_deferred_once(_update_selected_info)


func _on_workspace_context_selection_in_structures_changed(_in_structure_contexts: Array[StructureContext]) -> void:
	ScriptUtils.call_deferred_once(_update_selected_info)


func _on_workspace_context_structure_about_to_remove(_in_structe: NanoStructure) -> void:
	ScriptUtils.call_deferred_once(_update_selected_info)


func _update_selected_info() -> void:
	_clear()
	var contexts_with_selection: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection(false)
	var root: TreeItem = _tree_info.create_item()
	_tree_info.set_column_title(0, "Property")
	_tree_info.set_column_title(1, "Value")
	if contexts_with_selection.is_empty():
		return
	var total_atoms_selected: int = 0
	var total_bonds_selected: int = 0
	var total_springs_selected: int = 0
	var total_shapes_selected: int = 0
	var total_motors_selected: int = 0
	var total_anchors_selected: int = 0
	var selected_structures: Array[StructureContext] = _workspace_context.get_structure_contexts_with_selection()
	# 1. First pass only for counting
	for context in selected_structures:
		if context.nano_structure is AtomicStructure:
			total_atoms_selected += context.get_selected_atoms().size()
			total_bonds_selected += context.get_selected_bonds().size()
			total_springs_selected += context.get_selected_springs().size()
		elif context.nano_structure is NanoShape:
			total_shapes_selected += 1
		elif context.nano_structure is NanoVirtualMotor:
			total_motors_selected += 1
		elif context.nano_structure is NanoVirtualAnchor:
			total_anchors_selected += 1
	# 1.1 Render total counts
	if total_atoms_selected + total_bonds_selected + total_springs_selected + \
			total_shapes_selected + total_motors_selected + total_anchors_selected > 0:
		var item_summary: TreeItem = _tree_info.create_item(root)
		item_summary.set_text(0, tr(&"Summary"))
		if total_atoms_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Atoms count"))
			item.set_text(1, str(total_atoms_selected))
		if total_bonds_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Bonds count"))
			item.set_text(1, str(total_bonds_selected))
		if total_springs_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Springs count"))
			item.set_text(1, str(total_springs_selected))
		if total_shapes_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Shapes count"))
			item.set_text(1, str(total_shapes_selected))
		if total_motors_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Motors count"))
			item.set_text(1, str(total_motors_selected))
		if total_anchors_selected > 0:
			var item: TreeItem = _tree_info.create_item(item_summary)
			item.set_text(0, tr(&"Total Anchors count"))
			item.set_text(1, str(total_anchors_selected))
	# 2. Second pass for details
	for context in selected_structures:
		var selection_info: Dictionary = SelectionInfo.create_selection_info(context, SelectionInfo.Type.READ_WRITE_PROPERTIES)
		var structure_root: TreeItem = _tree_info.create_item(root)
		structure_root.set_text(0, context.nano_structure.get_structure_name())
		structure_root.set_icon(0, context.nano_structure.get_icon())
		_create_info_items(selection_info, structure_root)
		_tree_info.queue_redraw()


func _clear() -> void:
	_tree_info.clear()
	for editor: Control in _custom_editors.values():
		editor.queue_free()
	_custom_editors.clear()


func _create_info_items(in_info: Variant, parent: TreeItem) -> void:
	if _value_type_expands(in_info):
		match typeof(in_info):
			TYPE_DICTIONARY:
				for member: String in in_info.keys():
					var item: TreeItem = _tree_info.create_item(parent)
					item.set_text(0, member)
					var value: Variant = in_info[member]
					if _value_type_expands(value):
						_create_info_items(value, item)
					else:
						_create_value_cell(value, item)
			_:
				# All other types are just arrays
				for value: Variant in in_info:
					var item: TreeItem = _tree_info.create_item(parent)
					if _value_type_expands(value):
						_create_info_items(value, item)
					else:
						_create_value_cell(value, item)
	else:
		push_error("Unexpected value property %s" % str(in_info))
		breakpoint


func _create_value_cell(value: Variant, in_item: TreeItem) -> void:
	if value is InspectorControl:
		_configure_tree_item(in_item, value)
	elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		in_item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
		in_item.set_range_config(1, -1000, _MAX_VALUE, 0.001)
		in_item.set_range(1, value)
		in_item.set_editable(1, false)
	elif typeof(value) == TYPE_BOOL:
		in_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		in_item.set_checked(1, value)
	else:
		if str(value).length() > 20:
			var label := TrimLabel.new()
			label.text = str(value)
			in_item.set_tooltip_text(1, str(value))
			_configure_trim_label(in_item, label)
		else:
			in_item.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
			in_item.set_text(1, str(value))


func _configure_tree_item(in_item: TreeItem, in_editor_widget: InspectorControl) -> void:
	in_item.set_cell_mode(1, TreeItem.CELL_MODE_CUSTOM)
	in_item.set_custom_as_button(1, true)
	_tree_info.add_child(in_editor_widget)
	in_editor_widget.hide()
	var min_size: Vector2 = in_editor_widget.get_combined_minimum_size()
	in_item.custom_minimum_height = int(min_size.y)
	_custom_editors[in_item] = in_editor_widget
	in_item.set_custom_draw(1, self, &"_fit_editor_in_cell")
	in_item.set_editable(1, in_editor_widget.is_editable())


func _configure_trim_label(in_item: TreeItem, in_label: TrimLabel) -> void:
	in_item.set_cell_mode(1, TreeItem.CELL_MODE_CUSTOM)
	in_item.set_custom_as_button(1, true)
	_tree_info.add_child(in_label)
	in_label.hide()
	var min_size: Vector2 = in_label.get_combined_minimum_size()
	in_item.custom_minimum_height = int(min_size.y)
	_custom_editors[in_item] = in_label
	in_item.set_custom_draw(1, self, &"_fit_editor_in_cell")

func _on_tree_item_collapsed(_in_item: TreeItem) -> void:
	_hide_all_editors()


func _on_vertical_scrollbar_value_changed(_in_value: float) -> void:
	_hide_all_editors()


func _hide_all_editors() -> void:
	for editor: Control in _custom_editors.values():
		assert(editor)
		editor.hide()
		# NOTE: _fit_editor_in_cell will make the control visible again
		#+when drawing the cell of visible editors

func _fit_editor_in_cell(in_item: TreeItem, in_rect: Rect2) -> void:
	var editor: Control = _custom_editors[in_item]
	assert(editor)
	if in_rect.position.y < _RESERVED_TITLE_SPACE:
		# Make sure the editor does not overlap with Colum titles
		editor.hide()
		return
	editor.show()
	var min_size: Vector2 = editor.get_combined_minimum_size()
	editor.position = in_rect.position
	if min_size.x > in_rect.size.x:
		editor.position.x = in_rect.end.x - min_size.x
	editor.size = in_rect.size
	if in_item.get_text(0).is_empty():
		# Expand the editor to fit both colums:
		const PADDING: int = 60
		editor.position.x = PADDING
		editor.size.x = in_rect.end.x - PADDING

func _value_type_expands(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_DICTIONARY,
		TYPE_ARRAY,
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY
	]


class TrimLabel extends Label:
	func _init() -> void:
		text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var tree_font_color: Color = get_theme_color(&"font_color", &"Tree")
		add_theme_color_override(&"font_color", tree_font_color)
