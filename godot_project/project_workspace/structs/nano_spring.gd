class_name NanoSpring extends Resource

@export var constant_force: float = 500.0 # nN/nm
@export var equilibrium_length_is_auto: bool = true
@export var equilibrium_manual_length: float = 1.0
@export var target_atom: int
@export var target_atom2: int = -1
@export var target_anchor: int
var anchor_is_visible: bool = true


func is_atom_to_atom() -> bool:
	return target_atom2 != -1


static func create(in_taget_anchor: int, in_target_atom:int, in_spring_constant_force: float,
			is_equilibrium_length_automatic: bool, in_equilibrium_manual_length: float) -> NanoSpring:
	var nano_spring: NanoSpring = NanoSpring.new()
	nano_spring.target_anchor = in_taget_anchor
	nano_spring.target_atom = in_target_atom
	nano_spring.target_atom2 = AtomicStructure.INVALID_ATOMIC_NUMBER
	nano_spring.constant_force = in_spring_constant_force
	nano_spring.equilibrium_length_is_auto = is_equilibrium_length_automatic
	nano_spring.equilibrium_manual_length = in_equilibrium_manual_length
	return nano_spring


static func create_between_atoms(in_atom_id_1: int, in_atom_id_2: int, in_spring_constant_force: float,
			is_equilibrium_length_automatic: bool, in_equilibrium_manual_length: float) -> NanoSpring:
	var nano_spring: NanoSpring = NanoSpring.new()
	nano_spring.target_atom = min(in_atom_id_1, in_atom_id_2)
	nano_spring.target_atom2 = max(in_atom_id_1, in_atom_id_2)
	nano_spring.target_anchor = Workspace.INVALID_OBJECT_INDEX
	nano_spring.constant_force = in_spring_constant_force
	nano_spring.equilibrium_length_is_auto = is_equilibrium_length_automatic
	nano_spring.equilibrium_manual_length = in_equilibrium_manual_length
	return nano_spring
