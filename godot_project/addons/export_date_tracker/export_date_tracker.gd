@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin = null

func _get_plugin_name() -> String:
	return "Export Version Tracker"

func _enter_tree() -> void:
	_export_plugin = load("res://addons/export_date_tracker/editor_export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)

