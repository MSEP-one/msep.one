class_name Workspace extends Resource

signal structure_added(struct: NanoStructure)
signal structure_about_to_remove(struct: NanoStructure)
signal structure_removed(struct: NanoStructure)
signal structure_reparented(struct: NanoStructure, new_parent: NanoStructure)
signal structure_renamed(struct: NanoStructure, new_name: String)
signal representation_settings_changed()
signal bond_settings_changed(representation_settings: RepresentationSettings)

const INVALID_STRUCTURE_ID := 0
const INVALID_OBJECT_INDEX = -1
const MAX_SIGNED_32_BIT_INT = 2147483647

static var instance_counter: int = 0


@export var _structures: Dictionary = {
	# ID<int> : NanoStructure
}

@export var active_structure_int_guid: int = -1:
	get:
		if active_structure_int_guid == -1:
			# active structure has never set, fallback to root
			return main_structure_int_guid
		return active_structure_int_guid

@export var main_structure_int_guid: int:
	get:
		if _main_structure_int_guid == INVALID_STRUCTURE_ID:
			assert(false, "Atempting to get the main structure before it was added to the workspace")
			return INVALID_STRUCTURE_ID
		return _main_structure_int_guid
	set(v):
		# main_structure_int_guid is read only. Usually this would be an assert,
		# but because this variable is an @export, the assert would be thrown
		# from `ResourceLoader.load("file.msep1")`
		return


## User defined description of the project
@export var description: String:
	set(v):
		description = v
		changed.emit()


## User defined list of authors
@export var authors: String:
	set(v):
		authors = v
		changed.emit()


## Timestaps when user saved the files, with the version used.
## Collected for logging reasons
@export var msep_version_history: Dictionary = {
#	save_timestamp<String> = build_date_and_commit_hash<String>
}


## User defined representation/rendering settings 
## like atom size settings, background color, etc... stored inside the project
@export var representation_settings := RepresentationSettings.new():
	set = _set_representation_settings


## User defined simulation settings
## like simulation duration, time step, relax before simulating, etc... stored inside the project
## These are updated in the moment the user starts a new simulation, not before
@export var simulation_parameters := SimulationParameters.new()

@export_group("Simulation Settings", "simulation_settings_")

## Forcefield file used to Minimize Energy (relax), do Simulated Annealing,
## and perform Molecular Mechanics simulations
@export var simulation_settings_forcefield: String = OpenMMUtils.DEFAULT_FORCEFIELD


## Hash of the last used forcefield, used to detect if the forcefield file has changed
## since the last time the workspace was saved
@export var simulation_settings_forcefield_md5: String = OpenMMUtils.hash_forcefield(OpenMMUtils.DEFAULT_FORCEFIELD)


## Show user defined forcefields in the dropdown UI of the Simulations docker
@export var simulation_settings_show_user_defined_forcefields: bool = false


## Include or not unverified aproximations to simulate elements not supported
## by default by OpenFF
@export var simulation_settings_forcefield_extension: String = OpenMMUtils.DEFAULT_FORCEFIELD_EXTENSION


## Hash of the last used msep extensions forcefield, used to detect if the file has changed
## since the last time the workspace was saved
@export var simulation_settings_msep_extensions_md5: String = OpenMMUtils.hash_forcefield_extension(OpenMMUtils.MSEP_EXTENSIONS_FORCEFIELD)


## Show user defined forcefields in the dropdown UI of the Simulations docker
@export var simulation_settings_show_user_defined_extensions: bool = false

@export_group("", "") # end of "Simulation Settings" group


## RandomNumberGenerator is used to create unique IDs, state and seed are stored
## to avoid generating the same known ids in subsequent excecutions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## RandomNumberGenerator state, stored for performance reasons
@export var random_state: int:
	get:
		return _rng.state
	set(v):
		_rng.state = v
		changed.emit()


## RandomNumberGenerator seed, stored for performance reasons
@export var random_seed: int:
	get:
		return _rng.seed
	set(v):
		_rng.seed = v
		changed.emit()


## Create workspace camera using this transform
@export var camera_transform: Transform3D = Transform3D():
	set(v):
		camera_transform = v
		changed.emit()

## Create workspace camera with this orthogonal size
@export var camera_orthogonal_size: float = 1.0:
	set(v):
		camera_orthogonal_size = v
		changed.emit()


## Used when duplicating an existing workspace from a .msep1 file
var suggested_path: String = ""


var _main_structure_int_guid: int = 0
var _id: int
var _reserved_int_guids: Dictionary = {} # {guid<int>: true}


func _init() -> void:
	# prevent changed and representation_settings_changed signals from being emmited
	# when executing _set_representation_settings
	set_block_signals(true)
	_set_representation_settings(representation_settings)
	set_block_signals(false)
	_id = instance_counter
	instance_counter += 1


## called by WorkspaceFormatLoader right after loading the Workspace
## at this point all loaded @exported variables are available
func post_load() -> void:
	if _main_structure_int_guid != INVALID_STRUCTURE_ID:
		return
	# Rebuild the reserved id list
	# Main structure is the only one without a parent
	for structure_id: int in _structures:
		var structure: NanoStructure = _structures[structure_id]
		_reserved_int_guids[structure.int_guid] = true
		if structure.int_parent_guid == INVALID_STRUCTURE_ID:
			_main_structure_int_guid = structure_id


func get_nmb_of_structures() -> int:
	return _structures.size()


func get_structures() -> Array[NanoStructure]:
	var structures: Array[NanoStructure] = []
	structures.assign(_structures.values())
	return structures


func get_main_structure() -> NanoStructure:
	return get_structure_by_int_guid(main_structure_int_guid)


func get_main_structure_guid() -> int:
	return main_structure_int_guid


## This function is meant to be used for debug purposes
func print_structure_tree() -> void:
	print("===  ", get_user_friendly_name(), "  ===")
	for structure: NanoStructure in get_root_child_structures():
		_print_structure(structure, 0)
	print("=== /", get_user_friendly_name(), "/ ===")


func _print_structure(in_structure: NanoStructure, in_depth: int) -> void:
	var indent: String = "--".repeat(in_depth)
	print(indent," (", in_structure.get_type(), ") ", in_structure.get_structure_name())
	for child: NanoStructure in get_child_structures(in_structure):
		_print_structure(child, in_depth + 1)


func get_user_friendly_name() -> String:
	var user_friendly_name: String = resource_path.get_basename()
	if user_friendly_name.is_empty():
		if suggested_path.is_empty():
			user_friendly_name = "Unsaved Workspace"
		else:
			user_friendly_name = suggested_path.get_basename()
	return user_friendly_name


func change_bond_visibility(new_bond_visibility: bool) -> void:
	representation_settings.set_bond_visibility_and_notify(new_bond_visibility)


func get_string_id() -> String:
	return str(_id)


## Return a structure with matching int_guid or null if not found
func get_structure_by_int_guid(in_int_guid: int) -> NanoStructure:
	if in_int_guid <= 0:
		push_error("Invalid unique ID")
		return null
	return _structures.get(in_int_guid, null)


func has_structure(in_nano_structure: NanoStructure) -> bool:
	assert(is_instance_valid(in_nano_structure), "Invalid guid")
	return has_structure_with_int_guid(in_nano_structure.int_guid)


## Returns true if the workspace contains a structure with matching int_guid
func has_structure_with_int_guid(int_guid: int) -> bool:
	assert(int_guid > INVALID_STRUCTURE_ID, "Invalid unique ID")
	return _structures.has(int_guid)


## Adds a structure to the workspace. If in_parent is not null it sets the
## parenthood relationship
func add_structure(in_structure: NanoStructure, in_parent: NanoStructure = null) -> void:
	_internal_add_structure(in_structure, in_parent)
	structure_added.emit(in_structure)


func _internal_add_structure(in_structure: NanoStructure, in_parent: NanoStructure = null) -> void:
	if in_structure == null:
		push_error("Cannot add null structure")
		return
	if in_structure.get_type() == StringName():
		push_error("Invalid in_structure type")
		return
	if in_structure.int_guid <= 0:
		# initialize in_structure identifier
		in_structure.int_guid = create_int_guid()
		if _main_structure_int_guid == 0:
			_main_structure_int_guid = in_structure.int_guid
	_structures[in_structure.int_guid] = in_structure
	if in_parent != null:
		assert(_structures.has(in_parent.int_guid), "Parent structure is not part of the workspace")
		in_structure.int_parent_guid = in_parent.int_guid
	in_structure.set_representation_settings(representation_settings)
	if not in_structure.renamed.is_connected(_on_nano_structure_renamed):
		in_structure.renamed.connect(_on_nano_structure_renamed.bind(in_structure))


func reparent_structure(in_structure: NanoStructure, in_parent: NanoStructure = null) -> void:
	assert(_structures.has(in_structure.int_guid), "structure is not part of the workspace")
	assert(in_parent == null or _structures.has(in_parent.int_guid), "parent structure is not part of the workspace")
	var parent_guid: int = 0 if in_parent == null else in_parent.int_guid
	if in_structure.int_parent_guid == parent_guid:
		# Nothing to do here
		return
	in_structure.int_parent_guid = parent_guid
	structure_reparented.emit(in_structure, in_parent)


func remove_structure(struct: NanoStructure) -> void:
	if struct == null:
		push_error("Cannot add null structure")
		return
	if struct.get_type() == StringName():
		push_error("Invalid struct type")
		return
	if !_structures.has(struct.get_int_guid()):
		push_error("Can't remove unregistered structure")
		return
	if struct.renamed.is_connected(_on_nano_structure_renamed):
		struct.renamed.disconnect(_on_nano_structure_renamed)
	structure_about_to_remove.emit(struct)
	_structures.erase(struct.get_int_guid())
	_reserved_int_guids.erase(struct.get_int_guid())
	structure_removed.emit(struct)


func get_child_structures(in_parent: NanoStructure) -> Array[NanoStructure]:
	assert(in_parent != null and _structures.has(in_parent.int_guid), "parent structure is not part of the workspace")
	var out_child_structures: Array[NanoStructure] = []
	for structure_id: int in _structures:
		var structure: NanoStructure = _structures[structure_id]
		if structure.int_parent_guid == in_parent.int_guid:
			out_child_structures.append(structure)
	return out_child_structures


func get_descendant_structures(in_parent: NanoStructure) -> Array[NanoStructure]:
	assert(in_parent != null and _structures.has(in_parent.get_int_guid()), "parent structure is not part of the workspace")
	var out_descendant_structures: Array[NanoStructure] = []
	for structure_id: int in _structures:
		var structure: NanoStructure = _structures[structure_id]
		if is_a_ancestor_of_b(in_parent, structure):
			out_descendant_structures.append(structure)
	return out_descendant_structures


func get_root_child_structures() -> Array[NanoStructure]:
	var out_root_children: Array[NanoStructure] = []
	for structure_id: int in _structures:
		var structure: NanoStructure = _structures[structure_id]
		if structure.int_parent_guid == 0:
			out_root_children.append(structure)
	return out_root_children


func get_parent_structure(in_child: NanoStructure) -> NanoStructure:
	assert(_structures.has(in_child.int_guid), "child is not part of the workspace")
	if in_child.int_parent_guid == 0:
		return null
	return get_structure_by_int_guid(in_child.int_parent_guid)


func is_a_ancestor_of_b(in_ancestor_candidate: NanoStructure, in_descendant_candidate: NanoStructure) -> bool:
	assert(has_structure_with_int_guid(in_ancestor_candidate.int_guid), "in_ancestor_candidate is not part of the workspace")
	assert(has_structure_with_int_guid(in_descendant_candidate.int_guid), "in_descendant_candidate is not part of the workspace")
	if in_ancestor_candidate == in_descendant_candidate:
		return false
	var structure: NanoStructure = get_parent_structure(in_descendant_candidate) as NanoStructure
	while structure != null:
		if structure == in_ancestor_candidate:
			return true
		structure = get_parent_structure(structure)
	return false


func create_int_guid() -> int:
	var is_valid: bool = false
	var int_id: int = 0
	while !is_valid:
		# int_id must be in 32 bit range since we are using PackedInt32Array across the project
		int_id = _rng.randi_range(0, MAX_SIGNED_32_BIT_INT)
		
		if int_id <= 0 || _reserved_int_guids.has(int_id):
			continue
		is_valid = true
	_reserved_int_guids[int_id] = true
	return int_id


func _set_representation_settings(out_representation_settings: RepresentationSettings) -> void:
	if representation_settings != null and representation_settings.changed.is_connected(_on_representation_settings_changed_internal):
		representation_settings.changed.disconnect(_on_representation_settings_changed_internal)
		representation_settings.bond_visibility_changed.disconnect(_on_bond_visibility_settings_changed)
	representation_settings = out_representation_settings
	if representation_settings != null:
		representation_settings.changed.connect(_on_representation_settings_changed_internal)
		representation_settings.bond_visibility_changed.connect(_on_bond_visibility_settings_changed)
		for structure_id: int in _structures:
			var structure: NanoStructure = _structures[structure_id]
			structure.set_representation_settings(representation_settings)
		changed.emit()
		representation_settings_changed.emit()


func _on_representation_settings_changed_internal() -> void:
	# Forward the signal
	representation_settings_changed.emit()


func _on_bond_visibility_settings_changed(_visible: bool) -> void:
	bond_settings_changed.emit(representation_settings)


func _on_nano_structure_renamed(in_new_name: String, in_nano_structure: NanoStructure) -> void:
	structure_renamed.emit(in_nano_structure, in_new_name)


# # # # # # #
# # Snapshots
func create_state_snapshot() -> Dictionary:
	var structures_snapshot: Dictionary = {}
	for structure_id: int in _structures:
		var structure: NanoStructure = _structures[structure_id]
		var structure_snapshot: Dictionary = structure.create_state_snapshot()
		structures_snapshot[structure_id] = structure_snapshot
	
	var snapshot: Dictionary = {
		"structures_snapshot" : structures_snapshot,
		"representation_settings" : representation_settings.create_state_snapshot(),
		"simulation_parameters" : simulation_parameters.create_state_snapshot(),
		"msep_version_history" : msep_version_history.duplicate(),
		"main_structure_int_guid" : main_structure_int_guid,
		"description" : description,
		"authors" : authors,
		"camera_transform" : camera_transform,
		"suggested_path" : suggested_path,
		"_main_structure_int_guid" : _main_structure_int_guid,
		"_reserved_int_guids" : _reserved_int_guids,
		"_id" : _id
	}
	return snapshot


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	var structure_state: Dictionary = in_snapshot["structures_snapshot"]
	for snapshot_structure_id: int in structure_state:
		var structure_snapshot: Dictionary = structure_state[snapshot_structure_id]
		
		if not _structures.has(snapshot_structure_id):
			# need to create from snapshot
			var nano_struct_path: String = structure_snapshot["script.resource_path"]
			var nano_structure: NanoStructure = load(nano_struct_path).new()
			nano_structure.set_representation_settings(representation_settings)
			nano_structure.apply_state_snapshot(structure_snapshot)
			_structures[snapshot_structure_id] = nano_structure
			continue
		
		if _structures.has(snapshot_structure_id):
			_structures[snapshot_structure_id].apply_state_snapshot(structure_snapshot)
	
	for structure_id: int in _structures.keys():
		if structure_state.has(structure_id):
			continue
		
		var structure: NanoStructure = _structures[structure_id]
		MolecularEditorContext.get_workspace_context(self).get_rendering().remove(structure)
		_structures.erase(structure_id)
	
	representation_settings.apply_state_snapshot(in_snapshot["representation_settings"])
	simulation_parameters.apply_state_snapshot(in_snapshot["simulation_parameters"])
	msep_version_history = in_snapshot["msep_version_history"].duplicate()
	main_structure_int_guid = in_snapshot["main_structure_int_guid"]
	description = in_snapshot["description"]
	authors = in_snapshot["authors"]
	camera_transform = in_snapshot["camera_transform"]
	suggested_path = in_snapshot["suggested_path"]
	_main_structure_int_guid = in_snapshot["_main_structure_int_guid"]
	_id = in_snapshot["_id"]
	_reserved_int_guids = in_snapshot["_reserved_int_guids"]
