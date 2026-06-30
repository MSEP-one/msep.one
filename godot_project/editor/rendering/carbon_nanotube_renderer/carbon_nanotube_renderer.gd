class_name CarbonNanotubeRenderer
extends Node3D


@onready var _camera: Camera3D = get_viewport().get_camera_3d()
@onready var _path_representation: Control = %PathRepresentation


var _workspace_context: WorkspaceContext
var _structure_id: int
var _visible: bool = true
var _tube_start: Vector3
var _tube_end: Vector3

var _hover_disabled: bool = false
var _hovered_control_point: int = 0
var _highlighted_control_points: Dictionary[int, bool] = {}

var _camera_last_transform: Transform3D
var _camera_last_zoom: float
var _camera_last_projection: Camera3D.ProjectionType


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_path_representation.draw.connect(_on_path_representation_drawn)


func build(in_workspace_context: WorkspaceContext, in_structure: CarbonNanotubeStructure) -> void:
	_structure_id = in_structure.get_int_guid()
	_workspace_context = in_workspace_context
	_tube_start = in_structure.get_control_point(0)
	_tube_end = in_structure.get_control_point(1)
	in_structure.path_changed.connect(_on_tube_path_changed)
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func update(_delta: float) -> void:
	# Redraw if the camera is moving
	if is_instance_valid(_camera) and (
			_camera.global_transform != _camera_last_transform
			or _camera.size != _camera_last_zoom
			or _camera_last_projection != _camera.projection):
		_camera_last_transform = _camera.global_transform
		_camera_last_zoom = _camera.size
		_camera_last_projection = _camera.projection
		queue_redraw()


func disable_hover() -> void:
	_hover_disabled = true
	queue_redraw()

func queue_redraw() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_path_representation.queue_redraw()


func _update_simplified_representation() -> void:
	# TODO
	pass


#region: SignalHandlers
func _on_path_representation_drawn() -> void:
	if not _visible:
		return
	var from: Vector2 = _camera.unproject_position(_tube_start)
	var to: Vector2 = _camera.unproject_position(_tube_end)
	var colors: PackedColorArray = []
	colors.append(_get_control_point_color(0))
	colors.append(_get_control_point_color(1))
	_path_representation.draw_polyline_colors([from, to], colors, 4)
	_path_representation.draw_circle(from, 8, colors[0])
	_path_representation.draw_circle(to, 8, colors[1])


func _get_control_point_color(in_index: int) -> Color:
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var color: Color = representation_settings.get_theme().get_highlight_color()
	if representation_settings.get_custom_selection_outline_color_enabled():
		color = representation_settings.get_custom_selection_outline_color()
	var is_hovered: bool = _hover_disabled == false and _hovered_control_point == in_index
	var has_selection: bool = _highlighted_control_points.get(in_index, false) == true
	if is_hovered or has_selection:
		return color
	if color.v > 0.7:
		color = color.darkened(0.5)
	else:
		color = color.lightened(0.7)
	return color


func _on_tube_path_changed(from: Vector3, to: Vector3) -> void:
	_tube_start = from
	_tube_end = to
	queue_redraw()
	ScriptUtils.call_deferred_once(_update_simplified_representation)
#endregion: SignalHandlers


#region: UndoRedo
func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_visible"] = _visible
	snapshot["_tube_start"] = _tube_start
	snapshot["_tube_end"] = _tube_end
	snapshot["_highlighted_control_points"] = _highlighted_control_points.duplicate()
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_workspace_context = in_state_snapshot["_workspace_context"]
	_structure_id = in_state_snapshot["_structure_id"]
	_visible = in_state_snapshot["_visible"]
	_tube_start = in_state_snapshot["_tube_start"]
	_tube_end = in_state_snapshot["_tube_end"]
	_highlighted_control_points = in_state_snapshot["_highlighted_control_points"].duplicate()
#endregion: UndoRedo
