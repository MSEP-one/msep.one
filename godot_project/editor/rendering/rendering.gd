class_name Rendering extends Node
## Responsible for rendering of the nano structures
## It's providing all the public api that might be needed for the rendering

const AtomicStructureRendererScn: PackedScene = preload("res://editor/rendering/atomic_structure_renderer/atomic_structure_renderer.tscn")
const NanoShapeRendererScn: PackedScene = preload("res://editor/rendering/reference_shape_renderer/reference_shape_renderer.tscn")
const NanoVirtualMotorRendererScn: PackedScene = preload("res://editor/rendering/virtual_motor_renderer/virtual_motor_renderer.tscn")
const NanoVirtualAnchorRendererScn: PackedScene = preload("res://editor/rendering/virtual_anchor_and_spring_renderer/virtual_anchor_renderer.tscn")

const SELECTION_PREVIEW_LAYER_BIT = 3

enum Representation {
	VAN_DER_WAALS_SPHERES     = 0,
	MECHANICAL_SIMULATION     = 1,
	STICKS                    = 2,
	ENHANCED_STICKS           = 3,
	BALLS_AND_STICKS          = 4,
	ENHANCED_STICKS_AND_BALLS = 5,
}


signal representation_changed(new_representation: Representation)


@export var enabled: bool = true
@onready var _atomic_structure_renderers: Node = $AtomicStructureRenderers
@onready var _reference_shape_renderers: Node = $NanoShapeRenderers
@onready var _virtual_motor_renderers: Node = $VirtualMotorRenderers
@onready var _virtual_anchor_renderers: Node = $VirtualAnchorRenderers
@onready var _atom_preview: AtomPreview = $AtomPreview
@onready var _ballstick_bond_preview: BallStickBondPreview = $BallStickBondPreview
@onready var _structure_preview: StructurePreview = $StructurePreview
@onready var _reference_shape_preview: NanoShapeRenderer = $ReferenceShapePreview
@onready var _virtual_motor_preview: VirtualMotorRenderer = $VirtualMotorPreview
@onready var _virtual_anchor_preview: VirtualAnchorPreview = $VirtualAnchorPreview
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _spring_preview: SpringPreview = $SpringPreview
@onready var _selection_preview: SelectionPreview = $SelectionPreview
var _default_representation: Rendering.Representation = Representation.BALLS_AND_STICKS
var _environment: Environment = null
var _hover_disabled: bool = false
var _workspace_context: WorkspaceContext
var _theme_in_use: Theme3D


func rebuild(in_structure_context: StructureContext) -> void:
	var renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure_context.nano_structure)
	renderer.rebuild()


func snapshot_rebuild(in_structure_context: StructureContext) -> void:
	if in_structure_context.nano_structure is AtomicStructure:
		var renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure_context.nano_structure)
		renderer.snapshot_rebuild(in_structure_context)
	
	if in_structure_context.nano_structure is NanoVirtualAnchor:
		var renderer: VirtualAnchorRenderer = _get_renderer_for_virtual_anchor(in_structure_context.nano_structure.get_int_guid())
		renderer.snapshot_rebuild(in_structure_context.nano_structure)
	
	if in_structure_context.nano_structure is NanoVirtualMotor:
		var renderer: VirtualMotorRenderer = _get_renderer_for_virtual_motor(in_structure_context.nano_structure.get_int_guid())
		renderer.snapshot_rebuild(in_structure_context.nano_structure)


func initialize(in_workspace_context: WorkspaceContext) -> void:
	if not enabled: return
	var _selection_layer_bit_enumerated_from_0: int = SELECTION_PREVIEW_LAYER_BIT - 1
	assert(pow(2, _selection_layer_bit_enumerated_from_0) == RenderingUtils.get_selection_preview_visual_layer(),
			"SELECTION_PREVIEW_LAYER_BIT must correspond with constants.gdshaderinc.SELECTION_PREVIEW_VISUAL_LAYER")
	_workspace_context = in_workspace_context
	var workspace: Workspace = in_workspace_context.workspace
	_theme_in_use = workspace.representation_settings.get_theme()
	workspace.representation_settings.changed.connect(_on_workspace_settings_changed)
	workspace.representation_settings.theme_changed.connect(_on_representation_settings_theme_changed.bind(weakref(workspace)))
	workspace.representation_settings.color_palette_changed.connect(_on_representation_settings_color_palette_changed)
	apply_theme(workspace.representation_settings.get_theme())
	_selection_preview.init(_workspace_context)


## Returns whether it is initialized or not
func is_initialized() -> bool:
	return _workspace_context != null


## Note: this is very heavy operation, it should be performed only when it's necessary to build 
## internal rendering state
func build_atomic_structure_rendering(in_structure_context: StructureContext,
			in_representation: Rendering.Representation) -> void:
	if not enabled: return
	_default_representation = in_representation
	assert(in_structure_context.nano_structure)
	assert(not in_structure_context.nano_structure.is_being_edited(), "Can't build renderer for AtomicStructure which is being edited")
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure_context.nano_structure)
	atomic_structure_renderer.build(in_structure_context, _default_representation)
	var representation_settings: RepresentationSettings = in_structure_context.nano_structure.get_representation_settings()
	if representation_settings.get_hydrogens_visible():
		atomic_structure_renderer.ensure_hydrogens_rendering_on()
	else:
		atomic_structure_renderer.ensure_hydrogens_rendering_off()
	if representation_settings.get_display_atom_labels():
		atomic_structure_renderer.ensure_label_rendering_on()
	else:
		atomic_structure_renderer.ensure_label_rendering_off()
	if representation_settings.get_display_bonds():
		atomic_structure_renderer.ensure_bond_rendering_on()
	else:
		atomic_structure_renderer.ensure_bond_rendering_off()


func build_reference_shape_rendering(in_shape: NanoShape) -> void:
	if not enabled: return
	var shape_renderer: NanoShapeRenderer = _get_renderer_for_reference_shape(in_shape.get_int_guid())
	shape_renderer.build(_workspace_context, in_shape)
	if _hover_disabled:
		shape_renderer.disable_hover()


func build_virtual_motor_rendering(in_motor: NanoVirtualMotor) -> void:
	if not enabled: return
	var motor_renderer: VirtualMotorRenderer = _get_renderer_for_virtual_motor(in_motor.get_int_guid())
	motor_renderer.build(_workspace_context, in_motor)
	if _hover_disabled:
		motor_renderer.disable_hover()


func build_virtual_anchor_rendering(in_anchor: NanoVirtualAnchor) -> void:
	if not enabled: return
	var anchor_renderer: VirtualAnchorRenderer = _get_renderer_for_virtual_anchor(in_anchor.get_int_guid())
	anchor_renderer.build(_workspace_context, in_anchor)
	if _hover_disabled:
		anchor_renderer.disable_hover()


func get_selection_preview_texture() -> Texture:
	_selection_preview.refresh()
	return _selection_preview.get_texture()


func rotate_selection_preview(in_rotation_strength: float) -> void:
	_selection_preview.rotate_camera(in_rotation_strength)


func get_reference_shape_renderer(in_shape_renderer_name: String) -> NanoShapeRenderer:
	return _reference_shape_renderers.get_node(in_shape_renderer_name)


func get_rendered_structures() -> PackedInt32Array:
	var rendered_structures: PackedInt32Array = PackedInt32Array()
	
	for structure: Node in _atomic_structure_renderers.get_children():
		if structure is InstancePlaceholder:
			continue
		rendered_structures.append(structure.get_name().to_int())
	
	for structure: Node in _virtual_motor_renderers.get_children():
		if structure is InstancePlaceholder:
			continue
		rendered_structures.append(structure.get_name().to_int())
	
	for structure: Node in _reference_shape_renderers.get_children():
		if structure is InstancePlaceholder:
			continue
		rendered_structures.append(structure.get_name().to_int())
	
	for structure: Node in _virtual_anchor_renderers.get_children():
		if structure is InstancePlaceholder:
			continue
		rendered_structures.append(structure.get_name().to_int())
	
	return rendered_structures


func set_atomic_structure_material_overlay(in_structure: AtomicStructure, in_material_overlay: Material) -> void:
	if not enabled: return
	var structure_renderer_name: String = str(in_structure.int_guid)
	if not _atomic_structure_renderers.has_node(structure_renderer_name):
		return
	
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.material_overlay = in_material_overlay


func is_renderer_for_atomic_structure_built(in_structure: AtomicStructure) -> bool:
	if not enabled: return false
	var structure_renderer_name: String = str(in_structure.int_guid)
	if not _atomic_structure_renderers.has_node(structure_renderer_name):
		return false
	
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	return atomic_structure_renderer.is_built()


func is_renderer_for_nano_shape_built(in_nano_shape: NanoShape) -> bool:
	if not enabled: return false
	var structure_renderer_name: String = str(in_nano_shape.int_guid)
	if not _reference_shape_renderers.has_node(structure_renderer_name):
		return false
	return true


func is_renderer_for_motor_built(in_motor: NanoVirtualMotor) -> bool:
	if not enabled: return false
	var structure_renderer_name: String = str(in_motor.int_guid)
	if not _virtual_motor_renderers.has_node(structure_renderer_name):
		return false
	return true


func is_renderer_for_anchor_built(in_anchor: NanoVirtualAnchor) -> bool:
	if not enabled: return false
	var structure_renderer_name: String = str(in_anchor.int_guid)
	if not _virtual_anchor_renderers.has_node(structure_renderer_name):
		return false
	return true


func remove(in_structure: NanoStructure) -> void:
	remove_with_id(in_structure.get_int_guid())


func remove_with_id(in_structure_id: int) -> void:
	if not enabled: return
	var structure_renderer_name: String = str(in_structure_id)
	if _atomic_structure_renderers.has_node(structure_renderer_name):
		var atomic_structure_renderer: AtomicStructureRenderer = _atomic_structure_renderers.get_node(structure_renderer_name)
		atomic_structure_renderer.queue_free()
		atomic_structure_renderer.name = "_in_queue_free_" + atomic_structure_renderer.name
	if _reference_shape_renderers.has_node(structure_renderer_name):
		var shape_renderer: NanoShapeRenderer = _reference_shape_renderers.get_node(structure_renderer_name)
		shape_renderer.queue_free()
		shape_renderer.name = "_in_queue_free_" + shape_renderer.name
	if _virtual_motor_renderers.has_node(structure_renderer_name):
		var motor_renderer: VirtualMotorRenderer = _virtual_motor_renderers.get_node(structure_renderer_name)
		motor_renderer.queue_free()
		motor_renderer.name = "_in_queue_free_" + motor_renderer.name
	if _virtual_anchor_renderers.has_node(structure_renderer_name):
		var anchor_renderer: VirtualAnchorRenderer = _virtual_anchor_renderers.get_node(structure_renderer_name)
		anchor_renderer.queue_free()
		anchor_renderer.name = "_in_queue_free_" + anchor_renderer.name


func show_structure(in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.show()


func hide_structure(in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.hide()


func change_structure_representation(in_structure: AtomicStructure, in_representation: Rendering.Representation) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.change_representation(in_representation)


func get_default_representation() -> Rendering.Representation:
	return _default_representation


func change_default_representation(in_representation: Rendering.Representation) -> void:
	if not enabled: return
	if _default_representation == in_representation:
		return
	_default_representation = in_representation
	for sr in _atomic_structure_renderers.get_children():
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		if not is_instance_valid(structure_renderer):
			continue
		structure_renderer.change_representation(in_representation)
	representation_changed.emit(in_representation)


func refresh_atom_sizes() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.refresh_atom_sizes()


func highlight_atoms(in_atoms_ids: Array, in_structure: AtomicStructure,
			new_partially_influenced_bonds: PackedInt32Array,
			in_bonds_released_from_partial_influence: PackedInt32Array) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.highlight_atoms(in_atoms_ids, new_partially_influenced_bonds,
			in_bonds_released_from_partial_influence)
	Settings.handle_heavy_operation()


func lowlight_atoms(in_atoms_ids: Array, in_structure: AtomicStructure,
			in_bonds_released_from_partial_influence: PackedInt32Array, 
			new_partially_influenced_bonds: PackedInt32Array) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.lowlight_atoms(in_atoms_ids, in_bonds_released_from_partial_influence,
			new_partially_influenced_bonds)
	Settings.handle_heavy_operation()


func highlight_bonds(in_bonds_ids: PackedInt32Array, in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.highlight_bonds(in_bonds_ids)
	Settings.handle_heavy_operation()


func lowlight_bonds(in_bonds_ids: PackedInt32Array, in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.lowlight_bonds(in_bonds_ids)
	Settings.handle_heavy_operation()


func highlight_springs(in_springs_to_highlight: PackedInt32Array, in_structure: AtomicStructure) -> void:
	if not enabled: return
	Settings.handle_heavy_operation()
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.highlight_springs(in_springs_to_highlight)


func lowlight_springs(in_springs_to_lowlight: PackedInt32Array, in_structure: AtomicStructure) -> void:
	if not enabled: return
	Settings.handle_heavy_operation()
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.lowlight_springs(in_springs_to_lowlight)


func apply_theme(in_theme: Theme3D) -> void:
	if _theme_in_use == in_theme:
		_refresh_viewport_background()
		_refresh_outline_color()
		return
	_theme_in_use = in_theme
	_environment = in_theme.create_environment()
	_world_environment.environment = _environment
	var structure_renderers := _atomic_structure_renderers.get_children()
	for structure_renderer: Node in structure_renderers:
		if structure_renderer is InstancePlaceholder:
			continue
		structure_renderer.apply_theme(in_theme)
	
	_atom_preview.apply_theme(in_theme)
	_ballstick_bond_preview.apply_theme(in_theme)
	_refresh_viewport_background()
	_refresh_outline_color()


func _get_renderer_for_atomic_structure(in_structure: AtomicStructure) -> AtomicStructureRenderer:
	if not enabled: return null
	return _get_renderer_for_atomic_structure_id(in_structure.int_guid)


func _get_renderer_for_atomic_structure_id(in_structure_id: int) -> AtomicStructureRenderer:
	if not enabled: return null
	var structure_renderer_name: String = str(in_structure_id)
	var structure_renderer: AtomicStructureRenderer
	var need_to_create_structure_renderer: bool = not _atomic_structure_renderers.has_node(structure_renderer_name)
	if need_to_create_structure_renderer:
		structure_renderer = AtomicStructureRendererScn.instantiate()
		structure_renderer.set_name(structure_renderer_name)
		structure_renderer.set_workspace_context(_workspace_context)
		_atomic_structure_renderers.add_child(structure_renderer)
	structure_renderer = _atomic_structure_renderers.get_node(structure_renderer_name)
	return structure_renderer


func _get_renderer_for_reference_shape(in_structure_id: int) -> NanoShapeRenderer:
	if not enabled: return null
	var shape_renderer_name: String = str(in_structure_id)
	var shape_renderer: NanoShapeRenderer
	var need_to_create_shape_renderer: bool = not _reference_shape_renderers.has_node(shape_renderer_name)
	if need_to_create_shape_renderer:
		shape_renderer = NanoShapeRendererScn.instantiate()
		shape_renderer.set_name(shape_renderer_name)
		_reference_shape_renderers.add_child(shape_renderer)
	else:
		shape_renderer = _reference_shape_renderers.get_node(shape_renderer_name)
	return shape_renderer


func _get_renderer_for_virtual_motor(in_structure_id: int) -> VirtualMotorRenderer:
	if not enabled: return null
	var motor_renderer_name: String = str(in_structure_id)
	var motor_renderer: VirtualMotorRenderer
	var need_to_create_motor_renderer: bool = not _virtual_motor_renderers.has_node(motor_renderer_name)
	if need_to_create_motor_renderer:
		motor_renderer = NanoVirtualMotorRendererScn.instantiate()
		motor_renderer.set_name(motor_renderer_name)
		_virtual_motor_renderers.add_child(motor_renderer)
	else:
		motor_renderer = _virtual_motor_renderers.get_node(motor_renderer_name)
	return motor_renderer


func _get_renderer_for_virtual_anchor(in_structure_id: int) -> VirtualAnchorRenderer:
	if not enabled: return null
	var anchor_renderer_name: String = str(in_structure_id)
	var anchor_renderer: VirtualAnchorRenderer
	var need_to_create_anchor_renderer: bool = not _virtual_anchor_renderers.has_node(anchor_renderer_name)
	if need_to_create_anchor_renderer:
		anchor_renderer = NanoVirtualAnchorRendererScn.instantiate() as VirtualAnchorRenderer
		anchor_renderer.set_name(anchor_renderer_name)
		_virtual_anchor_renderers.add_child(anchor_renderer)
	else:
		anchor_renderer = _virtual_anchor_renderers.get_node(anchor_renderer_name) as VirtualAnchorRenderer
	return anchor_renderer


# very slow, should never be used in production
func __debug_rebuild_nano_structure(in_structure: AtomicStructure) -> void:
	if not enabled: return
	push_warning("This function should never be used in production")
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer._internal_build()


func disable_hover() -> void:
	_hover_disabled = true


func ensure_bond_rendering_on() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_bond_rendering_on()


func ensure_bond_rendering_off() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_bond_rendering_off()


func are_labels_enabled() -> bool:
	if not enabled: return false
	var are_labels_active: bool = false
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		are_labels_active = are_labels_active or structure_renderer.is_label_rendering_enabled()
	return are_labels_active


func enable_labels() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_label_rendering_on()


func disable_labels() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_label_rendering_off()


func enable_hydrogens() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_hydrogens_rendering_on()


func disable_hydrogens() -> void:
	if not enabled: return
	for sr in _atomic_structure_renderers.get_children():
		if sr is InstancePlaceholder:
			continue
		var structure_renderer: AtomicStructureRenderer = sr as AtomicStructureRenderer
		structure_renderer.ensure_hydrogens_rendering_off()


func set_partially_selected_bonds(in_partially_selected_bonds: PackedInt32Array, in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.set_partially_selected_bonds(in_partially_selected_bonds)


func set_atom_selection_position_delta(in_selection_delta: Vector3, in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.set_atom_selection_position_delta(in_selection_delta)


func rotate_atom_selection_around_point(in_point: Vector3, in_rotation_to_apply: Basis, in_structure: AtomicStructure) -> void:
	if not enabled: return
	var atomic_structure_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure(in_structure)
	atomic_structure_renderer.rotate_atom_selection_around_point(in_point, in_rotation_to_apply)


func transform_object_by_external_transform(in_structure: NanoStructure, in_selection_initial_pos: Vector3,
			in_initial_nano_struct_transform: Transform3D, in_gizmo_transform: Transform3D) -> void:
	if not enabled: return
	if in_structure is NanoShape:
		var nano_shape_renderer: NanoShapeRenderer = _get_renderer_for_reference_shape(in_structure.get_int_guid())
		nano_shape_renderer.transform_shape_by_external_transform(in_selection_initial_pos, in_initial_nano_struct_transform,
				in_gizmo_transform)
	elif in_structure is NanoVirtualMotor:
		var motor_renderer: VirtualMotorRenderer = _get_renderer_for_virtual_motor(in_structure.get_int_guid())
		motor_renderer.transform_by_external_transform(in_selection_initial_pos, in_initial_nano_struct_transform,
				in_gizmo_transform)
	elif in_structure is NanoVirtualAnchor:
		var anchor: NanoVirtualAnchor = in_structure as NanoVirtualAnchor
		var anchor_renderer: VirtualAnchorRenderer = _get_renderer_for_virtual_anchor(anchor.get_int_guid())
		anchor_renderer.transform_by_external_transform(in_selection_initial_pos, in_initial_nano_struct_transform,
				in_gizmo_transform)
		var structures: PackedInt32Array = in_structure.get_related_structures()
		for structure_id: int in structures:
			var struct_renderer: AtomicStructureRenderer = _get_renderer_for_atomic_structure_id(structure_id)
			struct_renderer.handle_anchor_transform_progress(in_structure, in_selection_initial_pos,
					in_initial_nano_struct_transform, in_gizmo_transform)
	else:
		push_warning("Transformable object is not represented in the viewport: ",
				in_structure.get_structure_name(), "(", in_structure.get_type(), ")")


func update(in_delta: float) -> void:
	if not enabled: return
	for renderer in _atomic_structure_renderers.get_children():
		if renderer is AtomicStructureRenderer:
			renderer.update(in_delta)
	for renderer in _virtual_motor_renderers.get_children():
		if renderer is VirtualMotorRenderer:
			renderer.update(in_delta)
	if is_structure_preview_visible():
		_structure_preview.update(in_delta)


# # # # # #
# # Preview api
func is_atom_preview_visible() -> bool:
	if not enabled: return false
	return _atom_preview.is_visible()


func atom_preview_show() -> Rendering:
	if not enabled: return
	_atom_preview.show()
	return self


func atom_preview_hide() -> Rendering:
	if not enabled: return
	_atom_preview.hide()
	return self


func atom_preview_set_position(in_position: Vector3) -> Rendering:
	if not enabled: return
	_atom_preview.set_position(in_position)
	_ballstick_bond_preview.update_second_atom_pos(in_position)
	return self


func atom_preview_get_position() -> Vector3:
	if not enabled: return Vector3()
	return _atom_preview.get_position()


func atom_preview_set_atomic_number(in_atomic_number: int) -> Rendering:
	if not enabled: return self
	_atom_preview.set_atomic_number(in_atomic_number)
	return self


func is_bond_preview_visible() -> bool:
	if not enabled: return false
	return _ballstick_bond_preview.is_visible()


func bond_preview_show() -> Rendering:
	if not enabled: return self
	_ballstick_bond_preview.show()
	return self


func bond_preview_hide() -> Rendering:
	if not enabled: return self
	_ballstick_bond_preview.hide()
	return self


func bond_preview_update_all(in_first_pos: Vector3, in_sec_pos: Vector3, in_first_atom_type: int,
		in_sec_atom_type: int, in_bond_order: int) -> Rendering:
	if not enabled: return self
	_ballstick_bond_preview.update_all(in_first_pos, in_sec_pos, in_first_atom_type, in_sec_atom_type, in_bond_order)
	return self


func bond_preview_set_order(in_bond_order: int) -> Rendering:
	if not enabled: return self
	_ballstick_bond_preview.set_order(in_bond_order)
	return self


func is_structure_preview_visible() -> bool:
	if not enabled: return false
	return _structure_preview.visible


func structure_preview_show() -> Rendering:
	if not enabled: return
	_structure_preview.show()
	return self


func structure_preview_hide() -> Rendering:
	if not enabled: return
	_structure_preview.hide()
	return self


func structure_preview_set_transform(in_transform: Transform3D) -> Rendering:
	if not enabled: return
	_structure_preview.set_transform(in_transform)
	return self


func structure_preview_get_transform() -> Transform3D:
	if not enabled: return Transform3D()
	return _structure_preview.get_transform()


func is_shape_preview_visible() -> bool:
	if not enabled: return false
	return _reference_shape_preview.visible


func shape_preview_show() -> Rendering:
	if not enabled: return self
	_reference_shape_preview.show()
	return self


func shape_preview_hide() -> Rendering:
	if not enabled: return self
	_reference_shape_preview.hide()
	return self


func shape_preview_set_nano_shape(in_nano_shape: NanoShape) -> Rendering:
	if not enabled: return self
	assert(in_nano_shape.is_ghost)
	_reference_shape_preview.build(_workspace_context, in_nano_shape)
	return self


func is_virtual_motor_preview_visible() -> bool:
	if not enabled: return false
	return _virtual_motor_preview.visible


func virtual_motor_preview_show() -> Rendering:
	if enabled:
		_virtual_motor_preview.show()
	return self


func virtual_motor_preview_hide() -> Rendering:
	if enabled:
		_virtual_motor_preview.hide()
	return self


func virtual_motor_preview_set_position(in_position: Vector3) -> Rendering:
	if enabled:
		_virtual_motor_preview.global_position = in_position
	return self


func virtual_motor_preview_get_position() -> Vector3:
	if not enabled or not is_virtual_motor_preview_visible():
		return Vector3()
	return _virtual_motor_preview.global_position


func virtual_motor_preview_set_rotation(in_rotation: Quaternion) -> Rendering:
	if enabled:
		_virtual_motor_preview.quaternion = in_rotation
	return self

func virtual_motor_preview_get_rotation() -> Quaternion:
	if not enabled or not is_virtual_motor_preview_visible():
		return Quaternion()
	return _virtual_motor_preview.quaternion

func virtual_motor_preview_set_parameters(in_motor_parameters: NanoVirtualMotorParameters) -> Rendering:
	if enabled:
		_virtual_motor_preview.parameters = in_motor_parameters
	return self


func is_virtual_anchor_preview_visible() -> bool:
	if not enabled: return false
	return _virtual_anchor_preview.visible


func virtual_anchor_preview_show() -> Rendering:
	if enabled:
		_virtual_anchor_preview.show()
		_spring_preview.show_preview()
	return self


func virtual_anchor_preview_hide() -> Rendering:
	if enabled:
		_virtual_anchor_preview.hide()
		_spring_preview.hide_preview()
	return self


func virtual_anchor_preview_set_position(in_position: Vector3) -> Rendering:
	if enabled:
		_virtual_anchor_preview.set_preview_position(in_position)
		_spring_preview.set_end_position(in_position)
	return self


func virtual_anchor_preview_get_position() -> Vector3:
	if not enabled or not is_virtual_anchor_preview_visible():
		return Vector3()
	return _virtual_anchor_preview.global_position


func virtual_anchor_preview_set_spring_ends(in_springs: PackedVector3Array) -> Rendering:
	if not enabled:
		return
	_spring_preview.update(in_springs)
	return self


func _refresh_outline_color() -> void:
	if not enabled: return
	var outline_color: Color
	var workspace: Workspace = _workspace_context.workspace
	if not is_instance_valid(workspace):
		push_error("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = workspace.representation_settings
	if representation_settings.get_custom_selection_outline_color_enabled():
		outline_color = representation_settings.get_custom_selection_outline_color()
	else:
		outline_color = representation_settings.get_theme().get_highlight_color()
	RenderingServer.global_shader_parameter_set(&"selected_atom_outline_color", outline_color)
	RenderingServer.global_shader_parameter_set(&"reference_shape_selected_wireframe_color", outline_color)

func _refresh_viewport_background() -> void:
	if not enabled: return
	var background_brightness: float
	var workspace: Workspace = _workspace_context.workspace
	if not is_instance_valid(workspace):
		push_error("Workspace is not valid")
		return
	var representation_settings: RepresentationSettings = workspace.representation_settings
	if not is_instance_valid(_environment):
		_environment = _world_environment.environment.duplicate(true)
		_world_environment.environment = _environment
	if representation_settings.get_custom_background_color_enabled():
		_environment.background_mode = Environment.BG_COLOR
		_environment.background_color = representation_settings.get_custom_background_color()
		background_brightness = representation_settings.get_custom_background_color().get_luminance()
	else:
		_environment.background_mode = Environment.BG_SKY
		background_brightness = 0.1
	_environment.glow_enabled = background_brightness < 0.22
	
	# Brigther backgrounds require less transparent previews, darker ones needs more transparency.
	var preview_transparency: float = remap(background_brightness, 0.0, 1.0, 0.35, 0.05)
	_atom_preview.set_transparency(preview_transparency)
	_ballstick_bond_preview.set_transparency(preview_transparency)
	_structure_preview.set_transparency(preview_transparency)

func spring_preview_hide() -> void:
	_spring_preview.hide_preview()


func _on_workspace_settings_changed() -> void:
	if not enabled: return
	_refresh_viewport_background()
	_refresh_outline_color()


func _on_representation_settings_theme_changed(in_workspace_wref: WeakRef) -> void:
	var workspace: Workspace = in_workspace_wref.get_ref() as Workspace
	if not is_instance_valid(workspace):
		push_error("Workspace is not valid")
		assert(false)
		return
	var representation_settings: RepresentationSettings = workspace.representation_settings
	apply_theme(representation_settings.get_theme())


func _on_representation_settings_color_palette_changed(in_new_color_palette: PeriodicTable.ColorPalette) -> void:
	PeriodicTable.load_palette(in_new_color_palette)
	var structure_renderers := _atomic_structure_renderers.get_children()
	for structure_renderer: Node in structure_renderers:
		if structure_renderer is AtomicStructureRenderer:
			structure_renderer.rebuild()


func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["_default_representation"] = _default_representation
	var renderers_data: Dictionary = _collect_renderer_snapshot_data(_atomic_structure_renderers.get_children())
	var anchors_data: Dictionary = _collect_renderer_snapshot_data(_virtual_anchor_renderers.get_children())
	var motors_data: Dictionary = _collect_renderer_snapshot_data(_virtual_motor_renderers.get_children())
	var shapes_data: Dictionary = _collect_renderer_snapshot_data(_reference_shape_renderers.get_children())
	snapshot["renderers_data"] = renderers_data
	snapshot["anchors_data"] = anchors_data
	snapshot["motors_data"] = motors_data
	snapshot["shapes_data"] = shapes_data
	return snapshot


func _collect_renderer_snapshot_data(in_collection: Array[Node]) -> Dictionary:
	var renderers_data: Dictionary = {}
	var renderers: Dictionary = {}
	var renderers_snapshots: Dictionary = {}
	for renderer in in_collection:
		if renderer is InstancePlaceholder:
			continue
		if renderer.is_queued_for_deletion():
			continue
		var renderer_name: String = renderer.get_name()
		renderers[renderer_name] = renderer
		renderers_snapshots[renderer_name] = renderer.create_state_snapshot()
	renderers_data["renderers"] = renderers
	renderers_data["renderers_snapshots"] = renderers_snapshots
	return renderers_data


func apply_state_snapshot(in_snapshot: Dictionary) -> void:
	_default_representation = in_snapshot["_default_representation"]
	
	#
	var renderers_data: Dictionary = in_snapshot["renderers_data"]
	var renderers: Dictionary = renderers_data["renderers"]
	var renderers_snapshots: Dictionary = renderers_data["renderers_snapshots"]
	for renderer_name: String in renderers:
		var renderer: AtomicStructureRenderer
		var renderer_snapshot: Dictionary = renderers_snapshots[renderer_name]
		var is_alive: bool = is_instance_valid(renderers[renderer_name]) and \
				not renderers[renderer_name].is_queued_for_deletion()
		if is_alive:
			renderer = renderers[renderer_name]
		else:
			# create new one
			renderer = _get_renderer_for_atomic_structure_id(renderer_name.to_int())
		renderer.apply_state_snapshot(renderer_snapshot)
	
	#
	var anchors_data: Dictionary = in_snapshot["anchors_data"]
	var anchor_renderers: Dictionary = anchors_data["renderers"]
	var anchor_renderes_snapshots: Dictionary = anchors_data["renderers_snapshots"]
	for renderer_name: String in anchor_renderers:
		var renderer: VirtualAnchorRenderer
		var anchor_renderer_snapshot: Dictionary = anchor_renderes_snapshots[renderer_name]
		if is_instance_valid(anchor_renderers[renderer_name]):
			renderer = anchor_renderers[renderer_name]
		else:
			# create new one
			renderer = _get_renderer_for_virtual_anchor(renderer_name.to_int())
		renderer.apply_state_snapshot(anchor_renderer_snapshot)
	
	#
	var motors_data: Dictionary = in_snapshot["motors_data"]
	var motors_renderers: Dictionary = motors_data["renderers"]
	var motors_renderers_snapshots: Dictionary = motors_data["renderers_snapshots"]
	for renderer_name: String in motors_renderers:
		var renderer: VirtualMotorRenderer
		var motor_renderer_snapshot: Dictionary = motors_renderers_snapshots[renderer_name]
		if is_instance_valid(motors_renderers[renderer_name]):
			renderer = motors_renderers[renderer_name]
		else:
			# create new one
			renderer = _get_renderer_for_virtual_motor(renderer_name.to_int())
		renderer.apply_state_snapshot(motor_renderer_snapshot)
	
	#
	var shapes_data: Dictionary = in_snapshot["shapes_data"]
	var shapes_renderers: Dictionary = shapes_data["renderers"]
	var shapes_renderers_snapshots: Dictionary = shapes_data["renderers_snapshots"]
	for renderer_name: String in shapes_renderers:
		var renderer: NanoShapeRenderer
		var shape_renderer_snapshot: Dictionary = shapes_renderers_snapshots[renderer_name]
		if is_instance_valid(shapes_renderers[renderer_name]):
			renderer = shapes_renderers[renderer_name]
		else:
			# create new one
			renderer = _get_renderer_for_reference_shape(renderer_name.to_int())
		renderer.apply_state_snapshot(shape_renderer_snapshot)
	
	apply_theme(_workspace_context.workspace.representation_settings.get_theme())
	_selection_preview.refresh()
