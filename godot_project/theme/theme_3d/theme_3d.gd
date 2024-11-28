class_name Theme3D extends Resource

@export var _ball_mesh: Mesh
@export var _single_atom_ball_mesh: Mesh
@export var _bond_order_1_mesh: Mesh
@export var _bond_order_2_mesh: Mesh
@export var _bond_order_3_mesh: Mesh
@export var _stick_mesh_order_1: Mesh
@export var _stick_mesh_order_2: Mesh
@export var _stick_mesh_order_3: Mesh
@export var _enhanced_stick_mesh_order_1: Mesh
@export var _enhanced_stick_mesh_order_2: Mesh
@export var _enhanced_stick_mesh_order_3: Mesh
@export var _spring_mesh: Mesh
@export var _ball_material: SphereMaterial
@export var _single_atom_ball_material: SphereMaterial
@export var _bond_order_1_material: CylinderStickMaterial
@export var _bond_order_2_material: CylinderStickMaterial
@export var _bond_order_3_material: CylinderStickMaterial
@export var _stick_order_1_material: CapsuleStickMaterial
@export var _stick_order_2_material: CapsuleStickMaterial
@export var _stick_order_3_material: CapsuleStickMaterial
@export var _enhanced_stick_order_1_material: CapsuleStickMaterial
@export var _enhanced_stick_order_2_material: CapsuleStickMaterial
@export var _enhanced_stick_order_3_material: CapsuleStickMaterial
@export var _spring_material: SpringMaterial
@export var _label_material: LabelMaterial
@export var _preview_ball_material: PreviewSphereMaterial
@export var _preview_bond_material: PreviewBondMaterial
@export var _environment: Environment
@export var _highlight_color: Color = Color.WHITE


func create_ball_mesh() -> Mesh:
	return _ball_mesh.duplicate()


func create_single_atom_ball_mesh() -> Mesh:
	return _single_atom_ball_mesh.duplicate()


func create_bond_order_1_mesh() -> Mesh:
	return _bond_order_1_mesh.duplicate()


func create_bond_order_2_mesh() -> Mesh:
	return _bond_order_2_mesh.duplicate()


func create_bond_order_3_mesh() -> Mesh:
	return _bond_order_3_mesh.duplicate()


func create_stick_mesh_order_1() -> Mesh:
	return _stick_mesh_order_1.duplicate()


func create_stick_mesh_order_2() -> Mesh:
	return _stick_mesh_order_2.duplicate()


func create_stick_mesh_order_3() -> Mesh: 
	return _stick_mesh_order_3.duplicate()


func create_enhanced_stick_mesh_order_1() -> Mesh:
	return _enhanced_stick_mesh_order_1.duplicate()


func create_enhanced_stick_mesh_order_2() -> Mesh:
	return _enhanced_stick_mesh_order_2.duplicate()


func create_enhanced_stick_mesh_order_3() -> Mesh:
	return _enhanced_stick_mesh_order_3.duplicate()


func create_spring_mesh() -> Mesh:
	return _spring_mesh.duplicate()


func create_ball_material() -> SphereMaterial:
	return _ball_material.duplicate()

func create_single_atom_ball_material() -> SphereMaterial:
	return _single_atom_ball_material.duplicate()

func create_bond_order_1_material() -> CylinderStickMaterial:
	return _bond_order_1_material.duplicate()


func create_bond_order_2_material() -> CylinderStickMaterial:
	return _bond_order_2_material.duplicate()


func create_bond_order_3_material() -> CylinderStickMaterial:
	return _bond_order_3_material.duplicate()


func create_stick_order_1_material() -> Material:
	return _stick_order_1_material.duplicate()


func create_stick_order_2_material() -> Material:
	return _stick_order_2_material.duplicate()


func create_stick_order_3_material() -> Material:
	return _stick_order_3_material.duplicate()


func create_enhanced_stick_order_1_material() -> Material:
	return _enhanced_stick_order_1_material.duplicate()


func create_enhanced_stick_order_2_material() -> Material:
	return _enhanced_stick_order_2_material.duplicate()


func create_enhanced_stick_order_3_material() -> Material:
	return _enhanced_stick_order_3_material.duplicate()


func create_spring_material() -> Material:
	return _spring_material.duplicate()


func create_label_material() -> Material:
	return _label_material.duplicate()


func create_preview_ball_material() -> PreviewSphereMaterial:
	return _preview_ball_material.duplicate()


func create_preview_bond_material() -> PreviewBondMaterial:
	return _preview_bond_material.duplicate()


func create_environment() -> Environment:
	return _environment.duplicate()


func get_highlight_color() -> Color:
	return _highlight_color


func get_background_color() -> Color:
	return _environment.background_color
