extends CanvasLayer

const PackedMolecule = preload("res://autoloads/dna_builder/templates/packed_molecule.gd")

var DNA_BASES_OFFSET: float = 0.6
const DNA_COMPLEMENT: Dictionary[String, String] = {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G'}

class Parameters:
	var bases_per_turn: float = 10.0
	var rise_nanometers: float = 0.34
	var dna_radius_nanometers: float = 1.0
	var double_strands: bool = true
	var include_hydrogens: bool = true

var _base_templates: Dictionary[String, PackedMolecule] = {}


func is_dev_tool_enabled() -> bool:
	return (FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER)
		and FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAGS_DNA_BUILDER_DEV_TOOL))


## Build a DNA AtomicStructure from in_sequence.
## Args:
##   in_sequence: DNA in_sequence string (e.g., "ATGC")
##   in_parameters: a DnaBuilder.Parameters object, or null for default
func build_dna_structure(in_sequence: String, in_params := Parameters.new()) -> AtomicStructure:
	var structure := AtomicStructure.create()
	var strand_count: int = 2 if in_params.double_strands else 1
	
	structure.start_edit()
	for strand in strand_count:
		_create_strand(structure, in_sequence.to_upper(), in_params, strand)
	structure.end_edit()
	
	return structure


func _create_strand(structure: AtomicStructure, in_sequence: String, in_params: Parameters, in_strand: int) -> void:
	var previous_backbone_atom_id: int = -1
	var next_backbone_atom_id: int = -1
	for i: int in in_sequence.length():
		var type: String = in_sequence[i] if in_strand == 0 else DNA_COMPLEMENT[in_sequence[i]]
		var nucleotide: PackedMolecule = _build_nucleotide(type, i, in_params, in_strand)
		
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
		next_backbone_atom_id = base_atom_start + nucleotide.previous_backbone_atom_id
		if previous_backbone_atom_id >= 0:
			structure.add_bond(previous_backbone_atom_id, next_backbone_atom_id, 1)
		previous_backbone_atom_id = base_atom_start + nucleotide.next_backbone_atom_id
		# Connect previous backbone to the next backbone


## Build a nucleotide at the specified (indexed) position.
func _build_nucleotide(
			in_base: String,
			in_index: int,
			in_params: Parameters,
			strand: int = 0
		) -> PackedMolecule:
	assert(in_base in ["A", "T", "G", "C"], "Unknown base: %s" % in_base)
	
	var template: PackedMolecule = _get_template(in_base, in_params.include_hydrogens)
	var result := PackedMolecule.new()
	
	# Calculate helix position
	var z_offset: float = in_index * in_params.rise_nanometers
	var twist: float = deg_to_rad(360.0 / in_params.bases_per_turn)
	var angle: float = in_index * twist
	
	# For complementary strand, flip and rotate 180 degrees
	if strand == 1:
		angle += PI
	
	var base_distance: float = in_params.dna_radius_nanometers - DNA_BASES_OFFSET
	var base_centroid: Vector3 = \
		(Vector3.RIGHT * base_distance).rotated(Vector3.BACK, angle)
	base_centroid.z += z_offset
	if is_dev_tool_enabled():
		# Show the centroid position. Sodium atom for base
		result.atoms.append(Vector4(base_centroid.x, base_centroid.y, base_centroid.z, 11))
	var first_base_atom: int = result.atoms.size()
	_dump_template(result, template, base_centroid, angle)
	assert(template.base_to_backbone_atom_id >= 0, "Unconfigured base_to_backbone_atom_id for template " + in_base)
	var base_bond_atom: int = first_base_atom + template.base_to_backbone_atom_id
	
	# Create the backbone
	var backbone_distance: float = in_params.dna_radius_nanometers
	var backbone_centroid: Vector3 = \
		(Vector3.RIGHT * backbone_distance).rotated(Vector3.BACK, angle)
	backbone_centroid.z += z_offset
	template = _get_template("backbone%d" % strand, in_params.include_hydrogens)
	assert(template.base_to_backbone_atom_id >= 0, "Unconfigured b	ase_to_backbone_atom_id for " + "backbone%d" % strand)
	if is_dev_tool_enabled():
		# Show the centroid position. Argon for Backbone
		result.atoms.append(Vector4(backbone_centroid.x, backbone_centroid.y, backbone_centroid.z, 18))
	var first_backbone_atom: int = result.atoms.size()
	_dump_template(result, template, backbone_centroid, angle)
	var backbone_bond_atom: int = first_backbone_atom + template.base_to_backbone_atom_id
	
	# Bond the base to the backbone
	result.bonds.push_back(Vector3i(base_bond_atom, backbone_bond_atom, 1))
	result.previous_backbone_atom_id = first_backbone_atom + template.previous_backbone_atom_id
	result.next_backbone_atom_id = first_backbone_atom + template.next_backbone_atom_id
	return result


func _get_template(in_base: String, in_include_hydrogens: bool = false) -> PackedMolecule:
	const FILENAMES = {
		"A" : "adenine",
		"T" : "thymine",
		"G" : "guanine",
		"C" : "cytosine",
		"backbone0" : "backbone0",
		"backbone1" : "backbone1",
	}
	const PATH = "res://autoloads/dna_builder/templates/%s.tres"
	var filename: String = FILENAMES[in_base] + ("_h" if in_include_hydrogens else "")
	if not _base_templates.has(filename) or is_dev_tool_enabled():
		_base_templates[filename] = ResourceLoader.load(PATH % filename, "", ResourceLoader.CACHE_MODE_IGNORE)
	return _base_templates[filename]


func _dump_template(
			out_result: PackedMolecule,
			in_template: PackedMolecule,
			in_centroid: Vector3,
			in_angle: float,
		) -> void:
	var first_atom: int = out_result.atoms.size()
	for atom_data: Vector4 in in_template.atoms:
		# Rotate around helix
		var position := Vector3(atom_data.x, atom_data.y, atom_data.z).rotated(Vector3.BACK, in_angle)
		position += in_centroid
		# Replace position
		atom_data.x = position.x
		atom_data.y = position.y
		atom_data.z = position.z
		out_result.atoms.append(atom_data)
	for bond_data: Vector3i in in_template.bonds:
		bond_data.x += first_atom
		bond_data.y += first_atom
		out_result.bonds.append(bond_data)
