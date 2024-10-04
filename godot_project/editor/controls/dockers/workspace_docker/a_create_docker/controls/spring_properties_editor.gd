class_name SpringsPropertiesEditor extends VBoxContainer


signal user_changed_constant_force(force_constant: float)
signal user_changed_equilibrium_length_is_auto(is_auto: bool)
signal user_changed_manual_equilibrium_length(manual_equilibrium_length: float)


var _multiple_values_info_label: InfoLabel
var _constant_force_spin_box: SpinBoxSlider
var _length_auto_button: Button
var _length_manual_button: Button
var _length_spin_box: SpinBoxSlider
# Properties editor could or not be editing spring(s). It depends if being used while
# creating a new spring or editing existing ones
var _edited_structure_contexts: PackedInt32Array = PackedInt32Array()

# when not null a snapshot in this workspace will be taken on change from UI
var _workspace_snapshot_target: WorkspaceContext = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_multiple_values_info_label = %MultipleValuesInfoLabel as InfoLabel
		_constant_force_spin_box = %ConstantForceSpinBox as SpinBoxSlider
		_length_auto_button = %LengthAutoButton as Button
		_length_manual_button = %LengthManualButton as Button
		_length_spin_box = %LengthSpinBox as SpinBoxSlider
		_multiple_values_info_label.hide()
		# Signal connections
		_constant_force_spin_box.value_confirmed.connect(_on_constant_force_spin_box_value_confirmed)
		_length_auto_button.toggled.connect(_on_length_manual_auto_button_toggled)
		_length_manual_button.toggled.connect(_on_length_manual_auto_button_toggled)
		_length_spin_box.value_confirmed.connect(_on_length_spin_box_value_confirmed)


func ensure_undo_redo_initialized(in_workspace_context: WorkspaceContext) -> void:
	if _workspace_snapshot_target != in_workspace_context:
		_workspace_snapshot_target = in_workspace_context


func _take_snapshot_if_configured(in_modified_property: String) -> void:
	if is_instance_valid(_workspace_snapshot_target):
		_workspace_snapshot_target.snapshot_moment("Set: " + in_modified_property)


func _on_constant_force_spin_box_value_confirmed(in_force: float) -> void:
	if is_editing_springs():
		for structure_context_id: int in _edited_structure_contexts:
			var struct_context: StructureContext = _workspace_snapshot_target.get_structure_context(structure_context_id)
			var nano_struct: NanoStructure = struct_context.nano_structure
			nano_struct.start_edit()
			var selected_springs: PackedInt32Array = struct_context.get_selected_springs()
			for spring_id in selected_springs:
				nano_struct.spring_set_constant_force(spring_id, in_force)
			nano_struct.end_edit()
	user_changed_constant_force.emit(in_force)
	_take_snapshot_if_configured(&"Spring Constant Force")


func _on_length_manual_auto_button_toggled(in_button_pressed: bool) -> void:
	if not in_button_pressed:
		return # Ignore when the toggle button is disabled
	
	var equilibrium_length_is_auto: bool = _length_auto_button.button_pressed
	if is_editing_springs():
		for structure_context_id: int in _edited_structure_contexts:
			var struct_context: StructureContext = _workspace_snapshot_target.get_structure_context(structure_context_id)
			var nano_struct: NanoStructure = struct_context.nano_structure
			var selected_springs: PackedInt32Array = struct_context.get_selected_springs()
			for spring_id in selected_springs:
				if nano_struct.spring_get_equilibrium_length_is_auto(spring_id) == equilibrium_length_is_auto:
					#Already set. Don't override the existing manual length if it exists
					continue
				if not nano_struct.is_being_edited():
					nano_struct.start_edit()
				nano_struct.spring_set_equilibrium_lenght_is_auto(spring_id, equilibrium_length_is_auto)
				if not equilibrium_length_is_auto:
					var new_length: float = nano_struct.spring_calculate_equilibrium_auto_length(spring_id, struct_context)
					nano_struct.spring_set_equilibrium_manual_length(spring_id, new_length)
					_length_spin_box.set_value_no_signal(new_length)
			if nano_struct.is_being_edited():
				nano_struct.end_edit()
	_length_spin_box.editable = not equilibrium_length_is_auto
	user_changed_equilibrium_length_is_auto.emit(equilibrium_length_is_auto)
	_take_snapshot_if_configured(&"Spring Equilibrium Length Type")


func _on_length_spin_box_value_confirmed(in_manual_length: float) -> void:
	if is_editing_springs():
		for structure_context_id: int in _edited_structure_contexts:
			var struct_context: StructureContext = _workspace_snapshot_target.get_structure_context(structure_context_id)
			var nano_struct: NanoStructure = struct_context.nano_structure
			var selected_springs: PackedInt32Array = struct_context.get_selected_springs()
			nano_struct.start_edit()
			for spring_id in selected_springs:
				nano_struct.spring_set_equilibrium_manual_length(spring_id, in_manual_length)
			nano_struct.end_edit()
	user_changed_manual_equilibrium_length.emit(in_manual_length)
	_take_snapshot_if_configured(&"Spring Equilibrium Manual Length")


# This is meant to be called from Create Docker
func setup_values(in_constant_force: float, in_length_is_auto: bool, in_manual_length: float) -> void:
	_constant_force_spin_box.set_value_no_signal(in_constant_force)
	_length_auto_button.set_pressed_no_signal(in_length_is_auto)
	_length_manual_button.set_pressed_no_signal(not in_length_is_auto)
	_length_spin_box.set_value_no_signal(in_manual_length)


# This is meant to be called from Dynamic Context Docker
func start_editing_springs(in_contextes_with_selected_springs: Array[StructureContext]) -> void:
	_edited_structure_contexts.clear()
	if in_contextes_with_selected_springs.size() == 0:
		return
	for structure_context: StructureContext in in_contextes_with_selected_springs:
		_edited_structure_contexts.push_back(structure_context.get_int_guid())
	_internal_update()


func _internal_update() -> void:
	if _edited_structure_contexts.is_empty():
		return
	var first_structure_id: int = _edited_structure_contexts[0]
	var springs_have_multiple_values: bool = false
	var springs_have_multiple_is_auto_values: bool = false
	var context: StructureContext = _workspace_snapshot_target.get_structure_context(first_structure_id)
	var nano_structure: NanoStructure = context.nano_structure
	var selected_springs: PackedInt32Array = context.get_selected_springs()
	if selected_springs.is_empty():
		return
	
	var first_spring_id: int = selected_springs[0]
	var force: float = nano_structure.spring_get_constant_force(first_spring_id)
	var is_length_auto: bool = nano_structure.spring_get_equilibrium_length_is_auto(first_spring_id)
	var manual_length: float = nano_structure.spring_get_equilibrium_manual_length(first_spring_id)
	
	for structure_context_id: int in _edited_structure_contexts:
		var struct_context: StructureContext = _workspace_snapshot_target.get_structure_context(structure_context_id)
		var nano_struct: NanoStructure = struct_context.nano_structure
		selected_springs = struct_context.get_selected_springs()
		for spring_id: int in selected_springs:
			var constant_force: float = nano_struct.spring_get_constant_force(spring_id)
			var equilibrium_length_is_auto: bool = nano_struct.spring_get_equilibrium_length_is_auto(spring_id)
			var equilibrium_manual_length: float = nano_struct.spring_get_equilibrium_manual_length(spring_id)
			if  force != constant_force or is_length_auto != equilibrium_length_is_auto or \
					manual_length != equilibrium_manual_length:
				springs_have_multiple_values = true
			if is_length_auto != equilibrium_length_is_auto:
				springs_have_multiple_is_auto_values = true
				break
	
	_multiple_values_info_label.visible = springs_have_multiple_values
	_constant_force_spin_box.set_value_no_signal(force)
	_length_auto_button.set_pressed_no_signal(is_length_auto and not springs_have_multiple_is_auto_values)
	_length_manual_button.set_pressed_no_signal(not is_length_auto and not springs_have_multiple_is_auto_values)
	_length_spin_box.set_value_no_signal(manual_length)
	_length_spin_box.editable = _length_manual_button.button_pressed


func is_editing_springs() -> bool:
	return _edited_structure_contexts.size() > 0
