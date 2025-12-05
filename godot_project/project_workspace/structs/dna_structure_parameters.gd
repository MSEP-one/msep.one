class_name DnaStructureParameters extends Resource


enum StrandPolicy {
	A,
	B,
	DOUBLE
}


var bases_per_turn: float = 10.0
var rise_nanometers: float = 0.34
var dna_radius_nanometers: float = 1.0
var initial_twist_rad: float = 0.0
var strand_policy:= StrandPolicy.DOUBLE
var include_hydrogens: bool = true


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = {}
	state_snapshot["bases_per_turn"] = bases_per_turn
	state_snapshot["rise_nanometers"] = rise_nanometers
	state_snapshot["dna_radius_nanometers"] = dna_radius_nanometers
	state_snapshot["initial_twist_rad"] = initial_twist_rad
	state_snapshot["strand_policy"] = strand_policy
	state_snapshot["include_hydrogens"] = include_hydrogens
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	bases_per_turn = in_state_snapshot["bases_per_turn"]
	rise_nanometers = in_state_snapshot["rise_nanometers"]
	dna_radius_nanometers = in_state_snapshot["dna_radius_nanometers"]
	initial_twist_rad = in_state_snapshot["initial_twist_rad"]
	strand_policy = in_state_snapshot["strand_policy"]
	include_hydrogens = in_state_snapshot["include_hydrogens"]
