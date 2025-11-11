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
func notify_added_to_workspace(in_workspace_context: WorkspaceContext) -> void:
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


func get_total_springs_count() -> int:
	var total: int = 0
	for structure_id: int in _linked_nano_structures.keys():
		total += _linked_nano_structures[structure_id].size()
	return total


## Structure types needs to return a valid type name to be considered valid
func get_type() -> StringName:
	return &"AnchorPoint"


func get_readable_type() -> String:
	return "Anchor"


func get_tooltip_text() -> String:
	var tooltip: String = ""
	tooltip += get_readable_type() + "\n"
	tooltip += tr("Position: %s\n") % str(_position)
	if _linked_nano_structures.size():
		tooltip += tr("%d Springs in %d Groups:\n") % [get_total_springs_count(), _linked_nano_structures.size()]
		# NOTE: This code assumes only the currently active workspace an have a hovered anchor
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
		assert(workspace_context != null and workspace_context.workspace.has_structure(self))
		for structure_id: int in get_related_structures():
			var structure: AtomicStructure = workspace_context.get_structure_context(structure_id).nano_structure
			var all_hidden_springs: PackedInt32Array = structure.springs_get_hidden()
			var structure_springs: PackedInt32Array = get_related_springs(structure_id)
			var filter_hidden: Callable = func(spring: int) -> bool:
				return spring in all_hidden_springs
			var hidden_springs: PackedInt32Array = Array(structure_springs).filter(filter_hidden)
			if structure_springs.size() == hidden_springs.size() and hidden_springs.size() > 0:
				tooltip += tr_n(
					"- %s: %d hidden spring\n",
					"- %s: %d hidden springs\n",
					hidden_springs.size()
				) % [structure.get_structure_name(), hidden_springs.size()]
			elif hidden_springs.size() > 0:
				# Note: structure_springs.size() cannot be 1 or less, so is safe to assume plural
				tooltip += tr(
					"- %s: %d springs (%d hidden)\n"
				) % [structure.get_structure_name(), structure_springs.size(), hidden_springs.size()]
			else:
				tooltip += tr_n(
					"- %s: %d spring\n",
					"- %s: %d springs\n",
					structure_springs.size()
				) % [structure.get_structure_name(), structure_springs.size()]
	return tooltip


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


func init_remap_structure_ids(in_structures_map: Dictionary) -> void:
	for old_structure_id: int in get_related_structures():
		var springs: Dictionary = _linked_nano_structures[old_structure_id]
		_linked_nano_structures.erase(old_structure_id)
		var new_structure: NanoStructure = in_structures_map.get(old_structure_id, null)
		assert(is_instance_valid(new_structure), "Structure has vanished during import")
		_linked_nano_structures[new_structure.int_guid] = springs


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
