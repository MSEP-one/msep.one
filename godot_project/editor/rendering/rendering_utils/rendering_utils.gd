class_name RenderingUtils


const SHADER_CONSTANTS_INCLUDE = preload("res://editor/rendering/atomic_structure_renderer/representation/constants.gdshaderinc")

# Those consts reflects the names from the constants.gdshaderinc file
const _CONST_NAME_BOND_HIGHLIGHT_FACTOR = "BOND_HIGHLIGHT_FACTOR"
const _SELECTION_PREVIEW_VISUAL_LAYER = "SELECTION_PREVIEW_VISUAL_LAYER"

static var shader_constant_data_cache: Dictionary = {}


static var _instance_uniform_regex: RegEx:
	get:
		if _instance_uniform_regex == null:
			_instance_uniform_regex = RegEx.new()
			_instance_uniform_regex.compile("instance uniform ([a-z][a-z0-9]+) ([a-zA-Z_][a-zA-Z0-9_]+) = ([a-z0-9_.]+);")
		return _instance_uniform_regex


static func calculate_atom_visual_radius(in_atomic_nmb: int, in_representation_settings: RepresentationSettings) -> float:
	var data: ElementData = PeriodicTable.get_by_atomic_number(in_atomic_nmb)
	var atom_scale_factor: float = Representation.get_atom_scale_factor(in_representation_settings)
	return Representation.get_atom_radius(data, in_representation_settings) * atom_scale_factor


static func get_bond_highlight_factor() -> float:
	return _get_shader_constants_data()[_CONST_NAME_BOND_HIGHLIGHT_FACTOR].to_float()


static func get_selection_preview_visual_layer() -> int:
	return _get_shader_constants_data()[_SELECTION_PREVIEW_VISUAL_LAYER].to_int()


# Can be used to get a dictionary of constants which are defined in constants.gdshaderinc
static func _get_shader_constants_data() -> Dictionary:
	if not shader_constant_data_cache.is_empty():
		return shader_constant_data_cache
	
	var include_code: String = SHADER_CONSTANTS_INCLUDE.code;
	var lines: PackedStringArray = include_code.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("//"):
			continue
		var equal_separation: PackedStringArray = line.split("=")
		var value: String = equal_separation[1].rstrip(";");
		var words_left_from_equal: PackedStringArray = equal_separation[0].split(" ", false)
		var constant_name: String = words_left_from_equal[words_left_from_equal.size()-1]
		shader_constant_data_cache[constant_name] = value
	return shader_constant_data_cache


static func copy_selected_uniforms_from(in_from_material: ShaderMaterial, out_destination_material: ShaderMaterial,
			list_to_copy: PackedStringArray) -> void:
	var uniforms_desc: Array = in_from_material.shader.get_shader_uniform_list()
	var uniform_list: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in uniforms_desc:
		var uniform_name: String = uniform["name"]
		if list_to_copy.has(uniform_name):
			uniform_list.append(uniform_name)
	
	for uniform: String in uniform_list:
		if has_uniform(out_destination_material, uniform):
			out_destination_material.set_shader_parameter(uniform, in_from_material.get_shader_parameter(uniform))


static func copy_uniforms_from(in_from_material: ShaderMaterial, out_destination_material: ShaderMaterial,
			in_ignore_uniforms := PackedStringArray()) -> void:
	var uniforms_desc: Array = in_from_material.shader.get_shader_uniform_list()
	var uniform_list: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in uniforms_desc:
		var uniform_name: String = uniform["name"]
		if in_ignore_uniforms.has(uniform_name):
			continue
		uniform_list.append(uniform_name)
	
	for uniform: String in uniform_list:
		if has_uniform(out_destination_material, uniform):
			out_destination_material.set_shader_parameter(uniform, in_from_material.get_shader_parameter(uniform))


static func has_uniform(in_material: ShaderMaterial, in_uniform: String) -> bool:
	var uniforms: Array = in_material.shader.get_shader_uniform_list()
	for uniform: Dictionary in uniforms:
		if uniform.name == in_uniform:
			return true
	return false


static func has_uniforms(in_material: ShaderMaterial, in_uniforms_to_check: PackedStringArray) -> bool:
	var existing_uniforms: Array = in_material.shader.get_shader_uniform_list()
	for uniform: Dictionary in existing_uniforms:
		if not in_uniforms_to_check.has(uniform.name):
			return false
	return true


static func has_instance_uniform(in_material: ShaderMaterial, in_uniform: String) -> bool:
	var results: Array[RegExMatch] = _instance_uniform_regex.search_all(in_material.shader.code)
	const UNIFORM_NAME_GROUP_INDEX: int = 2
	for result: RegExMatch in results:
		if result.strings[UNIFORM_NAME_GROUP_INDEX] == in_uniform:
			return true
	return false


static func debug_reload_shader(in_material: ShaderMaterial) -> void:
	var shader_path: String = in_material.shader.resource_path
	var shader_code: String = FileAccess.get_file_as_string(shader_path)
	in_material.shader.code = shader_code
