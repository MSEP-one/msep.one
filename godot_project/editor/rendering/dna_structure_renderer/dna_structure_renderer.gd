@tool
class_name DnaStructureRenderer extends Path3D


const StrandPolicy = DnaStructure.StrandPolicy


@export_group("Materials")
@export var a_strand_material: ShaderMaterial
@export var b_strand_material: ShaderMaterial
@export var base_pivot_material: ShaderMaterial


@export_group("Editor Debug", "_")
@export_custom(PROPERTY_HINT_ENUM, "A,B,DOUBLE", PROPERTY_USAGE_EDITOR)
var _strand_policy := StrandPolicy.DOUBLE:
	set = set_strand_policy
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR)
var _sequence: String:
	set = set_sequence
@export_custom(PROPERTY_HINT_RANGE, "0.1,2.0,0.05,or_greater", PROPERTY_USAGE_EDITOR)
var _rise_nanometers: float = 0.34:
	set = set_rise_nanometers
@export_custom(PROPERTY_HINT_RANGE, "0.5,1.5,0.05,or_greater", PROPERTY_USAGE_EDITOR)
var _dna_radius: float = 1.0:
	set = set_dna_radius
@export_custom(PROPERTY_HINT_RANGE, "5,15,0.1,or_greater,or_less", PROPERTY_USAGE_EDITOR)
var _bases_per_turn: float = 10:
	set = set_bases_per_turn 
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1", PROPERTY_USAGE_EDITOR)
var _initial_twist_degrees: float:
	set = _set_initial_twist_degrees,
	get = _get_initial_twist_degrees
var _initial_twist: float
@export_group("")


var _workspace_context: WorkspaceContext
var _structure_id: int
var _object_visible: bool = true
var _bases: Array[DnaBaseRepresentation]
var _applying_snapshot: bool = false
var _updating_parameters: bool = false

# hovering API
var _hover_enabled: bool = true
var _is_selectable: bool = true
var _path_hovered: bool = false
var _path_highlighted: bool = false
var _path_being_edited: bool = false
var _edit_mode: DnaStructure.EditMode
var _hovered_control_point: int = -1
var _highlighted_control_points: Dictionary[int, bool] = {}

@onready var _transform_helper: PathFollow3D = %TransformHelper
@onready var _path_representation: Control = %PathRepresentation


# Transform gizmo tools
# while transform gizmo is in use, _temp_curve will create a duplicate of dna's curve
# when transformation is applied, renderer retakes the curve from the object and _temp_curve is freed
var _original_curve: Curve3D = null
var _temp_curve: Curve3D = null

# Track camera changes
var _camera: Camera3D
var _camera_last_transform: Transform3D
var _camera_last_zoom: float
var _camera_last_projection: Camera3D.ProjectionType


func _ready() -> void:
	_update_bases()
	_transform_helper.progress_ratio = 1
	curve_changed.connect(_on_curve_changed)
	_path_representation.draw.connect(_on_path_representation_drawn)
	_camera = get_viewport().get_camera_3d()


func _process(_delta: float) -> void:
	# Redraw if the camera is moving
	if is_instance_valid(_camera) and (
			_camera.global_transform != _camera_last_transform
			or _camera.size != _camera_last_zoom
			or _camera_last_projection != _camera.projection):
		_camera_last_transform = _camera.global_transform
		_camera_last_zoom = _camera.size
		_camera_last_projection = _camera.projection
		queue_redraw()


func build(in_workspace_context: WorkspaceContext, in_structure: DnaStructure) -> void:
	_workspace_context = in_workspace_context
	_structure_id = in_structure.get_int_guid()
	in_structure.grab_curve(self)
	_updating_parameters = true
	_strand_policy = in_structure.get_strand_policy()
	_sequence = in_structure.get_sequence()
	_rise_nanometers = in_structure.get_rise_nanometers()
	_dna_radius = in_structure.get_dna_radius_nanometers()
	_bases_per_turn = in_structure.get_bases_per_turn()
	_initial_twist = in_structure.get_initial_twist_rad()
	_edit_mode = in_structure.get_edit_mode()
	_updating_parameters = false
	_update_bases()
	_ensure_structure_signal_connections(in_structure)


func _enter_tree() -> void:
	var editor_viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
	if not is_instance_valid(editor_viewport):
		return
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if not workspace_context.editable_structure_context_list_changed.is_connected(_on_editable_structure_context_list_changed):
		workspace_context.current_structure_context_changed.connect(_on_current_structure_context_changed)
		workspace_context.editable_structure_context_list_changed.connect(_on_editable_structure_context_list_changed)
		workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)
		workspace_context.selection_in_structures_changed.connect(_on_workspace_context_selection_in_structures_changed)


func _ensure_structure_signal_connections(in_structure: DnaStructure) -> void:
	if not in_structure.sequence_changed.is_connected(_on_sequence_changed):
		in_structure.sequence_changed.connect(_on_sequence_changed)
		in_structure.parameters_changed.connect(_on_parameters_changed)
		in_structure.visibility_changed.connect(_on_structure_visibility_changed)
		in_structure.edit_mode_changed.connect(_on_edit_mode_changed)


func _on_sequence_changed(in_sequence: String) -> void:
	set_sequence(in_sequence)
	_path_representation.queue_redraw()


func _on_parameters_changed(in_parameters: DnaStructureParameters) -> void:
	_updating_parameters = true
	_strand_policy = in_parameters.strand_policy
	_rise_nanometers = in_parameters.rise_nanometers
	_dna_radius = in_parameters.dna_radius_nanometers
	_bases_per_turn = in_parameters.bases_per_turn
	_initial_twist = in_parameters.initial_twist_rad
	_updating_parameters = false
	_update_bases()
	_path_representation.queue_redraw()


func _on_structure_visibility_changed(in_visible: bool) -> void:
	_object_visible = in_visible
	_update_visibility()


func _on_edit_mode_changed(in_mode: DnaStructure.EditMode) -> void:
	_edit_mode = in_mode
	_update_visibility()


func _on_curve_changed() -> void:
	assert(curve.point_count > 1, "Invalid curve, dna chain should be deleted in this case")
	_path_representation.queue_redraw()
	_transform_helper.progress_ratio = 1
	for base: DnaBaseRepresentation in _bases:
		base.set_deferred(&"base_offset", base.base_offset)


func highlight_control_points(in_control_points_to_highlight: PackedInt32Array) -> void:
	if in_control_points_to_highlight.is_empty(): return
	for p in in_control_points_to_highlight:
		_highlighted_control_points[p] = true
	_path_representation.queue_redraw()


func lowlight_control_points(in_control_points_to_lowlight: PackedInt32Array) -> void:
	if in_control_points_to_lowlight.is_empty(): return
	for p in in_control_points_to_lowlight:
		_highlighted_control_points.erase(p)
	_path_representation.queue_redraw()


func set_selection_position_delta(in_selection_delta: Vector3) -> void:
	queue_redraw()
	if in_selection_delta == Vector3():
		_reset_temp_curve()
		return
	_setup_temp_curve()
	var points_to_transform: PackedInt32Array = range(curve.point_count)
	var needs_recalculate_in_out: bool = false
	if _path_being_edited:
		needs_recalculate_in_out = _highlighted_control_points.size() != curve.point_count
		points_to_transform = _highlighted_control_points.keys()
	var inout_positions_to_update: Dictionary[int, bool]
	for p: int in points_to_transform:
		var original_pos: Vector3 = _original_curve.get_point_position(p)
		var transformed_pos: Vector3 = original_pos + in_selection_delta
		_temp_curve.set_point_position(p, transformed_pos)
		inout_positions_to_update[p - 1] = true
		inout_positions_to_update[p] = true
		inout_positions_to_update[p + 1] = true
	if not needs_recalculate_in_out:
		# The entire curve is being edited, inout wont change
		return
	for p: int in inout_positions_to_update.keys():
		DnaStructure.recalculate_curve_in_out(_temp_curve, p)


func rotate_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis) -> void:
	queue_redraw()
	if in_rotation_to_apply == Basis():
		_reset_temp_curve()
		return
	_setup_temp_curve()
	var points_to_transform: PackedInt32Array = range(curve.point_count)
	if _path_being_edited:
		points_to_transform = _highlighted_control_points.keys()
	var inout_positions_to_update: Dictionary[int, bool]
	for p: int in points_to_transform:
		var original_pos: Vector3 = _original_curve.get_point_position(p)
		var local_to_axis: Vector3 = original_pos - in_point
		var rotated: Vector3 = in_rotation_to_apply * local_to_axis
		var transformed_pos: Vector3 = rotated + in_point
		_temp_curve.set_point_position(p, transformed_pos)
		inout_positions_to_update[p - 1] = true
		inout_positions_to_update[p] = true
		inout_positions_to_update[p + 1] = true
	for p: int in inout_positions_to_update.keys():
		DnaStructure.recalculate_curve_in_out(_temp_curve, p)


func _reset_temp_curve() -> void:
	if _temp_curve != null:
		curve = _original_curve
		_original_curve = null
		_temp_curve = null


func _setup_temp_curve() -> void:
	if _temp_curve == null:
		_original_curve = curve
		_temp_curve = curve.duplicate()
		# Assign _temp_curve to be used by PathFollow3D during transformation
		curve = _temp_curve


func get_curve_final_transform() -> Transform3D:
	return _transform_helper.transform


func set_strand_policy(in_strand_policy: StrandPolicy) -> void:
	if is_node_ready() and in_strand_policy == _strand_policy:
		return
	_strand_policy = in_strand_policy
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func set_sequence(in_sequence: String) -> void:
	if is_node_ready() and in_sequence == _sequence:
		return
	_sequence = in_sequence
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func set_rise_nanometers(in_rise: float) -> void:
	if is_node_ready() and _rise_nanometers == in_rise:
		return
	_rise_nanometers = in_rise
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func set_dna_radius(in_radius: float) -> void:
	if is_node_ready() and _dna_radius == in_radius:
		return
	_dna_radius = in_radius
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func set_bases_per_turn(in_bases_per_turn: float) -> void:
	if is_node_ready() and _bases_per_turn == in_bases_per_turn:
		return
	_bases_per_turn = in_bases_per_turn
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func _set_initial_twist_degrees(in_twist_degrees: float) -> void:
	_initial_twist_degrees = in_twist_degrees
	set_initial_twist(deg_to_rad(in_twist_degrees))


func _get_initial_twist_degrees() -> float:
	return rad_to_deg(_initial_twist)


func set_initial_twist(in_twist_rad: float) -> void:
	if is_node_ready() and in_twist_rad == _initial_twist:
		return
	_initial_twist = in_twist_rad
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	_update_bases()


func _update_bases() -> void:
	if _updating_parameters:
		return
	var base_count: int = _sequence.length()
	while _bases.size() > base_count:
		_bases.pop_back().queue_free()
	while _bases.size() < base_count:
		var base := DnaBaseRepresentation.create()
		base.setup_materials(a_strand_material, b_strand_material, base_pivot_material)
		add_child(base)
		_bases.append(base)
	
	var delta_angle: float = deg_to_rad(360) / _bases_per_turn
	
	for i in base_count:
		_bases[i].strand_policy = _strand_policy
		_bases[i].base = _sequence[i]
		_bases[i].base_offset = i * _rise_nanometers
		_bases[i].dna_radius = _dna_radius
		_bases[i].base_twist = _initial_twist + delta_angle * i


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	_hover_enabled = false
	queue_redraw()


func queue_redraw() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_path_representation.queue_redraw()


func _on_current_structure_context_changed(structure_context: StructureContext) -> void:
	_path_being_edited = structure_context.get_int_guid() == _structure_id
	_update_visibility()


func _on_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_is_selectable = false
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.get_int_guid() == _structure_id:
			_is_selectable = true
			break
	const SELECTABLE_VALUE: float = 1.0
	const UNSELECTABLE_VALUE: float = 0.0
	_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if _is_selectable else UNSELECTABLE_VALUE)
	


func _on_hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
			hovered_structure_context: StructureContext, _atom_id: int, _bond_id: int, _spring_id: int,
			in_dna_control_point_idx: int) -> void:
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	_path_hovered = false
	_hovered_control_point = -1
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(dna_structure) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, dna_structure):
		_path_hovered = true
		_hovered_control_point = in_dna_control_point_idx
	elif is_instance_valid(hovered_structure_context):
		_path_hovered = dna_structure == hovered_structure_context.nano_structure
		if _path_hovered:
			_hovered_control_point = in_dna_control_point_idx
	queue_redraw()


func _update_visibility() -> void:
	visible = _object_visible and _edit_mode == DnaStructure.EditMode.SequenceAndPath
	queue_redraw()


func _on_path_representation_drawn() -> void:
	if !visible or is_queued_for_deletion() or not _is_selectable or Engine.is_editor_hint():
		return
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	var path: PackedVector3Array = dna_structure.get_baked_path(_temp_curve)
	if path.is_empty():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var last_pos2d: Vector2 = camera.unproject_position(path[0])
	const MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS: float = 3 * 3
	var last_idx: int = path.size() - 1
	var path_width: int = 2
	if _path_highlighted or _path_being_edited:
		path_width = 4
	for i in range(1, path.size()):
		var pos2d: Vector2 = camera.unproject_position(path[i])
		if last_pos2d.distance_squared_to(pos2d) >= MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS or i == last_idx:
			_path_representation.draw_line(last_pos2d, pos2d, _get_outline_color(), path_width)
			last_pos2d = pos2d
	if not _path_being_edited:
		return
	var drawn_curve: Curve3D = curve if _temp_curve == null else _temp_curve
	for cp_idx: int in drawn_curve.point_count:
		var pos: Vector3 = drawn_curve.get_point_position(cp_idx)
		var pos2d: Vector2 = camera.unproject_position(pos)
		const CONTROL_POINT_RADIUS: float = 5
		const CONTROL_POINT_COLOR := Color.DEEP_PINK
		const CONTROL_POINT_COLOR_HOVER := Color.GOLD
		const CONTROL_POINT_COLOR_HIGHLIGHTED := Color.CHARTREUSE
		var color: Color = CONTROL_POINT_COLOR
		if _highlighted_control_points.get(cp_idx, false):
			color = CONTROL_POINT_COLOR_HIGHLIGHTED
		elif _hovered_control_point == cp_idx:
			color = CONTROL_POINT_COLOR_HOVER
		_path_representation.draw_circle(pos2d, CONTROL_POINT_RADIUS, color)


func _get_outline_color() -> Color:
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var color: Color = representation_settings.get_theme().get_highlight_color()
	if representation_settings.get_custom_selection_outline_color_enabled():
		color = representation_settings.get_custom_selection_outline_color()
	var is_hovered: bool = _path_hovered and _hover_enabled
	if is_hovered or _path_highlighted or _path_being_edited:
		return color
	color.a = 0.5
	return color


func _on_workspace_context_selection_in_structures_changed(out_structure_contexts: Array[StructureContext]) -> void:
	for context: StructureContext in out_structure_contexts:
		var is_this_strucutre: bool = context.nano_structure.int_guid == _structure_id
		if is_this_strucutre:
			var is_selected: bool = context.is_dna_structure_fully_selected()
			if is_selected != _path_highlighted:
				_path_highlighted = is_selected
				queue_redraw()


func _set_shader_uniform(in_uniform: StringName, in_value: Variant) -> void:
	a_strand_material.set_shader_parameter(in_uniform, in_value)
	b_strand_material.set_shader_parameter(in_uniform, in_value)
	base_pivot_material.set_shader_parameter(in_uniform, in_value)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_strand_policy"] = _strand_policy
	snapshot["_sequence"] = _sequence
	snapshot["_rise_nanometers"] = _rise_nanometers
	snapshot["_bases_per_turn"] = _bases_per_turn
	snapshot["_initial_twist"] = _initial_twist
	snapshot["_path_highlighted"] = _path_highlighted
	snapshot["_path_being_edited"] = _path_being_edited
	snapshot["_edit_mode"] = _edit_mode
	snapshot["_highlighted_control_points"] = _highlighted_control_points.duplicate()
	snapshot["_is_selectable"] = _is_selectable
	snapshot["_object_visible"] = _object_visible
	snapshot["_selectable_uniform"] = base_pivot_material.get_shader_parameter(&"is_selectable")
	var bases_snapshots: Array[Dictionary] = []
	for b: DnaBaseRepresentation in _bases:
		bases_snapshots.append(b.create_state_snapshot())
	snapshot["bases_snapshots"] = bases_snapshots
	return snapshot

func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_applying_snapshot = true
	_workspace_context = in_state_snapshot["_workspace_context"]
	_structure_id = in_state_snapshot["_structure_id"]
	_strand_policy = in_state_snapshot["_strand_policy"]
	_sequence = in_state_snapshot["_sequence"]
	_rise_nanometers = in_state_snapshot["_rise_nanometers"]
	_bases_per_turn = in_state_snapshot["_bases_per_turn"]
	_initial_twist = in_state_snapshot["_initial_twist"]
	_path_highlighted = in_state_snapshot["_path_highlighted"]
	_path_being_edited = in_state_snapshot["_path_being_edited"]
	_edit_mode = in_state_snapshot["_edit_mode"]
	_highlighted_control_points = in_state_snapshot["_highlighted_control_points"].duplicate()
	_is_selectable = in_state_snapshot["_is_selectable"]
	_object_visible = in_state_snapshot["_object_visible"]
	_set_shader_uniform(&"is_selectable", in_state_snapshot["_selectable_uniform"])
	var bases_snapshots: Array[Dictionary] = in_state_snapshot["bases_snapshots"]
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	dna_structure.grab_curve(self)
	while _bases.size() > bases_snapshots.size():
		_bases.pop_back().queue_free()
	while _bases.size() < bases_snapshots.size():
		var base := DnaBaseRepresentation.create()
		add_child(base)
		_bases.append(base)
	for i in bases_snapshots.size():
		_bases[i].apply_state_snapshot(bases_snapshots[i])
	_applying_snapshot = false
	_ensure_structure_signal_connections(dna_structure)
	_update_visibility()
