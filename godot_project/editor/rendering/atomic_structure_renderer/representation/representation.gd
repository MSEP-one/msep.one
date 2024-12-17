"@abstract_class"
class_name Representation extends Node 
## Representation api (BallsRepresentation / StickRepresentation / SurfaceRepresentation / ... )

const SETTING_SCALE_FACTOR_VAN_DER_WAALS: StringName = &"msep/rendering/van_der_waals/radius_factor"
const SETTING_SCALE_FACTOR_MECHANICAL_SIMULATION: StringName = &"msep/rendering/mechanical_simulation/radius_factor"
const SETTING_SCALE_FACTOR_BALLS_AND_STICKS: StringName = &"msep/rendering/balls_and_sticks/radius_factor"

const SETTING_RADIUS_SOURCE_VAN_DER_WAALS: StringName = &"msep/rendering/van_der_waals/radius_source"
const SETTING_RADIUS_SOURCE_MECHANICAL_SIMULATION: StringName = &"msep/rendering/mechanical_simulation/radius_source"
const SETTING_RADIUS_SOURCE_BALLS_AND_STICKS: StringName = &"msep/rendering/balls_and_sticks/radius_source"

const SCALE_FACTOR_STICKS: float = 0.6


func build(_in_structure_context: StructureContext) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func highlight_atoms(_in_atoms_ids: PackedInt32Array, _new_partially_influenced_bonds: PackedInt32Array,
			_in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func lowlight_atoms(_in_atoms_ids: PackedInt32Array, 
			_in_bonds_released_from_partial_influence: PackedInt32Array,
			_new_partially_influenced_bonds: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func add_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func remove_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_positions(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_locking(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_atomic_number(_in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_sizes() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_color(_in_atoms: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_atoms_visibility(_in_atoms_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_bonds_visibility(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func refresh_all() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func clear() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func show() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func hide() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func hydrogens_rendering_off() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func hydrogens_rendering_on() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func add_bonds(_new_bonds: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func remove_bonds(_new_bonds: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func bonds_changed(_changed_bonds: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func highlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func lowlight_bonds(_in_bonds_ids: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func hide_bond_rendering() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func show_bond_rendering() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func set_material_overlay(_in_material: Material) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func update(_in_delta_time: float) -> void:
	return


func refresh_bond_influence(_in_partially_selected_bonds: PackedInt32Array) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func set_atom_selection_position_delta(_in_movement_delta: Vector3) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func rotate_atom_selection_around_point(_in_point: Vector3, _in_rotation_to_apply: Basis) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func set_transparency(_in_transparency: float) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	# pass is needed to avoid GdScript compile errors on Release when asserts are striped out
	pass


func handle_editable_structures_changed(_in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func handle_hover_structure_changed(_in_toplevel_hovered_structure_context: StructureContext,
			_in_hovered_structure_context: StructureContext, _in_atom_id: int, _in_bond_id: int,
			_in_spring_id: int) -> void:
	# TODO: it seems like highlight interface should be used instead??
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func apply_theme(_in_theme: Theme3D) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func saturate() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func desaturate() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


static func get_atom_scale_factor(in_representation_settings: RepresentationSettings) -> float:
	var representation := Rendering.Representation.BALLS_AND_STICKS
	if in_representation_settings != null:
		representation = in_representation_settings.get_rendering_representation()
	match representation:
		Rendering.Representation.VAN_DER_WAALS_SPHERES:
			return ProjectSettings.get_setting(SETTING_SCALE_FACTOR_VAN_DER_WAALS, 1.0)
		Rendering.Representation.MECHANICAL_SIMULATION:
			return ProjectSettings.get_setting(SETTING_SCALE_FACTOR_MECHANICAL_SIMULATION, 0.9)
		Rendering.Representation.STICKS, Rendering.Representation.ENHANCED_STICKS:
			return SCALE_FACTOR_STICKS
		Rendering.Representation.BALLS_AND_STICKS, _:
			if in_representation_settings != null:
				return in_representation_settings.get_balls_and_sticks_size_factor()
			return ProjectSettings.get_setting(SETTING_SCALE_FACTOR_BALLS_AND_STICKS, 0.3)


static func get_atom_radius(in_data: ElementData, in_representation_settings: RepresentationSettings) -> float:
	var representation := Rendering.Representation.BALLS_AND_STICKS
	if in_representation_settings != null:
		representation = in_representation_settings.get_rendering_representation()
	match representation:
		Rendering.Representation.VAN_DER_WAALS_SPHERES:
			return _get_van_der_waals_radius(in_data)
		Rendering.Representation.MECHANICAL_SIMULATION:
			return _get_mechanical_simulation_atom_radius(in_data)
		Rendering.Representation.STICKS, Rendering.Representation.ENHANCED_STICKS:
			# TODO: What value to return here?
			return 0.04
		Rendering.Representation.BALLS_AND_STICKS, _:
			return _get_balls_and_sticks_atom_radius(in_data, in_representation_settings)


static func _get_van_der_waals_radius(in_data: ElementData) -> float:
	var property_name: StringName = ProjectSettings.get_setting(SETTING_RADIUS_SOURCE_VAN_DER_WAALS,
			ElementData.PROPERTY_NAME_CONTACT_RADIUS)
	var property_value: float = in_data.get(property_name)
	return property_value


static func _get_mechanical_simulation_atom_radius(in_data: ElementData) -> float:
	var property_name: StringName = ProjectSettings.get_setting(SETTING_RADIUS_SOURCE_MECHANICAL_SIMULATION,
			ElementData.PROPERTY_NAME_CONTACT_RADIUS)
	var property_value: float = in_data.get(property_name)
	return property_value


static func _get_balls_and_sticks_atom_radius(in_data: ElementData, in_representation_settings: RepresentationSettings) -> float:
	var property_name: StringName = ProjectSettings.get_setting(SETTING_RADIUS_SOURCE_BALLS_AND_STICKS,
			ElementData.PROPERTY_NAME_CONTACT_RADIUS)
	if in_representation_settings != null:
		var is_using_van_der_walls_radius: bool = (in_representation_settings.get_balls_and_sticks_size_source() == RepresentationSettings.UserAtomSizeSource.VAN_DER_WAALS_RADIUS)
		property_name = ElementData.PROPERTY_NAME_CONTACT_RADIUS if is_using_van_der_walls_radius else \
				ElementData.PROPERTY_NAME_RENDER_RADIUS
	var property_value: float = in_data.get(property_name)
	return property_value


## Utility class to convert the instance state (selected, hovered etc) to a single float.
## This value is usually stored in the instance color's alpha channel.
## The states are packed in an integer, using 1 bit per boolean.
## This method can hold a maximum of 23 bools (because of the float conversion at the end).
class InstanceState:
	var is_visible: bool = true
	var is_hovered: bool = false
	var is_selected: bool = false
	var is_locked: bool = false
	var is_first_atom_selected: bool = false
	var is_second_atom_selected: bool = false
	var is_hydrogen: bool = false
	
	func _init(from_float: float = -1.0) -> void:
		if from_float < 0.0:
			return # Use the default values
		var packed_state: int = int(from_float)
		is_visible = _is_bit_set(packed_state, 0)
		is_hovered = _is_bit_set(packed_state, 1)
		is_selected = _is_bit_set(packed_state, 2)
		is_locked = _is_bit_set(packed_state, 3)
		is_first_atom_selected = _is_bit_set(packed_state, 4)
		is_first_atom_selected = _is_bit_set(packed_state, 5)
		is_hydrogen = _is_bit_set(packed_state, 6)
	
	func to_float() -> float:
		# The values to pack in a float. Declaration order is important and
		# must match what's defined in _init and instance_state.gdshaderinc
		var flags: Array[int] = [
			is_visible,
			is_hovered,
			is_selected,
			is_locked,
			is_first_atom_selected,
			is_second_atom_selected,
			is_hydrogen,
		]
		var bits: int = 0
		for i: int in flags.size():
			if flags[i]:
				bits = bits | (1 << i)
		return float(bits)
	
	func _is_bit_set(value: int, bit_position: int) -> bool:
		return bool(value & (1 << bit_position))
