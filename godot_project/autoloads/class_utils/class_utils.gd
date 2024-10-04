extends Node
## ClassUtils singleton. 
## Responsible for providing language features that gdscript does not posses. 
## Currently it's able to find all missing abstract function implementations.
## In order to use it please:
## - mark any abstract class as such by adding "@abstract_class" line 
##   above class_name. 
## - mark any abstract function by ussing such assert inside function body:
##   assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)

const ABSTRACT_FUNCTION_MSG := "Function needs to be implemented. "
const FILE_HEADER_NMB_OF_LINES := 3

var _check_thread: Thread
var _class_name_to_description: Dictionary = {
	# class_name : ClassDescription
}


func _ready() -> void:
	assert(ClassDB.get_class_list().find("ClassHelper") == -1, "Safety check to ensure this behavior
			has not changed upstream (custom classes should not be on the list)")
	assert(get_script().get_base_script() == null, "Safety check to ensure this behavior has not
			changed upstream (build in classes should not be considered)")
	
	if not OS.is_debug_build():
		return
	if not EngineDebugger.is_active():
		return
	
	_check_thread = Thread.new()
	_check_thread.start(_pre_check)


func _exit_tree() -> void:
	if is_instance_valid(_check_thread) and _check_thread.is_alive():
		_check_thread.wait_to_finish()


static func get_class_description(in_header: String, in_filepath: String) -> ClassDescription:
	var is_abstract: bool = in_header.find("@abstract_class") > -1
	in_header = in_header.replace("\n", " ")
	var first_words: PackedStringArray = in_header.split(" ", true, 10)
	var name_of_class: String = ""
	var name_of_parent_class: String = ""
	var next_word_is_class_name: bool = false
	var next_word_is_parent_name: bool = false
	for word in first_words:
		if next_word_is_class_name and name_of_class.is_empty():
			name_of_class = word
		if next_word_is_parent_name and name_of_parent_class.is_empty():
			name_of_parent_class = word
		var are_names_found: bool = (not name_of_class.is_empty()) and (not name_of_parent_class.is_empty())
		if are_names_found:
			break
		next_word_is_class_name = word == "class_name"
		next_word_is_parent_name = word == "extends"
	return ClassDescription.new(name_of_class, is_abstract, name_of_parent_class, in_filepath)


static func fetch_functions_from_path(in_script_filepath: String) -> Array[FunctionDescription]:
	var file := FileAccess.open(in_script_filepath, FileAccess.READ)
	assert(file != null)
	var content: String = file.get_as_text()
	file.close()
	return fetch_functions_from_script_content(content)


static func fetch_functions_from_script_content(in_source_code: String) -> Array[FunctionDescription]:
	var functions: Array[FunctionDescription] = []
	var lines: PackedStringArray = in_source_code.split("\n", false)
	for line in lines:
		if line.strip_edges().begins_with("#"):
			continue
		if line.begins_with("func "):
			var func_name: String = line.split(" ")[1].split("(")[0]
			var func_desc := FunctionDescription.new(func_name)
			functions.append(func_desc)
		if line.find("ABSTRACT_FUNCTION_MSG") > -1:
			functions.back().is_abstract = true
	return functions


func _pre_check() -> void:
	var all_gdscript_files: PackedStringArray = _find_all_gdscript_files()
	for gdscript_path in all_gdscript_files:
		var header: String = _read_header(gdscript_path)
		var desc: ClassDescription = get_class_description(header, gdscript_path)
		if desc.name_of_class == "":
			continue
		_class_name_to_description[desc.name_of_class] = desc
	
	var classes_to_test_for_abstraction: Array[ClassDescription] = []
	for class_desc: ClassDescription in _class_name_to_description.values():
		if _is_involved_with_abstraction(class_desc):
			classes_to_test_for_abstraction.append(class_desc)
	
	for test_class_desc: ClassDescription in classes_to_test_for_abstraction:
		test_class_desc.generate_functions()
	
	for test_class_desc: ClassDescription in classes_to_test_for_abstraction:
		_do_check(test_class_desc)


func _find_all_gdscript_files(in_path: String = "res://") -> PackedStringArray:
	var gdscript_files: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(in_path)
	if dir == null:
		return gdscript_files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var file_path := in_path + "/" + file_name
		if dir.current_is_dir():
			var sub_dir := DirAccess.open(file_path)
			if sub_dir != null:
				gdscript_files.append_array(_find_all_gdscript_files(file_path))
		else:
			if file_name.ends_with(".gd"):
				gdscript_files.append(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return gdscript_files


func _read_header(file_path: String) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	assert(file != null)
	
	var file_contents: String = ""
	for line_idx in FILE_HEADER_NMB_OF_LINES:
		var line: String = file.get_line().strip_edges(true, false)
		if line.begins_with("#"):
			continue
		file_contents += line + "\n"
	file.close()
	return file_contents


func _is_involved_with_abstraction(in_class: ClassDescription) -> bool:
	if in_class == null:
		return false
	if in_class.is_abstract_class:
		return true
	if in_class.name_of_parent_class.is_empty():
		return false
	var parent_desc: ClassDescription = _class_name_to_description.get(in_class.name_of_parent_class, null)
	return _is_involved_with_abstraction(parent_desc)


func _do_check(in_class_to_check: ClassDescription) -> void:
	if in_class_to_check.is_abstract_class:
		return
	
	var functions_which_needs_to_be_implemented: Array[FunctionDescription] = \
			_find_ancestor_abstract_functions(in_class_to_check)
	var all_implemented_functions: Dictionary = _find_all_implemented_functions(in_class_to_check)
	for function_desc: FunctionDescription in functions_which_needs_to_be_implemented:
		var is_implemented: bool = all_implemented_functions.has(function_desc.function_name)
		assert(is_implemented, "Class " + in_class_to_check.name_of_class + " needs to implement abstract function: " + function_desc.function_name)


func _find_ancestor_abstract_functions(in_class: ClassDescription) -> Array[FunctionDescription]:
	var out_parent_abstract_functions: Array[FunctionDescription] = []
	if not _class_name_to_description.has(in_class.name_of_parent_class):
		return out_parent_abstract_functions
	
	var parent: ClassDescription = _class_name_to_description[in_class.name_of_parent_class]
	var parent_functions: Array[FunctionDescription] = parent.get_functions()
	for function: FunctionDescription in parent_functions:
		if function.is_abstract:
			out_parent_abstract_functions.append(function)
	var parent_abstract_funcs := _find_ancestor_abstract_functions(parent)
	out_parent_abstract_functions.append_array(parent_abstract_funcs)
	return out_parent_abstract_functions


func _is_function_in_set(in_function_name: String, in_set: Array[FunctionDescription]) -> bool:
	for item: FunctionDescription in in_set:
		if item.function_name == in_function_name:
			return true
	return false


func _find_all_implemented_functions(in_class: ClassDescription) -> Dictionary:
	var out_implemented_functions: Dictionary = {
		# Using Dictionary instead of Array for performance purposes
		# function_name<String>: <FunctionDescription>
	}
	var functions: Array[FunctionDescription] = in_class.get_functions()
	for function: FunctionDescription in functions:
		if not function.is_abstract:
			out_implemented_functions[function.function_name] = function
	
	if in_class.has_parent():
		assert(_class_name_to_description.has(in_class.name_of_parent_class), in_class.name_of_parent_class + " most probably is not calling super._init()")
		var parent: ClassDescription = _class_name_to_description[in_class.name_of_parent_class]
		var implemented_by_ancestors := _find_all_implemented_functions(parent)
		for ancestor_function_name: String in implemented_by_ancestors.keys():
			out_implemented_functions[ancestor_function_name] = implemented_by_ancestors[ancestor_function_name]
	return out_implemented_functions


class ClassDescription:
	var name_of_class: String
	var name_of_parent_class: String
	var script_filepath: String
	var is_abstract_class: bool = false
	var _functions: Array[FunctionDescription] = []
	
	func _init(in_name_of_class: String, in_is_abstract: bool, in_name_of_parent_class: String, in_script_filepath: String) -> void:
		name_of_class = in_name_of_class
		is_abstract_class = in_is_abstract
		var is_parent_a_custom_class: bool = not ClassDB.get_class_list().has(in_name_of_parent_class)
		name_of_parent_class = in_name_of_parent_class if is_parent_a_custom_class else ""
		script_filepath = in_script_filepath
	
	
	func get_functions() -> Array[FunctionDescription]:
		return _functions
	
	
	func are_functions_descriptions_generated() -> bool:
		return _functions.size() > 0
	
	
	## This is slow operation, we are performing this only on a selected instances of ClassDescription
	func generate_functions() -> void:
		assert(not are_functions_descriptions_generated())
		_functions = ClassUtils.fetch_functions_from_path(script_filepath)
	
	
	func has_parent() -> bool:
		return name_of_parent_class != ""


class FunctionDescription:
	var function_name: String
	var is_abstract: bool = false
	
	func _init(in_name: String) -> void:
		function_name = in_name
