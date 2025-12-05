@tool
class_name DnaStructureRenderer extends Path3D


@onready var transform_helper: PathFollow3D = %TransformHelper


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
var _hover_enabled: bool = true
var _applying_snapshot: bool = false


func _ready() -> void:
	_update_bases()
	transform_helper.progress_ratio = 1
	curve_changed.connect(_on_curve_changed)


func build(in_workspace_context: WorkspaceContext, in_structure: DnaStructure) -> void:
	_workspace_context = in_workspace_context
	_structure_id = in_structure.get_int_guid()
	in_structure.grab_curve(self)
	_strand_policy = in_structure.get_strand_policy()
	_sequence = in_structure.get_sequence()
	_rise_nanometers = in_structure.get_rise_nanometers()
	_bases_per_turn = in_structure.get_bases_per_turn()
	_initial_twist = in_structure.get_initial_twist_rad()


func _on_curve_changed() -> void:
	transform_helper.progress_ratio = 1
	for base: DnaBaseRepresentation in _bases:
		const NEEDS_UPDATE_THRESHOLD: float = 0.9
		if base.progress_ratio >= NEEDS_UPDATE_THRESHOLD:
			# recalculate transform of trailing bases
			base.set_deferred(&"base_offset", base.base_offset)


func get_curve_final_transform() -> Transform3D:
	return transform_helper.transform


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
	if _workspace_context and _workspace_context.hovered_structure_context_changed.is_connected(_on_hovered_structure_context_changed):
		_workspace_context.hovered_structure_context_changed.disconnect(_on_hovered_structure_context_changed)
		@warning_ignore("unused_local_constant")
		const NOT_HOVERED = 0
		push_warning("TODO: mesh.set_instance_shader_parameter(&\"hovered\", NOT_HOVERED)")


func _on_hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
			hovered_structure_context: StructureContext, _atom_id: int, _bond_id: int, _spring_id: int) -> void:
	var dna_structure: DnaStructure = _workspace_context.workspace.get_structure_by_int_guid(_structure_id) as DnaStructure
	push_warning("TODO: Affect the right mesh")
	var mesh: Variant = null
	if not is_instance_valid(mesh) or not is_instance_valid(dna_structure):
		return
	@warning_ignore("unused_variable")
	var is_hovered: float = 0.0
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(dna_structure) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, dna_structure):
		is_hovered = 1.0
	elif is_instance_valid(hovered_structure_context):
		is_hovered = 1.0 if dna_structure == hovered_structure_context.nano_structure else 0.0
	push_warning("TODO: mesh.set_instance_shader_parameter(&\"hovered\", is_hovered)")


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
