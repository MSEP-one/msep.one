@tool
class_name CreateObjectParameters extends Resource


signal create_mode_enabled_changed(enabled: bool)
signal create_mode_type_changed(new_create_mode: CreateModeType)
signal new_atom_element_changed(atomic_number: int)
signal new_bond_order_changed(order: int)
signal new_structure_changed(structure: NanoStructure)
signal create_distance_method_changed(new_method: CreateDistanceMethod)
signal creation_distance_from_camera_factor_changed(new_distance: float)
signal selected_shape_for_new_objects_changed(in_shape: PrimitiveMesh)
signal selected_virtual_motor_parameters_changed(in_parameters: NanoVirtualMotorParameters)
signal simulation_type_changed(new_simulation_type: SimulationType)
signal snap_to_shape_surface_changed(enabled: bool)
signal create_small_molecule_in_subgroup_changed(enabled: bool)
signal spring_constant_force_changed(force: float)
signal spring_equilibrium_length_is_auto_changed(is_auto: bool)
signal spring_equilibrium_manual_length_changed(manual_length: float)
# validate_bonds_requested signal is used as intermediator between relax_tools_panel and validate_bonds_panel
signal validate_bonds_requested(selection_only: bool)


enum CreateModeType {
	CREATE_ATOMS_AND_BONDS,
	CREATE_SHAPES,
	CREATE_FRAGMENT,
	CREATE_VIRTUAL_MOTORS,
	CREATE_ANCHORS_AND_SPRINGS,
	CREATE_CUSTOM
}


enum CreateDistanceMethod {
	CLOSEST_OBJECT_TO_POINTER,
	CENTER_OF_SELECTION,
	FIXED_DISTANCE_TO_CAMERA
}


enum SimulationType {
	RELAXATION,
	MOLECULAR_MECHANICS,
	VALIDATION
}


@export var supported_shapes: Array[PrimitiveMesh]
@export_range(0.1, 100, 0.1) var min_drop_distance: float = 2
@export_range(0.1, 100, 0.1) var max_drop_distance: float = 20
@export var new_rotary_motor_parameters: NanoRotaryMotorParameters
@export var new_linear_motor_parameters: NanoLinearMotorParameters

var _create_mode_enabled: bool = false
var _create_mode_type: CreateModeType = CreateModeType.CREATE_ATOMS_AND_BONDS
var _selected_shape_for_new_objects: PrimitiveMesh
var _selected_virtual_motor_parameters: NanoVirtualMotorParameters

var drop_distance: float = 20:
	get = get_drop_distance

var _new_atom_element: int = PeriodicTable.ATOMIC_NUMBER_CARBON
var _new_bond_order: int = 1

var _new_structure: NanoStructure = null

var _create_distance_method := CreateDistanceMethod.CENTER_OF_SELECTION

var _creation_distance_from_camera_factor: float = 0.3

var _simulation_type := SimulationType.RELAXATION

var _snap_to_shape_surface: bool = false

var _create_small_molecule_in_subgroup: bool = false

var _spring_constant_force: float = 200000.0 # nN/nm

var _spring_equilibrium_length_is_auto: bool = true

var _spring_equilibrium_manual_length: float

var _default_shape: int = 0

static var _tmp_nano_shape := NanoShape.new()

func _get_property_list() -> Array[Dictionary]:
	var custom_props: Array[Dictionary] = []
	var supported_shapes_names: PackedStringArray = []
	for shape in supported_shapes:
		_tmp_nano_shape.set_shape(shape)
		var shape_name: String = _tmp_nano_shape.get_type()
		supported_shapes_names.push_back(shape_name)
	custom_props.append({
		&"name": &"default_shape",
		&"type": TYPE_INT,
		&"usage": PROPERTY_USAGE_DEFAULT,
		&"hint": PROPERTY_HINT_ENUM,
		&"hint_string": ",".join(supported_shapes_names)
	})
	_tmp_nano_shape.set_shape(null)
	return custom_props


func _get(property: StringName) -> Variant:
	if property == &"default_shape":
		return _default_shape
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property == &"default_shape":
		_default_shape = value
		if not Engine.is_editor_hint():
			if _default_shape >= 0 and _default_shape < supported_shapes.size():
				_selected_shape_for_new_objects = supported_shapes[_default_shape]
		return true
	return false


func set_create_mode_enabled(in_enabled: bool) -> void:
	if _create_mode_enabled == in_enabled:
		return
	_create_mode_enabled = in_enabled
	create_mode_enabled_changed.emit(in_enabled)


func get_create_mode_enabled() -> bool:
	return _create_mode_enabled


func set_create_mode_type(in_create_mode_type: CreateModeType) -> void:
	if in_create_mode_type == _create_mode_type:
		return
	_create_mode_type = in_create_mode_type
	create_mode_type_changed.emit(in_create_mode_type)
	set_create_mode_enabled(true)


func get_create_mode_type() -> CreateModeType:
	return _create_mode_type


func set_selected_shape_for_new_objects(in_shape: PrimitiveMesh) -> void:
	set_create_mode_enabled(true)
	var shape_changed: bool = in_shape != _selected_shape_for_new_objects
	_selected_shape_for_new_objects = in_shape
	if shape_changed:
		selected_shape_for_new_objects_changed.emit(in_shape)


func get_selected_shape_for_new_objects() -> PrimitiveMesh:
	return _selected_shape_for_new_objects


func set_selected_virtual_motor_parameters(in_parameters: NanoVirtualMotorParameters) -> void:
	set_create_mode_enabled(true)
	var type_changed: bool = in_parameters != _selected_virtual_motor_parameters
	_selected_virtual_motor_parameters = in_parameters
	if type_changed:
		selected_virtual_motor_parameters_changed.emit(in_parameters)


func get_selected_virtual_motor_parameters() -> NanoVirtualMotorParameters:
	if _selected_virtual_motor_parameters == null:
		# Default is rotary motor
		return new_rotary_motor_parameters
	return _selected_virtual_motor_parameters


func get_drop_distance() -> float:
	return lerp(min_drop_distance, max_drop_distance, _creation_distance_from_camera_factor)


func set_new_atom_element(in_element: int) -> void:
	set_create_mode_enabled(true)
	if in_element == _new_atom_element:
		return
	_new_atom_element = in_element
	new_atom_element_changed.emit(in_element)


func get_new_atom_element() -> int:
	return _new_atom_element


func set_new_bond_order(in_order: int) -> void:
	if in_order == _new_bond_order:
		return
	_new_bond_order = in_order
	new_bond_order_changed.emit(in_order)


func get_new_bond_order() -> int:
	return _new_bond_order


func set_new_structure(in_structure: NanoStructure) -> void:
	set_create_mode_enabled(true)
	if in_structure == _new_structure:
		return
	_new_structure = in_structure
	new_structure_changed.emit(in_structure)


func get_new_structure() -> NanoStructure:
	return _new_structure


func set_create_distance_method(in_new_method: CreateDistanceMethod) -> void:
	if in_new_method == _create_distance_method:
		return
	_create_distance_method = in_new_method
	create_distance_method_changed.emit(in_new_method)


func get_create_distance_method() -> CreateDistanceMethod:
	return _create_distance_method


func set_creation_distance_from_camera_factor(in_factor: float) -> void:
	if in_factor == _creation_distance_from_camera_factor:
		return
	_creation_distance_from_camera_factor = in_factor
	creation_distance_from_camera_factor_changed.emit(in_factor)


func get_creation_distance_from_camera_factor() -> float:
	return _creation_distance_from_camera_factor


func set_simulation_type(in_simulation_type: SimulationType) -> void:
	if in_simulation_type == _simulation_type:
		return
	_simulation_type = in_simulation_type
	simulation_type_changed.emit(in_simulation_type)


func get_simulation_type() -> SimulationType:
	return _simulation_type


func set_snap_to_shape_surface(in_enabled: bool) -> void:
	if _snap_to_shape_surface == in_enabled:
		return
	_snap_to_shape_surface = in_enabled
	snap_to_shape_surface_changed.emit(in_enabled)


func get_snap_to_shape_surface() -> bool:
	return _snap_to_shape_surface


func set_create_small_molecule_in_subgroup(in_enabled: bool) -> void:
	if _create_small_molecule_in_subgroup == in_enabled:
		return
	_create_small_molecule_in_subgroup = in_enabled
	create_small_molecule_in_subgroup_changed.emit(in_enabled)


func get_create_small_molecule_in_subgroup() -> bool:
	return _create_small_molecule_in_subgroup


func set_spring_constant_force(in_force: float) -> void:
	if _spring_constant_force == in_force:
		return
	_spring_constant_force = in_force
	spring_constant_force_changed.emit(in_force)


func get_spring_constant_force() -> float:
	return _spring_constant_force


func set_spring_equilibrium_length_is_auto(in_length_is_auto: bool) -> void:
	if _spring_equilibrium_length_is_auto == in_length_is_auto:
		return
	_spring_equilibrium_length_is_auto = in_length_is_auto
	spring_equilibrium_length_is_auto_changed.emit(in_length_is_auto)


func get_spring_equilibrium_length_is_auto() -> bool:
	return _spring_equilibrium_length_is_auto


func set_spring_equilibrium_manual_length(in_manual_length: float) -> void:
	if _spring_equilibrium_manual_length == in_manual_length:
		return
	_spring_equilibrium_manual_length = in_manual_length
	spring_equilibrium_manual_length_changed.emit(in_manual_length)


func get_spring_equilibrium_manual_length() -> float:
	return _spring_equilibrium_manual_length

