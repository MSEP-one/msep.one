@tool
class_name DnaBaseRepresentation extends Node3D


@export var strand_policy := DnaStructure.StrandPolicy.DOUBLE:
	set = _set_strand_policy
@export_enum("A", "T", "G", "C", "X") var base: String = "X":
	set = _set_base
@export var dna_radius: float = 1.0:
	set = _set_dna_radius

var origin: MeshInstance3D
var a_strand: Dictionary[StringName, MeshInstance3D]
var b_strand: Dictionary[StringName, MeshInstance3D]


var _applying_snapshot: bool = false

static func create() -> DnaBaseRepresentation:
	return preload("uid://cgh1pcn88ip1a").instantiate()


func setup_materials(
			a_strand_material: ShaderMaterial,
			b_strand_material: ShaderMaterial,
			pivot: ShaderMaterial
			) -> void:
	origin.material_override = pivot
	for mesh: MeshInstance3D in a_strand.values():
		mesh.material_override = a_strand_material
	for mesh: MeshInstance3D in b_strand.values():
		mesh.material_override = b_strand_material


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		origin = %Origin
		a_strand = {
			origin = %A,
			Backbone = %BackboneA,
			Base1 = %Base1A,
			Base2 = %Base2A,
		}
		b_strand = {
			origin = %B,
			Backbone = %BackboneB,
			Base1 = %Base1B,
			Base2 = %Base2B,
		}


func _set_dna_radius(in_radius: float) -> void:
	a_strand[&"Backbone"].position.x = in_radius
	b_strand[&"Backbone"].position.x = in_radius



func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["strand_policy"] = strand_policy
	snapshot["base"] = base
	snapshot["global_transform"] = global_transform
	snapshot["origin.rotation"] = origin.rotation
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
	global_transform = in_state_snapshot["global_transform"]
	origin.rotation = in_state_snapshot["origin.rotation"]
	var child_visibilities: Dictionary[NodePath, bool] = in_state_snapshot["child_visibilities"]
	for path: NodePath in child_visibilities.keys():
		get_node(path).visible = child_visibilities[path]
	_applying_snapshot = false
