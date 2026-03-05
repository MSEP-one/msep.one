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
const FEATURE_FLAG_ENABLE_VISUAL_MENU_ON_ALL_PLATFORMS := &"feature_flags/enable_visual_menu_on_all_platforms"
const FEATURE_FLAG_SHOW_ATOM_RENDERING_PROPERTIES_VIEW := &"feature_flags/show_rendering_atom_properties_view"
const SHOW_INPUT_OVERLAY := &"feature_flags/show_input_overlay"
const FEATURE_FLAG_EMITTERS_WITH_EMIT_COUNT = &"feature_flags/particle_emitters_with_emit_count"
const FEATURE_FLAG_EMITTERS_SHOW_UNSPAWNED_INSTANCES = &"feature_flags/particle_emitters_show_unspawned_instanes"
const FEATURE_FLAG_LMDB_STRUCTURE = &"feature_flags/use_lmdb_structure"
const FEATURE_FLAGS_ALLOW_SCALE_WIDGETS = &"feature_flags/allow_scale_widgets"
const FEATURE_FLAGS_MSEP_ONLINE = &"feature_flags/msep_online"
const FEATURE_FLAGS_MSEP_ONLINE_STUB_SERVICE = &"feature_flags/msep_online_stub_service"
const FEATURE_FLAGS_MSEP_ONLINE_RUN_TESTS = &"feature_flags/msep_online_run_tests"
const FEATURE_FLAGS_DNA_BUILDER_DEV_TOOL = &"feature_flags/dna_builder_dev_tool"
const FEATURE_FLAGS_TOOLTIP_SHOW_IDS = &"feature_flags/tooltip_show_ids"


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


func set_flag_value(in_path: String, in_value: bool) -> void:
	_featureflag_view_map[in_path].set_value(in_value)


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


func _unhandled_key_input(event: InputEvent) -> void:
## Workaround for the Shortcut object ignoring the pressed status and automatically closing
## this control as soon as it opens if you use the F12 shortcut.
	if shortcut_feature_flag_manager and shortcut_feature_flag_manager.matches_event(event) and not event.is_echo() and event.pressed:
		toggle()
