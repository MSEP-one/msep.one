from openmm.app import *
from openmm import *
from openmm.unit import *
from sys import stdout
from openff.toolkit.topology import Molecule
from openff.toolkit.utils.toolkits import RDKitToolkitWrapper
from openmmforcefields.generators import SMIRNOFFTemplateGenerator

sdf = Molecule.from_file("input.sdf", "sdf", toolkit_registry=RDKitToolkitWrapper())
smirnoff = SMIRNOFFTemplateGenerator(molecules=sdf)
forcefield = ForceField('amber/protein.ff14SB.xml', 'amber/tip3p_standard.xml', 'amber/tip3p_HFE_multivalent.xml')
forcefield.registerTemplateGenerator(smirnoff.generator)
openff_topology = sdf.to_topology()
topology = openff_topology.to_openmm()
system = forcefield.createSystem(topology, nonbondedMethod=NoCutoff, nonbondedCutoff=1*nanometer, constraints=HBonds)
integrator = LangevinMiddleIntegrator(300*kelvin, 1/picosecond, 0.004*picoseconds)
simulation = Simulation(topology, system, integrator)
initial_positions = openff_topology.get_positions().to_openmm()
simulation.context.setPositions(initial_positions)
simulation.minimizeEnergy()
simulation.reporters.append(PDBReporter('output.pdb', 1000))
simulation.reporters.append(StateDataReporter(stdout, 1000, step=True, potentialEnergy=True, temperature=True))
simulation.step(10000)
print("DONE!")