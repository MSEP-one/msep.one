"@abstract_class"
class_name NanoStructure extends Resource

signal renamed(new_name: String)
signal visibility_changed(_visible: bool)


## Visual representation of global unique id. Read only
@export var guid: StringName:
	get:
		if _guid == StringName():
			_guid = GUID_Utils.int_to_guid(int_guid)
		return _guid
	set(_v):
		pass # Read Only
var _guid: StringName


## Integer representation of global unique id. Read only
@export var int_guid: int = 0


## Visual representation of global unique id of the parent structure. Read only
@export var parent_guid: StringName:
	get:
		if int_parent_guid == 0:
			return StringName()
		if _parent_guid == StringName():
			_parent_guid = GUID_Utils.int_to_guid(int_parent_guid)
		return _parent_guid
	set(_v):
		pass # Read Only
var _parent_guid: StringName


## Integer representation of global unique id.
@export var int_parent_guid: int = 0

@export var _structure_name: String

## Should be rendered in the viewport
@export var _visible: bool = true


var _representation_settings: WeakRef = weakref(null) #WeakRef[RepresentationSettings]


func set_representation_settings(_in_representation_settings: RepresentationSettings) -> void:
	_representation_settings = weakref(_in_representation_settings)


func get_representation_settings() -> RepresentationSettings:
	return _representation_settings.get_ref()


func get_int_guid() -> int:
	return int_guid


## Structure types needs to return a valid type name to be considered valid
func get_type() -> StringName:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return StringName()


func get_readable_type() -> String:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return StringName()


func set_structure_name(new_name: String) -> void:
	if _structure_name == new_name:
		return
	_structure_name = new_name
	renamed.emit(_structure_name)


func get_structure_name() -> String:
	return _structure_name


func set_visible(new_visibility: bool) -> void:
	_visible = new_visibility
	visibility_changed.emit(_visible)


func get_visible() -> bool:
	return _visible


## Returns true if the object is not a group of particles. Ex: Shapes, Motors, Springs
func is_virtual_object() -> bool:
	return self is NanoShape or self.get_type() in \
			[&"RotaryMotor", &"LinearMotor", &"Spring", &"AnchorPoint"]

## Returns a texture to represent the structure in the UI, it can be a predefined
## icon or a thumbnail of the actual structure
func get_icon() -> Texture2D:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return null


## When this function returns [code]true[/code] then the TransformGizmo can change it's position
## and rotation using the `NanoStructure.transform` property (in example NanoShape and NanoVirtualMotor returns true)
func has_transform() -> bool:
	return &"_transform" in self


## Unlike Resource.duplicate(subresources=true) this method will make sure Arrays and Dictionaries
## of resources will also contain a duplicate of the collected subresource
func safe_duplicate() -> NanoStructure:
	"""You can override this method for a different result"""
	return self.duplicate(true)


func get_aabb() -> AABB:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return AABB()


# Note: this function is meant to be used inside an assert
# assert(_ensure_id_is_not_virtual(in_structure_id), "Connecting virtual objects is not supported")
func _ensure_id_is_not_virtual(in_structure_id: int) -> bool:
	# assuming connection only happens on an active workspace
	var current_workspace: Workspace = MolecularEditorContext.get_current_workspace()
	var structure: NanoStructure = current_workspace.get_structure_by_int_guid(in_structure_id)
	return _ensure_structure_is_not_virtual(structure)


func _ensure_structure_is_not_virtual(in_structure: NanoStructure) -> bool:
	return not in_structure.is_virtual_object()


## Called when importing a workspace, before the structures are actually added.
## Because the all the structure ids have changed, any reference to external
## structures must be updated.
## in_structure_map: {old_structure_id<int> : new_structure<NanoStructure>}
func init_remap_structure_ids(_in_structures_map: Dictionary) -> void:
	pass


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = {}
	state_snapshot["int_guid"] = int_guid
	state_snapshot["guid"] = guid
	state_snapshot["parent_guid"] = _parent_guid
	state_snapshot["int_parent_guid"] = int_parent_guid
	state_snapshot["_structure_name"] = _structure_name
	state_snapshot["_visible"] = _visible
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	int_guid = in_state_snapshot["int_guid"]
	guid = in_state_snapshot["guid"]
	_parent_guid = in_state_snapshot["parent_guid"]
	int_parent_guid = in_state_snapshot["int_parent_guid"]
	_structure_name = in_state_snapshot["_structure_name"]
	_visible = in_state_snapshot["_visible"]
