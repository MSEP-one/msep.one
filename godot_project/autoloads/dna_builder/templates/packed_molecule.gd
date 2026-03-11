extends Resource
## Atoms data packed as follows: xyz as the position, w as the atomic number
@export var atoms: PackedVector4Array
## Bonds data packed as follows: x and y as atom indexes, z as bond order
@export var bonds: Array[Vector3i]

@export var base_to_backbone_atom_id: int = -1
@export var next_backbone_atom_id: int = -1
@export var previous_backbone_atom_id: int = -1
@export var hydrogen_bonds: PackedInt32Array
@export var sugar_atoms: PackedInt32Array
@export var major_groove_atoms: PackedInt32Array
