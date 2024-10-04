@tool
extends ResourceFormatLoader
class_name ProteinDataBaseXmlFormatLoader
# # # #
# DEPRECATED. We have it in the project mostly as an inspiration.
# At the moment when our implementation of the loader will achieve feature parity, this file should be removed


var _classes := PackedStringArray(["AtomDb", "PdbAtom"])
var _dependencies := PackedStringArray()
func _get_classes_used(_path: String) -> PackedStringArray:
	return _classes

func _get_dependencies(_path: String, _add_types: bool):
	return _dependencies

func _get_recognized_extensions() -> PackedStringArray:
	return ["xml"]

func _get_resource_type(path: String):
	"ProteinDB"

func _handles_type(type: StringName):
	return type == StringName() # xml files are external, and are not directly represented by a type

func _recognize_path(path: String, type: StringName):
	var recognized = path.get_extension() == "xml" && type == StringName()
	if recognized:
		var f = FileAccess.open(path, FileAccess.READ)
		for i in range(5): #check only first 5 lines for the header
			var line = f.get_line()
			if line.lstrip(" \t").begins_with("<PDBx:datablock"):
				return true
	return false

func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int
) -> Variant:
	# TODO: This function is extremely ugly, dirty and incomplete.
	# Needs proper implementation
	var atom_data = ProteinDB.new()
	var f = FileAccess.open(path, FileAccess.READ)
	var index := 0
	var looking_for_atom = true
	var looking_for_positions = false
	var looking_for_symbol = false
	
	while not f.eof_reached():
		var atom: PdbAtom
		var line: String = f.get_line()
		if looking_for_atom:
			if line.find("PDBx:atom_site") > -1:
				atom = PdbAtom.new()
				atom.index = index
				atom_data.add_atom(atom)
				index+=1
				looking_for_atom = false
				looking_for_positions = true
		if looking_for_positions:
			if line.find("PDBx:Cartn_x") > -1:
				atom.position.x = _get_value(line).to_float()
			if line.find("PDBx:Cartn_y") > -1:
				atom.position.y = _get_value(line).to_float()
			if line.find("PDBx:Cartn_z") > -1:
				atom.position.z = _get_value(line).to_float()
				looking_for_positions = false
				looking_for_symbol = true
		if looking_for_symbol:
			if line.find("PDBx:type_symbol") > -1:
				atom.element_name = _get_value(line).trim_prefix(" ").trim_suffix(" ")
				looking_for_atom = true
				looking_for_symbol = false
	return atom_data


func _get_value(in_nmb_string: String) -> String:
	var val: String = in_nmb_string.split(">", false)[1]
	val = val.split("<",false)[0]
	return val
