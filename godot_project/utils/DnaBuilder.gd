extends Node

# Standard B-DNA geometry parameters
const DNA_RADIUS = 1.0  # Nanometers
const DNA_BASES: Dictionary[String, String] = {
		"A" : "res://chemical_structures/nucleobases/adenine.mol",
		"T" : "res://chemical_structures/nucleobases/thymine.mol",
		"G" : "res://chemical_structures/nucleobases/guanine.mol",
		"C" : "res://chemical_structures/nucleobases/cytosine.mol",
}
const DNA_COMPLEMENT: Dictionary[String, String] = {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G'}


var _base_templates: Dictionary[String, _Base]
var _all_templates_fetched: bool = false
var _template_fetching_completed := Signal()


func _ready() -> void:
	for base: String in DNA_BASES.keys():
		await _fetch_template(base)
	_all_templates_fetched = true
	_template_fetching_completed.emit()


class Parameters:
	var bases_per_turn: float = 10.0
	var rise_nanometers: float = 0.34
	var dna_radius_nanometers: float = 1.0
	var double_strands: bool = true


## Build a DNA AtomicStructure from in_sequence.
## Args:
##   in_sequence: DNA in_sequence string (e.g., "ATGC")
##   in_parameters: a DnaBuilder.Parameters object, or null for default
func build_dna_structure(in_sequence: String, in_params := Parameters.new()) -> AtomicStructure:
	var structure := AtomicStructure.create()
	
	structure.start_edit()
	var strand_count: int = 2 if in_params.double_strands else 1
	for strand in strand_count:
		for i: int in in_sequence.length():
			var type: String = in_sequence[i] if strand == 0 else DNA_COMPLEMENT[in_sequence[i]]
			var nucleotide: _Base = _build_nucleotide(type, i, in_params, strand)
			
			# Add atoms to structure
			var base_atom_start: int = structure.get_valid_atoms_count()
			for a: int in nucleotide.atoms.size():
				var atom_data: Vector4 = nucleotide.atoms[a]
				var atomic_number: int = int(atom_data.w)
				var position := Vector3(atom_data.x, atom_data.y, atom_data.z)
				structure.add_atom(AtomicStructure.AddAtomParameters.new(atomic_number, position))
			for bond_data: Vector3i in nucleotide.bonds:
				var atom_a: int = base_atom_start + bond_data.x
				var atom_b: int = base_atom_start + bond_data.y
				var order: int = bond_data.z
				structure.add_bond(atom_a, atom_b, order)
	
	structure.end_edit()
	
	return structure


## Build a nucleotide at the specified (indexed) position.
func _build_nucleotide(
			in_base: String,
			in_position: int,
			in_params: Parameters,
			strand: int = 0
		) -> _Base:
	assert(in_base in DNA_BASES, "Unknown base: %s" % in_base)
	
	var template: _Base = _base_templates[in_base]
	var result := _Base.new()
	
	# Calculate helix position
	var z_offset: float = in_position * in_params.rise_nanometers
	var twist: float = deg_to_rad(360.0 / in_params.bases_per_turn)
	var angle: float = in_position * twist
	
	# For complementary strand, flip and rotate 180 degrees
	if strand == 1:
		angle += PI
		
	var base_centroid: Vector3 = (Vector3.RIGHT * in_params.dna_radius_nanometers).rotated(Vector3.FORWARD, angle)
	for atom_data: Vector4 in template.atoms:
		# Rotate around helix
		var position := Vector3(atom_data.x, atom_data.y, atom_data.z).rotated(Vector3.FORWARD, angle)
		position.z += z_offset
		position += base_centroid
		# Replace position
		atom_data.x = position.x
		atom_data.y = position.y
		atom_data.z = position.z
		
		result.atoms.append(atom_data)
	result.bonds = template.bonds.duplicate()
	
	return result


func _fetch_template(in_base: String) -> void:
	if not in_base in _base_templates:
		var template := _Base.new()
		var unpacked_mol_path: String = WorkspaceUtils.unpack_mol_file_and_get_path(DNA_BASES[in_base])
		var absolute_path: String = ProjectSettings.globalize_path(unpacked_mol_path)
		var structure: AtomicStructure = await WorkspaceUtils.get_nano_structure_from_file(
			null, absolute_path, false, false, false)
		var atom_remap: Dictionary[int, int] = {
			# structure_atom_id : template_atom_id
		}
		var next_atom_id: int = 0
		for atom_id in structure.get_valid_atoms():
			var atomic_number: int = structure.atom_get_atomic_number(atom_id)
			if atomic_number == PeriodicTable.ATOMIC_NUMBER_HYDROGEN:
				# skip hydrogens
				continue
			var position: Vector3 = structure.atom_get_position(atom_id)
			atom_remap[atom_id] = next_atom_id
			var atom_data := Vector4(position.x, position.y, position.z, atomic_number)
			template.atoms.append(atom_data)
			next_atom_id += 1
		for bond_id: int in structure.get_valid_bonds():
			var bond_data: Vector3i = structure.get_bond(bond_id)
			if atom_remap.has(bond_data.x) and atom_remap.has(bond_data.y):
				# is not a bond to hydrogen, remap the atom ids and append
				bond_data.x = atom_remap[bond_data.x]
				bond_data.y = atom_remap[bond_data.y]
				template.bonds.append(bond_data)
		_base_templates[in_base] = template


class _Base:
	## Atoms data packed as follows: xyz as the position, w as the atomic number
	var atoms: PackedVector4Array
	## Bonds data packed as follows: x and y as atom indexes, z as bond order
	var bonds: Array[Vector3i]
