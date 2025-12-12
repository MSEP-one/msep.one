@tool
class_name DnaStructureRenderer extends Path3D


@onready var _transform_helper: PathFollow3D = %TransformHelper
@onready var _path_hover_representation: Control = %PathHoverRepresentation



@export_custom(PROPERTY_HINT_ENUM, "A,B,DOUBLE", PROPERTY_USAGE_EDITOR)
var _strand_policy := DnaStructure.StrandPolicy.DOUBLE:
	set = set_strand_policy

@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR)
var _sequence: String:
	set = set_sequence


@export_custom(PROPERTY_HINT_RANGE, "0.1,2.0,0.05,or_greater", PROPERTY_USAGE_EDITOR)
var _rise_nanometers: float = 0.34:
	set = set_rise_nanometers


@export_custom(PROPERTY_HINT_RANGE, "5,15,0.1,or_greater,or_less", PROPERTY_USAGE_EDITOR)
var _bases_per_turn: float = 10:
	set = set_bases_per_turn 


@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1", PROPERTY_USAGE_EDITOR)
var _initial_twist_degrees: float:
	set = _set_initial_twist_degrees,
	get = _get_initial_twist_degrees
var _initial_twist: float


var _workspace_context: WorkspaceContext
var _structure_id: int
var _bases: Array[DnaBaseRepresentation]
var _applying_snapshot: bool = false

# hovering API
var _hover_enabled: bool = true
var _path_hovered: bool = false
var _hovered_control_point: int = -1
var _path_position_hovered: Vector3
var _highlighted_control_points: Dictionary[int, bool]

func _ready() -> void:
	_update_bases()
	_transform_helper.progress_ratio = 1
	curve_changed.connect(_on_curve_changed)
	_path_hover_representation.draw.connect(_on_path_hover_representation_drawn)


func build(in_workspace_context: WorkspaceContext, in_structure: DnaStructure) -> void:
	_workspace_context = in_workspace_context
	_structure_id = in_structure.get_int_guid()
	in_structure.grab_curve(self)
	_strand_policy = in_structure.get_strand_policy()
	_sequence = in_structure.get_sequence()
	_rise_nanometers = in_structure.get_rise_nanometers()
	_bases_per_turn = in_structure.get_bases_per_turn()
	_initial_twist = in_structure.get_initial_twist_rad()

	if not in_workspace_context.editable_structure_context_list_changed.is_connected(_on_editable_structure_context_list_changed):
		in_workspace_context.editable_structure_context_list_changed.connect(_on_editable_structure_context_list_changed)
		in_workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)


func _on_curve_changed() -> void:
	_transform_helper.progress_ratio = 1
	for base: DnaBaseRepresentation in _bases:
		const NEEDS_UPDATE_THRESHOLD: float = 0.9
		if base.progress_ratio >= NEEDS_UPDATE_THRESHOLD:
			# recalculate transform of trailing bases
			base.set_deferred(&"base_offset", base.base_offset)


func get_curve_final_transform() -> Transform3D:
	return _transform_helper.transform


func set_strand_policy(in_strand_policy: DnaStructure.StrandPolicy) -> void:
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
	if Engine.is_editor_hint():
		_update_bases_deferred()
	else:
		ScriptUtils.call_deferred_once(_update_bases_deferred)


func _update_bases_deferred() -> void:
	var base_count: int = _sequence.length()
	while _bases.size() > base_count:
		_bases.pop_back().queue_free()
	while _bases.size() < base_count:
		var base := DnaBaseRepresentation.create()
		add_child(base)
		_bases.append(base)
	
	var delta_angle: float = deg_to_rad(360) / _bases_per_turn
	
	for i in base_count:
		_bases[i].strand_policy = _strand_policy
		_bases[i].base = _sequence[i]
		_bases[i].base_offset = i * _rise_nanometers
		_bases[i].base_twist = _initial_twist + delta_angle * i


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	_hover_enabled = false
	_path_hover_representation.queue_redraw()


func _on_editable_structure_context_list_changed(in_new_editable_structure_contexts: Array[StructureContext]) -> void:
	print_debug("TODO: _on_editable_structure_context_list_changed")


func _on_hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
			hovered_structure_context: StructureContext, _atom_id: int, _bond_id: int, _spring_id: int,
			in_dna_control_point_idx: int) -> void:
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	_path_hovered = false
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(dna_structure) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, dna_structure):
		_path_hovered = true
		_hovered_control_point = in_dna_control_point_idx
	elif is_instance_valid(hovered_structure_context):
		_path_hovered = dna_structure == hovered_structure_context.nano_structure
		if _path_hovered:
			_hovered_control_point = in_dna_control_point_idx
	_path_hover_representation.queue_redraw()


func _on_path_hover_representation_drawn() -> void:
	if not _hover_enabled or not _path_hovered:
		return
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	var path: PackedVector3Array = dna_structure.get_baked_path()
	if path.is_empty():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var last_pos2d: Vector2 = camera.unproject_position(path[0])
	const MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS: float = 3 * 3
	var last_idx: int = path.size() - 1
	for i in range(1, path.size()):
		var pos2d: Vector2 = camera.unproject_position(path[i])
		if last_pos2d.distance_squared_to(pos2d) >= MIN_SEGMENT_DISTANCE_SQRD_IN_PIXELS or i == last_idx:
			const PATH_COLOR = Color.WHITE
			const PATH_WIDTH = 2
			_path_hover_representation.draw_line(last_pos2d, pos2d, PATH_COLOR, PATH_WIDTH)
			last_pos2d = pos2d
	for cp_idx: int in dna_structure.get_control_point_count():
		var pos: Vector3 = dna_structure.get_control_point_position(cp_idx)
		var pos2d: Vector2 = camera.unproject_position(pos)
		const CONTROL_POINT_RADIUS: float = 5
		const CONTROL_POINT_COLOR := Color.ROYAL_BLUE
		const CONTROL_POINT_COLOR_HOVER := Color.GOLD
		const CONTROL_POINT_COLOR_HIGHLIGHTED := Color.CHARTREUSE
		var color: Color = CONTROL_POINT_COLOR
		if _highlighted_control_points.get(cp_idx, false):
			color = CONTROL_POINT_COLOR_HIGHLIGHTED
		elif _hovered_control_point == cp_idx:
			color = CONTROL_POINT_COLOR_HOVER
		_path_hover_representation.draw_circle(pos2d, CONTROL_POINT_RADIUS, color)


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_workspace_context"] = _workspace_context
	snapshot["_structure_id"] = _structure_id
	snapshot["_strand_policy"] = _strand_policy
	snapshot["_sequence"] = _sequence
	snapshot["_rise_nanometers"] = _rise_nanometers
	snapshot["_bases_per_turn"] = _bases_per_turn
	snapshot["_initial_twist"] = _initial_twist
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
