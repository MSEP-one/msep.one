class_name BallStickBondPreview extends Node



var _bond_order_to_mesh: Dictionary = {
	1: preload("res://editor/rendering/atomic_structure_renderer/representation/stick_representation/cylinder_stick_representation/assets/cylinder_single.mesh"),
	2: preload("res://editor/rendering/atomic_structure_renderer/representation/stick_representation/cylinder_stick_representation/assets/cylinder_double.mesh"),
	3: preload("res://editor/rendering/atomic_structure_renderer/representation/stick_representation/cylinder_stick_representation/assets/cylinder_tripple.mesh")
}

@onready var _preview: MeshInstance3D = $PreviewInstance
@onready var _material: PreviewBondMaterial = _preview.material_override

var _first_atomic_number: int = 6
var _second_atomic_number: int = 6
var _first_pos := Vector3.ZERO
var _second_pos := Vector3.ONE
var _bond_order: int = 1
var _representation_settings: RepresentationSettings = null
var _preview_alpha: float = 0.65


func _ready() -> void:
	_preview.hide()
	_ready_deferred.call_deferred()


func _ready_deferred() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(workspace_context)
	_representation_settings = workspace_context.workspace.representation_settings
	_representation_settings.changed.connect(_on_representation_settings_changed)


func is_visible() -> bool:
	return is_instance_valid(_preview) and _preview.visible


func show() -> void:
	_preview.show()


func hide() -> void:
	_preview.hide()


func update_all(in_first_pos: Vector3, in_sec_pos: Vector3, in_first_atomic_number: int,
		in_sec_atomic_number: int, in_bond_order: int) -> void:
	_first_atomic_number = in_first_atomic_number
	_second_atomic_number = in_sec_atomic_number
	_first_pos = in_first_pos
	_second_pos = in_sec_pos
	_bond_order = in_bond_order
	_update_preview()


func update_second_atom_pos(in_sec_pos: Vector3) -> void:
	_second_pos = in_sec_pos
	_update_preview()


func set_order(in_bond_order: int) -> void:
	var mesh_2_use: Mesh = _bond_order_to_mesh[in_bond_order]
	if _preview.mesh != mesh_2_use:
		_preview.mesh = mesh_2_use


func set_transparency(transparency: float) -> void:
	_preview_alpha = 1.0 - transparency


func apply_theme(in_theme: Theme3D) -> void:
	_material = in_theme.create_preview_bond_material()
	_preview.material_override = _material
	_bond_order_to_mesh[1] = in_theme.create_bond_order_1_mesh()
	_bond_order_to_mesh[2] = in_theme.create_bond_order_2_mesh()
	_bond_order_to_mesh[3] = in_theme.create_bond_order_3_mesh()


func _update_preview() -> void:
	var first_data: ElementData = PeriodicTable.get_by_atomic_number(_first_atomic_number)
	var second_data: ElementData = PeriodicTable.get_by_atomic_number(_second_atomic_number)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var up_vector: Vector3 = camera.basis.z * -1.0
	var bond_transform: Transform3D = CylinderStickRepresentation.calculate_transform_for_bond(_first_pos,
			_second_pos, up_vector)
	_preview.transform = bond_transform
	_material.apply_element_data(first_data, second_data)
	set_order(_bond_order)


func _on_representation_settings_changed() -> void:
	_update_preview()
