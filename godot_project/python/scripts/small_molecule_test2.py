from openmm.app import *
from openmm.unit import *

from openmm import LangevinMiddleIntegrator, VerletIntegrator
from openmm import Context, System, NonbondedForce, HarmonicAngleForce, HarmonicBondForce
from openmm import LocalEnergyMinimizer

from openff.toolkit import ForceField, Molecule, Topology
# from openff.toolkit.utils.toolkits import AmberToolsToolkitWrapper
from openff.toolkit.utils.toolkits import RDKitToolkitWrapper
# from openff.toolkit.utils.toolkits import BuiltInToolkitWrapper
from openff.interchange import Interchange

from sys import stdout
""" 
import math

class Vector3(tuple):
	def __new__(cls, x: float, y: float, z: float):
		return super().__new__(cls, (x, y, z))


# region: Constants
KJPerKcal           = 4.184
AngstromsPerNm      = 10.0
SigmaPerVdwRadius = 1.7817974362806786095
VdwRadiusPerSigma = .56123102415468649070
known_charges = {
	1: 0.0605,
	6: -.1815
}
vdw_radii = {
	1:  0.110,
	2:  0.140,
	3:  0.181,
	4:  0.153,
	5:  0.192,
	6:  0.170,
	7:  0.155,
	8:  0.152,
	9:  0.147,
	10: 0.154,
	11: 0.227,
	12: 0.173,
	13: 0.184,
	14: 0.210,
	15: 0.180,
	16: 0.180,
	17: 0.175,
	18: 0.188,
	19: 0.275,
	20: 0.231
}
bond_length = {
	1:  [0.032,  None,  None],
	2:  [0.046,  None,  None],
	3:  [0.133, 0.124,  None],
	4:  [0.102, 0.090, 0.085],
	5:  [0.085, 0.078, 0.073],
	6:  [0.075, 0.067, 0.060],
	7:  [0.071, 0.060, 0.054],
	8:  [0.063, 0.057, 0.053],
	9:  [0.064, 0.059, 0.053],
	10: [0.067, 0.096,  None],
	11: [0.155, 0.160,  None],
	12: [0.139, 0.132, 0.127],
	13: [0.126, 0.113, 0.111],
	14: [0.116, 0.107, 0.102],
	15: [0.111, 0.102, 0.094],
	16: [0.103, 0.094, 0.095],
	17: [0.099, 0.095, 0.093],
	18: [0.096, 0.107, 0.096],
	19: [0.196, 0.193,  None],
	20: [0.171, 0.147, 0.133]
}
known_energy = {
	1: 0.0157,
	6: 0.1094
}
bond_stiffness = {
	1: 310 * 2 * KJPerKcal * AngstromsPerNm * AngstromsPerNm,
	2: 340 * 2 * KJPerKcal * AngstromsPerNm * AngstromsPerNm,
	3: 370 * 2 * KJPerKcal * AngstromsPerNm * AngstromsPerNm
}



def prewarm_minimize_energy(openmm_topology: Topology, openmm_positions):
	system = System()

	nonbond = NonbondedForce()
	if system.addForce(nonbond) == -1:
		return
	bond_bend = HarmonicAngleForce()
	if system.addForce(bond_bend) == -1:
		return
	bond_force = HarmonicBondForce()
	if system.addForce(bond_force) == -1:
		return

	# set parametters
	for atom in openmm_topology.atoms():
		system.addParticle(atom.element.mass) # grams per mole
		atomic_number = atom.element.atomic_number

		# charge: double, L-J sigma (nm): double, well depth (kJ)
		charge = known_charges.get(atomic_number, 0.0)
		radii = vdw_radii.get(atomic_number)
		sigma = SigmaPerVdwRadius * radii
		epsilon = KJPerKcal * known_energy.get(atomic_number, 0.0)
		nonbond.addParticle(charge, sigma, epsilon)
	

	# Find angles in this Atom
	for atom in openmm_topology.atoms():
		atom_bonds = list(filter(lambda bond: bond[0] == atom or bond[1] == atom ,openmm_topology.bonds()))
		func_other = lambda bond: bond[0] if bond[1] == atom else bond[1]
		match len(atom_bonds):
			case 2:
				angle = math.radians(109.5)
				a1: int = func_other(atom_bonds[0]).index
				a3: int = func_other(atom_bonds[1]).index
				bond_bend.addAngle(
					a1, atom.index, a3,
					angle, 100 * 2 * 4.184
				)
			case 3:
				# a1 - atom - a3
				# a1 - atom - a4
				# a3 - atom - a4
				angle = math.radians(360.0/3.0)
				a1: int = func_other(atom_bonds[0]).index
				a3: int = func_other(atom_bonds[1]).index
				a4: int = func_other(atom_bonds[2]).index
				bond_bend.addAngle(
					a1, atom.index, a3,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a1, atom.index, a4,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a3, atom.index, a4,
					angle, 80 * 2 * 4.184
				)
			case 4:
				# a1 - atom - a3
				# a1 - atom - a4
				# a1 - atom - a5
				# a3 - atom - a4
				# a3 - atom - a5
				# a4 - atom - a5
				angle = math.radians(109.5)
				a1: int = func_other(atom_bonds[0]).index
				a3: int = func_other(atom_bonds[1]).index
				a4: int = func_other(atom_bonds[2]).index
				a5: int = func_other(atom_bonds[3]).index
				bond_bend.addAngle(
					a1, atom.index, a3,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a1, atom.index, a4,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a1, atom.index, a5,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a3, atom.index, a4,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a3, atom.index, a5,
					angle, 80 * 2 * 4.184
				)
				bond_bend.addAngle(
					a4, atom.index, a5,
					angle, 80 * 2 * 4.184
				)

	#now add constraints
	bond_pairs: list = []
	for bond in openmm_topology.bonds():
		atom_1 = bond[0]
		atom_2 = bond[1]
		atom_id_1: int = bond[0].index
		atom_id_2: int = bond[1].index
		order: int = 1 #bond_data.z
		atomic_number_1: int = atom_1.element.atomic_number
		atomic_number_2: int = atom_2.element.atomic_number
		distance: float = 0
		distance += bond_length[atomic_number_1][order-1]
		distance += bond_length[atomic_number_2][order-1]
#		real_distance = (link.nanode_a.transform.origin - link.nanode_b.transform.origin).length()
#		print("PDB Distance: %.4f...		Expected Constraint: %.4f...		%s	->	%s" % [real_distance, distance, link.nanode_a.get_element_data().symbol, link.nanode_b.get_element_data().symbol])
#		system.add_constraint(p1, p2, distance)
		bond_force.addBond(atom_id_1, atom_id_2, distance, bond_stiffness[order])

		bond_pairs.append((atom_id_1, atom_id_2))
	nonbond.createExceptionsFromBonds(bond_pairs, 0.5, 0.5)

	step_size_in_nanoseconds: float = 0.004
	integrator = VerletIntegrator(step_size_in_nanoseconds)

	context = Context(system, integrator)
	context.setPositions(openmm_positions)
	LocalEnergyMinimizer.minimize(context, 10.0)
	minimized_positions = context.getState(getPositions = True).getPositions()
	PDBFile.writeFile(openmm_topology, minimized_positions, open('large_bearing/marianos_minimization.pdb', 'w'))

	return minimized_positions
 """

def main () -> int:
	molecule = Molecule.from_file("large_bearing/input.sdf")
	molecule.assign_partial_charges(partial_charge_method="mmff94", toolkit_registry=RDKitToolkitWrapper())
	topology = molecule.to_topology()

	forcefield = ForceField("openff-2.1.0.offxml")
	interchange = Interchange.from_smirnoff(forcefield, topology, charge_from_molecules=[molecule])

	openmm_system = interchange.to_openmm()
	openmm_topology = interchange.to_openmm_topology()
	openmm_original_positions = interchange.positions.to_openmm()
	# prewarm_positions = prewarm_minimize_energy(openmm_topology, openmm_original_positions)

	integrator = LangevinMiddleIntegrator(300*kelvin, 1/picosecond, 0.004*picoseconds)
	simulation = Simulation(openmm_topology, openmm_system, integrator)
	simulation.context.setPositions(openmm_original_positions)
	simulation.minimizeEnergy()
	PDBFile.writeFile(openmm_topology, final_positions, open('large_bearing/openff_minimization.pdb', 'w'))
	
	simulation.reporters.append(PDBReporter('large_bearing/output.pdb', 10000))
	# simulation.reporters.append(StateDataReporter(stdout, 1000, step=True, potentialEnergy=True, temperature=True))
	simulation.step(10000)
	final_positions = simulation.context.getState(getPositions = True).getPositions()
	PDBFile.writeFile(openmm_topology, final_positions, open('large_bearing/openff_simulate_10000.pdb', 'w'))
	return 0

main()