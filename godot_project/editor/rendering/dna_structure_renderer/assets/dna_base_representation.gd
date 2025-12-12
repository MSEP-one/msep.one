@tool
class_name DnaBaseRepresentation extends PathFollow3D


@export var strand_policy := DnaStructure.StrandPolicy.DOUBLE:
	set = _set_strand_policy
@export_enum("A", "T", "G", "C", "X") var base: String = "X":
	set = _set_base
@export var base_offset: float:
	set = _set_base_offset
@export var base_twist: float:
	set = _set_base_twist

@onready var origin: Node3D = %Origin
@onready var a_strand: Dictionary[StringName, Node3D] = {
	origin = %A,
	Backbone = %BackboneA,
	Base1 = %Base1A,
	Base2 = %Base2A,
}

@onready var b_strand: Dictionary[StringName, Node3D] = {
	origin = %B,
	Backbone = %BackboneB,
	Base1 = %Base1B,
	Base2 = %Base2B,
}


var _applying_snapshot: bool = false


static func create() -> DnaBaseRepresentation:
	return preload("uid://cgh1pcn88ip1a").instantiate()


func _set_strand_policy(in_policy: DnaStructure.StrandPolicy) -> void:
	strand_policy = in_policy
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	a_strand[&"origin"].visible = in_policy != DnaStructure.StrandPolicy.B
	b_strand[&"origin"].visible = in_policy != DnaStructure.StrandPolicy.A


func _set_base(in_base: String) -> void:
	assert(in_base.length() <= 1)
	in_base = in_base.to_upper()
	if not in_base in ["A","T","C","G", "X"]:
		push_error("Invalid base ", in_base)
		in_base = "X"
	if in_base == base and is_node_ready():
		return
	base = in_base
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	a_strand[&"Base1"].visible = base in ["A", "T", "G", "C"]
	a_strand[&"Base2"].visible = base in ["A", "G"]
	b_strand[&"Base1"].visible = base in ["A", "T", "G", "C"]
	b_strand[&"Base2"].visible = base in ["T", "C"]


func _set_base_offset(in_offset: float) -> void:
	base_offset = in_offset
	if _applying_snapshot == true: return
	var max_progress: float = _get_max_progress()
	if in_offset > max_progress:
		var t: Transform3D = _get_curve_final_transform()
		var remaining_offset: float = in_offset - max_progress
		t.origin += t.basis.z * remaining_offset
		transform = t
	else:
		progress = in_offset



func _set_base_twist(in_twist: float) -> void:
	base_twist = in_twist
	if _applying_snapshot == true: return
	if not is_node_ready():
		await ready
	origin.rotation.z = base_twist


func _get_max_progress() -> float:
	var parent: Path3D = get_parent() as Path3D
	if parent != null:
		return parent.curve.get_baked_length()
	return 0

func _get_curve_final_transform() -> Transform3D:
	var parent: DnaStructureRenderer = get_parent() as DnaStructureRenderer
	if parent != null:
		return parent.get_curve_final_transform()
	return Transform3D()


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["strand_policy"] = strand_policy
	snapshot["base"] = base
	snapshot["base_offset"] = base_offset
	snapshot["base_twist"] = base_twist
	snapshot["global_transform"] = global_transform
	var child_visibilities: Dictionary[NodePath, bool] = {}
	for node: Node3D in a_strand.values():
		child_visibilities[get_path_to(node)] = node.visible
	for node: Node3D in b_strand.values():
		child_visibilities[get_path_to(node)] = node.visible
	snapshot["child_visibilities"] = child_visibilities
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_applying_snapshot = true
	strand_policy = in_state_snapshot["strand_policy"]
	base = in_state_snapshot["base"]
	base_offset = in_state_snapshot["base_offset"]
	base_twist = in_state_snapshot["base_twist"]
	global_transform = in_state_snapshot["global_transform"]
	var child_visibilities: Dictionary[NodePath, bool] = in_state_snapshot["child_visibilities"]
	for path: NodePath in child_visibilities.keys():
		get_node(path).visible = child_visibilities[path]
	_applying_snapshot = false
