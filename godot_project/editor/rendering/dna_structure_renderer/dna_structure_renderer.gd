@tool
class_name DnaStructureRenderer extends Path3D


const Strand = DnaStructure.Strand
const StrandPolicy = DnaStructure.StrandPolicy
const DnaRepresentation = RepresentationSettings.DnaRepresentation
const BackboneColorPolicy = DnaStructure.BackboneColorPolicy
const BasesColorPolicy = DnaStructure.BasesColorPolicy
const BasesColorSchema = DnaStructure.BasesColorSchema


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

@export var _default_material: ShaderMaterial

@onready var _backbone_a_strand: ShaderMaterial = _default_material.duplicate(false)
@onready var _backbone_b_strand: ShaderMaterial = _default_material.duplicate(false)
@onready var _base_a_strand: ShaderMaterial = _default_material.duplicate(false)
@onready var _base_b_strand: ShaderMaterial = _default_material.duplicate(false)
@onready var _base_per_type: Dictionary[StringName, ShaderMaterial] = {
	&"A" : _default_material.duplicate(false),
	&"T" : _default_material.duplicate(false),
	&"C" : _default_material.duplicate(false),
	&"G" : _default_material.duplicate(false),
}


var _workspace_context: WorkspaceContext
var _structure_id: int
var _current_representation: DnaRepresentation
var _object_visible: bool = true
var _bases: Array[DnaBaseRepresentation]
var _applying_snapshot: bool = false
var _updating_parameters: bool = false
# Color tracking
var _backbone_color_policy: BackboneColorPolicy
var _bases_color_policy: BasesColorPolicy
var _bases_color_schema: BasesColorSchema


# hovering API
var _hover_enabled: bool = true
var _is_selectable: bool = true
var _is_top_level: bool = true
var _path_hovered: bool = false
var _path_highlighted: bool = false
var _hovered_control_point: int = -1
var _should_hide_in_simulation: bool = false
var _is_simulating: bool = false
var _highlighted_control_points: Dictionary[int, bool] = {}

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

# Track atomic Representation
var _atomic_structure_renderer: AtomicStructureRenderer

func _ready() -> void:
	_update_bases()
	curve_changed.connect(_on_curve_changed)
	_path_representation.draw.connect(_on_path_representation_drawn)
	_camera = get_viewport().get_camera_3d()


func set_atomic_renderer(in_renderer: AtomicStructureRenderer) -> void:
	_atomic_structure_renderer = in_renderer


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
	_current_representation = in_structure.get_representation_settings().get_dna_representation()
	_backbone_color_policy = in_structure.get_backbone_color_policy()
	_bases_color_policy = in_structure.get_bases_color_policy()
	_bases_color_schema = in_structure.get_bases_color_schema()
	_updating_parameters = false
	_workspace_context.workspace.representation_settings \
		.should_hide_virtual_object_during_simulation_changed \
		.connect(_on_should_hide_virtual_object_during_simulation_changed)
	_workspace_context.simulation_started.connect(_on_simulation_started_or_finished.bind(true))
	_workspace_context.simulation_finished.connect(_on_simulation_started_or_finished.bind(false))
	_is_simulating = _workspace_context.is_simulating()
	_should_hide_in_simulation = _workspace_context.workspace.representation_settings \
			.get_should_hide_virtual_object_during_simulation(DnaStructure)
	_on_structure_colors_changed()
	_update_bases()
	_ensure_structure_signal_connections(in_structure)
	_update_visibility()
	_refresh_atomic_preview_selection()


func get_backbone_material(in_strand: Strand) -> ShaderMaterial:
	return _backbone_a_strand if in_strand == Strand.A else _backbone_b_strand


func get_base_material(in_strand: Strand, in_base: StringName) -> ShaderMaterial:
	match _bases_color_policy:
		BasesColorPolicy.BASES_NO_COLORS, \
		BasesColorPolicy.BASES_PER_STRAND, \
		BasesColorPolicy.BASES_MAJOR_MINOR_GROOVE:
			return _base_a_strand if in_strand == Strand.A else _base_b_strand
		BasesColorPolicy.BASES_PER_TYPE:
			assert(in_base in _base_per_type, "Unexpected base %s" % in_base)
			return _base_per_type[in_base]
	assert(false, "Unhandled case: BasesColorPolicy=%d Strand=%s Base=%s"
		% [_bases_color_policy, in_strand, in_base]
	)
	return null


func _enter_tree() -> void:
	var editor_viewport: WorkspaceEditorViewport = get_viewport() as WorkspaceEditorViewport
	if not is_instance_valid(editor_viewport):
		return
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if not workspace_context.editable_structure_context_list_changed.is_connected(_on_editable_structure_context_list_changed):
		workspace_context.editable_structure_context_list_changed.connect(_on_editable_structure_context_list_changed)
		workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)


func _ensure_structure_signal_connections(in_structure: DnaStructure) -> void:
	if not in_structure.sequence_changed.is_connected(_on_sequence_changed):
		in_structure.sequence_changed.connect(_on_sequence_changed)
		in_structure.parameters_changed.connect(_on_parameters_changed)
		in_structure.visibility_changed.connect(_on_structure_visibility_changed)
		in_structure.colors_changed.connect(_on_structure_colors_changed)
		
		var representation_settings: RepresentationSettings = in_structure.get_representation_settings()
		representation_settings.dna_representation_changed.connect(_on_dna_representation_changed)


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


func _on_structure_colors_changed() -> void:
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	# Base representation only needs to change materials when switching between
	# per-base and per-strand
	var prev_mat_is_per_base: bool = _bases_color_policy == BasesColorPolicy.BASES_PER_TYPE
	var new_mat_is_per_base: bool = dna_structure.get_bases_color_policy() == BasesColorPolicy.BASES_PER_TYPE
	# Update Policies and materials
	_backbone_color_policy = dna_structure.get_backbone_color_policy()
	_bases_color_policy = dna_structure.get_bases_color_policy()
	_bases_color_schema = dna_structure.get_bases_color_schema()
	var base_materials_changed: bool = prev_mat_is_per_base != new_mat_is_per_base
	if base_materials_changed:
		for base_representation in _bases:
			base_representation.update_materials(self)
	# Update Backbone Colors
	var colors: Dictionary[Strand, Color] = {
		Strand.A : DnaBaseColorPalette.DEFAULT_A_STRAND_COLOR,
		Strand.B : DnaBaseColorPalette.DEFAULT_B_STRAND_COLOR,
	}
	if _backbone_color_policy == BackboneColorPolicy.BACKBONE_PER_STRAND:
		colors[Strand.A] = dna_structure.get_backbone_strand_color(Strand.A)
		colors[Strand.B] = dna_structure.get_backbone_strand_color(Strand.B)
	_backbone_a_strand.set_shader_parameter(&"albedo", colors[Strand.A])
	_backbone_b_strand.set_shader_parameter(&"albedo", colors[Strand.B])
	# Update Bases colors
	if new_mat_is_per_base:
		var schema_colors: Dictionary[StringName, Color] = \
			DnaBaseColorPalette.get_schema_colors_or_empty(_bases_color_schema)
		for base_type: StringName in _base_per_type.keys():
			_base_per_type[base_type].set_shader_parameter(&"albedo",
				schema_colors.get(base_type, dna_structure.get_base_custom_colors(base_type)))
	else:
		if _bases_color_policy == BasesColorPolicy.BASES_PER_STRAND:
			colors[Strand.A] = dna_structure.get_bases_strand_colors(Strand.A)
			colors[Strand.B] = dna_structure.get_bases_strand_colors(Strand.B)
		else:
			colors[Strand.A] = DnaBaseColorPalette.DEFAULT_A_STRAND_COLOR
			colors[Strand.B] = DnaBaseColorPalette.DEFAULT_B_STRAND_COLOR
		_base_a_strand.set_shader_parameter(&"albedo", colors[Strand.A])
		_base_b_strand.set_shader_parameter(&"albedo", colors[Strand.B])


func _on_dna_representation_changed(in_representation: DnaRepresentation) -> void:
	_current_representation = in_representation
	if _current_representation == DnaRepresentation.SIMPLIFIED:
		_update_bases()
	_update_visibility()
	_refresh_atomic_preview_selection()


func _on_curve_changed() -> void:
	if _applying_snapshot:
		return
	assert(curve.point_count > 1, "Invalid curve, dna object should be deleted in this case")
	_path_representation.queue_redraw()
	if _current_representation == DnaRepresentation.SIMPLIFIED:
		_update_base_transforms()


func highlight_control_points(in_control_points_to_highlight: PackedInt32Array) -> void:
	if in_control_points_to_highlight.is_empty(): return
	var was_selected: bool = _highlighted_control_points.size() > 0
	for p in in_control_points_to_highlight:
		_highlighted_control_points[p] = true
	if not was_selected:
		_refresh_selection_preview(true)
	_path_representation.queue_redraw()


func lowlight_control_points(in_control_points_to_lowlight: PackedInt32Array) -> void:
	if in_control_points_to_lowlight.is_empty(): return
	var was_selected: bool = _highlighted_control_points.size() > 0
	for p in in_control_points_to_lowlight:
		_highlighted_control_points.erase(p)
	var is_selected: bool = _highlighted_control_points.size() > 0
	if was_selected != is_selected:
		_refresh_selection_preview(is_selected)
	_path_representation.queue_redraw()


func _refresh_selection_preview(in_is_selected: bool, in_starting_from_base: int = 0) -> void:
	for base_idx: int in range(in_starting_from_base, _bases.size()):
		_bases[base_idx].refresh_selection_preview(in_is_selected)
	_set_shader_uniform(&"is_selected", 1.0 if in_is_selected else 0.0)
	_refresh_atomic_preview_selection.call_deferred()


func _refresh_atomic_preview_selection() -> void:
	if _current_representation == DnaRepresentation.ATOMS_AND_BONDS and _atomic_structure_renderer:
		var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
		var has_selection: bool = _highlighted_control_points.size() > 0
		if has_selection:
			_atomic_structure_renderer.highlight_atoms(dna_structure.get_valid_atoms(), [], [])
			_atomic_structure_renderer.highlight_bonds(dna_structure.get_bonds_ids())
		else:
			_atomic_structure_renderer.lowlight_atoms(dna_structure.get_valid_atoms(), [], [])
			_atomic_structure_renderer.lowlight_bonds(dna_structure.get_bonds_ids())


func set_control_point_selection_position_delta(in_selection_delta: Vector3) -> void:
	queue_redraw()
	if in_selection_delta == Vector3():
		_reset_temp_curve()
		return
	_setup_temp_curve()
	var needs_recalculate_in_out: bool = _highlighted_control_points.size() != curve.point_count
	var points_to_transform: PackedInt32Array = _highlighted_control_points.keys()
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
	var points_to_transform: PackedInt32Array = _highlighted_control_points.keys()
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


func _on_should_hide_virtual_object_during_simulation_changed(in_type: StringName, in_should_hide: bool) -> void:
	if in_type == RepresentationSettings.script_to_virtual_object_key(DnaStructure):
		_should_hide_in_simulation = in_should_hide
		_update_visibility()


func _on_simulation_started_or_finished(in_is_simulating: bool) -> void:
	_is_simulating = in_is_simulating
	_update_visibility()


func _update_bases() -> void:
	if _updating_parameters:
		return
	var base_count: int = _sequence.length()
	while _bases.size() > base_count:
		_bases.pop_back().queue_free()
	var first_new_base: int = _bases.size()
	while _bases.size() < base_count:
		var base := DnaBaseRepresentation.create()
		base.base = _sequence[_bases.size()]
		add_child(base)
		_bases.append(base)
	_refresh_selection_preview(_highlighted_control_points.size() > 0, first_new_base)
	for i in base_count:
		_bases[i].strand_policy = _strand_policy
		_bases[i].base = _sequence[i]
		_bases[i].dna_radius = _dna_radius
		_bases[i].update_materials(self)
	_update_base_transforms()


func _update_base_transforms() -> void:
	var base_count: int = _sequence.length()
	for i in base_count:
		_bases[i].transform = DnaStructure.calculate_base_origin_transform(
			i, curve, _rise_nanometers, _bases_per_turn, _initial_twist
		)


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	_hover_enabled = false
	queue_redraw()


func queue_redraw() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_path_representation.queue_redraw()


func _on_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	_is_selectable = false
	_is_top_level = false
	var current: StructureContext = _workspace_context.get_current_structure_context()
	for context: StructureContext in in_new_editable_structure_contexts:
		if context.get_int_guid() == _structure_id:
			_is_selectable = true
			_is_top_level = context == current or _workspace_context.get_toplevel_editable_context(context) == context
			break
	const SELECTABLE_VALUE: float = 1.0
	const UNSELECTABLE_VALUE: float = 0.0
	_set_shader_uniform(&"is_selectable", SELECTABLE_VALUE if _is_selectable else UNSELECTABLE_VALUE)
	if not _is_selectable:
		_path_hovered = false
		queue_redraw()
	


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
	visible = _object_visible and _current_representation == DnaRepresentation.SIMPLIFIED \
		and ((not _is_simulating) or (not _should_hide_in_simulation))
	queue_redraw()


func _on_path_representation_drawn() -> void:
	if is_queued_for_deletion() or not _is_selectable or Engine.is_editor_hint():
		return
	if not is_instance_valid(_workspace_context):
		return
	if (_is_simulating and _should_hide_in_simulation):
		return
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	if _current_representation == DnaRepresentation.ATOMS_AND_BONDS:
		_path_representation_draw_aabb(dna_structure)
	var path: PackedVector3Array = dna_structure.get_baked_path(_temp_curve)
	if path.is_empty():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var last_pos2d: Vector2 = camera.unproject_position(path[0])
	const MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS: float = 3 * 3
	var last_idx: int = path.size() - 1
	var path_width: int = 2
	if _highlighted_control_points.size() > 0:
		path_width = 4
	var outline_color: Color = _get_outline_color()
	for i in range(1, path.size()):
		var pos2d: Vector2 = camera.unproject_position(path[i])
		if last_pos2d.distance_squared_to(pos2d) >= MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS or i == last_idx:
			_path_representation.draw_line(last_pos2d, pos2d, outline_color, path_width)
			last_pos2d = pos2d
	if _is_top_level == false:
		return
	if _highlighted_control_points.size() == 0 and _hovered_control_point == -1 and _path_hovered == false:
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
		_path_representation.draw_circle(pos2d, CONTROL_POINT_RADIUS + 1, Color.BLACK)
		_path_representation.draw_circle(pos2d, CONTROL_POINT_RADIUS, color)


func _path_representation_draw_aabb(in_dna_structure: DnaStructure) -> void:
	var path_width: int = 2
	var aabb: AABB = in_dna_structure.get_aabb().abs()
	var start: Vector3 = aabb.position
	var end: Vector3 = aabb.end
	var camera: Camera3D = get_viewport().get_camera_3d()
	var outline_color: Color = _get_outline_color()
	var corners: PackedVector3Array = [start, end]
	var corners_2d: PackedVector2Array = [camera.unproject_position(start),camera.unproject_position(end)]
	for c in 3:
		var p2: Vector3 = start
		p2[c] = end[c]
		corners.append(p2)
		corners_2d.append(camera.unproject_position(p2))
		p2 = end
		p2[c] = start[c]
		corners.append(p2)
		corners_2d.append(camera.unproject_position(p2))
	var farthest_idx: int = -1
	var fathest_distance_sqrd: float = 0
	for i in corners.size():
		var corner_distance_sqrd: float = camera.global_position.distance_squared_to(corners[i])
		if corner_distance_sqrd > fathest_distance_sqrd:
			farthest_idx = i
			fathest_distance_sqrd = corner_distance_sqrd
	corners.remove_at(farthest_idx)
	corners_2d.remove_at(farthest_idx)
	for i: int in range(corners_2d.size() - 1):
		for j: int in range(i, corners_2d.size()):
			var common: int = 0
			for c in 3:
				if corners[i][c] == corners[j][c]:
					common += 1
			if common > 1:
				_path_representation.draw_line(corners_2d[i], corners_2d[j], outline_color, path_width)


func _get_outline_color() -> Color:
	var representation_settings: RepresentationSettings = _workspace_context.workspace.representation_settings
	var color: Color = representation_settings.get_theme().get_highlight_color()
	if representation_settings.get_custom_selection_outline_color_enabled():
		color = representation_settings.get_custom_selection_outline_color()
	var is_hovered: bool = _path_hovered and _hover_enabled
	var has_selection: bool = _highlighted_control_points.size() > 0
	if is_hovered or has_selection:
		return color
	color.a = 0.5
	return color


func _set_shader_uniform(in_uniform: StringName, in_value: Variant) -> void:
	assert(in_uniform != &"albedo", "ALBEDO uniform is not meant to be set to all materials")
	_backbone_a_strand.set_shader_parameter(in_uniform, in_value)
	_backbone_b_strand.set_shader_parameter(in_uniform, in_value)
	_base_a_strand.set_shader_parameter(in_uniform, in_value)
	_base_b_strand.set_shader_parameter(in_uniform, in_value)
	for base_type_material: ShaderMaterial in _base_per_type.values():
		base_type_material.set_shader_parameter(in_uniform, in_value)


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
	snapshot["_current_representation"] = _current_representation
	snapshot["_highlighted_control_points"] = _highlighted_control_points.duplicate()
	snapshot["_is_selectable"] = _is_selectable
	snapshot["_is_top_level"] = _is_top_level
	snapshot["_should_hide_in_simulation"] = _should_hide_in_simulation
	snapshot["_object_visible"] = _object_visible
	snapshot["_selectable_uniform"] = _backbone_a_strand.get_shader_parameter(&"is_selectable")
	snapshot["_backbone_color_policy"] = _backbone_color_policy
	snapshot["_bases_color_policy"] = _bases_color_policy
	snapshot["_bases_color_schema"] = _bases_color_schema
	snapshot["_material_colors"] = {
		&"_backbone_a_strand" : _backbone_a_strand.get_shader_parameter(&"albedo"),
		&"_backbone_b_strand" : _backbone_b_strand.get_shader_parameter(&"albedo"),
		&"_base_a_strand" : _base_a_strand.get_shader_parameter(&"albedo"),
		&"_base_b_strand" : _base_b_strand.get_shader_parameter(&"albedo"),
		&"_base_per_typeA" : _base_per_type.A.get_shader_parameter(&"albedo"),
		&"_base_per_typeT" : _base_per_type.T.get_shader_parameter(&"albedo"),
		&"_base_per_typeC" : _base_per_type.C.get_shader_parameter(&"albedo"),
		&"_base_per_typeG" : _base_per_type.G.get_shader_parameter(&"albedo"),
	}
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
	_current_representation = in_state_snapshot["_current_representation"]
	_highlighted_control_points = in_state_snapshot["_highlighted_control_points"].duplicate()
	_is_selectable = in_state_snapshot["_is_selectable"]
	_is_top_level = in_state_snapshot["_is_top_level"]
	_should_hide_in_simulation = in_state_snapshot["_should_hide_in_simulation"]
	_object_visible = in_state_snapshot["_object_visible"]
	_set_shader_uniform(&"is_selectable", in_state_snapshot["_selectable_uniform"])
	_backbone_color_policy = in_state_snapshot["_backbone_color_policy"]
	_bases_color_policy = in_state_snapshot["_bases_color_policy"]
	_bases_color_schema = in_state_snapshot["_bases_color_schema"]
	var material_colors: Dictionary = in_state_snapshot["_material_colors"]
	_backbone_a_strand.set_shader_parameter(&"albedo", material_colors._backbone_a_strand)
	_backbone_b_strand.set_shader_parameter(&"albedo", material_colors._backbone_b_strand)
	_base_a_strand.set_shader_parameter(&"albedo", material_colors._base_a_strand)
	_base_b_strand.set_shader_parameter(&"albedo", material_colors._base_b_strand)
	_base_per_type.A.set_shader_parameter(&"albedo", material_colors._base_per_typeA)
	_base_per_type.T.set_shader_parameter(&"albedo", material_colors._base_per_typeT)
	_base_per_type.C.set_shader_parameter(&"albedo", material_colors._base_per_typeC)
	_base_per_type.G.set_shader_parameter(&"albedo", material_colors._base_per_typeG)
	var bases_snapshots: Array[Dictionary] = in_state_snapshot["bases_snapshots"]
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	while _bases.size() > bases_snapshots.size():
		_bases.pop_back().queue_free()
	while _bases.size() < bases_snapshots.size():
		var base := DnaBaseRepresentation.create()
		add_child(base)
		_bases.append(base)
	dna_structure.grab_curve(self)
	for i in bases_snapshots.size():
		_bases[i].apply_state_snapshot(bases_snapshots[i])
		_bases[i].update_materials(self)
	var is_selected: bool = _highlighted_control_points.size() > 0
	_refresh_selection_preview(is_selected)
	_applying_snapshot = false
	_ensure_structure_signal_connections(dna_structure)
	_update_visibility()
