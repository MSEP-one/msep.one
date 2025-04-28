class_name NanoVirtualMotor extends NanoStructure

signal transform_changed(new_transform: Transform3D)
signal parameters_changed(in_parameters: NanoVirtualMotorParameters)
signal structure_connected(in_new_structure_id: int)
signal structure_disconnected(in_disconnected_structure_id: int)


@export var _transform: Transform3D
@export var _parameters: NanoVirtualMotorParameters
@export var _connected_structures: Dictionary = {
#	structure_id<int> = true<bool>
}


## Structure types needs to return a valid type name to be considered valid
func get_type() -> StringName:
	match _parameters.motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			return &"RotaryMotor"
		NanoVirtualMotorParameters.Type.LINEAR:
			return &"LinearMotor"
		_:
			assert(false, "Unexpected motor type: %d" % _parameters.motor_type)
			pass
	return &"VirtualMotor"


func get_readable_type() -> String:
	match _parameters.motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			return "Rotary Motor"
		NanoVirtualMotorParameters.Type.LINEAR:
			return "Linear Motor"
		_:
			assert(false, "Unexpected motor type: %d" % _parameters.motor_type)
			pass
	return "Virtual Motor"


## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	return null


func set_transform(new_transform: Transform3D) -> void:
	if _transform == new_transform:
		return
	_transform = new_transform
	transform_changed.emit(new_transform)


func get_transform() -> Transform3D:
	return _transform


func set_parameters(new_parameters: NanoVirtualMotorParameters) -> void:
	if new_parameters == _parameters:
		return
	_parameters = new_parameters
	parameters_changed.emit(_parameters)


func get_parameters() -> NanoVirtualMotorParameters:
	return _parameters


func get_aabb() -> AABB:
	var aabb := AABB(_transform.origin, Vector3())
	aabb = aabb.grow(0.5)
	return aabb.abs()


func is_structure_id_connected(in_structure_id: int) -> bool:
	return _connected_structures.get(in_structure_id, false)


func is_structure_connected(in_structure: NanoStructure) -> bool:
	assert(in_structure != null, "<null> cannot be connected to motor")
	return _connected_structures.get(in_structure.int_guid, false)


func is_structure_context_connected(in_context: StructureContext) -> bool:
	assert(is_instance_valid(in_context) and in_context.nano_structure != null,
		"<null> cannot be connected to motor")
	return _connected_structures.get(in_context.nano_structure.int_guid, false)


func get_connected_structures() -> PackedInt32Array:
	return PackedInt32Array(_connected_structures.keys())


func connect_structure(in_structure: NanoStructure) -> void:
	assert(in_structure != null, "Cannot connect <null> to motor")
	assert(_ensure_structure_is_not_virtual(in_structure),
			"Connecting virtual objects is not supported")
	if is_structure_connected(in_structure):
		return
	_connected_structures[in_structure.int_guid] = true
	structure_connected.emit(in_structure.int_guid)


func connect_structure_by_id(in_structure_id: int) -> void:
	assert(in_structure_id != 0, "Cannot connect <null> to motor")
	assert(_ensure_id_is_not_virtual(in_structure_id),
			"Connecting virtual objects is not supported")
	if is_structure_id_connected(in_structure_id):
		return
	_connected_structures[in_structure_id] = true
	structure_connected.emit(in_structure_id)


func disconnect_structure(in_structure: NanoStructure) -> void:
	assert(in_structure != null, "Cannot disconnect <null> to motor")
	assert(_ensure_structure_is_not_virtual(in_structure),
			"Connecting virtual objects is not supported (and by extension disconnecting is neither)")
	if not is_structure_connected(in_structure):
		return
	_connected_structures.erase(in_structure.int_guid)
	structure_disconnected.emit(in_structure.int_guid)


func disconnect_structure_by_id(in_structure_id: int) -> void:
	assert(in_structure_id != 0, "Cannot disconnect <null> to motor")
	assert(_ensure_id_is_not_virtual(in_structure_id),
			"Connecting virtual objects is not supported (and by extension disconnecting is neither)")
	if not is_structure_id_connected(in_structure_id):
		return
	_connected_structures.erase(in_structure_id)
	structure_disconnected.emit(in_structure_id)


## Returns true if motor is within the Rect2i, or false otherwise
func is_motor_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	var motor_screen_position: Vector2 = in_camera.unproject_position(_transform.origin)
	if screen_rect.abs().has_point(motor_screen_position):
		return true
	return false


func init_remap_structure_ids(in_structures_map: Dictionary) -> void:
	for old_structure_id: int in get_connected_structures():
		_connected_structures.erase(old_structure_id)
		var new_structure: NanoStructure = in_structures_map.get(old_structure_id, null)
		assert(is_instance_valid(new_structure), "Structure has vanished during import")
		_connected_structures[new_structure.int_guid] = true


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_transform"] = _transform
	state_snapshot["_parameters_snapshot"] = _parameters.create_state_snapshot()
	state_snapshot["_connected_structures"] = _connected_structures.duplicate(true)
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	_transform = in_state_snapshot["_transform"]
	if _parameters == null:
		# HACK: undo and redo the creation of the motor will make a motor without parameters
		# lets peek into the _parameters_snapshot to know what kind of parameters create
		if in_state_snapshot["_parameters_snapshot"].motor_type == NanoVirtualMotorParameters.Type.LINEAR:
			_parameters = NanoLinearMotorParameters.new()
		elif in_state_snapshot["_parameters_snapshot"].motor_type == NanoVirtualMotorParameters.Type.ROTARY:
			_parameters = NanoRotaryMotorParameters.new()
	_parameters.apply_state_snapshot(in_state_snapshot["_parameters_snapshot"])
	_connected_structures = in_state_snapshot["_connected_structures"].duplicate(true)
