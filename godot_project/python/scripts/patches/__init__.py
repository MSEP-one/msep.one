from .patch_frozen_molecule import apply_frozen_molecule_patch

def apply_all_patches():
	apply_frozen_molecule_patch()

__all__ = [
	"apply_all_patches",
	"apply_frozen_molecule_patch"
]
