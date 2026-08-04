extends NanoFileDialog


const _MAIN_CONTAINER_INTERNAL_INDEX = 3
const ExportSettingsScn: PackedScene = preload("uid://dtxfj1243co7v")


var _main_container: VBoxContainer = null
var _export_settings: VBoxContainer = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		hide()
		# Godot overrides title and OK text when instancing the dialog
		# Because of that we manually set it from code
		title = tr(&"Export a File")
		ok_button_text = tr(&"Save")
		if _export_settings == null:
			_main_container = get_child(_MAIN_CONTAINER_INTERNAL_INDEX, true) as VBoxContainer
			assert(_main_container)
			_export_settings = ExportSettingsScn.instantiate()
			_main_container.add_child(_export_settings)


func _ready() -> void:
	about_to_popup.connect(_on_about_to_popup)


func is_export_dna_enabled() -> bool:
	return _export_settings.is_export_dna_enabled()


func is_export_nanotube_enabled() -> bool:
	return _export_settings.is_export_nanotube_enabled()


func _on_about_to_popup() -> void:
	_export_settings.visible = _export_settings.should_show()


