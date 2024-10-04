## Feature Flag Manager, class that enables developers and testers to toggle features.
## Check example on this file on how to use it.

extends Window
@export var shortcut_feature_flag_manager: Shortcut
@export var EntryScene: PackedScene
const FEATURE_FLAG_BASE_PATH = "feature_flags"


@onready var always_on_top_button: CheckButton = %AlwaysOnTopButton as CheckButton
@onready var scroll_container: ScrollContainer = $ScrollContainer as ScrollContainer
@onready var feature_flag_container: Container = %FFContainer as Container
@onready var background: TextureRect = $Background as TextureRect

# const with the full path of the feature, under Project Settings
# Keep them in alphabetical order:
const FEATURE_FLAG_DISPLAY_GIZMO := &"feature_flags/display_gizmo"
const FEATURE_FLAG_ENABLE_VISUAL_MENU_ON_ALL_PLATFORMS := &"feature_flags/enable_visual_menu_on_all_platforms"
const FEATURE_FLAG_SHOW_ATOM_RENDERING_PROPERTIES_VIEW := &"feature_flags/show_rendering_atom_properties_view"
const FEATURE_FLAG_TOGGLE_BACKGROUND := &"feature_flags/show_irritating_background"
const SHOW_INPUT_OVERLAY := &"feature_flags/show_input_overlay"
const USE_DARK_BACKGROUND_ENVIRONMENT_FLAG = &"feature_flags/use_dark_background_environment"
const SHOW_ASYNC_PROCESS_ELAPSED_TIME = &"feature_flags/show_async_process_elapsed_time"
const RELAX_EDITABLE_TEMPERATURE = &"feature_flags/relax_editable_temperature"
const TEMPERATURE_IN_FAHRENHEIT = &"feature_flags/temperature_in_fahrenheit"
const FEATURE_FLAG_VIRTUAL_MOTORS = &"feature_flags/virtual_motors"
const FEATURE_FLAG_VIRTUAL_MOTORS_SIMULATION_WARNING = &"feature_flags/virtual_motors_simulation_warning"
const FEATURE_FLAG_VIRTUAL_SPRINGS = &"feature_flags/virtual_springs"
const FEATURE_FLAG_APPLY_WORKSPACE_VERSION_FIXES = &"feature_flags/apply_workspace_version_fixes"
const FEATURE_FLAG_LMDB_STRUCTURE = &"feature_flags/use_lmdb_structure"
const FEATURE_FLAGS_ALLOW_SCALE_WIDGETS = &"feature_flags/allow_scale_widgets"
const FEATURE_FLAGS_ALLOW_CREATE_SMALL_MOLECULES_IN_NEW_GROUP = &"feature_flags/allow_create_small_molecules_in_new_group"

var irritating_bg: Texture = preload("res://autoloads/feature_flag_manager/assets/seamless_floral_background.png")
var slightly_less_irritating_bg: Texture = preload("res://autoloads/feature_flag_manager/assets/seamless_flamingo_background.png")

## A map that holds a reference for the FeatureFlagView
var _featureflag_view_map: Dictionary = {
#	feature_name<String> = view<Control>
}

## Connect to this signal anywhere in the lifecycle of the application and
## listen for the specific feature flag as desired. 
signal on_feature_flag_toggled(path: String, new_value: bool)

func _ready() -> void:
	if not OS.is_debug_build():
		shortcut_feature_flag_manager = null
		
	_populate_featureflag_view_map()
	close_requested.connect(_on_close_requested)
	# Connect to the feature flag 
	on_feature_flag_toggled.connect(_on_feature_flag_toggled)
	always_on_top_button.toggled.connect(_on_always_on_top_button_toggled)
	hide()

func _on_always_on_top_button_toggled(in_button_pressed: bool) -> void:
	always_on_top = in_button_pressed

func toggle() -> void:
	if visible:
		hide()
	else:
		popup_centered_ratio(.5)

func get_flag_value(in_path: String) -> bool:
	assert(_featureflag_view_map.has(in_path))
	return _featureflag_view_map[in_path].get_current_toggle()


func _populate_featureflag_view_map() -> void:
	var entries: Array[String] = []
	_clear()
	for entry: Dictionary in ProjectSettings.get_property_list():
		if entry.name.begins_with(FEATURE_FLAG_BASE_PATH):
			entries.append(entry.name)
	for entry: String in entries:
		var initial_value: Variant = ProjectSettings.get_setting(entry)
		var current_feature_flag_entry_view: Control = EntryScene.instantiate()
		feature_flag_container.add_child(current_feature_flag_entry_view)
		var split_path: PackedStringArray = entry.split("/")
		current_feature_flag_entry_view.setup(split_path[split_path.size() - 1]
			.capitalize(), initial_value)
		current_feature_flag_entry_view.value_toggled.connect( _on_value_toggled.bind(entry))
		_featureflag_view_map[entry] = current_feature_flag_entry_view

func _clear() -> void:
	_clear_view()

func _clear_view() -> void:
	for feature_flag_entry_view: Control in _featureflag_view_map.values():
		feature_flag_entry_view.queue_free()
	_featureflag_view_map.clear()

func _on_value_toggled(new_value: bool, path: String) -> void:
	on_feature_flag_toggled.emit(path, new_value)

func _on_close_requested() -> void:
	hide()

func _on_feature_flag_toggled(path: String, new_value: bool) -> void:
	if path != FEATURE_FLAG_TOGGLE_BACKGROUND:
		return
	if new_value:
		background.texture = irritating_bg
	else:
		background.texture = slightly_less_irritating_bg

func _unhandled_key_input(event: InputEvent) -> void:
## Workaround for the Shortcut object ignoring the pressed status and automatically closing
## this control as soon as it opens if you use the F12 shortcut.
	if shortcut_feature_flag_manager and shortcut_feature_flag_manager.matches_event(event) and not event.is_echo() and event.pressed:
		toggle()
