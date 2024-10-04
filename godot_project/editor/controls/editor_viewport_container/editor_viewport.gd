extends SubViewport
class_name WorkspaceEditorViewport

# region public API

## Actions whitelisted in this constant will be allowed even if input forwarding
## is disabled
const INPUT_EVENT_ACTIONS_WHITELIST: Array[StringName] = [
	&"camera_left",
	&"camera_forward",
	&"camera_back",
	&"camera_right",
	&"faster_camera",
	&"camera_orbit_modifier",
	&"camera_up",
	&"camera_down",
	&"toggle_ring_menu"
]

## Returns the WorkspaceContext associated to the active workspace
## Any node inside this viewport can access to it with the following code
## [code]
## var workspace_context: WorkspaceContext = get_viewport().get_workspace_context()
## [/code]
func get_workspace_context() -> WorkspaceContext:
	return _workspace_context


## Returns the object in charge of managing rendering of the workspace
func get_rendering() -> Rendering:
	return _rendering


func get_box_selection() -> BoxSelection:
	return _box_selection


# region internal

var _workspace_context: WorkspaceContext:
	set(v):
		if _workspace_context == v:
			return
		assert(_workspace_context == null and v != null, "This member should be assigned only once")
		_workspace_context = v
		_workspace_context.current_structure_context_changed.connect(_on_workspace_context_current_structure_context_changed)
		_box_selection.init(_workspace_context)
		_initialize()


@onready var _rendering: Rendering = $Rendering
@onready var _box_selection: BoxSelection = $ViewportOverlays/BoxSelection
@onready var _viewport_input: ViewportInput = $ViewportInput
@onready var _pause_input_timer: Timer = $PauseInputTimer
@onready var _orientation_widget: Node3D = get_parent().get_node("%OrientationWidget")
@onready var _camera_widget: CameraWidget = get_parent().get_camera_widget()

var workspace_tools_container: Control = null
var _input_forwarding_enabled: bool = true


func _ready() -> void:
	var main_view: WorkspaceMainView = get_parent().get_parent() as WorkspaceMainView
	assert(main_view, "main_view is not WorkspaceMainView, did the scene structure change?")
	workspace_tools_container = main_view.workspace_tools_container
	assert(workspace_tools_container, "workspace_tools_container is not assigned to main_view!")
	_configure_settings()


func _configure_settings() -> void:
	Settings.resolution_scale_changed.connect(_on_settings_resolution_scale_changed)
	Settings.scale_method_changed.connect(_on_settings_scale_method_changed)
	Settings.msaa2d_changed.connect(_on_settings_msaa2d_changed)
	Settings.screen_space_aa_changed.connect(_on_settings_screen_space_aa_changed)
	scaling_3d_mode = Settings.get_scale_method()
	scaling_3d_scale = Settings.get_resolution_scale()
	msaa_2d = Settings.get_msaa2d()
	screen_space_aa = Settings.get_screen_space_aa()


func _on_settings_resolution_scale_changed(new_scale: float) -> void:
	scaling_3d_scale = new_scale


func _on_settings_scale_method_changed(new_scale_method: Viewport.Scaling3DMode) -> void:
	scaling_3d_mode = new_scale_method


func _on_settings_msaa2d_changed(new_mssa2d: Viewport.MSAA) -> void:
	msaa_2d = new_mssa2d


func _on_settings_screen_space_aa_changed(new_screen_space_aa: Viewport.ScreenSpaceAA) -> void:
	screen_space_aa = new_screen_space_aa


func _initialize() -> void:
	_viewport_input.init(_workspace_context)


func get_orientation_widget() -> Node3D:
	return _orientation_widget


func get_ring_menu() -> NanoRingMenu:
	return get_parent().get_ring_menu()


func get_camera_widget() -> CameraWidget:
	return _camera_widget


func set_input_forwarding_enabled(in_enabled: bool) -> void:
	_input_forwarding_enabled = in_enabled
	if not in_enabled:
		_viewport_input.notify_input_omitted()


func has_exclusive_input_consumer() -> bool:
	return _viewport_input.has_exclusive_input_consumer()


func pause_inputs(duration: float) -> void:
	assert(duration > 0,
	"Pause input is meant to be used during fixed time animations," +
	" it requires a valid fixed duration")
	_pause_input_timer.start(duration)
	_viewport_input.notify_input_omitted()


func forward_viewport_input(event: InputEvent) -> void:
	if not is_instance_valid(_workspace_context):
		return
	
	if not _pause_input_timer.is_stopped():
		return
	if not _input_forwarding_enabled:
		var is_whitelisted: bool = false
		for action in INPUT_EVENT_ACTIONS_WHITELIST:
			if event.is_action(action):
				is_whitelisted = true
				break
		if not is_whitelisted:
			return
	_viewport_input.forward_viewport_input(event, self, _get_structure_context())


func _get_structure_context() -> StructureContext:
	var output: StructureContext = null
	if is_instance_valid(_workspace_context):
		if _workspace_context.is_creating_object():
			output = _workspace_context._current_create_object_structure_context
		else:
			output = _workspace_context.get_current_structure_context()
	if not is_instance_valid(output):
		output = null
	return output


func update(delta: float) -> void:
	_rendering.update(delta)


func _on_workspace_context_current_structure_context_changed(_in_context: StructureContext) -> void:
	var ring_menu: NanoRingMenu = get_ring_menu()
	if !is_instance_valid(ring_menu):
		return
	if !ring_menu.visible:
		# when ring menu is visible, the change is of the current context is a
		# consecuence of a ring menu action. In this case the action should
		# take care of changes in the menu
		ring_menu.clear()

