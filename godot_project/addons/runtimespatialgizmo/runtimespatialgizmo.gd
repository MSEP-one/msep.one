@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("GizmoRoot", "res://addons/runtimespatialgizmo/RuntimeSpatialGizmo/GizmoRoot.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("GizmoRoot")
