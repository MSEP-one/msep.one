class_name NanoEditorClipboard extends Node


const PASTE_OFFSET_DISTANCE: float = 2.0


var _content: ClipboardContent
var _paste_count: int = 0
var _latest_clipboard_action_camera_transform: Transform3D = Transform3D()

enum ClipboardContentType {
	ATOMS_AND_BONDS, 
	OBJECT_DUPLICATE, 
	SPRINGS,
}


func copy(in_workspace_context: WorkspaceContext) -> void:
	var selection_result: Array[Dictionary] = _get_selected_structure_and_atoms(in_workspace_context)
	if selection_result.is_empty():
		return
	var camera_transform: Transform3D = in_workspace_context.get_camera_global_transform()
	_latest_clipboard_action_camera_transform = camera_transform
	_paste_count = 0
	
	var new_content: Array[Dictionary] = []
	for selection_data in selection_result:
		var structure_context: StructureContext = selection_data.structure_context
		var nano_structure: NanoStructure = selection_data.nano_structure
		var atom_selection: PackedInt32Array = selection_data.atom_selection
		var spring_selection: PackedInt32Array = selection_data.spring_selection
	
		if nano_structure == null or nano_structure.get_type() == StringName():
			continue
		
		match nano_structure.get_type():
			&"MolecularStructure":
				_copy_selected_atoms(
					structure_context, nano_structure, atom_selection, new_content
				)
				_copy_selected_springs(
					structure_context, nano_structure, spring_selection, atom_selection, new_content
				)
			&"Cylinder",&"Cone",&"Pyramid",&"Box",&"Capsule",&"Plane",&"Prism",&"Sphere",&"Torus":
				_copy_reference_shape(structure_context, nano_structure, new_content)
			&"RotaryMotor",&"LinearMotor":
				_copy_motor(structure_context, nano_structure, new_content)
			&"AnchorPoint":
				_copy_anchor(structure_context, nano_structure, new_content)
			&"ParticleEmitter":
				_copy_particle_emitter(structure_context, nano_structure, new_content)
			_:
				push_warning("Nano structure type not implemented for copy")
	var root_group_id: int = -1
	if in_workspace_context.get_current_structure_context() != null:
		root_group_id = in_workspace_context.get_current_structure_context().nano_structure.int_guid
	_content.set_content(new_content, root_group_id)


func _get_selected_structure_and_atoms(in_workspace_context: WorkspaceContext) -> Array[Dictionary]:
	var nano_structure: NanoStructure = null
	var atom_selection: PackedInt32Array = []
	var spring_selection: PackedInt32Array = []
	var result: Array[Dictionary] = []
	var selected_structures: Array[StructureContext] = \
		in_workspace_context.get_structure_contexts_with_selection(true)
	for structure_context in selected_structures:
		nano_structure = structure_context.nano_structure
		if !nano_structure:
			continue
		atom_selection = structure_context.get_selected_atoms()
		spring_selection = structure_context.get_selected_springs()
		var context_selection: Dictionary = {
			nano_structure = nano_structure,
			atom_selection = atom_selection,
			spring_selection = spring_selection,
			structure_context = structure_context
		}
		result.push_back(context_selection)
	return result


func _copy_selected_atoms(
	in_structure_context: StructureContext,
	in_structure: NanoStructure,
	in_atom_selection: PackedInt32Array,
	out_content: Array[Dictionary]) -> void:
	
	var camera_transform: Transform3D = \
		in_structure_context.workspace_context.get_camera_global_transform()
	
	var atom_selection: PackedInt32Array = in_atom_selection.duplicate()
	atom_selection.sort()
	var clipboard_atoms: Array[ClipboardAtom] = []
	for atom_id in atom_selection:
		var local_to_camera_position: Vector3 = \
				camera_transform.inverse() * in_structure.atom_get_position(atom_id)
		var color_override: Variant = null
		if in_structure.has_color_override(atom_id):
			color_override = in_structure.get_color_override(atom_id)
		var atom: ClipboardAtom = ClipboardAtom.new(
			local_to_camera_position, 
			in_structure.atom_get_atomic_number(atom_id),
			color_override,
			atom_id,
			in_structure.int_guid
		)
		clipboard_atoms.push_back(atom)
	
	var clipboard_bonds: Array[ClipboardBond] = []
	for atom_idx: int in range(atom_selection.size()):
		for bond_id: int in in_structure.atom_get_bonds(atom_selection[atom_idx]):
			var other_atom_idx: int = in_structure.atom_get_bond_target(atom_selection[atom_idx], bond_id)
			if atom_selection.find(other_atom_idx) == -1:
				continue
			var atom_a: int = atom_idx
			var atom_b: int = atom_selection.find(other_atom_idx)
			# Prevents adding duplicated bonds
			if atom_b < atom_a:
				continue
			var order: int = in_structure.get_bond(bond_id).z
			clipboard_bonds.push_back(ClipboardBond.new(atom_a, atom_b, order))
	
	var new_content: Dictionary = {}
	new_content[&"type"] = ClipboardContentType.ATOMS_AND_BONDS
	new_content[&"data"] = {}
	new_content[&"data"][&"group_id"] = in_structure.int_guid
	new_content[&"data"][&"parent_group_id"] = in_structure.int_parent_guid
	new_content[&"data"][&"name"] = in_structure.get_structure_name()
	new_content[&"data"][&"bonds"] = clipboard_bonds
	new_content[&"data"][&"atoms"] = clipboard_atoms
	out_content.push_back(new_content)


func _copy_selected_springs(
	in_structure_context: StructureContext,
	in_structure: AtomicStructure,
	in_spring_selection: PackedInt32Array,
	in_atom_selection: PackedInt32Array, 
	out_content: Array[Dictionary]) -> void:
	var clipboard_springs: Dictionary = {
		#original_spring_id:int = ClipboardSpring
	}
	# Springs' related structures have to be pasted before it can be pasted
	var related_structure_ids: Dictionary = {
		#original_spring_id:int = PackedInt32Array[related_structures_int_guids]
	}
	# Springs' required structures have to exist/be valid at the moment of pasting (all of them),
	# otherwise the spring becomes invalid and is not pasted
	var required_structure_ids: Dictionary = {
		#original_spring_id:int = PackedInt32Array[required_structures_int_guids]
	}
	# Structures are either related or required, they can't be both.
	
	# selected_anchor_ids = {anchor_id: int = true}
	var selected_anchor_ids: Dictionary = _get_selected_anchor_ids(in_structure_context.workspace_context)
	for spring_id: int in in_spring_selection:
		var target_anchor_id: int = in_structure.spring_get_anchor_id(spring_id)
		var target_atom_id: int = in_structure.spring_get_atom_id(spring_id)
		if not selected_anchor_ids.has(target_anchor_id) \
			and not in_atom_selection.has(target_atom_id):
			continue
		clipboard_springs[spring_id] = ClipboardSpring.new(
				in_structure.spring_get_constant_force(spring_id),
				in_structure.spring_get_equilibrium_length_is_auto(spring_id),
				in_structure.spring_get_equilibrium_manual_length(spring_id),
				target_atom_id,
				target_anchor_id
		)
		
		related_structure_ids[spring_id] = PackedInt32Array()
		required_structure_ids[spring_id] = PackedInt32Array()
		if in_atom_selection.has(target_atom_id):
			related_structure_ids[spring_id].append(in_structure.int_guid)
		else:
			required_structure_ids[spring_id].append(in_structure.int_guid)
		if selected_anchor_ids.has(target_anchor_id):
			related_structure_ids[spring_id].append(target_anchor_id)
		else:
			required_structure_ids[spring_id].append(target_anchor_id)
		
	var new_content: Dictionary = {}
	new_content[&"type"] = ClipboardContentType.SPRINGS
	new_content[&"data"] = {}
	new_content[&"data"][&"group_id"] = in_structure.int_guid
	new_content[&"data"][&"parent_group_id"] = in_structure.int_parent_guid
	new_content[&"data"][&"springs"] = clipboard_springs
	new_content[&"data"][&"related_structures"] = related_structure_ids
	new_content[&"data"][&"required_structures"] = required_structure_ids
	out_content.push_back(new_content)


func _get_selected_anchor_ids(in_workspace_context: WorkspaceContext) -> Dictionary:
	var result: Dictionary = {}
	var selected_structures: Array[StructureContext] = \
		in_workspace_context.get_structure_contexts_with_selection()
	for structure_context in selected_structures:
		if structure_context.is_anchor_selected():
			result[structure_context.nano_structure.int_guid] = true
	return result


func _copy_structure(
	in_structure_context: StructureContext, 
	in_structure: NanoStructure, 
	out_content: Array[Dictionary]) -> void:
	var new_content: Dictionary = {}
	new_content[&"type"] = ClipboardContentType.OBJECT_DUPLICATE
	new_content[&"data"] = {}
	new_content[&"data"][&"group_id"] = in_structure.int_guid
	new_content[&"data"][&"parent_group_id"] = in_structure.int_parent_guid
	new_content[&"data"][&"object"] = in_structure.duplicate(true)
	new_content[&"data"][&"object"].int_guid = 0
	
	var camera_transform: Transform3D = \
		in_structure_context.workspace_context.get_camera_global_transform()
	if in_structure.has_transform():
		new_content[&"data"][&"local_to_camera_transform"] = \
			camera_transform.inverse() * in_structure.get_transform()
	if in_structure is NanoVirtualAnchor: # Anchors don't have a transform but have a position
		new_content[&"data"][&"local_to_camera_transform"] = \
			camera_transform.inverse() * Transform3D(Basis(), in_structure.get_position())
	
	out_content.push_back(new_content)


func _copy_reference_shape(
	in_structure_context: StructureContext,
	in_shape: NanoShape,
	out_content: Array[Dictionary]) -> void:
	_copy_structure(in_structure_context, in_shape, out_content)


func _copy_motor(
	in_structure_context: StructureContext,
	in_motor: NanoVirtualMotor,
	out_content: Array[Dictionary]) -> void:
	_copy_structure(in_structure_context, in_motor, out_content)


func _copy_anchor(
	in_structure_context: StructureContext,
	in_anchor: NanoVirtualAnchor,
	out_content: Array[Dictionary]) -> void:
	_copy_structure(in_structure_context, in_anchor, out_content)


func _copy_particle_emitter(
	in_structure_context: StructureContext,
	in_emitter: NanoParticleEmitter,
	out_content: Array[Dictionary]) -> void:
	_copy_structure(in_structure_context, in_emitter, out_content)


func cut(out_workspace_context: WorkspaceContext) -> void:
	copy(out_workspace_context)
	if out_workspace_context.has_selection():
		out_workspace_context.action_delete.execute()


func has_content() -> bool:
	return !_content.is_empty()


func paste(out_workspace_context: WorkspaceContext, in_auto_bond_order: int) -> void:
	var target_structure: NanoStructure = null
	var did_create_undo_action: bool = false
	if out_workspace_context.get_current_structure_context() != null:
		target_structure = out_workspace_context.get_current_structure_context().nano_structure
	var original_to_new_structure_id: Dictionary = {
	#	old_id<int> = new_id<int>
	}
	# reference root to allow pasting direct childs
	var current_structure_id: int = out_workspace_context.get_current_structure_context().nano_structure.int_guid
	original_to_new_structure_id[current_structure_id] = current_structure_id
	original_to_new_structure_id[_content.get_content_root_group_id()] = current_structure_id
	
	var selected_structures: Array[StructureContext] = \
		out_workspace_context.get_structure_contexts_with_selection()
	var selection_per_structure: Dictionary = {} #{StructureContext : SelectionSnapshot<Dictionary>}
	for structure_context in selected_structures:
		selection_per_structure[structure_context] = structure_context.get_selection_snapshot()
	var camera_transform: Transform3D = out_workspace_context.get_camera_global_transform()
	if _latest_clipboard_action_camera_transform.is_equal_approx(camera_transform):
		_paste_count += 1
	else:
		_paste_count = 0
		_latest_clipboard_action_camera_transform = camera_transform
	var pasted_atoms: Dictionary = {
		# old_structure_id = Dictionary {old_atom_id = new_atom_id}
	}
	var pasted_motors: Array[NanoVirtualMotor] = []
	var next_pass_content: Array[Dictionary] = _content.get_content().duplicate(true)
	# This methods removes copied springs that can't be pasted because they are missing at 
	# least one required structure (and therefore are invalid). The removal is done
	# from the next_pass_content variable, so clipboard's content remains unchanged.
	_remove_invalid_springs(out_workspace_context.workspace, next_pass_content)
	next_pass_content.sort_custom(_custom_sort_clipboard_content)
	while not next_pass_content.is_empty():
		var this_pass_content: Array[Dictionary] = next_pass_content
		next_pass_content = []
		for entity: Dictionary in this_pass_content:
			match entity.type:
				ClipboardContentType.ATOMS_AND_BONDS:
					if not did_create_undo_action:
						did_create_undo_action = true
					var target_context: StructureContext = null
					if _content.get_content_root_group_id() == entity.data.group_id \
						and target_structure is AtomicStructure:
						# atoms and bolds belongs to root, so we paste on root
						original_to_new_structure_id[entity.data.group_id] = target_structure.int_guid
						original_to_new_structure_id[entity.data.parent_group_id] = target_structure.int_parent_guid
						_paste_atoms_and_bonds_in_structure(out_workspace_context, 
							target_structure, pasted_atoms, entity.data, in_auto_bond_order)
						target_context = out_workspace_context.get_nano_structure_context(target_structure)
					else:
						if not original_to_new_structure_id.has(entity.data.parent_group_id):
							# new parent was not created yet, we deferr it for a next pass
							next_pass_content.push_back(entity)
							continue
						var new_structure := AtomicStructure.create()
						var new_name: String = entity.data.get(&"name", &"")
						if new_name.is_empty():
							new_name = "Structure %d" % (out_workspace_context.workspace.get_nmb_of_structures() + 1)
						new_structure.set_structure_name(new_name)
						var new_parent_id: int = original_to_new_structure_id[entity.data.parent_group_id]
						var parent: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(new_parent_id)
						assert(parent)
						out_workspace_context.workspace.add_structure(new_structure, parent)
						# register the newly assigned structure id
						assert(new_structure.int_guid != 0, "Invalid structure id")
						original_to_new_structure_id[entity.data.group_id] = new_structure.int_guid
						_paste_atoms_and_bonds_in_structure(out_workspace_context, 
							new_structure, pasted_atoms, entity.data, in_auto_bond_order)
						target_context = out_workspace_context.get_nano_structure_context(new_structure)
					if target_context != null and selection_per_structure.has(target_context):
						selection_per_structure.erase(target_context)
				ClipboardContentType.OBJECT_DUPLICATE:
					if not original_to_new_structure_id.has(entity.data.parent_group_id):
						# new parent was not created yet, we deferr it for a next pass
						next_pass_content.push_back(entity)
						continue
					if not did_create_undo_action:
						did_create_undo_action = true
					var new_parent_id: int = original_to_new_structure_id[entity.data.parent_group_id]
					var parent: NanoStructure = out_workspace_context.workspace.get_structure_by_int_guid(new_parent_id)
					assert(parent)
					var new_structure: NanoStructure = paste_object(out_workspace_context, entity.data, parent)
					original_to_new_structure_id[entity.data.group_id] = new_structure.int_guid
					if new_structure is NanoVirtualMotor:
						pasted_motors.push_back(new_structure)
				ClipboardContentType.SPRINGS:
					if not original_to_new_structure_id.has(entity.data.parent_group_id):
						# new parent was not created yet, we deferr it for a next pass
						next_pass_content.push_back(entity)
						continue
					var skip_to_next_pass: bool = false
					var related_structures: Dictionary = entity.data.related_structures
					for spring_id: int in related_structures.keys():
						for related_structure_id: int in related_structures[spring_id]:
							if not original_to_new_structure_id.has(related_structure_id):
								# Either the structure that contains the springs or one 
								# of the anchors the springs are connected to have 
								# not been created yet, we defer them for a next pass
								next_pass_content.push_back(entity)
								skip_to_next_pass = true
								break
						if skip_to_next_pass:
							break
					if skip_to_next_pass:
						continue
					_paste_springs(out_workspace_context,
							entity.data, pasted_atoms, original_to_new_structure_id)
				_:
					pass
	# retarget newly pasted motors
	for original_id: int in original_to_new_structure_id.keys():
		var new_id: int = original_to_new_structure_id[original_id]
		if original_id == new_id:
			# no need to retarget
			continue
		for new_motor: NanoVirtualMotor in pasted_motors:
			if new_motor.is_structure_id_connected(original_id):
				new_motor.disconnect_structure_by_id(original_id)
				new_motor.connect_structure_by_id(new_id)
	if did_create_undo_action:
		for structure_context: StructureContext in selection_per_structure.keys():
			structure_context.clear_selection()
		out_workspace_context.snapshot_moment("Paste clipboard content")


func _get_paste_offset_direction() -> Vector3:
	var offset := Vector3.ZERO
	offset.x = ProjectSettings.get_setting("msep/clipboard/paste_offset_direction/x", 0)
	offset.y = ProjectSettings.get_setting("msep/clipboard/paste_offset_direction/y", 0)
	offset.z = ProjectSettings.get_setting("msep/clipboard/paste_offset_direction/z", 0)
	if offset.length_squared() > 0.01:
		offset = offset.normalized()
	return offset


func _remove_invalid_springs(in_workspace: Workspace, out_content: Array[Dictionary]) -> void:
	for entity: Dictionary in out_content:
		if entity.type != ClipboardContentType.SPRINGS:
			continue
		# required_structures = {original_spring_id: int = PackedInt32Array[required_structures_int_guids]}
		var required_structures: Dictionary = entity.data.required_structures.duplicate(true)
		for spring_id: int in required_structures.keys():
			for required_structure_id: int in required_structures[spring_id]:
				if not in_workspace.has_structure_with_int_guid(required_structure_id):
					entity.data.springs.erase(spring_id)
					entity.data.related_structures.erase(spring_id)
					entity.data.required_structures.erase(spring_id)
					break


func _get_copied_anchor_ids() -> PackedInt32Array:
	var result: PackedInt32Array = []
	for entity: Dictionary in _content.get_content():
		if entity.type == ClipboardContentType.OBJECT_DUPLICATE \
		and entity.data.object.get_type() == &"AnchorPoint":
			result.append(entity.data.group_id)
	return result

# This function sorts entities leaving elements in the clipboard in the following order:
# ATOMS_AND_BONDS, OBJECT_DUPLICATE, SPRINGS
func _custom_sort_clipboard_content(in_a: Dictionary, in_b: Dictionary) -> bool:
	assert(ClipboardContentType.ATOMS_AND_BONDS < ClipboardContentType.OBJECT_DUPLICATE 
		and ClipboardContentType.OBJECT_DUPLICATE < ClipboardContentType.SPRINGS, 
		"Default order of dictionary types changed, review validity of _custom_sort_clipboard_content"
	)
	return in_b.type >= in_a.type


func _paste_atoms_and_bonds_in_structure(
			out_workspace_context: WorkspaceContext,
			out_structure: NanoMolecularStructure,
			out_pasted_atoms: Dictionary,
			in_entity_data: Dictionary,
			in_auto_bond_order: int) -> void:
	assert(in_auto_bond_order >= -1 and in_auto_bond_order <= 3 and in_auto_bond_order != 0)
	var clipboard_atoms: Array[ClipboardAtom] = in_entity_data.atoms
	var clipboard_bonds: Array[ClipboardBond] = in_entity_data.bonds
	var camera_transform: Transform3D = out_workspace_context.get_camera_global_transform()
	var old_index_to_new_index: Dictionary = {}
	var structure_context: StructureContext = \
		out_workspace_context.get_nano_structure_context(out_structure)
	var new_atoms: PackedInt32Array = []
	var new_bonds: PackedInt32Array = []
	
	var carbon_atom_diameter: float = \
		_get_carbon_atom_diameter(
		structure_context.nano_structure.get_representation_settings())
	var paste_position_offset: Vector3 = \
		(camera_transform.basis.get_rotation_quaternion() * _get_paste_offset_direction())
	paste_position_offset *= PASTE_OFFSET_DISTANCE
	paste_position_offset *= carbon_atom_diameter
	paste_position_offset *= _paste_count
	out_structure.start_edit()
	var colors_to_atom_list: Dictionary = {
	#	color_override<Color> = atom_ids<PackedInt32Array>
	}
	if not out_pasted_atoms.has(in_entity_data.group_id):
		out_pasted_atoms[in_entity_data.group_id] = {}
	var old_atom_id_to_new_atom_id: Dictionary = out_pasted_atoms[in_entity_data.group_id]
	for idx in range(clipboard_atoms.size()):
		var atom: ClipboardAtom = clipboard_atoms[idx]
		old_index_to_new_index[idx] = out_structure.add_atom(
			AtomicStructure.AddAtomParameters.new(atom.atomic_number, 
				(camera_transform * atom.position) + paste_position_offset
			)
		)
		old_atom_id_to_new_atom_id[atom.origin_id] = old_index_to_new_index[idx]
		if in_auto_bond_order > -1 and atom.origin_group_id == out_structure.int_guid:
			# Cannot paste bonded atoms to a different structure from where it was originated
			assert(atom.origin_id > -1, "Bonded paste has been used, but there is no information about the source atom")
			var valence_left: int = out_structure.atom_get_remaining_valence(atom.origin_id)
			var valance_allows_new_bond: bool = valence_left > 0
			if valance_allows_new_bond:
				var new_bond_order: int = min(in_auto_bond_order, valence_left)
				assert(new_bond_order < 4, "System does not support bond orders greater then 3")
				var bond_id: int = out_structure.add_bond(old_index_to_new_index[idx], atom.origin_id, new_bond_order)
				new_bonds.append(bond_id)
		if atom.has_color_override:
			if not colors_to_atom_list.has(atom.color_override):
				colors_to_atom_list[atom.color_override] = PackedInt32Array()
			colors_to_atom_list[atom.color_override].append(old_index_to_new_index[idx])
		new_atoms.append(old_index_to_new_index[idx])
	for color: Color in colors_to_atom_list.keys():
		out_structure.set_color_override(colors_to_atom_list[color], color)
	for bond in clipboard_bonds:
		var new_bond_id: int = out_structure.add_bond(
			old_index_to_new_index[bond.atom_index_a], 
			old_index_to_new_index[bond.atom_index_b], 
			bond.bond_order
		)
		new_bonds.append(new_bond_id)
		
	out_structure.end_edit()
	
	structure_context.set_atom_selection(new_atoms)
	structure_context.set_bond_selection(new_bonds)


func _get_copied_structure_original_atom_ids(in_structure_id: int) -> PackedInt32Array:
	var searched_entity: Dictionary = {}
	for entity: Dictionary in _content.get_content():
		if entity.type == ClipboardContentType.ATOMS_AND_BONDS \
			and entity.data.group_id == in_structure_id:
			searched_entity = entity
			break
	return PackedInt32Array(searched_entity.data.atoms.map(
		func (atom: ClipboardAtom) -> int: return atom.origin_id
		)
	) if not searched_entity.is_empty() else PackedInt32Array()


func _paste_springs(
	out_workspace_context: WorkspaceContext,
	clipboard_data: Dictionary,
	in_pasted_atoms: Dictionary,
	in_original_to_new_structure_id: Dictionary) -> void:
	var springs_pending_creation: Dictionary= {
		#target_structure_id: int = Array[ClipboardSpring]
	}
	var copied_anchor_ids: PackedInt32Array = _get_copied_anchor_ids()
	var clipboard_springs: Dictionary = clipboard_data.springs
	var original_atom_ids: PackedInt32Array = \
		_get_copied_structure_original_atom_ids(clipboard_data.group_id)
	var target_structure: AtomicStructure
	for original_spring_id: int in clipboard_springs.keys():
		var spring: ClipboardSpring = clipboard_springs[original_spring_id]
		var target_atom_was_copied: bool = original_atom_ids.has(spring.target_atom)
		var target_anchor_was_copied: bool = copied_anchor_ids.has(spring.target_anchor)
		if target_atom_was_copied and target_anchor_was_copied:
			# create new spring attached to new atom and new anchor
			var new_anchor_id: int = in_original_to_new_structure_id[spring.target_anchor]
			var new_atom_id: int = in_pasted_atoms[clipboard_data.group_id][spring.target_atom]
			var new_structure_id: int = in_original_to_new_structure_id[clipboard_data.group_id]
			target_structure = \
				out_workspace_context.workspace.get_structure_by_int_guid(new_structure_id) as AtomicStructure
			assert(is_instance_valid(target_structure), "New MolecularNanoStructure does not exists!")
			var new_spring: ClipboardSpring = \
				ClipboardSpring.new(spring.constant_force, spring.equilibrium_length_is_auto,
					spring.equilibrium_manual_length, new_atom_id, new_anchor_id)
			if not springs_pending_creation.has(new_structure_id):
				springs_pending_creation[new_structure_id] = []
			springs_pending_creation[new_structure_id].push_back(new_spring)
		elif target_atom_was_copied: # but target_anchor was not
			# create new spring attached to new atom and original anchor
			var original_anchor_structure: NanoStructure = \
				out_workspace_context.workspace.get_structure_by_int_guid(spring.target_anchor)
			if not is_instance_valid(original_anchor_structure):
				continue
			var new_atom_id: int = in_pasted_atoms[clipboard_data.group_id][spring.target_atom]
			var new_target_structure_id: int = in_original_to_new_structure_id[clipboard_data.group_id]
			target_structure = \
				out_workspace_context.workspace.get_structure_by_int_guid(new_target_structure_id) as AtomicStructure
			assert(is_instance_valid(target_structure), "New MolecularNanoStructure does not exists!")
			var new_spring: ClipboardSpring = \
				ClipboardSpring.new(spring.constant_force, spring.equilibrium_length_is_auto,
					spring.equilibrium_manual_length, new_atom_id, spring.target_anchor)
			if not springs_pending_creation.has(new_target_structure_id):
				springs_pending_creation[new_target_structure_id] = []
			springs_pending_creation[new_target_structure_id].push_back(new_spring)
		elif target_anchor_was_copied: # but target_atom was not
			# create new spring attached to new anchor and original atom
			target_structure = \
				out_workspace_context.workspace.get_structure_by_int_guid(clipboard_data.group_id) as AtomicStructure
			if not is_instance_valid(target_structure):
				continue
			if not target_structure.is_atom_valid(spring.target_atom):
				continue
			var new_anchor_id: int = in_original_to_new_structure_id[spring.target_anchor]
			var new_spring: ClipboardSpring = \
				ClipboardSpring.new(spring.constant_force, spring.equilibrium_length_is_auto,
					spring.equilibrium_manual_length, spring.target_atom, new_anchor_id)
			if not springs_pending_creation.has(clipboard_data.group_id):
				springs_pending_creation[clipboard_data.group_id] = []
			springs_pending_creation[clipboard_data.group_id].push_back(new_spring)
		else:
			assert(true, "This should never happen. Springs without atom or anchor selected should not"
				+ " have been copied in the first place")
			continue
	var target_structure_context: StructureContext
	var new_spring_ids: PackedInt32Array = []
	for structure_id: int in springs_pending_creation.keys():
		target_structure = \
			out_workspace_context.workspace.get_structure_by_int_guid(structure_id) as AtomicStructure
		target_structure.start_edit()
		for new_spring_params_idx: int in springs_pending_creation[structure_id].size():
			var new_spring_params: ClipboardSpring = springs_pending_creation[structure_id][new_spring_params_idx]
			new_spring_ids.append(
				target_structure.spring_create(
					new_spring_params.target_anchor,
					new_spring_params.target_atom,
					new_spring_params.constant_force,
					new_spring_params.equilibrium_length_is_auto,
					new_spring_params.equilibrium_manual_length
				)
			)
		target_structure.end_edit()
		target_structure_context = \
			out_workspace_context.get_nano_structure_context_from_id(structure_id)
		target_structure_context.set_spring_selection(new_spring_ids)
		new_spring_ids.clear()


func paste_object(
	out_workspace_context: WorkspaceContext, 
	in_entity_data: Dictionary, 
	in_parent_structure: NanoStructure) -> NanoStructure:
	var structure_template: NanoStructure = in_entity_data.object
	var new_structure: NanoStructure = structure_template.duplicate(true)
	new_structure.set_structure_name(new_structure.get_structure_name() + "(copy)")
	if &"local_to_camera_transform" in in_entity_data:
		var local_to_camera_transform: Transform3D = in_entity_data.local_to_camera_transform
		var camera_transform: Transform3D = out_workspace_context.get_camera_global_transform()
		var carbon_atom_diameter: float = _get_carbon_atom_diameter(
			new_structure.get_representation_settings())
		var paste_position_offset: Vector3 = \
			camera_transform.basis.get_rotation_quaternion() * _get_paste_offset_direction()
		paste_position_offset *= PASTE_OFFSET_DISTANCE
		paste_position_offset *= _paste_count
		paste_position_offset *= carbon_atom_diameter
		var new_transform: Transform3D = camera_transform * local_to_camera_transform
		new_transform.origin += paste_position_offset
		if new_structure is NanoVirtualAnchor:
			new_structure.set_position(new_transform.origin)
		else:
			new_structure.set_transform(new_transform)
	out_workspace_context.workspace.add_structure(new_structure, in_parent_structure)
	var new_structure_context: StructureContext = \
		out_workspace_context.get_nano_structure_context(new_structure)
	new_structure_context.select_all()
	
	return new_structure


func _get_carbon_atom_diameter(
	in_representation_settings: RepresentationSettings) -> float:
	var carbon_data: ElementData = PeriodicTable.get_by_atomic_number(
		PeriodicTable.ATOMIC_NUMBER_CARBON)
	return 2.0 \
			* Representation.get_atom_radius(carbon_data, in_representation_settings) \
			* Representation.get_atom_scale_factor(in_representation_settings)


func _init() -> void:
	_content = ClipboardContent.new()


class ClipboardContent:
	var _content: Array[Dictionary] = [
#		{
#			type, -> ClipboardContentType
#			data
#		}
	]
	var _root_group_id: int # = NanoStructure.int_guid
	
	
	func is_empty() -> bool:
		return _content.is_empty()
	
	
	func set_content(new_content: Array[Dictionary], in_root_group_id: int) -> void:
		_content = new_content
		_root_group_id = in_root_group_id
		_print_content_verbose()
	
	
	func get_content() -> Array[Dictionary]:
		return _content
	
	func get_content_root_group_id() -> int:
		return _root_group_id
	
	func _print_content_verbose() -> void:
		if !OS.is_stdout_verbose():
			# early return to save useless string process
			return
		
		var out := String()
		for entry in _content:
			if !out.is_empty():
				out += "\n"
			match entry.type:
				ClipboardContentType.ATOMS_AND_BONDS:
					out += "\t%d Atoms and %d Bonds" % [
						entry.data.atoms.size(), 
						entry.data.bonds.size()
					]
				ClipboardContentType.OBJECT_DUPLICATE:
					out += "\tEntire object %s of type %s" % [
						entry.data.object.get_structure_name(),
						entry.data.object.get_type()
					]
					if &"transform" in entry.data.object:
						out += " at " + str(entry.data.object.get_transform().origin)
		if !out.is_empty():
			print_verbose("Clipboard Content:\n" + out)

class ClipboardAtom:
	var position: Vector3 = Vector3.ZERO
	var atomic_number: int = -1
	var has_color_override: bool = false
	var color_override: Color = Color.BLACK
	var origin_id: int
	var origin_group_id: int
	
	func _init(in_position: Vector3, in_atomic_number: int, in_color_override: Variant = null,
			in_originating_from_atom: int = AtomicStructure.INVALID_ATOM_ID,
			in_origination_from_group: int = Workspace.INVALID_STRUCTURE_ID) -> void:
		position = in_position
		atomic_number = in_atomic_number
		origin_id = in_originating_from_atom
		origin_group_id = in_origination_from_group
		if typeof(in_color_override) == TYPE_COLOR:
			has_color_override = true
			color_override = in_color_override


class ClipboardBond:
	var atom_index_a: int = -1
	var atom_index_b: int = -1
	var bond_order: int
	
	
	func _init(in_atom_index_a: int, in_atom_index_b: int, in_bond_order: int) -> void:
		atom_index_a = in_atom_index_a
		atom_index_b = in_atom_index_b
		bond_order = in_bond_order


class ClipboardSpring:
	var constant_force: float = 500.0 # kJ/mol/nm^2
	var equilibrium_length_is_auto: bool = true
	var equilibrium_manual_length: float = 1.0
	var target_atom: int
	var target_anchor: int
	
	func _init(in_constant_force: float, in_equilibrium_length_is_auto: bool,
		in_equilibrium_manual_length: float, in_target_atom: int, in_target_anchor: int) -> void:
		constant_force = in_constant_force
		equilibrium_length_is_auto = in_equilibrium_length_is_auto
		equilibrium_manual_length = in_equilibrium_manual_length
		target_atom = in_target_atom
		target_anchor = in_target_anchor
