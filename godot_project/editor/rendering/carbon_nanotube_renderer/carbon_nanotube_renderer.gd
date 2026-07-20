class_name CarbonNanotubeRenderer
extends Node3D


@export var material: ShaderMaterial


@onready var _camera: Camera3D = get_viewport().get_camera_3d()
@onready var _path_representation: Control = %PathRepresentation
@onready var _tube: Node3D = $Tube


var _workspace_context: WorkspaceContext
var _structure_id: int
var _visible: bool = true
var _simplified_representation_visible: bool = true
var _is_simulating: bool = false
var _should_hide_in_simulation: bool = false
var _is_selectable: bool = true
var _tube_start: Vector3
var _tube_end: Vector3
var _tube_basis: Basis
var _tube_radius: float = 1.0
var _control_point_override: Dictionary[int, Vector3]

var _hover_disabled: bool = false
var _hovered_control_point: int = -1
var _is_top_level: bool = true
var _path_hovered: bool = false
var _highlighted_control_points: Dictionary[int, bool] = {}

var _camera_last_transform: Transform3D
var _camera_last_zoom: float
var _camera_last_projection: Camera3D.ProjectionType


func _enter_tree() -> void:
	var editor_viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
	if not is_instance_valid(editor_viewport):
		return
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if not workspace_context.editable_structure_context_list_changed.is_connected(_on_editable_structure_context_list_changed):
		workspace_context.editable_structure_context_list_changed.connect(_on_editable_structure_context_list_changed)
		workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)
		var representation_settings: RepresentationSettings = workspace_context.workspace.representation_settings
		representation_settings.nanotube_representation_changed.connect(_on_nanotube_representation_changed)
		_on_nanotube_representation_changed(representation_settings.get_nanotube_representation())

func _ready() -> void:
	_path_representation.draw.connect(_on_path_representation_drawn)
	_tube.get_node("Cylinder").material_override = material


func build(in_workspace_context: WorkspaceContext, in_structure: CarbonNanotubeStructure) -> void:
	_structure_id = in_structure.get_int_guid()
	_workspace_context = in_workspace_context
	_tube_start = in_structure.get_control_point_position(0)
	_tube_end = in_structure.get_control_point_position(1)
	_tube_basis = in_structure.get_repetition_transform(0).basis
	ScriptUtils.call_deferred_once(_update_simplified_representation)
	ScriptUtils.call_deferred_once(_update_simplified_representation_colors)
	_ensure_structure_signal_connections(in_structure)
	
	_is_simulating = _workspace_context.is_simulating()
	_should_hide_in_simulation = _workspace_context.workspace.representation_settings \
			.get_should_hide_virtual_object_during_simulation(CarbonNanotubeStructure)
	_workspace_context.workspace.representation_settings \
		.should_hide_virtual_object_during_simulation_changed \
		.connect(_on_should_hide_virtual_object_during_simulation_changed)
	_workspace_context.simulation_started.connect(_on_simulation_started_or_finished.bind(true))
	_workspace_context.simulation_finished.connect(_on_simulation_started_or_finished.bind(false))


func _ensure_structure_signal_connections(in_structure: CarbonNanotubeStructure) -> void:
	if not in_structure.visibility_changed.is_connected(_on_object_visibility_changed):
		in_structure.path_changed.connect(_on_tube_path_changed)
		in_structure.chiral_indices_changed.connect(_on_tube_chiral_indices_changed.unbind(2))
		in_structure.visibility_changed.connect(_on_object_visibility_changed)


func apply_theme(_in_theme: Theme3D) -> void:
	_update_simplified_representation_colors()


func apply_schema(_in_new_color_schema: PeriodicTable.ColorSchema) -> void:
	_update_simplified_representation_colors()


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


func highlight_control_points(in_control_points_to_highlight: PackedInt32Array) -> void:
	if in_control_points_to_highlight.is_empty(): return
	for p in in_control_points_to_highlight:
		_highlighted_control_points[p] = true
	ScriptUtils.call_deferred_once(_update_simplified_representation)
	_update_simplified_representation_selection()
	queue_redraw()


func lowlight_control_points(in_control_points_to_lowlight: PackedInt32Array) -> void:
	if in_control_points_to_lowlight.is_empty(): return
	for p in in_control_points_to_lowlight:
		_highlighted_control_points.erase(p)
	ScriptUtils.call_deferred_once(_update_simplified_representation)
	_update_simplified_representation_selection()
	queue_redraw()


func set_control_point_selection_position_delta(in_selection_delta: Vector3) -> void:
	queue_redraw()
	if in_selection_delta == Vector3():
		_control_point_override.clear()
		return
	var points_to_transform: PackedInt32Array = _highlighted_control_points.keys()
	var original_positions := PackedVector3Array([_tube_start, _tube_end])
	for p: int in points_to_transform:
		var original_pos: Vector3 = original_positions[p]
		var transformed_pos: Vector3 = original_pos + in_selection_delta
		_control_point_override[p] = transformed_pos


func rotate_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	queue_redraw()
	if in_rotation_to_apply == Basis():
		_control_point_override.clear()
		return
	var points_to_transform: PackedInt32Array = _highlighted_control_points.keys()
	var original_positions := PackedVector3Array([_tube_start, _tube_end])
	for p: int in points_to_transform:
		var original_pos: Vector3 = original_positions[p]
		var local_to_axis: Vector3 = original_pos - in_point
		var rotated: Vector3 = in_rotation_to_apply * local_to_axis
		var transformed_pos: Vector3 = rotated + in_point
		_control_point_override[p] = transformed_pos


func queue_redraw() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_path_representation.queue_redraw()


func _update_simplified_representation() -> void:
	if !_visible or !_simplified_representation_visible or is_queued_for_deletion():
		_tube.hide()
		return
	if _is_simulating and _should_hide_in_simulation:
		_tube.hide()
		return
	_tube.show()
	var nanotube_structure: CarbonNanotubeStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as CarbonNanotubeStructure
	_tube_radius = nanotube_structure.get_estimated_diameter() / 2.0
	_tube.global_transform = nanotube_structure.get_repetition_transform(0)
	_tube.global_transform.basis.x *= _tube_radius
	_tube.global_transform.basis.y *= _tube_radius
	_tube.global_transform.basis.z *= nanotube_structure.get_tube_length()
	var t_len: float = nanotube_structure._basis.get_translational_vector_length()
	var rep: float = nanotube_structure.get_tube_length() / t_len
	material.set_shader_parameter(&"n", nanotube_structure.get_chiral_index_n())
	material.set_shader_parameter(&"m", nanotube_structure.get_chiral_index_m())
	material.set_shader_parameter(&"nprime", nanotube_structure._basis._nprime)
	material.set_shader_parameter(&"mprime", nanotube_structure._basis._mprime)
	material.set_shader_parameter(&"repetitions", rep)


func _update_simplified_representation_colors() -> void:
	var nanotube_structure: CarbonNanotubeStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as CarbonNanotubeStructure
	var representation_settings: RepresentationSettings = nanotube_structure.get_representation_settings()
	var color_schema: PeriodicTable.ColorSchema = representation_settings.get_color_schema()
	var color_palette: PeriodicTableColorPalette = PeriodicTable.PALETTES[color_schema]
	var bond_color: Color = color_palette.get_bond_color_for_element(PeriodicTable.ATOMIC_NUMBER_CARBON)
	var theme: Theme3D = representation_settings.get_theme()
	var highlight_color: Color = theme.get_highlight_color()
	if representation_settings.get_custom_selection_outline_color_enabled():
		highlight_color = representation_settings.get_custom_selection_outline_color()
	material.set_shader_parameter(&"atom_color", bond_color)
	material.set_shader_parameter(&"highlight_color", highlight_color)


func _update_simplified_representation_selection() -> void:
	var selection: PackedFloat32Array
	selection.append(_highlighted_control_points.get(0, 0.0))
	selection.append(_highlighted_control_points.get(1, 0.0))
	material.set_shader_parameter(&"selection", selection)


#region: SignalHandlers
func _on_path_representation_drawn() -> void:
	if is_queued_for_deletion() or not _visible or not _is_selectable:
		return
	if (_is_simulating and _should_hide_in_simulation):
		return
	var from_3d: Vector3 = _control_point_override.get(0, _tube_start)
	var to_3d: Vector3 = _control_point_override.get(1, _tube_end)
	if _simplified_representation_visible:
		var atom_color: Color = material.get_shader_parameter(&"atom_color")
		var highlight_color: Color = material.get_shader_parameter(&"highlight_color")
		var col: Color = highlight_color if _highlighted_control_points.get(0, false) else atom_color
		var width: int = 3 if _highlighted_control_points.get(0, false) else 2
		_draw_cylinder_cap(from_3d, col, width)
		col = highlight_color if _highlighted_control_points.get(1, false) else atom_color
		width = 3 if _highlighted_control_points.get(1, false) else 2
		_draw_cylinder_cap(to_3d, col, width)
	var from: Vector2 = _camera.unproject_position(from_3d)
	var to: Vector2 = _camera.unproject_position(to_3d)
	var path_width: int = 2
	if _highlighted_control_points.size() > 0:
		path_width = 4
	const ONE_PIXEL_SQUARED = 1.0
	if from.distance_squared_to(to) < ONE_PIXEL_SQUARED:
		# Watching from the side, ensure axis is visible why drawing a dot
		_path_representation.draw_circle(from, 1, _get_outline_color())
	else:
		_path_representation.draw_line(from, to, _get_outline_color(), path_width)
	if _is_top_level == false:
		return
	if not _path_hovered and _hovered_control_point == -1 and _highlighted_control_points.is_empty():
		return
	const CONTROL_POINT_RADIUS: float = 5
	_path_representation.draw_circle(from, CONTROL_POINT_RADIUS + 1, Color.BLACK)
	_path_representation.draw_circle(from, CONTROL_POINT_RADIUS, _get_control_point_color(0))
	_path_representation.draw_circle(to, CONTROL_POINT_RADIUS + 1, Color.BLACK)
	_path_representation.draw_circle(to, CONTROL_POINT_RADIUS, _get_control_point_color(1))


func _draw_cylinder_cap(in_position: Vector3, in_color: Color, in_width: int) -> void:
	const MIN_STEPS: float = 8
	var step_size: float = (2.0 * PI) / MIN_STEPS
	var angle: float = 0
	var points: PackedVector2Array
	var colors: PackedColorArray
	while angle < 2.0 * PI:
		var offset: Vector3 = _tube_basis.y.rotated(_tube_basis.z, angle) * _tube_radius
		var next_point: Vector2 = _camera.unproject_position(in_position + offset)
		const MAX_BAKE_DISTANCE_IN_PIXELS_SQUARED = 6.0
		while points.size() > 0 and points[-1].distance_squared_to(next_point) > MAX_BAKE_DISTANCE_IN_PIXELS_SQUARED:
			# Divide the arc in more steps
			# This should ensure smothness without sacrifice performance
			step_size *= 0.5
			angle -= step_size
			offset = _tube_basis.y.rotated(_tube_basis.z, angle) * _tube_radius
			next_point = _camera.unproject_position(in_position + offset)
		points.append(next_point)
		colors.append(in_color)
		angle += step_size
	_path_representation.draw_polyline_colors(points, colors, in_width)


func _get_outline_color() -> Color:
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var color: Color = representation_settings.get_theme().get_highlight_color()
	if representation_settings.get_custom_selection_outline_color_enabled():
		color = representation_settings.get_custom_selection_outline_color()
	var is_hovered: bool = _path_hovered and _hover_disabled == false
	var has_selection: bool = _highlighted_control_points.size() > 0
	if is_hovered or has_selection:
		return color
	color.a = 0.5
	return color


func _get_control_point_color(in_index: int) -> Color:
	const CONTROL_POINT_COLOR := Color.DEEP_PINK
	const CONTROL_POINT_COLOR_HOVER := Color.GOLD
	const CONTROL_POINT_COLOR_HIGHLIGHTED := Color.CHARTREUSE
	var color: Color = CONTROL_POINT_COLOR
	if _highlighted_control_points.get(in_index, false):
		color = CONTROL_POINT_COLOR_HIGHLIGHTED
	elif _hovered_control_point == in_index:
		color = CONTROL_POINT_COLOR_HOVER
	return color


func _on_should_hide_virtual_object_during_simulation_changed(in_type: StringName, in_should_hide: bool) -> void:
	if in_type == RepresentationSettings.script_to_virtual_object_key(CarbonNanotubeStructure):
		_should_hide_in_simulation = in_should_hide
		if _is_simulating:
			queue_redraw()
			ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_simulation_started_or_finished(in_is_simulating: bool) -> void:
	_is_simulating = in_is_simulating
	queue_redraw()
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_tube_path_changed(from: Vector3, to: Vector3) -> void:
	_tube_start = from
	_tube_end = to
	var nanotube: CarbonNanotubeStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as CarbonNanotubeStructure
	if nanotube:
		_tube_basis = nanotube.get_repetition_transform(0).basis
	queue_redraw()
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_object_visibility_changed(in_is_visible: bool) -> void:
	_visible = in_is_visible
	queue_redraw()
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_tube_chiral_indices_changed() -> void:
	queue_redraw()
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_nanotube_representation_changed(representation: RepresentationSettings.NanotubeRepresentation) -> void:
	_simplified_representation_visible = representation == RepresentationSettings.NanotubeRepresentation.SIMPLIFIED
	ScriptUtils.call_deferred_once(_update_simplified_representation)


func _on_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_is_top_level = false
	_is_selectable = false
	var current: StructureContext = _workspace_context.get_current_structure_context()
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.get_int_guid() == _structure_id:
			_is_selectable = true
			_is_top_level = context == current or _workspace_context.get_toplevel_editable_context(context) == context
			break
	#const SELECTABLE_VALUE: float = 1.0
	#const UNSELECTABLE_VALUE: float = 0.0
	#_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if _is_selectable else UNSELECTABLE_VALUE)
	if not _is_selectable:
		_path_hovered = false
		queue_redraw()


func _on_hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
			hovered_structure_context: StructureContext, _atom_id: int, _bond_id: int, _spring_id: int,
			in_control_point_idx: int) -> void:
	var nanotube_structure: CarbonNanotubeStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as CarbonNanotubeStructure
	_path_hovered = false
	_hovered_control_point = -1
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(nanotube_structure) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, nanotube_structure):
		_path_hovered = true
		_hovered_control_point = in_control_point_idx
	elif is_instance_valid(hovered_structure_context):
		_path_hovered = nanotube_structure == hovered_structure_context.nano_structure
		if _path_hovered:
			_hovered_control_point = in_control_point_idx
	queue_redraw()
#endregion: SignalHandlers


#region: UndoRedo
func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_visible"] = _visible
	snapshot["_should_hide_in_simulation"] = _should_hide_in_simulation
	snapshot["_simplified_representation_visible"] = _simplified_representation_visible
	snapshot["_is_selectable"] = _is_selectable
	snapshot["_is_top_level"] = _is_top_level
	snapshot["_tube_start"] = _tube_start
	snapshot["_tube_end"] = _tube_end
	snapshot["_tube_basis"] = _tube_basis
	snapshot["_tube_radius"] = _tube_radius
	snapshot["_highlighted_control_points"] = _highlighted_control_points.duplicate()
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_workspace_context = in_state_snapshot["_workspace_context"]
	_structure_id = in_state_snapshot["_structure_id"]
	_visible = in_state_snapshot["_visible"]
	_should_hide_in_simulation = in_state_snapshot["_should_hide_in_simulation"]
	_simplified_representation_visible = in_state_snapshot["_simplified_representation_visible"]
	_is_selectable = in_state_snapshot["_is_selectable"]
	_is_top_level = in_state_snapshot["_is_top_level"]
	_tube_start = in_state_snapshot["_tube_start"]
	_tube_end = in_state_snapshot["_tube_end"]
	_tube_basis = in_state_snapshot["_tube_basis"]
	_tube_radius = in_state_snapshot["_tube_radius"]
	_highlighted_control_points = in_state_snapshot["_highlighted_control_points"].duplicate()
	ScriptUtils.call_deferred_once(_update_simplified_representation)
	ScriptUtils.call_deferred_once(_update_simplified_representation_colors)
	ScriptUtils.call_deferred_once(_update_simplified_representation_selection)
	var nanotube: CarbonNanotubeStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as CarbonNanotubeStructure
	_ensure_structure_signal_connections(nanotube)
#endregion: UndoRedo
