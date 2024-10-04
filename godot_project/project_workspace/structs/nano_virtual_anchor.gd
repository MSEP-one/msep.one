class_name NanoVirtualAnchor extends NanoStructure


## Size of the 3D model in nanometers
const MODEL_SIZE: float = 0.17


signal position_changed(new_position: Vector3)


@export var _position: Vector3


# These variables are needed to validate sensitive information
var _workspace_context: WorkspaceContext
var _linked_nano_structures: Dictionary = {
	# nano_structure_id<int> : connected_springs<Dictionary> {spring_id<int> : true}
}

# Meant to be called from WorkspaceContext when am Anchor is added to the workspace
func initialize(in_workspace_context: WorkspaceContext) -> void:
	assert(is_instance_valid(in_workspace_context), "Invalid WorkspaceContext")
	_workspace_context = in_workspace_context


# Meant to be called from WorkspaceContext when an Anchor is removed from the workspace
func deinitialize() -> void:
	_workspace_context = null


func set_position(new_position: Vector3) -> void:
	if _position == new_position:
		return
	_position = new_position
	position_changed.emit(new_position)


func get_position() -> Vector3:
	return _position


func handle_spring_added(in_nano_structure: NanoStructure, in_spring_id: int) -> void:
	if not _linked_nano_structures.has(in_nano_structure.int_guid):
		_linked_nano_structures[in_nano_structure.int_guid] = {}
	_linked_nano_structures[in_nano_structure.int_guid][in_spring_id] = true


func handle_spring_removed(in_nano_structure: NanoStructure, in_spring_id: int) -> void:
	if not _linked_nano_structures.has(in_nano_structure.int_guid):
		# nothing to do
		return
	assert(_linked_nano_structures[in_nano_structure.int_guid].has(in_spring_id))
	_linked_nano_structures[in_nano_structure.int_guid].erase(in_spring_id)
	if _linked_nano_structures[in_nano_structure.int_guid].is_empty():
		_linked_nano_structures.erase(in_nano_structure.int_guid)
	

func get_related_structures() -> PackedInt32Array:
	return PackedInt32Array(_linked_nano_structures.keys())


func is_structure_related(in_nano_structure_id: int) -> bool:
	return _linked_nano_structures.has(in_nano_structure_id)


func get_related_springs(in_nano_structure_id: int) -> PackedInt32Array:
	if not _linked_nano_structures.has(in_nano_structure_id):
		return PackedInt32Array()
	return PackedInt32Array(_linked_nano_structures[in_nano_structure_id].keys() as Array[int])


## Structure types needs to return a valid type name to be considered valid
func get_type() -> StringName:
	return &"AnchorPoint"


func get_readable_type() -> String:
	return "Anchor"


## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	return null


func get_aabb() -> AABB:
	var aabb := AABB(_position, Vector3())
	aabb = aabb.grow(MODEL_SIZE * 0.5)
	return aabb.abs()


## Returns true if anchor is within the Rect2i, or false otherwise
func is_anchor_within_screen_rect(in_camera: Camera3D, screen_rect: Rect2i) -> bool:
	var anchor_screen_position: Vector2 = in_camera.unproject_position(_position)
	if screen_rect.abs().has_point(anchor_screen_position):
		return true
	return false


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary =  super.create_state_snapshot()
	state_snapshot["script.resource_path"] = get_script().resource_path
	state_snapshot["_position"] = _position
	state_snapshot["_linked_nano_structures"] = _linked_nano_structures.duplicate(true)
	state_snapshot["signals"] = History.create_signal_snapshot_for_object(self)
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	super.apply_state_snapshot(in_state_snapshot)
	
	_position = in_state_snapshot["_position"]
	_linked_nano_structures = in_state_snapshot["_linked_nano_structures"].duplicate(true)
	
	# Deffering this call should not be needed when Renderer will implement snapshoting
	History.apply_signal_snapshot_to_object.call_deferred(self, in_state_snapshot["signals"])

