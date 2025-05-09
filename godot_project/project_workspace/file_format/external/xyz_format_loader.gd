extends ResourceFormatLoader

## XYZ format specification:
##
## <number of atoms>
## comment line
## <element> <X> <Y> <Z>
##
## Notes:
## + Atoms' positions are stored in ångströms.
## + Bonds are not included, they are implied from the distance between atoms.

const ANGSTROMS_TO_NANOMETERS: float = 1.0 / 10.0


func _get_recognized_extensions() -> PackedStringArray:
	var extensions := PackedStringArray()
	extensions.push_back("xyz")
	return extensions


func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ERR_FILE_CANT_OPEN
	
	var structure: NanoMolecularStructure = NanoMolecularStructure.new()
	
	# First line - Atoms count
	var declared_atom_count: int = int(file.get_line())
	
	# Second line - Comment, can be ignored
	var _comment: String = file.get_line()
	
	# Atoms positions
	structure.start_edit()
	for i in declared_atom_count:
		var line: String = file.get_line()
		var tokens: PackedStringArray = line.split(" ", false)
		if tokens.size() != 4:
			continue # Error ?
		
		var symbol: String = tokens[0].capitalize()
		var x: float = float(tokens[1])
		var y: float = float(tokens[2])
		var z: float = float(tokens[3])
		var position: Vector3 = Vector3(x, y, z) * ANGSTROMS_TO_NANOMETERS
		var element_data: ElementData = PeriodicTable.get_by_symbol(symbol)
		if element_data.number == -1:
			push_error("Unknown element: " + symbol)
			continue
		structure.add_atom(
			AtomicStructure.AddAtomParameters.new(element_data.number, position)
		)
	structure.end_edit()

	file.close()
	return structure
