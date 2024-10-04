class_name PdbAtom extends RefCounted

enum ValenceState {
	UNKNOWN,
	INCOMPLETE,
	COMPLETE_WITH_INCOMPLETE_NEIGHBOR,
	COMPLETE
}

var pdb_id: int = 0
var name: String
var residue: String
var chain: String
var residue_id: int
var position: Vector3
var occupancy: float
var temperature_factor: float
var element_name: String
var connections: Array
var valence: int
var has_valence_incomplete_neighbor: float = false
var valence_state: ValenceState = ValenceState.UNKNOWN:
	get = _get_valence_state

func duplicate() -> PdbAtom:
	var dup := PdbAtom.new()
	dup.pdb_id = pdb_id
	dup.name = name
	dup.residue = residue
	dup.chain = chain
	dup.residue_id = residue_id
	dup.position = position
	dup.occupancy = occupancy
	dup.temperature_factor = temperature_factor
	dup.element_name = element_name
	for connection in connections:
		dup.connections.append(connection.duplicate())
	dup.valence_state = valence_state
	return dup


func get_pdb_id() -> int:
	return pdb_id


func add_connection(atom_id_to_connect: int, double: bool = false):
	var conn = Connection.new()
	conn.atom_id = atom_id_to_connect
	conn.double_connection = double
	connections.append(conn)
	valence_state = ValenceState.UNKNOWN
	

func has_connection_to_atom(in_atom_id: int) -> bool:
	for connection in connections:
		if connection.atom_id == in_atom_id:
			return true
	return false

func _get_valence_state() -> ValenceState:
	if valence_state == ValenceState.COMPLETE and has_valence_incomplete_neighbor:
		return ValenceState.COMPLETE_WITH_INCOMPLETE_NEIGHBOR
	return valence_state

class Connection:
	var atom_id: int
	var double_connection = false
	
	func duplicate() -> Connection:
		var new_con = Connection.new()
		new_con.atom_id = atom_id
		new_con.double_connection = double_connection
		return new_con
