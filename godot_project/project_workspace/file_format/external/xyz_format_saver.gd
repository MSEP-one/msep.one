extends ResourceFormatSaver

## XYZ format specification:
##
## <number of atoms>
## comment line
## <element> <X> <Y> <Z>
##
## Notes:
## + Atoms' positions are stored in ångströms.
## + Bonds are not included, they are implied from the distance between atoms.

const NANOMETERS_TO_ANGSTROMS: float = 10.0


func _recognize(resource: Resource) -> bool:
	return resource is Workspace


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	var extensions := PackedStringArray()
	extensions.push_back("xyz")
	return extensions


func _save(resource: Resource, path: String, flags: int) -> Error:
	var workspace: Workspace = resource as Workspace
	if not workspace:
		return ERR_INVALID_DATA
	
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	
	# First line - Atoms count
	var total_atom_count: int = 0
	for structure: NanoStructure in workspace.get_structures():
		if structure is NanoMolecularStructure:
			total_atom_count += structure.get_valid_atoms_count()
	file.store_line(str(total_atom_count))
	
	# Second line - Comment (File description, authors and Msep version)
	var msep_version: String = Editor_Utils.get_msep_version(false)
	var timestamp: String = Time.get_datetime_string_from_system()
	var author: String = workspace.authors
	if author.is_empty():
		author = "Unknown"
	file.store_line("%s - Author: %s - MSEP %s" % [workspace.description, workspace.authors, msep_version])
	
	# Atoms positions
	for structure: NanoStructure in workspace.get_structures():
		if not structure is NanoMolecularStructure:
			continue
		
		var atoms_count: int = structure.get_valid_atoms_count()
		if atoms_count == 0:
			continue
		
		for atom_id: int in structure.get_valid_atoms():
			var position: Vector3 = structure.atom_get_position(atom_id) * NANOMETERS_TO_ANGSTROMS
			var atomic_number: int = structure.atom_get_atomic_number(atom_id)
			var element_data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
			file.store_line("%s %f %f %f" % [element_data.symbol, position.x, position.y, position.z])

	file.close()
	return OK
