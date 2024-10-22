class_name NanoShapeRenderer extends Node3D


@export var color_selected   := Color.ORANGE
@export var color_unselected := Color.SEASHELL

var _shape_id: int
var _workspace_context: WorkspaceContext
var _nano_shape_primitive_mesh: PrimitiveMesh
var _hover_enabled: bool = true

@onready var shape: MeshInstance3D = $Shape
@onready var pivot: MeshInstance3D = shape.get_node("Pivot")


const _CAMERA_PROJECTION_TO_PIVOT_SCALE: Dictionary = {
	Camera3D.ProjectionType.PROJECTION_PERSPECTIVE: 0.004,
	Camera3D.ProjectionType.PROJECTION_ORTHOGONAL: 0.04,
	Camera3D.ProjectionType.PROJECTION_FRUSTUM: 0.04,
}


func build(in_workspace_context: WorkspaceContext, in_shape: NanoShape) -> void:
	shape.mesh = _get_flat_shaded_mesh(in_shape.get_shape())
	global_transform = in_shape.get_transform()
	_shape_id = in_shape.get_int_guid()
	_workspace_context = in_workspace_context
	_nano_shape_primitive_mesh = in_shape.get_shape()
	
	if in_shape.transform_changed.is_connected(_on_reference_shape_transform_changed):
		# Already initialized
		return
	in_shape.transform_changed.connect(_on_reference_shape_transform_changed)
	in_shape.shape_changed.connect(_on_reference_shape_shape_changed)
	in_shape.visibility_changed.connect(_on_reference_shape_visibility_changed)
	if _nano_shape_primitive_mesh:
		_nano_shape_primitive_mesh.changed.connect(_on_nano_shape_primitive_mesh_changed)
	if in_shape.is_ghost:
		pivot.hide()
		shape.set_layer_mask_value(1, false) # Disable "Representations" layer
		shape.set_layer_mask_value(2, true)  # Enable  "Previews" layer
		return
	var editor_viewport: SubViewport = get_viewport()
	assert(editor_viewport)
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	assert(workspace_context, "Reference shape renderer was asked to build when no workspace is active")
	var shape_context: StructureContext = workspace_context.get_nano_structure_context(in_shape)
	assert(shape_context, "Reference shape renderer was asked to build, but it does not belong to the current workspace")
	shape_context.virtual_object_selection_changed.connect(_on_shape_context_virtual_object_selection_changed)
	_on_shape_context_virtual_object_selection_changed(shape_context.is_shape_selected())
	workspace_context.hovered_structure_context_changed.connect(_on_hovered_structure_context_changed)


func disable_hover() -> void:
	# This is used to ensure the hover effect is never used in the 3D preview of the DynamicContextDocker
	_hover_enabled = false
	var editor_viewport: SubViewport = get_viewport()
	var workspace_context: WorkspaceContext = editor_viewport.get_workspace_context()
	if workspace_context and workspace_context.hovered_structure_context_changed.is_connected(_on_hovered_structure_context_changed):
		workspace_context.hovered_structure_context_changed.disconnect(_on_hovered_structure_context_changed)
		const NOT_HOVERED = 0
		shape.set_instance_shader_parameter(&"hovered", NOT_HOVERED)


func _ready() -> void:
	MolecularEditorContext.msep_editor_settings.changed.connect(_on_editor_settings_changed)
	_on_editor_settings_changed.call_deferred()


func _on_editor_settings_changed() -> void:
	if not is_inside_tree():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	pivot.scale = Vector3.ONE * _CAMERA_PROJECTION_TO_PIVOT_SCALE[camera.projection]


func _exit_tree() -> void:
	shape.mesh = null


func transform_shape_by_external_transform(in_selection_initial_pos: Vector3, in_initial_nano_struct_transform: Transform3D,
			in_external_transform: Transform3D) -> void:
	var inverse_gizmo_basis: Basis = in_external_transform.affine_inverse().basis.transposed()
	var local_transform := Transform3D(inverse_gizmo_basis, in_external_transform.origin)
	var relative_transform: Transform3D = local_transform * in_initial_nano_struct_transform
	var final_rotation: Transform3D = Transform3D(relative_transform.basis, relative_transform.origin)
	var delta_pos: Vector3 = in_initial_nano_struct_transform.origin - in_selection_initial_pos
	var new_pos: Vector3 = in_external_transform.origin + in_external_transform.basis * delta_pos
	global_transform = Transform3D(final_rotation.basis.orthonormalized(), new_pos)


func set_material_override(in_override: Material) -> void:
	shape.material_override = in_override


# Creates a flat shaded ArrayMesh from a PrimitiveMesh
# This code assumes the input mesh only have one surface (which is the case for
# every built-in PrimitiveMesh)
# Could be turned into a static helper method elsewhere.
func _get_flat_shaded_mesh(primitive_mesh: PrimitiveMesh) -> ArrayMesh:
	if not is_instance_valid(primitive_mesh):
		return null
	# Use a MeshDataTool for easier access to face data
	var reference_mesh: ArrayMesh = ArrayMesh.new()
	reference_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive_mesh.get_mesh_arrays())
	var mesh_data_tool: MeshDataTool = MeshDataTool.new()
	mesh_data_tool.create_from_surface(reference_mesh, 0)
	
	# Create the flat shaded Mesh by not sharing the vertices between each faces
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face_id: int in mesh_data_tool.get_face_count():
		for i in 3:
			var vertex_id: int = mesh_data_tool.get_face_vertex(face_id, i)
			var vertex_pos: Vector3 = mesh_data_tool.get_vertex(vertex_id)
			surface_tool.add_vertex(vertex_pos)
	return surface_tool.commit()


func _on_reference_shape_transform_changed(in_transform: Transform3D) -> void:
	global_transform = in_transform


# Called when the shape resource is replaced by a different shape
func _on_reference_shape_shape_changed(in_shape: PrimitiveMesh) -> void:
	if _nano_shape_primitive_mesh and _nano_shape_primitive_mesh.changed.is_connected(_on_nano_shape_primitive_mesh_changed):
		_nano_shape_primitive_mesh.changed.disconnect(_on_nano_shape_primitive_mesh_changed)
	
	_nano_shape_primitive_mesh = in_shape
	_nano_shape_primitive_mesh.changed.connect(_on_nano_shape_primitive_mesh_changed)
	_on_nano_shape_primitive_mesh_changed()


# Called when the shape resource parameters are modified (height, radius etc)
func _on_nano_shape_primitive_mesh_changed() -> void:
	shape.mesh = _get_flat_shaded_mesh(_nano_shape_primitive_mesh)

 
func _on_reference_shape_visibility_changed(in_visibility: bool) -> void:
	visible = in_visibility


func _on_shape_context_virtual_object_selection_changed(in_is_selected: bool) -> void:
	var material: StandardMaterial3D = pivot.material_override
	if material != null:
		material.albedo_color = color_selected if in_is_selected else color_unselected
	shape.set_instance_shader_parameter(&"selected", 1.0 if in_is_selected else 0.0)


func _on_hovered_structure_context_changed(toplevel_hovered_structure_context: StructureContext,
			hovered_structure_context: StructureContext, _atom_id: int, _bond_id: int, _spring_id: int) -> void:
	var nano_shape: NanoShape = _workspace_context.workspace.get_structure_by_int_guid(_shape_id) as NanoShape
	if not is_instance_valid(shape) or not is_instance_valid(nano_shape):
		return
	var is_hovered: float = 0.0
	if is_instance_valid(toplevel_hovered_structure_context) and is_instance_valid(nano_shape) and \
			_workspace_context.workspace.is_a_ancestor_of_b(toplevel_hovered_structure_context.nano_structure, nano_shape):
		is_hovered = 1.0
	elif not nano_shape.is_ghost and is_instance_valid(hovered_structure_context):
		is_hovered = 1.0 if nano_shape == hovered_structure_context.nano_structure else 0.0
	shape.set_instance_shader_parameter(&"hovered", is_hovered)


func create_state_snapshot() -> Dictionary:
	var shape_context: StructureContext = _workspace_context.get_structure_context(_shape_id)
	var nano_shape: NanoShape = shape_context.nano_structure
	var snapshot: Dictionary = {}
	
	snapshot["global_transform"] = global_transform
	snapshot["_workspace_context"] = _workspace_context
	snapshot["color_selected"] = color_selected
	snapshot["color_unselected"] = color_unselected
	snapshot["_nano_shape_primitive_mesh"] = _nano_shape_primitive_mesh.duplicate(true)
	snapshot["_shape_id"] = _shape_id
	snapshot["_hover_enabled"] = _hover_enabled
	snapshot["visible"] = visible
	snapshot["material_selected"] = shape.get_instance_shader_parameter(&"selected")
	
	snapshot["nano_shape.transform_changed"] = History.pack_signal(nano_shape.transform_changed, self)
	snapshot["nano_shape.shape_changed"] = History.pack_signal(nano_shape.shape_changed, self)
	snapshot["nano_shape.visibility_changed"] = History.pack_signal(nano_shape.visibility_changed, self)
	snapshot["shape_context.virtual_object_selection_changed"] = History.pack_signal(shape_context.virtual_object_selection_changed, self)
	snapshot["_workspace_context.hovered_structure_context_changed"] = History.pack_signal(_workspace_context.hovered_structure_context_changed, self)
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	global_transform = in_state_snapshot["global_transform"]
	_workspace_context = in_state_snapshot["_workspace_context"]
	color_selected = in_state_snapshot["color_selected"]
	color_unselected = in_state_snapshot["color_unselected"]
	_shape_id = in_state_snapshot["_shape_id"]
	_hover_enabled = in_state_snapshot["_hover_enabled"]
	visible = in_state_snapshot["visible"]
	shape.set_instance_shader_parameter(&"selected", in_state_snapshot["material_selected"])
	
	var shape_context: StructureContext = _workspace_context.get_structure_context(_shape_id)
	var nano_shape: NanoShape = shape_context.nano_structure
	# A new instance of NanoShape was created to replace the original
	_on_reference_shape_shape_changed(nano_shape.get_shape())
	History.apply_signal_pack(in_state_snapshot["nano_shape.transform_changed"], nano_shape.transform_changed, self)
	History.apply_signal_pack(in_state_snapshot["nano_shape.shape_changed"], nano_shape.shape_changed, self)
	History.apply_signal_pack(in_state_snapshot["nano_shape.visibility_changed"], nano_shape.visibility_changed, self)
	History.apply_signal_pack(in_state_snapshot["shape_context.virtual_object_selection_changed"], shape_context.virtual_object_selection_changed, self)
	History.apply_signal_pack(in_state_snapshot["_workspace_context.hovered_structure_context_changed"], _workspace_context.hovered_structure_context_changed, self)
