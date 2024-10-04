extends RefCounted

var file_path := String()
var generate_bonds: bool = false
var add_hydrogens: bool = false
var remove_waters: bool = false


func _init(
	in_file_path: String,
	in_generate_bonds: bool,
	in_add_hydrogens: bool,
	in_remove_waters: bool) -> void:
	
	file_path = in_file_path
	generate_bonds = in_generate_bonds
	add_hydrogens = in_add_hydrogens
	remove_waters = in_remove_waters


func to_multipart_message() -> PackedStringArray:
	var message: PackedStringArray = [
		"Import File", # Action header
		file_path,
		"--generate_bonds=" + _flag_to_str(generate_bonds),
		"--add_hydrogens=" + _flag_to_str(add_hydrogens),
		"--remove_waters=" + _flag_to_str(remove_waters)
	]
	return message


func _flag_to_str(flag: bool) -> String:
	return "yes" if flag else "no"

