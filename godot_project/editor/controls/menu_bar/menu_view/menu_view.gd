extends NanoPopupMenu

signal request_hide

@export var shortcut_focus_on_visible_objects: Shortcut
@export var shortcut_focus_on_selected_objects: Shortcut
@export var shortcut_toggle_object_tree_view: Shortcut
@export var shortcut_hide_selected_objects: Shortcut
@export var shortcut_show_hidden_objects: Shortcut


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	set_item_shortcut(get_item_index(ID_FOCUS_ON_VISIBLE_OBJECTS), shortcut_focus_on_visible_objects, true)
	set_item_shortcut(get_item_index(ID_FOCUS_ON_SELECTED_OBJECTS), shortcut_focus_on_selected_objects, true)
	set_item_shortcut(get_item_index(ID_TOGGLE_OBJECT_TREE_VIEW), shortcut_toggle_object_tree_view, true)
	set_item_shortcut(get_item_index(ID_HIDE_SELECTED_OBJECTS), shortcut_hide_selected_objects)
	set_item_shortcut(get_item_index(ID_SHOW_HIDDEN_OBJECTS), shortcut_show_hidden_objects)
	if OS.is_debug_build():
		set_item_shortcut(get_item_index(ID_TOGGLE_FEATURE_FLAGS_MANAGER), FeatureFlagManager.shortcut_feature_flag_manager, true)
	else:
		# Removes entry from the menu if not on debug builds
		var separator_index: int = get_item_index(ID_DEBUG_FEATURES_SEPARATOR)
		remove_item(separator_index)
		var object_tree_view_index: int = get_item_index(ID_TOGGLE_OBJECT_TREE_VIEW)
		remove_item(object_tree_view_index)
		var feature_flag_index: int = get_item_index(ID_TOGGLE_FEATURE_FLAGS_MANAGER)
		remove_item(feature_flag_index)
		var algorithm_tweaks_index: int = get_item_index(ID_SHOW_ALGORITHM_TWEAKS)
		remove_item(algorithm_tweaks_index)


func _update_menu() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	_update_for_context(workspace_context)


func _update_for_context(in_context: WorkspaceContext) -> void:
	var has_context: bool = is_instance_valid(in_context)
	set_item_disabled(get_item_index(ID_FOCUS_ON_VISIBLE_OBJECTS), !has_context)
	set_item_disabled(get_item_index(ID_FOCUS_ON_SELECTED_OBJECTS), !has_context)
	set_item_disabled(get_item_index(ID_TOGGLE_OBJECT_TREE_VIEW), !has_context)
	set_item_disabled(get_item_index(ID_HIDE_SELECTED_OBJECTS), !has_context)
	set_item_disabled(get_item_index(ID_SHOW_HIDDEN_OBJECTS), !has_context)
	set_item_disabled(get_item_index(ID_OVERRIDE_DEFAULT_COLORS), !has_context)
	var visible_object_tree: bool = false
	if has_context:
		visible_object_tree = in_context.visible_object_tree
		var has_visible_objects: bool = in_context.get_visible_structure_contexts().size() > 0
		var has_selected_objects: bool = in_context.get_structure_contexts_with_selection().size() > 0
		var has_hidden_objects: bool = in_context.has_hidden_objects()
		set_item_disabled(get_item_index(ID_FOCUS_ON_VISIBLE_OBJECTS), !has_visible_objects)
		set_item_disabled(get_item_index(ID_FOCUS_ON_SELECTED_OBJECTS), !has_selected_objects)
		set_item_disabled(get_item_index(ID_HIDE_SELECTED_OBJECTS), !has_selected_objects)
		set_item_disabled(get_item_index(ID_SHOW_HIDDEN_OBJECTS), !has_hidden_objects)
		set_item_disabled(get_item_index(ID_OVERRIDE_DEFAULT_COLORS), !in_context.is_any_atom_selected())
		
		
		var current_representation: int = in_context.workspace.representation_settings.get_rendering_representation()
		set_item_disabled(get_item_index(ID_REPRESENTATION_VAN_DER_WAALS), \
			Rendering.Representation.VAN_DER_WAALS_SPHERES == current_representation)
		set_item_disabled(get_item_index(ID_REPRESENTATION_MECHANICAL_SIMULATION), \
			Rendering.Representation.MECHANICAL_SIMULATION == current_representation)
		set_item_disabled(get_item_index(ID_REPRESENTATION_STICKS), \
			Rendering.Representation.STICKS == current_representation)
		set_item_disabled(get_item_index(ID_REPRESENTATION_ENHANCED_STICKS), \
			Rendering.Representation.ENHANCED_STICKS == current_representation)
		set_item_disabled(get_item_index(ID_REPRESENTATION_BALLS_AND_STICKS), \
			Rendering.Representation.BALLS_AND_STICKS == current_representation)
	set_item_checked(get_item_index(ID_TOGGLE_OBJECT_TREE_VIEW), visible_object_tree)


func _on_id_pressed(in_id: int) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	var representation_settings: RepresentationSettings = workspace_context.workspace.representation_settings
	match in_id:
		ID_FOCUS_ON_VISIBLE_OBJECTS:
			assert(workspace_context)
			var focus_aabb: AABB = WorkspaceUtils.get_visible_objects_aabb(workspace_context)
			WorkspaceUtils.focus_camera_on_aabb(workspace_context, focus_aabb)
		ID_FOCUS_ON_SELECTED_OBJECTS:
			assert(workspace_context)
			var focus_aabb: AABB = WorkspaceUtils.get_selected_objects_aabb(workspace_context)
			WorkspaceUtils.focus_camera_on_aabb(workspace_context, focus_aabb)
		ID_HIDE_SELECTED_OBJECTS:
			assert(workspace_context)
			WorkspaceUtils.hide_selected_objects(workspace_context)
		ID_SHOW_HIDDEN_OBJECTS:
			assert(workspace_context)
			WorkspaceUtils.show_hidden_objects(workspace_context)
		ID_OVERRIDE_DEFAULT_COLORS:
			assert(workspace_context)
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(DynamicContextDocker.UNIQUE_DOCKER_NAME, &"Override Default Colors")
		ID_TOGGLE_OBJECT_TREE_VIEW:
			request_hide.emit()
			if !is_instance_valid(workspace_context):
				return
			workspace_context.visible_object_tree = !workspace_context.visible_object_tree
			var object_tree_view_index: int = get_item_index(ID_TOGGLE_OBJECT_TREE_VIEW)
			
			set_item_icon(object_tree_view_index,
				preload("res://editor/controls/dockers/workspace_docker/icons/icon_visible.svg")
				if workspace_context.visible_object_tree else
				preload("res://editor/controls/dockers/workspace_docker/icons/icon_hidden.svg")
			)
		ID_TOGGLE_FEATURE_FLAGS_MANAGER:
			request_hide.emit()
			FeatureFlagManager.toggle.call_deferred()
		ID_SHOW_ALGORITHM_TWEAKS:
			request_hide.emit()
			AlgorithmTweaks.show()
		ID_REPRESENTATION_VAN_DER_WAALS:
			representation_settings.set_rendering_representation(Rendering.Representation.VAN_DER_WAALS_SPHERES)
			representation_settings.emit_changed()
		ID_REPRESENTATION_MECHANICAL_SIMULATION:
			representation_settings.set_rendering_representation(Rendering.Representation.MECHANICAL_SIMULATION)
			representation_settings.emit_changed()
		ID_REPRESENTATION_STICKS:
			representation_settings.set_rendering_representation(Rendering.Representation.STICKS)
			representation_settings.emit_changed()
		ID_REPRESENTATION_ENHANCED_STICKS:
			representation_settings.set_rendering_representation(Rendering.Representation.ENHANCED_STICKS)
			representation_settings.emit_changed()
		ID_REPRESENTATION_BALLS_AND_STICKS:
			representation_settings.set_rendering_representation(Rendering.Representation.BALLS_AND_STICKS)
			representation_settings.emit_changed()
			representation_settings.set_bond_visibility_and_notify(true)
		ID_REPRESENTATION_ENHANCED_STICKS_AND_BALLS:
			representation_settings.set_rendering_representation(Rendering.Representation.ENHANCED_STICKS_AND_BALLS)
			representation_settings.emit_changed()
		ID_REPRESENTATION_SIZE_SETTINGS:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
		ID_THEME_3D:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
		ID_CAMERA_PROJECTION:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"MSEP Settings")
		ID_REPRESENTATION_SHOW_BONDS:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
		ID_REPRESENTATION_SHOW_ELEMENTS_LABEL:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")
		ID_REPRESENTATION_SHOW_HYDROGENS:
			request_hide.emit()
			MolecularEditorContext.request_workspace_docker_focus(WorkspaceSettingsDocker.UNIQUE_DOCKER_NAME, &"Representation Settings")


enum {
	ID_FOCUS_ON_VISIBLE_OBJECTS        = 0,
	ID_FOCUS_ON_SELECTED_OBJECTS       = 1,
#	Representation separator           = 3,
	ID_REPRESENTATION_VAN_DER_WAALS    = 4,
	ID_REPRESENTATION_MECHANICAL_SIMULATION = 5,
	ID_REPRESENTATION_STICKS           = 6,
	ID_REPRESENTATION_ENHANCED_STICKS  = 7,
	ID_REPRESENTATION_BALLS_AND_STICKS = 8,
	ID_REPRESENTATION_ENHANCED_STICKS_AND_BALLS = 9,
	ID_REPRESENTATION_SIZE_SETTINGS    = 10,
	ID_REPRESENTATION_SHOW_BONDS       = 15,
	ID_REPRESENTATION_SHOW_ELEMENTS_LABEL = 16,
	ID_REPRESENTATION_SHOW_HYDROGENS   = 17,
	ID_DEBUG_FEATURES_SEPARATOR        = 11,
	ID_TOGGLE_OBJECT_TREE_VIEW         = 12,
	ID_TOGGLE_FEATURE_FLAGS_MANAGER    = 13,
	ID_SHOW_ALGORITHM_TWEAKS           = 14,
	ID_HIDE_SELECTED_OBJECTS           = 18,
	ID_SHOW_HIDDEN_OBJECTS             = 19,
	ID_OVERRIDE_DEFAULT_COLORS         = 20,
	ID_THEME_3D                        = 21,
	ID_CAMERA_PROJECTION               = 22,
}
