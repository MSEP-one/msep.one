class_name HAtomsEmptyValenceDirections extends RefCounted


## Functions for calculating directions for bonds to an atom with empty valence locations.
## They cover the cases of 0, 1, 2, and 3 existing bonds, and account for various atom types
## that define valence and geometry. In case 1, an optional additional atom defines a
## reference direction for choosing a torsion angle (by "pushing atoms away"); in case 2,
## an optional additional atom defines a choice of two bond directions in a pyramidal geometry
## (by "pushing the atom away"). In case 0, a dummy atom is added, then the case 2 function is applied.
## [br][br]
## The functions return unit direction-vectors. Applications include adding hydrogens and
## displaying ghost atoms to enable users to place other kinds of atoms in realistic geometries.
## [br][br]
## As written, this code requires a "table_of_valences" that maps atom_type to integers and a
## "table_of_geometries" that maps atom_type to one of "none", "sp1", "sp2", or "tetra"
## (where the latter usually means sp3 hybridization, but extensions to hypervalent sulfur
## and phosphorus would also be tetrahedral without being sp3).[br]
## - The geometry "none" describes (for example) helium, argon, chloride ions, and sodium ions.[br]
## - The geometry "sp1" applies to triple-bonded carbon and nitrogen.[br]
## - "sp2" applies to double-bonded carbon and nitrogen.[br]
## - Hydroxyl and amine groups count as "tetra" here, which makes sense if we think of lone pairs
## as being like atoms, but otherwise looks like a confusing name.[br]
## - Most angles will be only approximate, but roughly correct. Greater accuracy would require a
## table that maps triples of atoms to angles, which is necessary for molecular mechanics but ignored here.


## This table shows how many electrons are required to each non metal to reach stability
const TABLE_OF_VALENCES: Dictionary = {
	&"dummy" : 0,
	&"H"  : 1,
	&"C"  : 4,
	&"N"  : 3,
	&"O"  : 2,
	&"F"  : 1,
	&"Si" : 4,
	&"P"  : 3,
	&"S"  : 2,
	&"Cl" : 1
}

## Known geometries
const Geometries: Dictionary = {
	NONE = "none",
	SP1 = "sp1",
	SP2 = "sp2",
	TETRA = "tetra"
}

## Table of geometries has the default geometry used to complete each atom type
## under the assumption all the bound atoms around it are of order 1
## When this is not the case, the geometry member needs to be changed manually
## to match the expected result before calling fill_valence_from_X method
const TABLE_OF_GEOMETRIES: Dictionary = {
	&"dummy": Geometries.NONE,
	&"H"    : Geometries.NONE,
	&"C"    : Geometries.TETRA,
	&"N"    : Geometries.SP2,
	&"O"    : Geometries.SP1,
	&"F"    : Geometries.NONE,
	&"Si"   : Geometries.TETRA,
	&"P"    : Geometries.SP2,
	&"S"    : Geometries.SP1,
	&"Cl"   : Geometries.NONE
}

## Atom is a collection representing a particle, at least a position and type
## is required, but after it's creation the valence and geometry can be changed
## depending on the special cases of the system (double or triple bonds afects
## valence and geometry)
class Atom:
	## The position of this Atom
	var position: Vector3
	## Periodic Table Symbol representing this element
	var atom_type: String
	## The number of hydrogens required to reach stability
	var valence: int
	## The shape this Atom wants to arrange it's neighbors, based on valence and
	## order of known covalent bonds
	var geometry: String

	func _init(in_position: Vector3, in_atom_type: String) -> void:
		self.position = in_position
		self.atom_type = in_atom_type
		# Lookup valence in the table of valences using atom-type as a key
		# fallsback to 0 if non a NON-METALLIC atom
		self.valence = TABLE_OF_VALENCES.get(atom_type, 0)
		# Lookup geometry in the table of geometries using atom-type as a key
		# fallsback to NONE if non a NON-METALLIC atom
		self.geometry = TABLE_OF_GEOMETRIES.get(atom_type, Geometries.NONE)


## Given an atom without known neighbors, find all missing hydrogens directions
## [codeblock]
## Args:
##     atom0: (Atom): The atom to add hydrogens to.
## Returns:
##     PackedVector3Array: normalized directions in which to distribute hydrogens for
##                         a physically realistic atomic distribution
## [/codeblock]
static func fill_valence_from_0(atom0: Atom) -> PackedVector3Array:
	var valence: int= atom0.valence

	if valence == 0:
		return []

	var offset_direction := Vector3(1, 1, 1.5).normalized()    # Likely to make all bonds visible
	var dummy_atom := Atom.new(atom0.position + offset_direction, "dummy")
	var directions: PackedVector3Array = [offset_direction]
	directions.append_array(fill_valence_from_1(atom0, dummy_atom))
	return directions

## Given an atom and 1 known neighbor, find all missing hydrogens directions.
## An optional third atom, bound to the neighbor, but not to the target atom0 can be
## passed to find the best direction caused by each other repullsion
## [codeblock]
## Args:
##     atom0: (Atom): The atom to add hydrogens to.
##     atom1: (Atom): The known neighbor
##     atomT: (Atom)[Optional]: An atom bound to atom1, used for torsion calculation
## Returns:
##     PackedVector3Array: normalized directions in which to distribute hydrogens for
##                         a physically realistic atomic distribution
## [/codeblock]
static func fill_valence_from_1(atom0: Atom, atom1: Atom, atomT: Atom = null) -> PackedVector3Array:
	var bond_vector: Vector3 = atom1.position - atom0.position
	if is_equal_approx(bond_vector.length(), 0):
		push_error("Zero-length bond vector.")
	var bond_direction: Vector3 = bond_vector.normalized()
	var valence: int = atom0.valence
	var geometry: String = atom0.geometry

	if valence <= 1:
		return []
	
	if geometry == "sp1":  # Case 1+1 sp1: bond direction aligned with the given bond (= -bond_direction)
		return [-bond_direction]

	var torsion_reference: Vector3 = HAtomsEmptyValenceDirections._torsion_reference_direction(atom0, atom1, atomT)
	var bond_angle: float = deg_to_rad(120) if geometry == "sp2" else deg_to_rad(109.5)
	var first_bond_direction: Vector3 = cos(bond_angle) * bond_direction - sin(bond_angle) * torsion_reference

	if valence == 2 and geometry == "sp2":    # Case 1+1 sp2: single bond direction at 120° to bond_direction
		return [first_bond_direction]

	if valence == 2 and geometry =="tetra":   # Case 1+1 tetra: single bond direction at 109.5° to bond_direction
		return [first_bond_direction]

	if valence == 3 and geometry == "sp2":    # Case 1+2 sp2: two bond directions, all angles = 120°
		var second_bond_direction: Vector3 = cos(bond_angle) * bond_direction + sin(bond_angle) * torsion_reference
		return [first_bond_direction, second_bond_direction]

	if valence == 3 and geometry == "tetra":  # Case 1+2 tetra: two bond directions, angles = 109.5° to bond_direction
		var q_plus := Quaternion(bond_direction, deg_to_rad(60))
		var q_minus := Quaternion(bond_direction, deg_to_rad(-60))
		var second_bond_direction: Vector3 = q_plus * first_bond_direction
		var third_bond_direction: Vector3 = q_minus * first_bond_direction
		return [second_bond_direction, third_bond_direction]

	if valence == 4 and geometry == "tetra":  # Case 1+3 tetra: three bond directions, all angles = 109.5°
		var q_twice := Quaternion(bond_direction, deg_to_rad(120))
		var second_bond_direction: Vector3 = q_twice * first_bond_direction
		var third_bond_direction: Vector3 = q_twice * second_bond_direction
		return [first_bond_direction, second_bond_direction, third_bond_direction]

	push_error("Invalid geometry or valence for atom0")
	return []

## Given an atom and 2 known neighbors, find all missing hydrogens directions.
## An optional fourth atom, bound to one of the neighbors, but not to the target atom0 can be
## passed to find the best direction caused by each other repullsion
## [codeblock]
## Args:
##     atom0: (Atom): The atom to add hydrogens to.
##     atom1: (Atom): A known neighbor
##     atom2: (Atom): Another known neighbor
##     atomP: (Atom)[Optional]: An atom bound to atom1, or atom2; used for torsion calculation
## Returns:
##     PackedVector3Array: normalized directions in which to distribute hydrogens for
##                         a physically realistic atomic distribution
## [/codeblock]
static func fill_valence_from_2(atom0: Atom, atom1: Atom, atom2: Atom, atomP: Atom = null) -> PackedVector3Array:
	var valence: int = atom0.valence
	var geometry: String = atom0.geometry

	if valence <= 2:
		return []

	var bond_direction1: Vector3 = (atom1.position - atom0.position).normalized()
	var bond_direction2: Vector3 = (atom2.position - atom0.position).normalized()

	var norm_cross_product: Vector3 = (bond_direction1.cross(bond_direction2)).normalized()

	# For use in the next three cases:
	var outward_direction: Vector3 = -(bond_direction1 + bond_direction2).normalized()
	if outward_direction.length() == 0:
		# Outward direction cannot have zero lenght, let's randomize it
		# 1. Make outward direction perpendicular to bond_direction1 and bond_direction2
		if abs(bond_direction2) == Vector3.UP:
			# When bonds are perfectly paralell to UP we use cross product to RIGHT
			outward_direction = bond_direction1.cross(Vector3.RIGHT)
		else:
			# Otherwise we can use cross product to UP
			outward_direction = bond_direction1.cross(Vector3.UP)
		# 2. Randomize direction by rotating the vector by a random angle
		outward_direction.rotated(bond_direction1, randf())

	# Case 2+1 sp2, valence = 3: one bond directed away from two input bonds
	if geometry == "sp2" and valence == 3:
		return [outward_direction]

	# For use in the next two cases:
	var angle: float = deg_to_rad(109.5 / 2)
	var direction1: Vector3 = cos(angle) * outward_direction + sin(angle) * norm_cross_product
	var direction2: Vector3 = cos(angle) * outward_direction - sin(angle) * norm_cross_product

	# Case 2+1 tetra, valence = 3: one bond directed away from two input bonds but out of plane
	if geometry == "tetra" and valence == 3:
		var pyramid_vector: Vector3 = -norm_cross_product
		if atomP == null:
			pyramid_vector = norm_cross_product  # In effect a random choice
		elif ((atomP.position - atom0.position).normalized()).dot(norm_cross_product) > 0:
			pyramid_vector = norm_cross_product

		return [direction2] if direction1.dot(pyramid_vector) > 0 else [direction1]

	# Case 2+2 tetra valence = 4: two bonds directed away from two input bonds but above and below plane
	if geometry == "tetra" and valence == 4:
		return [direction1, direction2]

	push_error("Invalid geometry or valence for atom0")
	return []


## Given an atom and 3 known neighbors, find the missing hydrogens directions, if exists
## [codeblock]
## Args:
##     atom0: (Atom): The atom to add hydrogens to.
##     atom1: (Atom): A known neighbor
##     atom2: (Atom): A second known neighbor
##     atom3: (Atom): A third known neighbor
## Returns:
##     PackedVector3Array: normalized directions to place a missing hydrogen, or emty is not needed
## [/codeblock]
static func fill_valence_from_3(atom0: Atom, atom1: Atom, atom2: Atom, atom3: Atom) -> PackedVector3Array:
	var valence: int = atom0.valence
	var geometry: String = atom0.geometry

	if valence <= 3:
		return []

	if valence == 4 and geometry == "tetra":
		var bond_direction1: Vector3 = (atom1.position - atom0.position).normalized()
		var bond_direction2: Vector3 = (atom2.position - atom0.position).normalized()
		var bond_direction3: Vector3 = (atom3.position - atom0.position).normalized()

		# Case 3+1: one bond directed away from three input bonds
		var outward_direction: Vector3 = -(bond_direction1 + bond_direction2 + bond_direction3).normalized()
		if outward_direction.length() == 0:
			push_error("Outward direction has zero length")

		return [outward_direction]

	push_error("Invalid geometry or valence for atom0")
	return []


static func _torsion_reference_direction(atom0: Atom, atom1: Atom, atomT: Atom = null) -> Vector3:
	var bond_vector: Vector3 = atom1.position - atom0.position
	var plane_defining_vector := Vector3.ZERO
	if atomT != null:
		var atomT_vector: Vector3 = atomT.position - atom1.position
		if not is_equal_approx(atomT_vector.length(), 0) and not is_equal_approx(abs(atomT_vector.normalized().dot(bond_vector.normalized())), 1.0):
			# Find a vector perpendicular to the bond vector in the bond - atomT plane
			plane_defining_vector = (atomT_vector - atomT_vector.project(bond_vector)).normalized()
	if plane_defining_vector == Vector3.ZERO:
		var up: Vector3 = Vector3(1, 0, 0) if not (bond_vector.normalized().dot(Vector3(1, 0, 0)) > 0.4) else Vector3(0, 1, 0)
		plane_defining_vector = bond_vector.cross(up)
	var orthogonalized_plane_defining_vector: Vector3 = (plane_defining_vector - bond_vector * (bond_vector.dot(plane_defining_vector))).normalized()
	return orthogonalized_plane_defining_vector
