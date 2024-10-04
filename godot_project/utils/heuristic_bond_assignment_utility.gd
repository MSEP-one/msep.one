@tool
extends Node

## 
## Heuristic Bond Assignment Algorithm [br] [br]
## [color=green]Problem Statement:[/color] [br]
## Given a set of atoms and bonds, add missing bonds that will not result in
## excessive strain energy when the structure is relaxed. This heuristic algorithm takes account
## of both bond lengths and angles, and as a consequence, it can assign plausible bonds in
## highly distorted structures. It contains several adjustable parameters.
## [br] [br]
## [color=green]Algorithm Overview (GPT-4 summary):[/color]
## [codeblock]
##  1   Constants: Tables of atom types, maximum bond numbers, reference bond lengths, and
##              heuristic constants for bond length and angle cutoffs and costs.
##  2   Objects: "atom", "bond", "atomic node", and "link" objects are used to store information.
##  3   Inputs: A collection of atoms and a collection of bonds.
##  4   Outputs: An updated collection of bonds.
##  5   Initialization: Initialize a collection of nodes, map atoms to nodes, add input bonds
##              to nodes, and copy input bonds to output bonds.
##  6   Creating a priority queue of links: Examine all pairs of nodes and create candidate bonds
##              based on distance. Initialize links with a bond, bond length, acceptance cost,
##              and validity flag. Load links into a priority queue.
##  7   Accepting and rejecting links: Pop links from the priority queue, accept valid links,
##              and add their bonds to the output bonds. Update bond lists and links in
##              neighboring (bonded) nodes, and update the acceptance costs and validity
##              of remaining links.
##  8   Updating link (candidate bond) acceptance cost and validity: Calculate the acceptance
##              cost based on length cost and angle costs, and update the link's position in the
##              priority queue. Set the link's validity flag based on bond angles and bond lengths.
##  9   Termination: Return the list of bonds when the priority queue is empty.
## [/codeblock]
## [br] [br]
## [color=green]Discussion:[/color][br]
## The bond assignment algorithm adds bonds to a set of atoms in a best-first order, discarding
## candidate bonds that violate geometric criteria. It operates on lists of simple atom and
## bond objects and returns a list of bonds. Pairs of proximate unbonded atoms form candidate
## bonds. The algorithm wraps atoms and candidate bonds in node and link objects that carry
## bookkeeping information: Nodes contain and atom and lists of links and bonds, links contain
## a bond object, a bond length, an acceptance cost, and a validity flag. Geometric
## considerations determine bond validity (does it violate a criterion?) and acceptance cost
## (how badly does the bond fit the structure?). Adding a bond between atoms updates their bond
## geometry and the validity and acceptance costs of links to the atom's node. A priority queue
## keeps track of changing priorities (acceptance costs) and supports the best-first strategy

# Basic object definitions
class Atom:
	var position: Vector3
	var atom_type: String
	var unspecified_bond_count: int
	
	func _init(in_position: Vector3, in_atom_type: String, in_unspecified_bond_count: int = 0) -> void:
		self.position = in_position
		self.atom_type = in_atom_type
		self.unspecified_bond_count = in_unspecified_bond_count

class Bond:
	var atoms: Array[Atom]
	
	func _init(atom1: Atom, atom2: Atom) -> void:
		self.atoms = [atom1, atom2]

	func other_atom(atom: Atom) -> Atom:
		return self.atoms[1] if atom == self.atoms[0] else self.atoms[0]

class AtomicNode:
	var atom: Atom
	var bonds: Array[Bond]
	var links: Array[Link]
	var bonds_count: int:
		get:
			return len(bonds) + atom.unspecified_bond_count
	
	func _init(in_atom: Atom, in_bonds: Array[Bond], in_links: Array[Link]) -> void:
		self.atom = in_atom
		self.bonds = in_bonds
		self.links = in_links

class Link:
	var bond: Bond
	var length: float
	var acceptance_cost: float
	var is_valid: bool
	
	func _init(in_bond: Bond, in_length: float, in_acceptance_cost: float, in_is_valid: bool) -> void:
		self.bond = in_bond
		self.length = in_length
		assert(!is_nan(in_acceptance_cost))
		self.acceptance_cost = in_acceptance_cost
		self.is_valid = in_is_valid


# Constants

# A table of atom types assigns a maximum bond number to each type
const MAX_BOND_NUMBERS: Dictionary = {
	"H":  1,
	"C":  4,
	"N":  3,
	"O":  2,
	"F":  1,
	"Si": 4,
	"P":  3,
	"S":  2,
	"Cl": 1,
	# Add more atom types as needed
}

const ANGSTRONGS_TO_NANOMETERS: float = 1.0 / 10.0
# A table assigns a reference bond length to each pair of atom types
var REFERENCE_BOND_LENGTHS: Dictionary = {
	# Equal Pairs
	["H", "H"]: (0.74) * ANGSTRONGS_TO_NANOMETERS,
	["C", "C"]: (1.54) * ANGSTRONGS_TO_NANOMETERS,
	["N", "N"]: (1.45) * ANGSTRONGS_TO_NANOMETERS,
	["O", "O"]: (1.48) * ANGSTRONGS_TO_NANOMETERS,
	["F", "F"]: (1.42) * ANGSTRONGS_TO_NANOMETERS,
	["Si","Si"]: (1.48) * ANGSTRONGS_TO_NANOMETERS,
	["P", "P"]: (2.20) * ANGSTRONGS_TO_NANOMETERS,
	["S", "S"]: (2.06) * ANGSTRONGS_TO_NANOMETERS,
	["Cl","Cl"]: (1.99) * ANGSTRONGS_TO_NANOMETERS,
	# Hydrogen to others
	["H", "C"]: (0.74 * 0.5 + 1.54 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H", "N"]: (0.74 * 0.5 + 1.45 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H", "O"]: (0.74 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["F", "F"]: (0.74 * 0.5 + 1.42 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H","Si"]: (0.74 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H", "P"]: (0.74 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H", "S"]: (0.74 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["H","Cl"]: (0.74 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Carboon to others
	["C", "N"]: (1.54 * 0.5 + 1.45 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C", "O"]: (1.54 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C", "F"]: (1.54 * 0.5 + 1.42 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C","Si"]: (1.54 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C", "P"]: (1.54 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C", "S"]: (1.54 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["C","Cl"]: (1.54 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Nytrogen to others
	["N", "O"]: (1.45 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["N", "F"]: (1.45 * 0.5 + 1.42 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["N","Si"]: (1.45 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["N", "P"]: (1.45 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["N", "S"]: (1.45 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["N","Cl"]: (1.45 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Oxigen to others
	["O", "F"]: (1.48 * 0.5 + 1.42 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["O","Si"]: (1.48 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["O", "P"]: (1.48 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["O", "S"]: (1.48 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["O","Cl"]: (1.48 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Flourine to others
	["F","Si"]: (1.42 * 0.5 + 1.48 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["F", "P"]: (1.42 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["F", "S"]: (1.42 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["F","Cl"]: (1.42 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Silicon to others
	["Si", "P"]: (1.48 * 0.5 + 2.20 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["Si", "S"]: (1.48 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["Si","Cl"]: (1.48 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Phosphorus to others
	["P", "S"]: (2.20 * 0.5 + 2.06 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	["P","Cl"]: (2.20 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Sulfur to others
	["S","Cl"]: (2.06 * 0.5 + 1.99 * 0.5) * ANGSTRONGS_TO_NANOMETERS,
	# Add more pairs of atom types as needed
}

func _init() -> void:
	# Each pair of atom types is assigned a reference bond length
	for atom_pair: Array in REFERENCE_BOND_LENGTHS.keys():
		var atom1: String = atom_pair[0]
		var atom2: String = atom_pair[1]
		if [atom2, atom1] not in REFERENCE_BOND_LENGTHS.keys():
			REFERENCE_BOND_LENGTHS[[atom2, atom1]] = REFERENCE_BOND_LENGTHS[atom_pair]

# Heuristic constants are used to determine bond length and angle cutoffs and costs
var MAX_LENGTH_FACTOR: float  = 3.0   # 3 * bond-length is too long
var TINY_LENGTH_FACTOR: float = 0.3   # must be longer to strongly indicate bond direction
var LENGTH_COST_FACTOR: float = 1.0   # cost = 1.0 * (3 - 1)^2 = 4.0 at max length
var SHORT_DIST_PREF: float    = 0.1   # cost = 0.1 at reference bond length
var ANGLE_COST_FACTOR: float  = 0.001 # cost = 0.001 * (109.5 - 40)^2 ≈ 4.8 at min angle
var MIN_ANGLE: float          = 40.0  # 40°is too small
var COMMON_ANGLE: float       = 109.5 # ≥ tetrahedral angle is OK


## This function initializes a dictionary that maps atoms to nodes and creates a list of output bonds. 
## It iterates over the input atoms, creating a AtomicNode object for each atom and adding it to the dictionary. 
## Then, it iterates over the input bonds, updating the bond lists of the corresponding AtomicNode objects.
## [codeblock]
## Args:
##     atoms (Array): A list of Atom objects representing the input atoms.
##     bonds (Array): A list of Bond objects representing the input bonds.
## Returns:
##     Dictionary: A dictionary containing the mapping of atoms to nodes and a list of output bonds (a copy of the input bonds).
## [/codeblock]
func initialize_nodes(atoms: Array[Atom], bonds: Array[Bond]) -> Dictionary:
	var atom_to_node: Dictionary = {}
	var output_bonds: Array[Bond] = bonds.duplicate()
	var neighborhoods: Dictionary = {
		#center:Vector3 = neighborhood:Neighborhood
	}
	
	for atom in atoms:
		var node := AtomicNode.new(atom, [], [])
		atom_to_node[atom] = node
		var neighborhood_center: Vector3 = snapped(atom.position, Vector3.ONE * Neighborhood.RESIDENCE_SIZE)
		if not neighborhoods.has(neighborhood_center):
			neighborhoods[neighborhood_center] = Neighborhood.new(neighborhood_center)
		for n: Neighborhood in neighborhoods.values():
			n.add_if_neighbor(node)

	for bond in bonds:
		var atom1: Atom = bond.atoms[0]
		var atom2: Atom = bond.atoms[1]
		var node1: AtomicNode = atom_to_node[atom1]
		var node2: AtomicNode = atom_to_node[atom2]
		
		node1.bonds.append(bond)
		node2.bonds.append(bond)

	return {
				"atom_to_node": atom_to_node,
				"neighborhoods" : neighborhoods.values(),
				"output_bonds": output_bonds,
			}


# Indexed priority queue object

class IndexedPriorityQueue:
	var elements: Array = [
		# Array([priority: float, item: Variant])
	]
	var index: Dictionary = {
		# item:variant = priority:float
	}
	var is_batching: bool = false

	func _init() -> void:
		pass

	func is_empty() -> bool:
		return elements.size() == 0

	func start_batch_operation() -> void:
		is_batching = true
	
	func end_batch_operation() -> void:
		if is_batching:
			elements.sort()
		is_batching = false
	
	func put(item: Variant, priority: float) -> void:
		if item in index:
			update(item, priority)
		else:
			elements.append([priority, item])
			if !is_batching:
				elements.sort()
			index[item] = priority

	func pop() -> Variant:
		var priority_item: Array = elements.pop_front() #Array[float,Variant]
		var item: Variant = priority_item[1]
		index.erase(item)
		return item

	func update(item: Variant, new_priority: float) -> void:
		var old_priority: float = index[item]
		elements.erase([old_priority, item])
		elements.append([new_priority, item])
		if !is_batching:
			elements.sort()
		index[item] = new_priority

## This function creates an array of objects that can be used as a key for a dictionary.[br]
## Because arrays are only equal when the order matches, when asigning and reading an [Array] key in
## a [Dictionary], in order to get and replace the right value, the order of members should match.
## Using this method when passing an array as key of a dictionary makes sure the objects inside the
## Array are always in the same order, because they are sorted by instance id. 
## [codeblock]
## Args:
##     in_set (Array): A list of objects
## Returns:
##     Array: A copy of the input list of objects sorted by instance id
## [/codeblock]
func frozenset(in_set: Array[Atom]) -> Array[Atom]:
	var new_set: Array[Atom] = in_set.duplicate()
	new_set.sort_custom(_sort_frozen_set)
	return new_set

func _sort_frozen_set(a: Atom, b: Atom) -> bool:
	return a.get_instance_id() > b.get_instance_id()


## Create a priority queue of links by examining all pairs of nodes and initializing links based on their
## distance and reference length. Update links' acceptance conditions and add links to the nodes and
## priority queue.
## [codeblock]
## Args:
##     nodes (Dictionary): A dictionary mapping atoms to their corresponding nodes.
##     input_bonds (Array[Bond]): A list of input bonds.
##     neighborhoods: (Array[Neighborhood])
## Returns:
##     IndexedPriorityQueue: A priority queue containing links sorted by their acceptance costs.
## [/codeblock]
func create_priority_queue(nodes: Dictionary, input_bonds: Array[Bond], neighborhoods: Array) -> IndexedPriorityQueue:
	var input_bonds_set: Dictionary = {
		#frozenset[atoms] = true
	}
	for bond in input_bonds:
		input_bonds_set[frozenset(bond.atoms)] = true
	var priority_queue: IndexedPriorityQueue = IndexedPriorityQueue.new()
	priority_queue.start_batch_operation()
	for nhood: Neighborhood in neighborhoods:
		for i in range(len(nhood.residents) - 1):
			var node1: AtomicNode = nhood.residents[i]
			for j in range(i + 1, len(nhood.residents)):
				var node2: AtomicNode = nhood.residents[j]
				_evaluate_and_create_link(nodes, node1, node2, input_bonds_set, priority_queue)
			for neighbor_node in nhood.neighbors:
				_evaluate_and_create_link(nodes, node1, neighbor_node, input_bonds_set, priority_queue)
	priority_queue.end_batch_operation()
	return priority_queue


func _evaluate_and_create_link(
			nodes: Dictionary, node1: AtomicNode, node2: AtomicNode,
			input_bonds_set: Dictionary, priority_queue: IndexedPriorityQueue) -> void:
	var atom1: Atom = node1.atom
	var atom2: Atom = node2.atom
	var actual_length_squared: float = atom1.position.distance_squared_to(atom2.position)
	
	var atom_pair: Array = [atom1.atom_type, atom2.atom_type]
	if not REFERENCE_BOND_LENGTHS.has(atom_pair):
		return
	
	if actual_length_squared < MAX_LENGTH_FACTOR * (REFERENCE_BOND_LENGTHS[atom_pair] ** 2):
		var bond_key: Array[Atom] = frozenset([atom1, atom2])

		if not input_bonds_set.has(bond_key):
			var bond: Bond = Bond.new(atom1, atom2)
			var link: Link = Link.new(bond, sqrt(actual_length_squared), 0, true)
			update_link_acceptance_conditions_and_cost(link, nodes)
			if link.is_valid:
				node1.links.append(link)
				node2.links.append(link)
				priority_queue.put(link, link.acceptance_cost)
				input_bonds_set[bond_key] = true

## Calculate the angle (in degrees) between three points in 3D space.
## [codeblock]
## Args:
##     position1: A Vector3 representing the x, y, and z coordinates of the first point.
##     position2: A Vector3 representing the x, y, and z coordinates of the second point.
##     position3: A Vector3 representing the x, y, and z coordinates of the third point.
## Returns:
##     float: The angle in degrees between the three points as a float value, being
##            position2 the wedge of the angle
## [/codeblock]
func calculate_angle(position1: Vector3, position2: Vector3, position3: Vector3) -> float:
	var vector1: Vector3 = position1 - position2
	var vector2: Vector3 = position3 - position2

	return rad_to_deg(vector1.angle_to(vector2))

# Acceptance cost and validity calculations

## Check for max bond number constraint violation.
## [codeblock]
## Args:
##     link0 (Link): The link to be checked.
##     nodes (Dictionary): A dictionary mapping atoms to their corresponding nodes.
## Returns:
##     bool: true if the Link (bond candidate) does not exceed the limit of allowed bonds in the atom
## [/codeblock]
func check_max_bond_number_violation(link0: Link, nodes: Dictionary) -> bool:
	var atom1: Atom = link0.bond.atoms [0]
	var atom2: Atom = link0.bond.atoms [1]
	var node1: AtomicNode = nodes[atom1]
	var node2: AtomicNode = nodes[atom2]

	if node1.bonds_count >= MAX_BOND_NUMBERS[atom1.atom_type] or node2.bonds_count >= MAX_BOND_NUMBERS[atom2.atom_type]:
		return true
	return false


## Calculate the length costs for a given link.
## [codeblock]
## Args:
##     link0 (Link): The link for which angle costs are to be calculated.
##     atom_type_pair (Array[String]): a pair of strings containing the atom_type of both atoms
## Returns:
##     float: The calculated length costs for the given link.
## [/codeblock]
func calculate_length_cost(link0: Link, atom_type_pair: Array[String]) -> float:
	var reference_length: float = REFERENCE_BOND_LENGTHS[atom_type_pair]
	var scaled_length: float = link0.length / reference_length
	var excess_length: float = scaled_length - 1.0
	var short_preference: float = SHORT_DIST_PREF * scaled_length

	if excess_length < 0.0:
		return short_preference
	else:
		return short_preference + LENGTH_COST_FACTOR * (excess_length ** 2)


## Calculate the angle costs for a given link and check if it is valid based on minimum angle constraint.
## [codeblock]
## Args:
##     link0 (Link): The link for which angle costs are to be calculated.
##     nodes (Dictionary): A dictionary mapping atoms to their corresponding nodes.
##     tiny_length (float): The length threshold below which bonds are considered tiny and their angle calculations are skipped.
## Returns:
##     Array = [
##         float: The sum of angle costs for the given link.
##         bool: A flag indicating whether the link is valid based on minimum angle constraint.
##     ]
## [/codeblock]
func calculate_angle_costs(link0: Link, nodes: Dictionary, tiny_length: float) -> Array: #Array[float, bool]:
	var atom1: Atom = link0.bond.atoms [0]
	var atom2: Atom = link0.bond.atoms [1]
	var node1: AtomicNode = nodes[atom1]
	var node2: AtomicNode = nodes[atom2]

	var angle_costs: Array[float] = []
	var link0_valid: bool = true

	for node_pair: Array in [[node1, node2], [node2, node1]]:
		var node: AtomicNode = node_pair[0]
		var other_node: AtomicNode = node_pair[1]
		var atom: Atom = node.atom
		var middle_atom: Atom = other_node.atom
		for bond in other_node.bonds:
			var far_atom: Atom = bond.other_atom(middle_atom)
			if far_atom == atom:
				continue
			var middle_far_length: float = middle_atom.position.distance_to(far_atom.position)
			var angle_cost: float = 0.0

			if middle_far_length < tiny_length:
				angle_cost = 0.0
			else:
				var angle: float = calculate_angle(atom.position, middle_atom.position, far_atom.position)

				if angle < MIN_ANGLE:
					link0_valid = false

				if angle >= COMMON_ANGLE:
					angle_cost = 0.0
				else:
					angle_cost = ANGLE_COST_FACTOR * ((COMMON_ANGLE - angle) ** 2)

			angle_costs.append(angle_cost)

	return [_sum(angle_costs), link0_valid]

func _sum(values: Array[float]) -> float:
	var result: float = 0.0
	for v in values:
		result += v
		assert(!is_nan(result))
	return result


## Check for max bond number constraint violation, update the validity flag of a given link. Check for angle validity
## and update the link acceptance cost.
## [codeblock]
## Args:
##     link0 (Link): The link to be updated.
##     nodes (Dictionary): A dictionary mapping atoms to their corresponding nodes.
## [/codeblock]
func update_link_acceptance_conditions_and_cost(link0: Link, nodes: Dictionary) -> void:
	if check_max_bond_number_violation(link0, nodes):
		link0.is_valid = false
	else:
		var atom_type_pair: Array[String] = [link0.bond.atoms[0].atom_type, link0.bond.atoms[1].atom_type]
		var tiny_length: float = TINY_LENGTH_FACTOR * REFERENCE_BOND_LENGTHS[atom_type_pair]

		var length_cost: float = calculate_length_cost(link0, atom_type_pair)
		var angle_costs_and_link0_valid: Array = \
				calculate_angle_costs(link0, nodes, tiny_length) #Array[float,bool]

		# Update acceptance cost and validity flag
		link0.acceptance_cost = length_cost + angle_costs_and_link0_valid[0]
		link0.is_valid = angle_costs_and_link0_valid[1]


## Assigns missing bonds in the input structure to achieve a low strain energy-minimized structure.
## [br][br]
## This function implements the Heuristic Bond Assignment Algorithm, which initializes nodes based on the
## input atoms and bonds, creates a priority queue of candidate links, and iteratively adds bonds to the
## output bonds based on their acceptance cost and validity.
## [codeblock]
## Args:
##     atoms (Array): A list of Atom objects representing the atoms in the structure.
##     input_bonds (Array): A list of Bond objects representing the known bonds in the structure.
## Returns:
##     Array: A list of Bond objects representing the updated bonds in the structure after
##            applying the heuristic bond assignment.
## [/codeblock]
func heuristic_bond_assignment(atoms: Array[Atom], input_bonds: Array[Bond]) -> Array[Bond]:
	MAX_LENGTH_FACTOR  = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/max_length_factor", 3.0)
	TINY_LENGTH_FACTOR = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/tiny_length_factor", 0.3)
	LENGTH_COST_FACTOR = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/length_cost_factor", 1.0)
	SHORT_DIST_PREF    = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/short_dist_pref", 0.1)
	ANGLE_COST_FACTOR  = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/angle_cost_factor", 0.001)
	MIN_ANGLE          = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/min_angle", 40.0)
	COMMON_ANGLE       = ProjectSettings.get_setting(&"msep/heuristic_bond_assignment/common_angle", 109.5)
	var nodes_and_output_bonds: Dictionary = initialize_nodes(atoms, input_bonds)
	var nodes: Dictionary = nodes_and_output_bonds["atom_to_node"]
	var neighborhoods: Array = nodes_and_output_bonds["neighborhoods"]
	var output_bonds: Array[Bond] = nodes_and_output_bonds["output_bonds"]

	for n: Neighborhood in neighborhoods:
		var priority_queue: IndexedPriorityQueue = create_priority_queue(nodes, input_bonds, [n])
		while not priority_queue.is_empty():
			var current_link: Link = priority_queue.pop()
			var atom1: Atom = current_link.bond.atoms[0]
			var atom2: Atom = current_link.bond.atoms[1]
			var node1: AtomicNode = nodes[atom1]
			var node2: AtomicNode = nodes[atom2]

			if current_link.is_valid:
				output_bonds.append(current_link.bond)
				node1.bonds.append(current_link.bond)
				node2.bonds.append(current_link.bond)

				# Remove the link from the nodes' links list
				node1.links.erase(current_link)
				node2.links.erase(current_link)

				# Update the acceptance conditions of the affected links
				priority_queue.start_batch_operation()
				for link in node1.links + node2.links:
					var old_cost: float = link.acceptance_cost
					update_link_acceptance_conditions_and_cost(link, nodes)
					var new_cost: float = link.acceptance_cost

					if new_cost != old_cost:
						priority_queue.put(link, new_cost)
				priority_queue.end_batch_operation()

	return output_bonds

class Neighborhood:
	const RESIDENCE_SIZE := 4.0 * ANGSTRONGS_TO_NANOMETERS
	const NEIGHBORHOOD_GROW := 3.0 * ANGSTRONGS_TO_NANOMETERS
	var residents_bounds: AABB
	var neighbors_bounds: AABB
	var residents: Array[AtomicNode]
	var neighbors: Array[AtomicNode]
	func _init(in_center_of_residence: Vector3) -> void:
		residents_bounds = AABB(in_center_of_residence, Vector3.ZERO)
		residents_bounds = residents_bounds.grow(RESIDENCE_SIZE)
		neighbors_bounds = residents_bounds.grow(NEIGHBORHOOD_GROW)
	func add_if_neighbor(in_node: AtomicNode) -> void:
		if residents_bounds.has_point(in_node.atom.position):
			residents.append(in_node)
		elif neighbors_bounds.has_point(in_node.atom.position):
			neighbors.append(in_node)
