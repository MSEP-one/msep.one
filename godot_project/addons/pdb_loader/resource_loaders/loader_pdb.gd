@tool
extends ResourceFormatLoader
class_name ProteinDataBaseFormatLoader
# # # #
# DEPRECATED. We have it in the project mostly as an inspiration.
# At the moment when our implementation of the loader will achieve feature parity, this file should be removed

static var autogenerate_bonds: bool = true
static var PeriodicTableInstance: Node = null: get = _get_periodic_table_instance

var _classes := PackedStringArray(["AtomDb", "PdbAtom"])
var _dependencies := PackedStringArray()
func _get_classes_used(_path: String) -> PackedStringArray:
	return _classes

func _get_dependencies(_path: String, _add_types: bool):
	return _dependencies

func _get_recognized_extensions() -> PackedStringArray:
	return ["pdb"]

func _get_resource_type(path: String):
	"ProteinDB"

func _handles_type(type: StringName):
	return type == StringName() # pdb files are external, and are not directly represented by a type

func _recognize_path(path: String, type: StringName):
	return path.get_extension() == "pdb" && type == StringName()

func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int
) -> Variant:
	var atom_data = ProteinDB.new()
	
	var current_chain := Chain.new("")
	var current_residue = Residue.new(-1)
	var is_first_atom: bool = true
	current_chain.residues = [current_residue]
	var all_chains: Array[Chain] = [current_chain]
	
	
	var contents: String = FileAccess.get_file_as_string(path)
	contents = contents.replace("\r\n", "\n")
	# We found some files using "\r" as end of line
	contents = contents.replace("\r", "\n")
	
	var lines: PackedStringArray = contents.split("\n")
	for line in lines:
		var atom = PdbAtom.new()
		
		if _get_str(line, 0, 6) == "CONECT":
			_hetatm_connections(atom_data, line)
			continue
		
		if not ((_get_str(line,0,4)=="ATOM") or (_get_str(line,0,6)=="HETATM")):
			continue
			
		atom.pdb_id = _get_str(line, 6, 13).to_int()
		atom.name = _get_str(line, 12, 16)
		atom.residue = _get_str(line, 17, 20)
		atom.chain = _get_str(line, 21, 22)
		atom.residue_id =_get_str(line, 22, 27).to_int()
		var pos_x: float = _get_str(line, 30, 38).to_float()
		var pos_y: float = _get_str(line, 38, 46).to_float()
		var pos_z: float = _get_str(line, 46, 54).to_float()
		atom.position = Vector3(pos_x, pos_y, pos_z)# + position_shift
		atom.occupancy = _get_str(line, 54, 60).to_float()
		atom.temperature_factor = _get_str(line, 60, 66).to_float()
		atom.element_name = _get_str(line, 76, 78).trim_prefix(" ").trim_suffix(" ").capitalize()
		if atom.element_name.is_empty():
			if atom.name == "OH2":
				# Some files has the oxigen atom of water molecules labeled as "OH2"
				atom.element_name = "O"
			else:
				# Turns "C_3", "C7", "C 4" into "C"
				for character in atom.name:
					if character.to_lower() >= 'a' and character.to_lower() <= 'z':
						atom.element_name += character
				atom.element_name = atom.element_name.capitalize()
		atom_data.add_atom(atom)
		
		if is_first_atom:
			current_chain.name = atom.chain
			current_residue.id = atom.residue_id
			is_first_atom = false
		
		var new_chain: bool = current_chain.name != atom.chain
		var new_residue: bool = new_chain or current_residue.id != atom.residue_id
		if new_chain:
			current_chain = Chain.new(atom.chain)
			current_residue = Residue.new(atom.residue_id)
			current_chain.residues = [current_residue]
			all_chains.push_back(current_chain)
		elif new_residue:
			current_residue = Residue.new(atom.residue_id)
			current_chain.residues.push_back(current_residue)
		current_residue.atoms.append(atom)
	# /for
	
	if autogenerate_bonds:
		for chain in all_chains:
			var chain_atoms: Array[PdbAtom] = []
			for residue in chain.residues:
				residue.atoms.all(_reset_incomplete_neighbor_state)
				# First phase connect atoms of the same residue
				# atom.valence_state is used to skip atoms with
				# valence already complete from the calculation
				_calculate_valence_state_for_atoms(atom_data, residue.atoms)
				_auto_create_bonds(residue.atoms)
				chain_atoms.append_array(residue.atoms)
			# Second phase will connect neighbor residues to each other
			# only atoms with new connections will require to update valence_state
			chain_atoms.all(_reset_incomplete_neighbor_state)
			_calculate_valence_state_for_atoms(atom_data, chain_atoms)
			_auto_create_bonds(chain_atoms)
	
	return atom_data;


func _get_str(inStr: String, from: int, to: int) -> String:
	return inStr.substr(from, to - from).strip_edges()


func _hetatm_connections(atomdb: ProteinDB, in_str_data: String):
	var connection_data = []
	var max_nmb_connections = 4
	var str_pointer = 6
	for connection_idx in range(max_nmb_connections + 1):
		var connection_str = in_str_data.substr(str_pointer, 5).strip_edges()
		if not connection_str.is_empty():
			connection_data.append(in_str_data.substr(str_pointer, 5).to_int())
		str_pointer += 5
	
	var connect_from_idx_atom = connection_data[0]
	var connect_from_atom = atomdb.get_atom_from_pdb_id(connect_from_idx_atom)
	var connect_to_idx_list = connection_data.slice(1)
	for connect_to_idx_atom in connect_to_idx_list:
		var connect_to_atom = atomdb.get_atom_from_pdb_id(connect_to_idx_atom)
		_connect_atoms(connect_from_atom, connect_to_atom, false)

func _reset_incomplete_neighbor_state(out_atom: PdbAtom) -> bool:
	out_atom.has_valence_incomplete_neighbor = false
	return true

func _calculate_valence_state_for_atoms(out_atom_data: ProteinDB, out_atoms: Array[PdbAtom]):
	for atom in out_atoms:
		_calculate_valence_state(out_atom_data, atom)

func _calculate_valence_state(out_atom_data: ProteinDB, out_atom: PdbAtom):
	if out_atom.valence_state == PdbAtom.ValenceState.UNKNOWN:
		if out_atom.valence == 0:
			out_atom.valence = PeriodicTableInstance.get_by_symbol(out_atom.element_name).valence
		if out_atom.connections.size() < out_atom.valence:
			out_atom.valence_state = PdbAtom.ValenceState.INCOMPLETE
			for conn in out_atom.connections:
				var other_atom: PdbAtom = out_atom_data.get_atom(conn.atom_id)
				other_atom.has_valence_incomplete_neighbor = true
		else:
			out_atom.valence_state = PdbAtom.ValenceState.COMPLETE

const HBAUtilityClass = preload("res://utils/heuristic_bond_assignment_utility.gd")
const _ANGSTROM_TO_NANOMETER: float = 0.1
func _auto_create_bonds(out_atoms: Array[PdbAtom]):
	if out_atoms.is_empty():
		return
	var pdb_atoms: Dictionary = {
		#pdb_id: int, pdb_atom:PdbAtom
	}
	var autobonder_atoms: Dictionary = {
		#atom:HBAUtilityClass.Atom = pdb_atom:PdbAtom
	}
	var autobonder_bonds: Dictionary = {
		#bond:HBAUtilityClass.Bond = Vector2i(min_atom_id, max_atom_id)
	}
	var in_atoms: Array[HBAUtilityClass.Atom] = []
	var in_bonds: Array[HBAUtilityClass.Bond] = []
	# 1. Define Atoms
	for pdb_atom in out_atoms:
		assert(pdb_atom.valence_state != PdbAtom.ValenceState.UNKNOWN)
		if pdb_atom.valence_state == PdbAtom.ValenceState.COMPLETE:
			continue
		pdb_atoms[pdb_atom.pdb_id] = pdb_atom
		var atom := HBAUtilityClass.Atom.new(
			pdb_atom.position * _ANGSTROM_TO_NANOMETER,
			pdb_atom.element_name.capitalize()
		)
		autobonder_atoms[atom] = pdb_atom
		in_atoms.push_back(atom)
	# 2. Define existing Bonds
	for pdb_atom in autobonder_atoms.values():
		for conn in pdb_atom.connections:
			var min_atom_id: int = min(conn.atom_id, pdb_atom.pdb_id)
			var max_atom_id: int = max(conn.atom_id, pdb_atom.pdb_id)
			var normalized_bond_id := Vector2i(min_atom_id, max_atom_id)
			if autobonder_bonds.find_key(normalized_bond_id):
				# Was already added by the other atom_id
				continue
			var atom1: HBAUtilityClass.Atom = autobonder_atoms.find_key(pdb_atoms.get(min_atom_id, null))
			var atom2: HBAUtilityClass.Atom = autobonder_atoms.find_key(pdb_atoms.get(max_atom_id, null))
			if atom1 == null:
				atom2.unspecified_bond_count += 1
				continue
			elif atom2 == null:
				atom1.unspecified_bond_count += 1
				continue
			var bond := HBAUtilityClass.Bond.new(
				atom1, atom2
			)
			autobonder_bonds[bond] = normalized_bond_id
			in_bonds.push_back(bond)
	# Project singletons cannot be referenced from ResourceFormatLoader
	# because of that we get access to the autoload on demand using the nodepath
	var utility: HBAUtilityClass = Engine.get_main_loop().root.get_node("HeuristicBondAssignmentUtility")
	assert(utility != null, "HeuristicBondAssignmentUtility could not be found")
	var bond_candidates: Array[HBAUtilityClass.Bond] = \
			utility.heuristic_bond_assignment(in_atoms, in_bonds)
	for bond in bond_candidates:
		var is_new: bool = not autobonder_bonds.has(bond)
		if is_new:
			var atom_id1: PdbAtom = autobonder_atoms[bond.atoms[0]]
			var atom_id2: PdbAtom = autobonder_atoms[bond.atoms[1]]
			_connect_atoms(atom_id1, atom_id2, false)


var nmb_of_connections = 0
func _connect_atoms(in_first_atom: PdbAtom, in_second_atom: PdbAtom, double: bool = false):
	assert(in_first_atom != in_second_atom) 
	
	if in_second_atom == null:
		return
	
	if not in_first_atom.has_connection_to_atom(in_second_atom.pdb_id):
		in_first_atom.add_connection(in_second_atom.pdb_id, double)
		nmb_of_connections+=1
		return

static func _get_periodic_table_instance() -> Node:
	if PeriodicTableInstance == null:
		PeriodicTableInstance = Engine.get_main_loop().root.get_node("PeriodicTable")
	return PeriodicTableInstance

class Residue:
	var id: int = -1
	var atoms: Array[PdbAtom] = []

	
	func _init(in_id: int) -> void:
		id = in_id

class Chain:
	var name: String
	var residues: Array[Residue]
	
	func _init(in_name: String):
		name = in_name
