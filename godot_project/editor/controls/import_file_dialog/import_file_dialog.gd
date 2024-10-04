class_name ImportFileDialog extends NanoFileDialog


enum Placement {
	KEEP_ORIGINAL,
	IN_FRONT_OF_CAMERA,
	CENTER_ON_ORIGIN
}


const _MAIN_CONTAINER_INTERNAL_INDEX = 3
const ImportSettingsScn: PackedScene = preload("res://editor/controls/import_file_dialog/import_settings.tscn")

var _main_container: VBoxContainer = null
var _import_settings: VBoxContainer = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		hide()
		# Godot overrides title and OK text when instancing the dialog
		# Because of that we manually set it from code
		title = tr(&"Select a file")
		ok_button_text = tr(&"Import")
		_main_container = get_child(_MAIN_CONTAINER_INTERNAL_INDEX, true) as VBoxContainer
		assert(_main_container)
		_import_settings = ImportSettingsScn.instantiate()
		_main_container.add_child(_import_settings)


func is_autogenerate_bonds_enabled() -> bool:
	return _import_settings.is_autogenerate_bonds_enabled()


func is_add_missing_hydrogens_enabled() -> bool:
	return _import_settings.is_add_missing_hydrogens_enabled()


func is_remove_waters_enabled() -> bool:
	return _import_settings.is_remove_waters_enabled()


func is_create_new_group_enabled() -> bool:
	return _import_settings.is_create_new_group_enabled()


func get_desired_placement() -> Placement:
	return _import_settings.get_desired_placement() as Placement
