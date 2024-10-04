from openff.toolkit.topology import Molecule, FrozenMolecule
import networkx as nx
from typing_extensions import TypeAlias
from typing import (
    Dict,
    Optional,
    Tuple,
    Union,
)
from openff.toolkit.utils.toolkits import (
    GLOBAL_TOOLKIT_REGISTRY,
    ToolkitRegistry,
    ToolkitWrapper,
)
TKR: TypeAlias = Union[ToolkitRegistry, ToolkitWrapper]


are_molecules_isomorphic_original = None

def are_molecules_isomorphic_patched(
		mol1: Union["FrozenMolecule", "_SimpleMolecule", nx.Graph],
		mol2: Union["FrozenMolecule", "_SimpleMolecule", nx.Graph],
		return_atom_map: bool = False,
		aromatic_matching: bool = True,
		formal_charge_matching: bool = True,
		bond_order_matching: bool = True,
		atom_stereochemistry_matching: bool = True,
		bond_stereochemistry_matching: bool = True,
		strip_pyrimidal_n_atom_stereo: bool = True,
		toolkit_registry: TKR = GLOBAL_TOOLKIT_REGISTRY,
	) -> Tuple[bool, Optional[Dict[int, int]]]:

	import networkx as nx

	_cls = FrozenMolecule

	if isinstance(mol1, nx.Graph) and isinstance(mol2, nx.Graph):
		pass

	elif isinstance(mol1, nx.Graph):
		assert isinstance(mol2, _cls)

	elif isinstance(mol2, nx.Graph):
		assert isinstance(mol1, _cls)

	else:
		# static methods (by definition) know nothing about their class,
		# so the class to compare to must be hard-coded here
		if not (isinstance(mol1, _cls) and isinstance(mol2, _cls)):
			return False, None

	def _object_to_n_atoms(obj):
		if isinstance(obj, FrozenMolecule):
			return obj.n_atoms
		elif isinstance(obj, nx.Graph):
			return obj.number_of_nodes()
		else:
			raise TypeError(
				"are_isomorphic accepts a NetworkX Graph or OpenFF "
				+ f"(Frozen)Molecule, not {type(obj)}"
			)

	# Quick number of atoms check. Important for large molecules
	if _object_to_n_atoms(mol1) != _object_to_n_atoms(mol2):
		return False, None

	# If the number of atoms match, check the Hill formula
	if Molecule._object_to_hill_formula(mol1) != Molecule._object_to_hill_formula(
		mol2
	):
		return False, None

	# Do a quick check to see whether the inputs are totally identical (including being in the same atom order)
	if isinstance(mol1, FrozenMolecule) and isinstance(mol2, FrozenMolecule):
		if mol1._is_exactly_the_same_as(mol2):
			if return_atom_map:
				return True, {i: i for i in range(mol1.n_atoms)}
			else:
				return True, None

	# ----------- MSEP.one OPTIMIZATION! -----------
	# Any structure bigger than this threshoold will take more time to identify isomorphism than it takes to
	# parse again the forcefields, so we make an early return
	if _object_to_n_atoms(mol1) >= 200:
		return False, None

	return are_molecules_isomorphic_original(
			mol1,
			mol2,
			return_atom_map,
			aromatic_matching,
			formal_charge_matching,
			bond_order_matching,
			atom_stereochemistry_matching,
			bond_stereochemistry_matching,
			strip_pyrimidal_n_atom_stereo,
			toolkit_registry)

def apply_frozen_molecule_patch():
	global are_molecules_isomorphic_original
	if not are_molecules_isomorphic_original is None:
		# Patch already applied!
		return
	are_molecules_isomorphic_original = Molecule.are_isomorphic
	Molecule.are_isomorphic = staticmethod(are_molecules_isomorphic_patched)

if __name__ == "__main__":
	print("\tThis module is not meant to be run as standalone. Please run openmm_server.py")