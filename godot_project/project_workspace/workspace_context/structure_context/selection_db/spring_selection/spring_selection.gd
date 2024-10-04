class_name SpringSelection extends Node


var _structure_context: StructureContext = null

var _spring_selection: Dictionary = {
	#SpringID<int> : true<bool>
}

var _aabb: AABB = AABB()
var _aabb_rebuild_needed: bool = true


func initialize(in_related_structure_context: StructureContext) -> void:
	if is_instance_valid(_structure_context):
		var old_structure: NanoStructure = _structure_context.nano_structure
		if old_structure and old_structure.springs_moved.is_connected(_on_nano_structure_springs_moved):
			old_structure.springs_moved.disconnect(_on_nano_structure_springs_moved)
			old_structure.springs_removed.disconnect(_on_nano_structure_springs_removed)
	
	_structure_context = in_related_structure_context
	if not _structure_context.nano_structure is AtomicStructure:
		return
	_structure_context.nano_structure.springs_moved.connect(_on_nano_structure_springs_moved)
	_structure_context.nano_structure.springs_removed.connect(_on_nano_structure_springs_removed)


func _on_nano_structure_springs_moved(_springs: PackedInt32Array) -> void:
	_aabb_rebuild_needed = true


func _on_nano_structure_springs_removed(in_removed_springs: PackedInt32Array) -> void:
	for spring_id: int in in_removed_springs:
		_spring_selection.erase(spring_id)
	_aabb_rebuild_needed = true


func select_springs(in_springs: PackedInt32Array) -> PackedInt32Array:
	return _internal_select_spring(in_springs)


func get_spring_selection() -> PackedInt32Array:
	return PackedInt32Array(_spring_selection.keys())


func _internal_select_spring(in_springs: PackedInt32Array) -> PackedInt32Array:
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var new_springs_selected: PackedInt32Array = PackedInt32Array()
	for spring_id in in_springs:
		if not _spring_selection.has(spring_id):
			_spring_selection[spring_id] = true
			new_springs_selected.append(spring_id)
			var atom_position: Vector3 = nano_structure.spring_get_atom_position(spring_id)
			var anchor_position: Vector3 = nano_structure.spring_get_anchor_position(spring_id, _structure_context)
			_aabb = _aabb.expand(atom_position)
			_aabb = _aabb.expand(anchor_position)
	return new_springs_selected


func is_spring_selected(in_spring_id: int) -> bool:
	return _spring_selection.has(in_spring_id)


func get_selection() -> PackedInt32Array:
	return PackedInt32Array(_spring_selection.keys())


func has_selection() -> bool:
	return not _spring_selection.is_empty()


func clear_selection() -> void:
	_spring_selection.clear()
	_aabb_rebuild_needed = true


func deselect_springs(in_springs_to_deselect: PackedInt32Array,
			out_deselected_springs: PackedInt32Array = PackedInt32Array()) -> bool:
	var overall_success: bool = false
	var spring_success: bool = false
	for spring_to_deselect in in_springs_to_deselect:
		spring_success = _spring_selection.erase(spring_to_deselect)
		if spring_success:
			out_deselected_springs.push_back(spring_to_deselect)
		overall_success = overall_success or spring_success
	_aabb_rebuild_needed = overall_success
	return overall_success


func get_aabb() -> AABB:
	assert(has_selection(), "generating aabb is possible only when there is a selection")
	if not _aabb_rebuild_needed:
		return _aabb
	var nano_structure: NanoStructure = _structure_context.nano_structure
	var springs: PackedInt32Array = nano_structure.springs_get_all()
	var first_id: int = springs[0]
	var initial_position: Vector3 = nano_structure.spring_get_atom_position(first_id)
	_aabb = AABB(initial_position, Vector3.ZERO)
	for spring_id: int in _spring_selection:
		var first_pos: Vector3 = nano_structure.spring_get_atom_position(spring_id)
		var second_pos: Vector3 = nano_structure.spring_get_anchor_position(spring_id, _structure_context)
		_aabb = _aabb.expand(first_pos)
		_aabb = _aabb.expand(second_pos)
	_aabb_rebuild_needed = false
	return _aabb



# # # #
# Snapshots
func get_snapshot() -> Array:
	return [_spring_selection.duplicate(true)]


func apply_snapshot(in_snapshot: Array) -> void:
	_spring_selection = in_snapshot[0].duplicate()
	_aabb_rebuild_needed = true
	
