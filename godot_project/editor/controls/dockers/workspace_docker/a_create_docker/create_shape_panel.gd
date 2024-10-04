extends DynamicContextControl


@onready var shape_preview: Control = %ShapePreview
@onready var properties_container: Container = %PropertiesContainer
@onready var menu_selected_shape: MenuButton = %MenuSelectedShape
@onready var _preview_shape: NanoShape = NanoShape.new()
@onready var _preview_shape_renderer: NanoShapeRenderer = null
@onready var _dummy_workspace := Workspace.new()
@onready var _dummy_workspace_context := preload("res://project_workspace/workspace_context/workspace_context.tscn").instantiate()

var _workspace_context: WorkspaceContext = null
var _selected_shape: WeakRef = weakref(null)
var _shape_properties: Dictionary = {}
var _shape_property_controls: Array[Control] = []


func should_show(in_workspace_context: WorkspaceContext) -> bool:
	if !_is_workspace_context_initialized():
		_initialize_workspace_context(in_workspace_context)
	
	var check_object_being_created: Callable = func(in_struct: NanoStructure) -> bool:
		return in_struct is NanoShape
	
	if in_workspace_context.create_object_parameters.get_create_mode_type() \
			!= CreateObjectParameters.CreateModeType.CREATE_SHAPES:
		if in_workspace_context.is_creating_object() and \
				in_workspace_context.peek_object_being_created(check_object_being_created):
			in_workspace_context.abort_creating_object()
		return false
	
	if in_workspace_context.is_creating_object() and \
			not in_workspace_context.peek_object_being_created(check_object_being_created):
		# Another object is being created
		in_workspace_context.abort_creating_object()
	
	if not in_workspace_context.is_creating_object():
		in_workspace_context.start_creating_object(NanoShape.new())
	
	return true


func _initialize_preview_shape() -> void:
	_preview_shape.int_guid = 1234 # dummy value
	_preview_shape.is_ghost = true
	# Share representation settings with main workspace
	_dummy_workspace.representation_settings = _workspace_context.workspace.representation_settings
	_on_selected_shape_for_new_objects_changed(_preview_shape.get_shape())
	var rendering: Rendering = shape_preview.preview_viewport.get_rendering()
	_dummy_workspace_context._weak_workspace = weakref(_dummy_workspace)
	rendering.initialize(_dummy_workspace_context)
	assert(rendering, "Invalid preview scene")
	rendering.build_reference_shape_rendering(_preview_shape)
	_preview_shape_renderer = rendering.get_reference_shape_renderer("1234")
	
	if rendering.enabled:
		assert(_preview_shape_renderer, "Invalid preview renderer")

func _exit_tree() -> void:
	_preview_shape = null
	var shape: PrimitiveMesh = _selected_shape.get_ref()
	if is_instance_valid(shape) and shape.changed.is_connected(_on_shape_resource_changed):
		shape.changed.disconnect(_on_shape_resource_changed)
	shape = null
	_selected_shape = weakref(null)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_preview_shape_renderer = null
		_preview_shape = null

func _is_workspace_context_initialized() -> bool:
	return _workspace_context != null


func _initialize_workspace_context(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context
	_initialize_preview_shape()
	in_workspace_context.create_object_parameters.selected_shape_for_new_objects_changed.connect(_on_selected_shape_for_new_objects_changed)
	_on_selected_shape_for_new_objects_changed(in_workspace_context.create_object_parameters.get_selected_shape_for_new_objects())
	# Fill menu_selected_shape with known shapes
	var menu_popup: PopupMenu = menu_selected_shape.get_popup()
	menu_popup.clear()
	for i in range(in_workspace_context.create_object_parameters.supported_shapes.size()):
		var shape: PrimitiveMesh = in_workspace_context.create_object_parameters.supported_shapes[i]
		var item_name: String = shape.get_class().replace("Mesh", "")
		if shape.has_method(&"get_shape_name"):
			item_name = str(shape.get_shape_name())
		menu_popup.add_item(item_name, i)
	menu_popup.id_pressed.connect(_on_menu_selected_shape_id_pressed)


func _on_menu_selected_shape_id_pressed(in_id: int) -> void:
	if _workspace_context != null:
		var selected: Mesh = _workspace_context.create_object_parameters.supported_shapes[in_id]
		_workspace_context.create_object_parameters.set_selected_shape_for_new_objects(selected)


func _on_selected_shape_for_new_objects_changed(in_shape: PrimitiveMesh) -> void:
	_preview_shape.set_shape(in_shape)
	if _selected_shape.get_ref() != in_shape:
		_setup_selected_shape_properties(in_shape)
	menu_selected_shape.text = tr("None") if in_shape == null else str(_preview_shape.get_type())


func _setup_selected_shape_properties(in_shape: PrimitiveMesh) -> void:
	# Clear previous shape controls
	for control in _shape_property_controls:
		control.queue_free()
	_shape_property_controls.clear()
	var previous_shape: PrimitiveMesh = _selected_shape.get_ref()
	if previous_shape != null && previous_shape.changed.is_connected(_on_shape_resource_changed):
		previous_shape.changed.disconnect(_on_shape_resource_changed)
	_selected_shape = weakref(in_shape)
	if in_shape != null:
		if !in_shape.changed.is_connected(_on_shape_resource_changed):
			in_shape.changed.connect(_on_shape_resource_changed)
		_shape_properties = NanoShapeUtils.get_reference_shape_properties(in_shape)
		assert(_shape_properties.size() > 0, "Failed to obtain reference shape's size properties")
		for prop_name: StringName in _shape_properties.keys():
			var property: NanoShapeUtils.ShapeProperty = _shape_properties[prop_name]
			assert(property != null)
			var name_label: Control = _create_shape_property_label(prop_name, property.unit)
			name_label.name = str(prop_name).capitalize().replace(" ", "") + "Label"
			var editor: Control = NanoShapeUtils.create_shape_property_editor(property, false)
			properties_container.add_child(editor)
			_shape_property_controls.push_back(editor)
			editor.name = str(prop_name).capitalize().replace(" ", "")
		_update_preview_camera()


func _on_shape_resource_changed() -> void:
	_update_preview_camera()


func _create_shape_property_label(in_prop_name: StringName, in_unit: String) -> Control:
	var name_label: Label = Label.new()
	var suffix: String = "" if in_unit.is_empty() else (" (%s)" % in_unit)
	name_label.text = tr(str(in_prop_name)).capitalize() + suffix
	properties_container.add_child(name_label)
	_shape_property_controls.push_back(name_label)
	return name_label


func _update_preview_camera() -> void:
	var shape: PrimitiveMesh = _selected_shape.get_ref()
	if shape == null:
		return
	var aabb: AABB = shape.get_aabb().abs()
	shape_preview.set_preview_camera_pivot_position(aabb.get_center())
	shape_preview.set_preview_camera_distance_to_pivot(ceil(aabb.get_longest_axis_size()) * 3)
