class_name NanoAtomLegacy extends Resource


@export var valid := true
@export var atomic_number: int = 6
@export var position := Vector3.ZERO
@export var bonds_ids: PackedInt32Array = []
@export var invalid_bonds_ids: PackedInt32Array = []


static func create(in_atomic_number: int, in_position: Vector3, in_valid: bool = true) -> NanoAtomLegacy:
	var atom := NanoAtomLegacy.new()
	atom.valid = in_valid
	atom.atomic_number = in_atomic_number
	atom.position = in_position
	return atom


func create_duplicate() -> NanoAtomLegacy:
	var copy: NanoAtomLegacy = NanoAtomLegacy.new()
	copy.bonds_ids = bonds_ids.duplicate()
	copy.invalid_bonds_ids = invalid_bonds_ids.duplicate()
	copy.valid = valid
	copy.atomic_number = atomic_number
	copy.position = position
	return copy

func create_state_snapshot() -> Dictionary:
	return {
		"valid" : valid,
		"atomic_number" : atomic_number,
		"position" : position,
		"bonds_ids" : bonds_ids.duplicate(),
		"invalid_bonds_ids" : invalid_bonds_ids.duplicate()
	}

#func apply
