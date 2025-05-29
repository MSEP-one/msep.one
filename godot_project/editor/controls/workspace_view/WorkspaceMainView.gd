class_name WorkspaceMainView extends Control

var editor_dockers: Dictionary #[StringName,WorkspaceDocker]

@onready var dock_area_left: Control = %DockAreaLeft
@onready var dock_area_right: Control = %DockAreaRight
@onready var editor_viewport_container: SubViewportContainer = %EditorViewportContainer
@onready var workspace_tools_container: Control = %WorkspaceToolsContainer
@onready var screen_capture_dialog: ConfirmationDialog = $ScreenCaptureDialog
@onready var quick_search_dialog: QuickSearchDialog = $QuickSearchDialog
@onready var _rendering_properties_editor_placeholder: InstancePlaceholder = $RenderingPropertiesEditorPlaceholder
@onready var _rendering_properties_editor: RenderingPropertiesEditor
@onready var _structure_selector_bar: Control = %StructureSelectorBar
@onready var _mode_selector: ModeSelector = %ModeSelector
@onready var _working_area_rect_control: Control = %WorkingAreaRectControl
@onready var _alerts_panel: AlertsPanel = %AlertsPanel


func _ready() -> void:
	instantiate_editor_dockers()
	_ready_deferred.call_deferred()
	FeatureFlagManager.on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	var show_rendering_properties_view: bool = FeatureFlagManager.get_flag_value(FeatureFlagManager.FEATURE_FLAG_SHOW_ATOM_RENDERING_PROPERTIES_VIEW)
	_refresh_rendering_properties_view(show_rendering_properties_view)
	var window: Window = get_window()
	window.size_changed.connect(_on_window_size_changed.bind(window))
	# initialize viewport area minimum size
	_on_window_size_changed(window)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_working_area_rect_control = %WorkingAreaRectControl
		editor_viewport_container = %EditorViewportContainer
		workspace_tools_container = %WorkspaceToolsContainer


func _ready_deferred() -> void:
	var viewport: WorkspaceEditorViewport = editor_viewport_container.editor_viewport
	var workspace_context: WorkspaceContext = editor_viewport_container.workspace_context
	var ring_menu: NanoRingMenu = null if viewport == null else viewport.get_ring_menu()
	ring_menu.set_context(NanoRingMenu.CONTEXT_MAIN)
	if workspace_context != null and not workspace_context.selection_in_structures_changed.is_connected(_on_workspace_context_selection_in_structures_changed):
		workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)
		workspace_context.started_creating_object.connect(_on_workspace_context_started_creating_object.bind(workspace_context))
		workspace_context.structure_about_to_remove.connect(_on_workspace_context_structure_about_to_remove.bind(workspace_context))
	_structure_selector_bar.initialize(workspace_context)
	_mode_selector.initialize(workspace_context)
	_alerts_panel.initialize(workspace_context)


func _on_window_size_changed(in_window: Window) -> void:
	if is_instance_valid(workspace_tools_container):
		workspace_tools_container.custom_minimum_size.x = in_window.size.x * 0.5


func _on_workspace_context_selection_in_structures_changed(in_contexts: Array[StructureContext]) -> void:
	if in_contexts.is_empty() or in_contexts[0].workspace_context == null:
		return
	var workspace_context: WorkspaceContext = in_contexts[0].workspace_context
	ScriptUtils.call_deferred_once(_update_dockers_visibility.bind(workspace_context))


func _on_workspace_context_started_creating_object(in_workspace_context: WorkspaceContext) -> void:
	ScriptUtils.call_deferred_once(_update_dockers_visibility.bind(in_workspace_context))


func _on_workspace_context_structure_about_to_remove(_in_structure: NanoStructure, in_workspace_context: WorkspaceContext) -> void:
	ScriptUtils.call_deferred_once(_update_dockers_visibility.bind(in_workspace_context))


func _update_dockers_visibility(in_workspace_context: WorkspaceContext) -> void:
	if in_workspace_context == null:
		return
	for docker: WorkspaceDocker in editor_dockers.values():
		docker._update_visibility(docker.should_show(in_workspace_context))


func _on_feature_flag_toggled(in_path: String, in_val: bool) -> void:
	if in_path == FeatureFlagManager.FEATURE_FLAG_SHOW_ATOM_RENDERING_PROPERTIES_VIEW:
		_refresh_rendering_properties_view(in_val)


func _refresh_rendering_properties_view(in_show_properties_view: bool) -> void:
	var need_to_remove_rendering_properties_editor: bool = not in_show_properties_view and \
			is_instance_valid(_rendering_properties_editor)
	var need_to_create_rendering_properties_editor: bool = in_show_properties_view and \
			not is_instance_valid(_rendering_properties_editor)
	if need_to_remove_rendering_properties_editor:
		_rendering_properties_editor.queue_free()
	elif need_to_create_rendering_properties_editor:
		_rendering_properties_editor = _rendering_properties_editor_placeholder.create_instance()


const DEFAULT_WORKSPACE_EDITOR_DOCKERS = [
	preload
	("res://editor/controls/dockers/workspace_docker/a_create_docker/create_docker.tscn"),
	preload
	("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_docker.tscn"),
	preload
	("res://editor/controls/dockers/workspace_docker/groups_docker/groups_docker.tscn"),
	preload
	("res://editor/controls/dockers/workspace_docker/simulations_docker/simulations_docker.tscn"),
	preload
	("res://editor/controls/dockers/workspace_docker/e_workspace_settings_docker/workspace_settings_docker.tscn")
]
func instantiate_editor_dockers() -> void:
	for docker_scene: PackedScene in DEFAULT_WORKSPACE_EDITOR_DOCKERS:
		var node: WorkspaceDocker = docker_scene.instantiate()
		_add_docker(node, docker_scene.resource_path)


func _add_docker(in_node: WorkspaceDocker, in_resource_path: NodePath) -> void:
	var editor := Editor_Utils.get_editor() as MolecularEditor
	assert(is_instance_valid(editor))
	var editor_layout: MolecularEditor.EditorLayoutSettings = editor.editor_layout
	var unique_name: StringName = in_node.get_unique_docker_name()
	assert(unique_name != StringName(), "Invalid unique_name %s for EditorDocker '%s'" % \
			[str(unique_name), in_resource_path])
	var dock_area: int = editor_layout.dock_areas.get(unique_name, in_node.get_default_docker_area())
	if dock_area == WorkspaceDocker.DOCK_AREA_HIDDEN:
		in_node.queue_free()
	else:
		if dock_area < WorkspaceDocker.DOCK_AREA_RIGHT_TOP_LEFT:
			# Located in the left area
			dock_area_left.add_dock(in_node, dock_area)
		else:
			# Located in the right area
			dock_area_right.add_dock(in_node, dock_area)
		editor_dockers[unique_name] = in_node


func get_box_selection() -> BoxSelection:
	return editor_viewport_container.get_box_selection()


func get_alerts_panel() -> AlertsPanel:
	return _alerts_panel


func get_camera() -> Camera3D:
	return editor_viewport_container.editor_viewport.get_camera_3d()


func get_working_area_rect_control() -> Control:
	return _working_area_rect_control



func set_camera_global_transform(in_transform: Transform3D) -> void:
	var camera: Camera3D = get_camera()
	camera.global_transform = in_transform


func get_camera_global_transform() -> Transform3D:
	return get_camera().global_transform


func set_camera_orthogonal_size(in_orthogonal_size: float) -> void:
	get_camera().size = in_orthogonal_size


func get_camera_orthogonal_size() -> float:
	return get_camera().size


func bottom_bar_update_distance(in_message_text: String, in_distance: float) -> void:
	editor_viewport_container.bottom_bar_update_distance(in_message_text, in_distance)
