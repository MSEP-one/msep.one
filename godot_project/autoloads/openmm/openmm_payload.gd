class_name OpenMMPayload extends RefCounted

const HEADER_SIZE: int         = 20 # in bytes
const ATOM_CHUNK_SIZE: int     = 4  # in bytes
const MOLECULE_CHUNK_SIZE: int = 12  # in bytes
const MOLECULE_ID_SIZE: int    = 4
const COUNT_SIZE: int          = 4
const POSITION_CHUNK_SIZE: int = 24 # in bytes
const BOND_CHUNK_SIZE: int     = 9  # in bytes
const FLOAT_SIZE: int          = 8  # in bytes
const ATOM_ID_SIZE: int        = 4  # in bytes

# To prevent forever relaxation because of bonds perfectly aligned to XYZ axes
const NUDGE_FIX_DISTANCE: float = 0.06

var header: PackedByteArray:
	get = _get_header
var topology: PackedByteArray:
	get = _get_topology
var state: PackedByteArray:
	get = _get_state
var topology_molecules: PackedByteArray = []
var topology_atoms: PackedByteArray = []
var topology_bonds: PackedByteArray = []
var topology_passivated_atoms: PackedByteArray = []
var atoms_state: PackedByteArray = []
var passivation_state: PackedByteArray = []
var request_atom_id_to_structure_and_atom_id_map: Dictionary = {
#	request_atom_id: int = [structure_int_guid: int, atom_id: int]
}
var raw_initial_positions: PackedVector3Array = [] # Unaltered positions from the source structure
var initial_positions: PackedVector3Array = [] # Positions with the random nudge offset applied
var lock_atoms: bool = false # send locking information to OpenMM
var passivate_molecules: bool = false # complete valences with extra hydrogens
var forcefield_files: PackedStringArray = []
var next_request_atom_id: int = 0
var next_request_bond_id: int = 0
var molecules_ids: PackedInt32Array = []
var atoms_count_per_molecule: Dictionary = {
#	molecule_id<int> = atoms_count<int>
}
var bonds_count_per_molecule: Dictionary = {
#	molecule_id<int> = bonds_count<int>
}
var other_objects_data: Dictionary = {
#	object_id<int> = object_data<String(JSON)>
}
var atoms_count: int = 0
var bonds_count: int = 0
var passivated_atoms_count: int = 0
var other_objects_count: int = 0
var nudge_atoms_fix_enabled: bool = false
var spring_counter: int = 0


func add_structure(structure: NanoStructure, atom_ids: PackedInt32Array, bond_ids: PackedInt32Array) -> void:
	atoms_count += atom_ids.size()
	bonds_count += bond_ids.size()
	
	# Pack molecule header data
	# chunk[0-3]:  molecule_id
	# chunk[4-7]:  atoms_count
	# chunk[8-11]: bonds_count
	molecules_ids.push_back(structure.int_guid)
	atoms_count_per_molecule[structure.int_guid] = atom_ids.size()
	bonds_count_per_molecule[structure.int_guid] = bond_ids.size()
	var pos: int = topology_molecules.size()
	topology_molecules.resize(topology_molecules.size() + MOLECULE_CHUNK_SIZE)
	# Molecule ID
	topology_molecules.encode_u32(pos, structure.int_guid)
	pos += MOLECULE_ID_SIZE
	# Atoms count
	topology_molecules.encode_u32(pos, atom_ids.size())
	pos += COUNT_SIZE
	
	var original_to_request_atom_id_map: Dictionary = {}
	for atom_id in atom_ids:
		# Register atom id
		var request_atom_id: int = next_request_atom_id
		request_atom_id_to_structure_and_atom_id_map[request_atom_id] = [structure.int_guid, atom_id]
		original_to_request_atom_id_map[atom_id] = request_atom_id
		next_request_atom_id += 1
		
		# Save topology_atoms data
		# chunk[0]: element
		# chunk[1]: hidrolization
		# chunk[2]: formal_charge
		# chunk[3]: is_locked
		var atomic_number: int = structure.atom_get_atomic_number(atom_id)
		topology_atoms.append(atomic_number)
		topology_atoms.append(0) # (reserved to specfy one of [auto, sp, sp2, sp3, sp3d, and sp3d2]
		var formal_charge: int = int(structure.atom_get_formal_charge(atom_id))
		topology_atoms.append(abs(formal_charge))
		if formal_charge < 0:
			topology_atoms[-1] |= 0b10000000
		var is_atom_locked: bool = lock_atoms and structure.atom_is_locked(atom_id)
		topology_atoms.push_back(1 if is_atom_locked else 0)
		
		# Save state data
		# chunk[0-7]:   position X
		# chunk[8-15]:  position Y
		# chunk[16-23]: position Z
		var atom_pos: Vector3 = structure.atom_get_position(atom_id)
		raw_initial_positions.push_back(atom_pos)
		if nudge_atoms_fix_enabled and not is_atom_locked:
			atom_pos += _create_random_nudge()
		initial_positions.push_back(atom_pos)
		var atoms_seek: int = atoms_state.size()
		atoms_state.resize(atoms_state.size() + POSITION_CHUNK_SIZE)
		for axis: int in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
			atoms_state.encode_double(atoms_seek, atom_pos[axis])
			atoms_seek += FLOAT_SIZE
	for bond_id in bond_ids:
		# chunk[0-3]: atom1
		# chunk[4-7]: atom2
		# chunk[8]:   order
		var bond: Vector3i = structure.get_bond(bond_id)
		var atom1: int = original_to_request_atom_id_map[bond.x]
		var atom2: int = original_to_request_atom_id_map[bond.y]
		var order: int = bond.z
		var bonds_seek: int = topology_bonds.size()
		topology_bonds.resize(topology_bonds.size() + BOND_CHUNK_SIZE)
		topology_bonds.encode_u32(bonds_seek, atom1)
		bonds_seek += ATOM_ID_SIZE
		topology_bonds.encode_u32(bonds_seek, atom2)
		bonds_seek += ATOM_ID_SIZE
		topology_bonds.encode_u8(bonds_seek,order)
	
	var structure_passivation_atoms_count: int = 0
	if passivate_molecules:
		var passivate_state_pos: int = passivation_state.size()
		var passivate_atom_pos: int = topology_passivated_atoms.size()
		for atom_id in atom_ids:
			var hydrogen_candidates: PackedVector3Array = _passivate_atom(structure, atom_id)
			var request_id: int = original_to_request_atom_id_map[atom_id]
			structure_passivation_atoms_count += hydrogen_candidates.size()
			passivation_state.resize(passivation_state.size() + POSITION_CHUNK_SIZE * hydrogen_candidates.size())
			topology_passivated_atoms.resize(topology_passivated_atoms.size() + ATOM_ID_SIZE * hydrogen_candidates.size())
			for candidate: Vector3 in hydrogen_candidates:
				for axis: int in [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z]:
					passivation_state.encode_double(passivate_state_pos, candidate[axis])
					passivate_state_pos += FLOAT_SIZE
				topology_passivated_atoms.encode_u32(passivate_atom_pos, request_id)
				passivate_atom_pos += ATOM_ID_SIZE
	# Passivation Atoms Count
	topology_molecules.encode_u32(pos, structure_passivation_atoms_count)
	pos += COUNT_SIZE
	passivated_atoms_count += structure_passivation_atoms_count
	
	assert (topology_molecules.size() + topology_atoms.size() + topology_bonds.size() + \
			topology_passivated_atoms.size() == \
			molecules_ids.size() * MOLECULE_CHUNK_SIZE \
			+ atoms_count * ATOM_CHUNK_SIZE \
			+ bonds_count * BOND_CHUNK_SIZE \
			+ passivated_atoms_count * ATOM_ID_SIZE)


func add_shape(in_shape: NanoShape) -> void:
	assert(not in_shape.int_guid in other_objects_data, "Shape is already registered")
	other_objects_count += 1
	# In order to stringify the shape transform we convert it to Dictionary
	var shape_dict: Dictionary = {}
	# convert transform to raw arrays for better parsing on python
	var shape_transform: Transform3D = in_shape.get_transform()
	var transform: Array = [
		[shape_transform.basis.x[0], shape_transform.basis.x[1], shape_transform.basis.x[2]],
		[shape_transform.basis.y[0], shape_transform.basis.y[1], shape_transform.basis.y[2]],
		[shape_transform.basis.z[0], shape_transform.basis.z[1], shape_transform.basis.z[2]],
		[shape_transform.origin[0],  shape_transform.origin[1],  shape_transform.origin[2]]
	]
	shape_dict[&"is"] = &"shape"
	shape_dict[&"molecule_id"] = in_shape.int_parent_guid # shape is attached to this molecule, and could be moved by a motor
	shape_dict[&"transform"] = transform
	other_objects_data[in_shape.int_guid] = JSON.stringify(shape_dict, "\t")


func add_motor(in_motor: NanoVirtualMotor) -> void:
	assert(not in_motor.int_guid in other_objects_data, "Motor is already registered")
	other_objects_count += 1
	# In order to stringify the motor parameters we convert them to Dictionary
	var motor_dict: Dictionary = {}
	var position: Vector3 = in_motor.get_transform().origin
	var axis_direction: Vector3 = in_motor.get_transform().basis * Vector3.RIGHT
	motor_dict[&"is"] = &"motor"
	motor_dict[&"molecule_id"] = in_motor.int_parent_guid # motor is attached to this molecule, and could be moved by another motor
	motor_dict[&"position"] = [position.x, position.y, position.z]
	motor_dict[&"axis_direction"] = [axis_direction.x, axis_direction.y, axis_direction.z]
	motor_dict[&"connected_molecules"] = in_motor._connected_structures.keys()
	motor_dict[&"parameters"] = {}
	for prop_info: Dictionary in in_motor.get_parameters().get_property_list():
		if not prop_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue # avoid serializing native class properties
		var value: Variant = in_motor.get_parameters().get(prop_info.name)
		motor_dict.parameters[prop_info.name] = value
	other_objects_data[in_motor.int_guid] = JSON.stringify(motor_dict, "\t")


func add_springs(in_structure_context: StructureContext, in_springs: PackedInt32Array) -> void:
	var workspace: Workspace = in_structure_context.workspace_context.workspace
	var nano_struct: AtomicStructure = in_structure_context.nano_structure as AtomicStructure
	for spring_id: int in in_springs:
		var atom_id: int = nano_struct.spring_get_atom_id(spring_id)
		if nano_struct.atom_is_locked(atom_id):
			# Ignore springs related to locked atoms
			continue
		var msep_structure_and_atom_id: Array = [nano_struct.int_guid, atom_id]
		var openmm_particle_id: Variant = request_atom_id_to_structure_and_atom_id_map.find_key(msep_structure_and_atom_id)
		if typeof(openmm_particle_id) != TYPE_INT:
			# Atom was not sent to openmm, skip spring
			continue
		
		var anchor_id: int = in_structure_context.nano_structure.spring_get_anchor_id(spring_id)
		if not anchor_id in other_objects_data:
			# Anchor is still not know, add it
			var anchor: NanoVirtualAnchor = workspace.get_structure_by_int_guid(anchor_id)
			_add_anchor(anchor)
		
		var spring_dict: Dictionary = {}
		spring_dict[&"is"] = &"spring"
		spring_dict[&"anchor_id"] = anchor_id
		spring_dict[&"particle_id"] = openmm_particle_id
		var k_constant_nn_by_nm: float = nano_struct.spring_get_constant_force(spring_id)
		# This constant converts nN/nm to the expected kJ/mol/nm^2
		const NN_NM__TO__JK_MOL_NM2 = 1.0 / 1.66054
		spring_dict[&"k_constant"] = k_constant_nn_by_nm * NN_NM__TO__JK_MOL_NM2
		spring_dict[&"equilibrium_length"] = nano_struct.spring_get_current_equilibrium_length(spring_id, in_structure_context)
		other_objects_data[spring_counter] = JSON.stringify(spring_dict, "\t")
		spring_counter += 1
		other_objects_count += 1


func _add_anchor(in_anchor: NanoVirtualAnchor) -> void:
	assert(not in_anchor.int_guid in other_objects_data, "AnchorPoint is already registered")
	other_objects_count += 1
	# In order to stringify the anchor parameters we convert them to Dictionary
	var anchor_dict: Dictionary = {}
	var position: Vector3 = in_anchor.get_position()
	anchor_dict[&"is"] = &"anchor"
	anchor_dict[&"anchor_id"] = in_anchor.int_guid
	anchor_dict[&"position"] = [position.x, position.y, position.z]
	other_objects_data[in_anchor.int_guid] = JSON.stringify(anchor_dict, "\t")


func _get_header() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE)
	
	# chunk[0-3]: Molecules count
	bytes.encode_u32(0, molecules_ids.size())
	# chunk[4-7]: Atoms count
	bytes.encode_u32(4, atoms_count)
	# chunk[8-11]: Bonds count
	bytes.encode_u32(8, bonds_count)
	# chunk[12-15]: Passivated atoms count
	bytes.encode_u32(12, passivated_atoms_count)
	# chunk[16-19]: Shapes+Motors count
	bytes.encode_u32(16, other_objects_count)
	return bytes


func _get_topology() -> PackedByteArray:
	var topo: PackedByteArray = topology_molecules.duplicate()
	topo.append_array(topology_atoms)
	topo.append_array(topology_bonds)
	topo.append_array(topology_passivated_atoms)
	return topo


func _get_state() -> PackedByteArray:
	var st: PackedByteArray = atoms_state.duplicate()
	st.append_array(passivation_state)
	return st


func _create_random_nudge() -> Vector3:
	var nudge := Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()
	nudge *= NUDGE_FIX_DISTANCE
	return nudge

# Returns a list of positions where hydrogens bonded to atoms would preferably be placed
func _passivate_atom(in_structure: AtomicStructure, in_atom_id: int) -> PackedVector3Array:
	var directions: PackedVector3Array = []
	var remaininig_valence: int = in_structure.atom_get_remaining_valence(in_atom_id)
	if remaininig_valence > 0:
		# Add hydrogens
		var atomic_number: int = in_structure.atom_get_atomic_number(in_atom_id)
		var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
		var atom_position: Vector3 = in_structure.atom_get_position(in_atom_id)
		var current_atom := HAtomsEmptyValenceDirections.Atom.new(atom_position, element_data.symbol)
		var known_bonds: PackedInt32Array = in_structure.atom_get_bonds(in_atom_id)
		current_atom.valence = remaininig_valence + known_bonds.size()
		match current_atom.valence:
			4:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.TETRA
			3:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP2
			_:
				current_atom.geometry = HAtomsEmptyValenceDirections.Geometries.SP1
		match known_bonds.size():
			0:
				directions = HAtomsEmptyValenceDirections.fill_valence_from_0(current_atom)
			1:
				var other_atom_id_1: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = in_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(in_structure,in_atom_id, [other_atom_id_1])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_1(current_atom, known_1, torsion_candidate)
			2:
				var other_atom_id_1: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = in_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = in_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var torsion_candidate: HAtomsEmptyValenceDirections.Atom = _find_torsion_candidate(in_structure,in_atom_id, [other_atom_id_1, other_atom_id_2])
				directions = HAtomsEmptyValenceDirections.fill_valence_from_2(current_atom, known_1, known_2, torsion_candidate)
			3:
				var other_atom_id_1: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[0])
				var other_atom_pos_1: Vector3 = in_structure.atom_get_position(other_atom_id_1)
				var known_1 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_1, "dummy")
				var other_atom_id_2: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[1])
				var other_atom_pos_2: Vector3 = in_structure.atom_get_position(other_atom_id_2)
				var known_2 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_2, "dummy")
				var other_atom_id_3: int = in_structure.atom_get_bond_target(in_atom_id, known_bonds[2])
				var other_atom_pos_3: Vector3 = in_structure.atom_get_position(other_atom_id_3)
				var known_3 := HAtomsEmptyValenceDirections.Atom.new(other_atom_pos_3, "dummy")
				directions = HAtomsEmptyValenceDirections.fill_valence_from_3(current_atom, known_1, known_2, known_3)
		for i in directions.size():
			# Correct the position of each atom
			directions[i] = _place_passivation_hydrogen(in_structure, in_atom_id, directions[i])
	return directions


func _place_passivation_hydrogen(in_nano_structure: NanoStructure, in_atom_id: int, in_direction: Vector3) -> Vector3:
	var offset: Vector3 = in_direction
	var atom_element: int = in_nano_structure.atom_get_atomic_number(in_atom_id)
	var atom_position: Vector3 = in_nano_structure.atom_get_position(in_atom_id)
	var atom_element_data: ElementData = PeriodicTable.get_by_atomic_number(atom_element)
	var hydrogen_element_data: ElementData = PeriodicTable.get_by_atomic_number(PeriodicTable.ATOMIC_NUMBER_HYDROGEN)
	const HYDROGEN_BOND_ORDER: int = 1
	offset *= (
		atom_element_data.covalent_radius[HYDROGEN_BOND_ORDER] +
		hydrogen_element_data.covalent_radius[HYDROGEN_BOND_ORDER]
	)
	var debug_multiplier: float = ProjectSettings.get_setting(
		&"msep/h_atoms_empty_valence_directions/hydrogen_bond_lengths_multiplier", 1.0)
	offset *= debug_multiplier
	return (atom_position + offset)


func _find_torsion_candidate(in_structure: NanoStructure, in_atom_id: int, other_atom_ids: PackedInt32Array) -> HAtomsEmptyValenceDirections.Atom:
	for other_atom_id in other_atom_ids:
		var bond_ids_of_other: PackedInt32Array = in_structure.atom_get_bonds(other_atom_id)
		for bond in bond_ids_of_other:
			var candidate_id: int = in_structure.atom_get_bond_target(other_atom_id, bond)
			if candidate_id != in_atom_id:
				var candidate_position: Vector3 = in_structure.atom_get_position(candidate_id)
				var torsion_candidate := HAtomsEmptyValenceDirections.Atom.new(candidate_position, "dummy")
				return torsion_candidate
	return null
