"@abstract_class"
class_name StickRepresentation extends Representation

const _DEFAULT_BOND_WIDTH: float = 1.0

var _workspace_context: WorkspaceContext
var _related_structure_id: int
var _bond_id_to_particle_id: Dictionary = {
	#bond_id<int> : particle_id<ParticleID>
}
var _current_bond_partial_selection: Dictionary = {
	# bond_id<int> : true<bool>
}
var _bond_id_to_bond_order: Dictionary = {
	# bond_id<int> : order<int>
}

static var _shader_scale_factor: float = 1.0

var _hovered_bond_id: int = -1
var _highlighted_bonds: Dictionary = {
	# bond_id<int> : is_highlighted<bool>
}

@onready var _single_stick_multimesh: SegmentedMultimesh = $SingleStickSegmentedMultiMesh
@onready var _double_stick_multimesh: SegmentedMultimesh = $DoubleStickSegmentedMultiMesh
@onready var _tripple_stick_multimesh: SegmentedMultimesh = $TrippleStickSegmentedMultiMesh
@onready var _bond_order_to_segmented_multimesh: Dictionary = {
	1 : _single_stick_multimesh,
	2 : _double_stick_multimesh,
	3 : _tripple_stick_multimesh,
	-1 : _single_stick_multimesh,
	-2 : _double_stick_multimesh,
	-3 : _tripple_stick_multimesh,
}

var _material_bond_1: Material
var _material_bond_2: Material
var _material_bond_3: Material


func _ready() -> void:
	_material_bond_1 = _single_stick_multimesh.get_material_override()
	_material_bond_2 = _double_stick_multimesh.get_material_override()
	_material_bond_3 = _tripple_stick_multimesh.get_material_override()
	_initialize()


func _initialize() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func _calculate_bond_transform(_in_bond: Vector3i) -> Transform3D:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return Transform3D()


func build(in_structure_context: StructureContext) -> void:
	assert(is_instance_valid(in_structure_context.nano_structure))
	_workspace_context = in_structure_context.workspace_context
	_related_structure_id = in_structure_context.get_int_guid()
	var related_nanostructure: AtomicStructure = in_structure_context.nano_structure as AtomicStructure
	clear()
	
	var bonds_ids: PackedInt32Array = related_nanostructure.get_bonds_ids()
	var bond_state := Representation.InstanceState.new()
	var selected_bonds: PackedInt32Array = in_structure_context.get_selected_bonds()
	var selected_atoms: PackedInt32Array = in_structure_context.get_selected_atoms()
	for bond_id in bonds_ids:
		if related_nanostructure.is_bond_valid(bond_id):
			bond_state.is_visible = not related_nanostructure.is_bond_hidden_by_user(bond_id)
			bond_state.is_selected = bond_id in selected_bonds
			var bond_data: Vector3i = related_nanostructure.get_bond(bond_id)
			bond_state.is_first_atom_selected = bond_data.x in selected_atoms
			bond_state.is_second_atom_selected = bond_data.y in selected_atoms
			bond_state.is_hydrogen = related_nanostructure.atom_is_any_hydrogen([bond_data.x, bond_data.y])
			_create_bond(bond_id, bond_state)
	
	_single_stick_multimesh.bake()
	_double_stick_multimesh.bake()
	_tripple_stick_multimesh.bake()
	
	var representation_settings: RepresentationSettings = related_nanostructure.get_representation_settings()
	apply_theme(representation_settings.get_theme())


func _update_is_selectable_uniform() -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var is_editable: bool = structure_context.is_editable()
	_material_bond_1.set_selectable(is_editable)
	_material_bond_2.set_selectable(is_editable)
	_material_bond_3.set_selectable(is_editable)


func _update_is_hovered_uniform(in_is_hovered: bool) -> void:
	_material_bond_1.set_hovered(in_is_hovered)
	_material_bond_2.set_hovered(in_is_hovered)
	_material_bond_3.set_hovered(in_is_hovered)


func _create_bond(bond_id: int, in_bond_state: Representation.InstanceState) -> ParticleID:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id) as AtomicStructure
	var bond: Vector3i = related_structure.get_bond(bond_id)
	var particle_transform: Transform3D = _calculate_bond_transform(bond)
	var first_atom_id: int = bond.x
	var second_atom_id: int = bond.y
	var bond_order: int =  bond.z
	var first_atom_type: int = related_structure.atom_get_atomic_number(first_atom_id)
	var second_atom_type: int = related_structure.atom_get_atomic_number(second_atom_id)
	var first_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(first_atom_type)
	var second_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(second_atom_type)
	var first_color: Color = StickRepresentation.get_bond_color(first_atom_id, related_structure)
	var second_color: Color = StickRepresentation.get_bond_color(second_atom_id, related_structure)
	var first_atom_radius: float = get_atom_radius(first_atom_periodic_table_data, related_structure.get_representation_settings())
	var second_atom_radius: float = get_atom_radius(second_atom_periodic_table_data, related_structure.get_representation_settings())
	var smaller_atom_radius: float = min(first_atom_radius, second_atom_radius)
	first_color.a = in_bond_state.to_float()
	second_color.a = smaller_atom_radius
	
	_bond_id_to_bond_order[bond_id] = bond_order;
	var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
	segmented_multimesh.add_particle(bond_id, particle_transform, first_color, second_color)
	_bond_id_to_particle_id[bond_id] = ParticleID.new(bond_order, bond_id)
	return _bond_id_to_particle_id[bond_id]


func _remove_bond(bond_id: int) -> void:
	var bond_order: int = _bond_id_to_bond_order[bond_id]
	var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
	var multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
	multimesh.queue_particle_removal(particle_id.bond_id)
	_bond_id_to_particle_id.erase(bond_id)
	_current_bond_partial_selection.erase(bond_id)
	_highlighted_bonds.erase(bond_id)
	_bond_id_to_bond_order.erase(bond_id)


static func _find_atom_connected_to_first_but_not_second(in_first_atom: int, in_second_atom: int,
			in_nanostructure: NanoStructure) -> int:
	var bonds: PackedInt32Array = in_nanostructure.atom_get_bonds(in_first_atom)
	for bond_id in bonds:
		var bond_target_atom: int = in_nanostructure.atom_get_bond_target(in_first_atom, bond_id)
		if bond_target_atom != in_second_atom:
			return bond_target_atom
	return -1


func highlight_atoms(_in_atoms_ids: PackedInt32Array, \
		new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array(), \
				in_bonds_released_from_partial_influence: PackedInt32Array = PackedInt32Array()) -> void:
	_refresh_bond_partial_influence_status(new_partially_influenced_bonds)
	_refresh_bond_partial_influence_status(in_bonds_released_from_partial_influence)


func _refresh_bond_partial_influence_status(new_partially_influenced_bonds: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	for bond_id: int in new_partially_influenced_bonds:
		if not bond_id in _bond_id_to_particle_id:
			continue
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var bond_state := Representation.InstanceState.new()
		bond_state.is_first_atom_selected = structure_context.is_atom_selected(bond.x)
		bond_state.is_second_atom_selected = structure_context.is_atom_selected(bond.y)
		bond_state.is_selected = _highlighted_bonds.get(bond_id, false)
		bond_state.is_hovered = bond_id == _hovered_bond_id
		bond_state.is_visible = not related_structure.is_bond_hidden_by_user(bond_id)
		bond_state.is_hydrogen = related_structure.atom_is_any_hydrogen([bond.x, bond.y])
		var bond_order: int = bond.z
		var first_atom_id: int = bond.x
		var second_atom_id: int = bond.y
		var first_atom_type: int = related_structure.atom_get_atomic_number(first_atom_id)
		var second_atom_type: int = related_structure.atom_get_atomic_number(second_atom_id)
		var first_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(first_atom_type)
		var second_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(second_atom_type)
		var first_highlight_color: Color = StickRepresentation.get_bond_color(first_atom_id, related_structure)
		var second_highlight_color: Color = StickRepresentation.get_bond_color(second_atom_id, related_structure)
		first_highlight_color.a = bond_state.to_float()
		var first_atom_radius: float = get_atom_radius(first_atom_periodic_table_data, related_structure.get_representation_settings())
		var second_atom_radius: float = get_atom_radius(second_atom_periodic_table_data, related_structure.get_representation_settings())
		var smaller_atom_radius: float = min(first_atom_radius, second_atom_radius)
		second_highlight_color.a = smaller_atom_radius
		var is_under_full_influence := bond_state.is_first_atom_selected and bond_state.is_second_atom_selected
		var is_under_no_influence := not bond_state.is_first_atom_selected and not bond_state.is_second_atom_selected
		var is_under_partial_influence := bond_state.is_first_atom_selected != bond_state.is_second_atom_selected
		if is_under_full_influence or is_under_no_influence:
			_current_bond_partial_selection.erase(bond_id)
		elif is_under_partial_influence:
			_current_bond_partial_selection[bond_id] = true
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		segmented_multimesh.update_particle_color(particle_id.bond_id, first_highlight_color,
				second_highlight_color)


func lowlight_atoms(_in_atoms_ids: PackedInt32Array, in_bonds_released_from_partial_influence: PackedInt32Array,
			new_partially_influenced_bonds: PackedInt32Array = PackedInt32Array()) -> void:
	_refresh_bond_partial_influence_status(in_bonds_released_from_partial_influence)
	_refresh_bond_partial_influence_status(new_partially_influenced_bonds)


func highlight_bonds(in_bonds_to_highlight: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	for bond_id in in_bonds_to_highlight:
		if _highlighted_bonds.get(bond_id, false):
			continue
		
		_highlighted_bonds[bond_id] = true
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var bond_order: int = bond.z
		var first_atom_id: int = bond.x
		var second_atom_id: int = bond.y
		var first_atom_type: int = related_structure.atom_get_atomic_number(first_atom_id)
		var second_atom_type: int = related_structure.atom_get_atomic_number(second_atom_id)
		var first_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(first_atom_type)
		var second_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(second_atom_type)
		var first_highlight_color: Color = StickRepresentation.get_bond_color(first_atom_id, related_structure)
		var second_highlight_color: Color = StickRepresentation.get_bond_color(second_atom_id, related_structure)
		var bond_state := Representation.InstanceState.new()
		bond_state.is_visible = not related_structure.is_bond_hidden_by_user(bond_id)
		bond_state.is_hovered = bond_id == _hovered_bond_id
		bond_state.is_selected = true
		bond_state.is_first_atom_selected = structure_context.is_atom_selected(first_atom_id)
		bond_state.is_second_atom_selected = structure_context.is_atom_selected(second_atom_id)
		bond_state.is_hydrogen = related_structure.atom_is_any_hydrogen([first_atom_id, second_atom_id])
		first_highlight_color.a = bond_state.to_float()
		var first_atom_radius: float = get_atom_radius(first_atom_periodic_table_data, related_structure.get_representation_settings())
		var second_atom_radius: float = get_atom_radius(second_atom_periodic_table_data, related_structure.get_representation_settings())
		var smaller_atom_radius: float = min(first_atom_radius, second_atom_radius)
		second_highlight_color.a = smaller_atom_radius
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		segmented_multimesh.update_particle_color(particle_id.bond_id, first_highlight_color,
				second_highlight_color)


func lowlight_bonds(in_bonds_to_lowlight: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	for bond_id in in_bonds_to_lowlight:
		var is_highlighted: bool = _highlighted_bonds.get(bond_id, false)
		if not is_highlighted:
			continue
		
		_highlighted_bonds[bond_id] = false
		var particle_id: ParticleID = _bond_id_to_particle_id.get(bond_id, null)
		if particle_id == null:
			# Particle doesn't exist anymore, assumed to be deleted
			continue
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var bond_order: int = bond.z
		var first_atom_id: int = bond.x
		var second_atom_id: int = bond.y
		var first_atom_type: int = related_structure.atom_get_atomic_number(first_atom_id)
		var second_atom_type: int = related_structure.atom_get_atomic_number(second_atom_id)
		var first_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(first_atom_type)
		var second_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(second_atom_type)
		var first_color: Color = StickRepresentation.get_bond_color(first_atom_id, related_structure)
		var second_color: Color = StickRepresentation.get_bond_color(second_atom_id, related_structure)
		var bond_state := Representation.InstanceState.new()
		bond_state.is_visible = not related_structure.is_bond_hidden_by_user(bond_id)
		bond_state.is_hovered = bond_id == _hovered_bond_id
		bond_state.is_selected = false
		bond_state.is_first_atom_selected = structure_context.is_atom_selected(first_atom_id)
		bond_state.is_second_atom_selected = structure_context.is_atom_selected(second_atom_id)
		bond_state.is_hydrogen = related_structure.atom_is_any_hydrogen([first_atom_id, second_atom_id])
		first_color.a = bond_state.to_float()
		var first_atom_radius: float = get_atom_radius(first_atom_periodic_table_data, related_structure.get_representation_settings())
		var second_atom_radius: float = get_atom_radius(second_atom_periodic_table_data, related_structure.get_representation_settings())
		var smaller_atom_radius: float = min(first_atom_radius, second_atom_radius)
		second_color.a = smaller_atom_radius
		
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		segmented_multimesh.update_particle_color(particle_id.bond_id, first_color, second_color)


func hide_bond_rendering() -> void:
	return


func show_bond_rendering() -> void:
	return


static func get_bond_color(in_atom_id: int, in_nano_structure: NanoStructure) -> Color:
	if in_nano_structure is NanoMolecularStructure and in_nano_structure.has_color_override(in_atom_id):
		return in_nano_structure.get_color_override(in_atom_id)
	var atomic_number: int = in_nano_structure.atom_get_atomic_number(in_atom_id)
	var data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
	return data.bond_color


func add_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	return


func remove_atoms(_in_atoms_ids: PackedInt32Array) -> void:
	return


func refresh_atoms_positions(in_atoms_ids: PackedInt32Array) -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	var already_served_bonds: Dictionary = {}
	for atom_id in in_atoms_ids:
		var atom_bonds: PackedInt32Array = related_structure.atom_get_bonds(atom_id)
		for bond_id in atom_bonds:
			if already_served_bonds.has(bond_id):
				continue
			already_served_bonds[bond_id] = true

			var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
			var related_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[particle_id.bond_order]
			var bond: Vector3i = related_structure.get_bond(bond_id)
			var bond_transform: Transform3D = _calculate_bond_transform(bond)
			related_multimesh.update_particle_transform(particle_id.bond_id, bond_transform)
			assert(bond.z == particle_id.bond_order, "Desynchronization between NanoStructure and Representation")
	
	_single_stick_multimesh.apply_queued_removals()
	_single_stick_multimesh.rebuild_if_needed()
	_double_stick_multimesh.apply_queued_removals()
	_double_stick_multimesh.rebuild_if_needed()
	_tripple_stick_multimesh.apply_queued_removals()
	_tripple_stick_multimesh.rebuild_if_needed()


func refresh_atoms_locking(_in_atoms_ids: PackedInt32Array) -> void:
	return


func refresh_atoms_atomic_number(in_atoms_and_atomic_numbers: Array[Vector2i]) -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	var bonds_to_update: Dictionary = {
		# bond_id<int> = true
	}
	var atom_ids: PackedInt32Array = []
	for atom_element_pair in in_atoms_and_atomic_numbers:
		var atom_id: int = atom_element_pair[0]
		atom_ids.append(atom_id)
		for bond_id in related_structure.atom_get_bonds(atom_id):
			bonds_to_update[bond_id] = true
	var bonds_ids: PackedInt32Array = bonds_to_update.keys()
	refresh_atomic_numbers_of_bond_atoms(bonds_ids)


func refresh_atoms_sizes() -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	_shader_scale_factor = Representation.get_atom_scale_factor(related_structure.get_representation_settings())
	_apply_scale_factor(_shader_scale_factor)
	refresh_all()


func refresh_atoms_color(in_atoms: PackedInt32Array) -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	var bonds_to_update: Dictionary = {
		# bond_id<int> = true
	}
	for atom_id: int in in_atoms:
		for bond_id in related_structure.atom_get_bonds(atom_id):
			bonds_to_update[bond_id] = true

	for bond_id: int in bonds_to_update:
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var bond_order: int = particle_id.bond_order
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		
		var current_color: Color = segmented_multimesh.get_particle_color(bond_id)
		var additional_data: Color = segmented_multimesh.get_particle_additional_data(bond_id)
		var first_color: Color = StickRepresentation.get_bond_color(bond.x, related_structure)
		var second_color: Color = StickRepresentation.get_bond_color(bond.y, related_structure)
		first_color.a = current_color.a
		second_color.a = additional_data.a
		
		segmented_multimesh.update_particle_color(bond_id, first_color, second_color)


func refresh_atoms_visibility(_in_atoms_ids: PackedInt32Array) -> void:
	return


func refresh_bonds_visibility(in_bonds_ids: PackedInt32Array) -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	for bond_id: int in in_bonds_ids:
		if not bond_id in _bond_id_to_particle_id:
			continue
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var bond_order: int = particle_id.bond_order
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		var color: Color = segmented_multimesh.get_particle_color(bond_id)
		var additional_data: Color = segmented_multimesh.get_particle_additional_data(bond_id)
		var bond_state := Representation.InstanceState.new(color.a)
		bond_state.is_visible = not related_structure.is_bond_hidden_by_user(bond_id)
		color.a = bond_state.to_float()
		segmented_multimesh.update_particle_color(bond_id, color, additional_data)


func refresh_all() -> void:
	var related_structure: AtomicStructure = _workspace_context.workspace.get_structure_by_int_guid(_related_structure_id)
	_refresh_bond_partial_influence_status(related_structure.get_valid_bonds())


func _apply_scale_factor(_new_scale_factor: float) -> void:
	assert(false, "this method should be overwritten")
	return


func clear() -> void:
	_current_bond_partial_selection.clear()
	_bond_id_to_particle_id.clear()
	_bond_id_to_bond_order.clear()
	_highlighted_bonds.clear()
	_single_stick_multimesh.prepare()
	_double_stick_multimesh.prepare()
	_tripple_stick_multimesh.prepare()


func show() -> void:
	_single_stick_multimesh.show()
	_double_stick_multimesh.show()
	_tripple_stick_multimesh.show()
	_update_is_selectable_uniform()


func hide() -> void:
	_single_stick_multimesh.hide()
	_double_stick_multimesh.hide()
	_tripple_stick_multimesh.hide()


func add_bonds(new_bonds: PackedInt32Array) -> void:
	var bond_state := Representation.InstanceState.new()
	var _structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var atomic_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var selected_bonds: PackedInt32Array = _structure_context.get_selected_bonds()
	var selected_atoms: PackedInt32Array = _structure_context.get_selected_atoms()
	for bond_id in new_bonds:
		bond_state.is_visible = not atomic_structure.is_bond_hidden_by_user(bond_id)
		bond_state.is_selected = bond_id in selected_bonds
		var bond_data: Vector3i = atomic_structure.get_bond(bond_id)
		bond_state.is_first_atom_selected = bond_data.x in selected_atoms
		bond_state.is_second_atom_selected = bond_data.y in selected_atoms
		bond_state.is_hydrogen = atomic_structure.atom_is_any_hydrogen([bond_data.x, bond_data.y])
		_create_bond(bond_id, bond_state)
	_single_stick_multimesh.rebuild_if_needed()
	_double_stick_multimesh.rebuild_if_needed()
	_tripple_stick_multimesh.rebuild_if_needed()


func remove_bonds(old_bonds: PackedInt32Array) -> void:
	for bond_id in old_bonds:
		_remove_bond(bond_id)
	_single_stick_multimesh.apply_queued_removals()
	_double_stick_multimesh.apply_queued_removals()
	_tripple_stick_multimesh.apply_queued_removals()


func bonds_changed(changed_bonds: PackedInt32Array) -> void:
	var _structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var atomic_structure: AtomicStructure = _structure_context.nano_structure as AtomicStructure
	var new_particles_colors: Array = []
	var bond_state := Representation.InstanceState.new()
	var selected_bonds: PackedInt32Array = _structure_context.get_selected_bonds()
	var selected_atoms: PackedInt32Array = _structure_context.get_selected_atoms()
	for bond_id in changed_bonds:
		var bond: Vector3i = atomic_structure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var old_bond_order: int = particle_id.bond_order
		var new_bond_order: int = bond.z
		_bond_id_to_bond_order[bond_id] = new_bond_order;
		var particle_really_changed: bool = new_bond_order != old_bond_order
		if particle_really_changed:

			#
			var old_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[old_bond_order]
			var particle_color: Color = old_multimesh.get_particle_color(particle_id.bond_id)
			var additional_data: Color = old_multimesh.get_particle_additional_data(particle_id.bond_id)
			
			#
			old_multimesh.queue_particle_removal(particle_id.bond_id)
			_bond_id_to_particle_id.erase(bond_id)
			
			#
			bond_state.is_visible = not atomic_structure.is_bond_hidden_by_user(bond_id)
			bond_state.is_selected = bond_id in selected_bonds
			bond_state.is_first_atom_selected = bond.x in selected_atoms
			bond_state.is_second_atom_selected = bond.y in selected_atoms
			bond_state.is_hydrogen = atomic_structure.atom_is_any_hydrogen([bond.x, bond.y])
			
			#
			_create_bond(bond_id, bond_state)
			
			#
			var new_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[new_bond_order]
			var reapply_color_info: Dictionary = {
				"segmented_multimesh" : new_multimesh,
				"bond_id" : bond_id,
				"color" : particle_color,
				"additional_data" : additional_data
			}
			new_particles_colors.append(reapply_color_info)

	_single_stick_multimesh.apply_queued_removals()
	_double_stick_multimesh.apply_queued_removals()
	_tripple_stick_multimesh.apply_queued_removals()
	_single_stick_multimesh.rebuild_if_needed()
	_double_stick_multimesh.rebuild_if_needed()
	_tripple_stick_multimesh.rebuild_if_needed()
	
	for reapply_color_info: Dictionary in new_particles_colors:
		var multimesh: SegmentedMultimesh = reapply_color_info["segmented_multimesh"]
		var bond_id: int = reapply_color_info["bond_id"]
		var color: Color = reapply_color_info["color"]
		var additional_data: Color = reapply_color_info["additional_data"]
		multimesh.update_particle_color(bond_id, color, additional_data)


func refresh_atomic_numbers_of_bond_atoms(changed_bonds: PackedInt32Array) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	for bond_id in changed_bonds:
		var bond: Vector3i = related_structure.get_bond(bond_id)
		var particle_id: ParticleID = _bond_id_to_particle_id[bond_id]
		var bond_order: int = particle_id.bond_order
		var segmented_multimesh: SegmentedMultimesh = _bond_order_to_segmented_multimesh[bond_order]
		var first_atom_type: int = related_structure.atom_get_atomic_number(bond.x)
		var second_atom_type: int = related_structure.atom_get_atomic_number(bond.y)
		var first_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(first_atom_type)
		var second_atom_periodic_table_data: ElementData = PeriodicTable.get_by_atomic_number(second_atom_type)
		var first_color: Color = StickRepresentation.get_bond_color(bond.x, related_structure)
		var second_color: Color = StickRepresentation.get_bond_color(bond.y, related_structure)
		var first_atom_radius: float = get_atom_radius(first_atom_periodic_table_data, related_structure.get_representation_settings())
		var second_atom_radius: float = get_atom_radius(second_atom_periodic_table_data, related_structure.get_representation_settings())
		var smaller_atom_radius: float = min(first_atom_radius, second_atom_radius)
		var bond_state := Representation.InstanceState.new()
		bond_state.is_visible = not related_structure.is_bond_hidden_by_user(bond_id)
		bond_state.is_hovered = bond_id == _hovered_bond_id
		bond_state.is_selected = _highlighted_bonds.get(bond_id, false)
		bond_state.is_first_atom_selected = structure_context.is_atom_selected(bond.x)
		bond_state.is_second_atom_selected = structure_context.is_atom_selected(bond.y)
		bond_state.is_hydrogen = related_structure.atom_is_any_hydrogen([bond.x, bond.y])
		first_color.a = bond_state.to_float()
		second_color.a = smaller_atom_radius
		var particle_transform: Transform3D = _calculate_bond_transform(bond)
		segmented_multimesh.update_particle_transform_and_color(bond_id, particle_transform, first_color, second_color)


func set_material_overlay(in_material: Material) -> void:
	_single_stick_multimesh.set_material_overlay(in_material)
	_double_stick_multimesh.set_material_overlay(in_material)
	_tripple_stick_multimesh.set_material_overlay(in_material)


static func _calc_up_vect_for_single_bond(in_dir_between_atoms: Vector3) -> Vector3:
	var not_parallel_dir: Vector3 = Vector3(in_dir_between_atoms.z,in_dir_between_atoms.x, in_dir_between_atoms.y)
	return in_dir_between_atoms.cross(not_parallel_dir)


static func _calc_up_vector_for_higher_bond(in_first_atom_id: int, in_second_atom_id: int, first_atom_position: Vector3,
			second_atom_position: Vector3, in_nanostructure: NanoStructure) -> Vector3:

	var third_atom_id: int = _find_atom_connected_to_first_but_not_second(in_first_atom_id, in_second_atom_id,
			in_nanostructure)

	if third_atom_id == -1:
		third_atom_id = _find_atom_connected_to_first_but_not_second(in_second_atom_id, in_first_atom_id,
				in_nanostructure)

	if third_atom_id == -1:
		# there is no way to determine proper up vector, we need at least three points for that, let's do our best
		# while working around it
		var camera: Camera3D = MolecularEditorContext.get_current_workspace_context().get_editor_viewport().get_camera_3d()
		if camera != null:
			return -camera.global_transform.basis.z
		else:
			var direction_between_atoms: Vector3 = first_atom_position.direction_to(second_atom_position)
			var up_vect: Vector3 = direction_between_atoms.cross(Vector3(0, 0, 1))
			return up_vect

	var third_atom_position: Vector3 = in_nanostructure.atom_get_position(third_atom_id)
	var plane: Plane = Plane(first_atom_position, second_atom_position, third_atom_position)
	return plane.normal


func refresh_bond_influence(in_partially_selected_bonds: PackedInt32Array) -> void:
	var bonds_to_refresh: Dictionary = {}
	for bond_id: int in in_partially_selected_bonds:
		bonds_to_refresh[bond_id] = true
	for bond_id: int in _current_bond_partial_selection:
		bonds_to_refresh[bond_id] = true
	_refresh_bond_partial_influence_status(bonds_to_refresh.keys())


func rotate_atom_selection_around_point(_in_point: Vector3, _in_rotation_to_apply: Basis) -> void:
	# TODO: CapsuleStickRepresentation and CylinderStickRepresentation most probably will be able to
	# share this when CapsuleStickRepresentation movement will be moved on the GPU
	assert(false, "Should be overwritten")
	return


func _calculate_partial_selection_transform(in_bond: Vector3i, in_rotation_point: Vector3, in_rotation_to_apply: Basis) -> Transform3D:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	if not is_instance_valid(structure_context):
		return Transform3D()
	
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	var bond_order: int = in_bond.z
	var first_atom_id: int = in_bond.x
	var second_atom_id: int = in_bond.y
	var is_first_atom_selected: bool = structure_context.is_atom_selected(first_atom_id)
	var is_second_atom_selected: bool = structure_context.is_atom_selected(second_atom_id)
	var first_atom_new_pos: Vector3 = related_structure.atom_get_position(first_atom_id)
	if is_first_atom_selected:
		var first_atom_old_position: Vector3 = first_atom_new_pos
		var first_delta_pos: Vector3 = first_atom_old_position - in_rotation_point
		first_atom_new_pos = in_rotation_point + in_rotation_to_apply * first_delta_pos
	var second_atom_new_pos: Vector3 = related_structure.atom_get_position(second_atom_id)
	if is_second_atom_selected:
		var second_old_atom_position: Vector3 = second_atom_new_pos
		var second_delta_pos: Vector3 = second_old_atom_position - in_rotation_point
		second_atom_new_pos = in_rotation_point + in_rotation_to_apply * second_delta_pos
	
	var dir_from_first_to_second: Vector3 = first_atom_new_pos.direction_to(second_atom_new_pos)
	var up_vector: Vector3 = StickRepresentation._calc_up_vect_for_single_bond(dir_from_first_to_second) if bond_order == 1 else \
			StickRepresentation._calc_up_vector_for_higher_bond(first_atom_id, second_atom_id, first_atom_new_pos,
					second_atom_new_pos, related_structure)
	var _particle_transform: Transform3D = calculate_transform_for_bond(first_atom_new_pos,
			second_atom_new_pos, up_vector)
	return _particle_transform


func set_atom_selection_position_delta(_in_movement_delta: Vector3) -> void:
	# TODO: CapsuleStickRepresentation and CylinderStickRepresentation most probably will be able to
	# share this when CapsuleStickRepresentation movement will be moved on the GPU
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return


func _calculate_partial_selection_translation(in_bond: Vector3i, in_delta_translation: Vector3) -> Transform3D:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var related_structure: AtomicStructure = structure_context.nano_structure as AtomicStructure
	var bond_order: int = in_bond.z
	var first_atom_id: int = in_bond.x
	var second_atom_id: int = in_bond.y
	var is_first_atom_selected: bool = structure_context.is_atom_selected(first_atom_id)
	var is_second_atom_selected: bool = structure_context.is_atom_selected(second_atom_id)
	var first_atom_new_pos: Vector3 = related_structure.atom_get_position(first_atom_id)
	if is_first_atom_selected:
		first_atom_new_pos += in_delta_translation
	var second_atom_new_pos: Vector3 = related_structure.atom_get_position(second_atom_id)
	if is_second_atom_selected:
		second_atom_new_pos += in_delta_translation
	
	var dir_from_first_to_second: Vector3 = first_atom_new_pos.direction_to(second_atom_new_pos)
	var up_vector: Vector3 = StickRepresentation._calc_up_vect_for_single_bond(dir_from_first_to_second) if bond_order == 1 else \
			StickRepresentation._calc_up_vector_for_higher_bond(first_atom_id, second_atom_id, first_atom_new_pos,
					second_atom_new_pos, related_structure)
	var _particle_transform: Transform3D = calculate_transform_for_bond(first_atom_new_pos,
			second_atom_new_pos, up_vector)
	return _particle_transform


static func calculate_transform_for_bond(in_first_pos: Vector3, in_sec_pos: Vector3,
			in_up_vector: Vector3) -> Transform3D:
	var particle_position: Vector3 = (in_first_pos + in_sec_pos) / 2.0
	var length: float = in_first_pos.distance_to(in_sec_pos)
	var particle_transform: Transform3D = Transform3D(Basis(), particle_position)
	if particle_transform.origin.distance_squared_to(in_first_pos) > 0.0001:
		particle_transform = particle_transform.looking_at(in_first_pos, in_up_vector)
	particle_transform = particle_transform.scaled_local(Vector3(1, 1, length))
	return particle_transform


static func calc_bond_width_factor(_in_bond_order: int, _in_smaller_atom_radius: float) -> float:
	return _DEFAULT_BOND_WIDTH


func update(_in_delta: float) -> void:
	return


func set_transparency(in_transparency: float) -> void:
	_single_stick_multimesh.set_transparency(in_transparency)
	_double_stick_multimesh.set_transparency(in_transparency)
	_tripple_stick_multimesh.set_transparency(in_transparency)


func handle_editable_structures_changed(_in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	if not _workspace_context.has_nano_structure_context_id(_related_structure_id):
		assert(ScriptUtils.is_queued_for_deletion_reqursive(self), "structure deleted, this rendering instance is about to be deleted")
		return
	_update_is_selectable_uniform()


func handle_hover_structure_changed(in_toplevel_hovered_structure_context: StructureContext,
			in_hovered_structure_context: StructureContext, _in_atom_id: int, in_bond_id: int,
			_in_spring_id: int) -> void:
	var structure_context: StructureContext = _workspace_context.get_structure_context(_related_structure_id)
	var workspace: Workspace = _workspace_context.workspace
	var current_context: StructureContext = _workspace_context.get_current_structure_context()
	var is_hovered: bool = false
	var did_hover_a_group: bool = in_toplevel_hovered_structure_context != null
	var is_context_edited_by_user: bool = current_context == structure_context
	if did_hover_a_group and not is_context_edited_by_user:
		var is_entire_group_hovered: bool = (
				in_toplevel_hovered_structure_context == structure_context
				or workspace.is_a_ancestor_of_b(
					in_toplevel_hovered_structure_context.nano_structure,
					structure_context.nano_structure)
				)
		if is_entire_group_hovered:
			is_hovered = true
	_update_is_hovered_uniform(is_hovered)
	if in_hovered_structure_context != structure_context:
		in_bond_id = -1 # Hovered bond is not part of this structure, remove roll over if needed
	if in_bond_id == _hovered_bond_id:
		return # Already set
	var bonds_to_update := PackedInt32Array()
	if _hovered_bond_id != -1:
		bonds_to_update.push_back(_hovered_bond_id)
	if in_bond_id != -1:
		bonds_to_update.push_back(in_bond_id)
	_hovered_bond_id = in_bond_id
	_refresh_bond_partial_influence_status(bonds_to_update)


func update_segments_if_needed() -> void:
	for segment: SegmentedMultimesh in [_single_stick_multimesh, _double_stick_multimesh, _tripple_stick_multimesh]:
		if segment.update_segments_on_movement:
			segment.rebuild_if_needed()
			segment.apply_queued_removals()


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_related_structure_id"] = _related_structure_id
	snapshot["_bond_id_to_particle_id"] = _bond_id_to_particle_id.duplicate(true)
	snapshot["_current_bond_partial_selection"] = _current_bond_partial_selection.duplicate()
	snapshot["_bond_id_to_bond_order"] = _bond_id_to_bond_order.duplicate()
	snapshot["_shader_scale_factor"] = _shader_scale_factor
	snapshot["_hovered_bond_id"] = _hovered_bond_id
	snapshot["_highlighted_bonds"] = _highlighted_bonds.duplicate()
	snapshot["_single_stick_multimesh.snapshot"] = _single_stick_multimesh.create_state_snapshot()
	snapshot["_double_stick_multimesh.snapshot"] = _double_stick_multimesh.create_state_snapshot()
	snapshot["_tripple_stick_multimesh.snapshot"] = _tripple_stick_multimesh.create_state_snapshot()
	snapshot["_workspace_context"] = _workspace_context
	if is_instance_valid(_material_bond_1):
		# ancestors of this class might use different material
		snapshot["_material_bond_1.snapshot"] = _material_bond_1.create_state_snapshot()
		snapshot["_material_bond_2.snapshot"] = _material_bond_2.create_state_snapshot()
		snapshot["_material_bond_3.snapshot"] = _material_bond_3.create_state_snapshot()
	
	return snapshot

func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_related_structure_id = in_snapshot["_related_structure_id"]
	_workspace_context = in_snapshot["_workspace_context"]
	_related_structure_id = in_snapshot["_related_structure_id"]
	_bond_id_to_particle_id = in_snapshot["_bond_id_to_particle_id"].duplicate(true)
	_current_bond_partial_selection = in_snapshot["_current_bond_partial_selection"].duplicate()
	_bond_id_to_bond_order = in_snapshot["_bond_id_to_bond_order"].duplicate()
	_shader_scale_factor = in_snapshot["_shader_scale_factor"]
	_hovered_bond_id = in_snapshot["_hovered_bond_id"]
	_highlighted_bonds = in_snapshot["_highlighted_bonds"].duplicate()
	
	_single_stick_multimesh.apply_state_snapshot(in_snapshot["_single_stick_multimesh.snapshot"])
	_double_stick_multimesh.apply_state_snapshot(in_snapshot["_double_stick_multimesh.snapshot"])
	_tripple_stick_multimesh.apply_state_snapshot(in_snapshot["_tripple_stick_multimesh.snapshot"])
	if is_instance_valid(_material_bond_1):
		# ancestors of this class might use different material
		_material_bond_1.apply_state_snapshot(in_snapshot["_material_bond_1.snapshot"])
		_material_bond_2.apply_state_snapshot(in_snapshot["_material_bond_2.snapshot"])
		_material_bond_3.apply_state_snapshot(in_snapshot["_material_bond_3.snapshot"])

class ParticleID:
	var bond_order: int
	var bond_id: int

	func _init(in_bond_order: int, in_bond_id: int) -> void:
		bond_order = in_bond_order
		bond_id = in_bond_id

