class_name AtomPreview extends Node

const DEFAULT_PREVIEW_TRANSPARENCY: float = 0.35

@onready var _preview: MeshInstance3D = $PreviewInstance
@onready var _material: PreviewSphereMaterial = _preview.material_override


var _atomic_number: int = 6
var _representation_settings: RepresentationSettings = null


func _ready() -> void:
	_preview.hide()
	set_transparency(DEFAULT_PREVIEW_TRANSPARENCY)
	
	_ready_deferred.call_deferred()


func _ready_deferred() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	assert(workspace_context)
	_representation_settings = workspace_context.workspace.representation_settings
	_representation_settings.changed.connect(_on_representation_settings_changed)


func _on_representation_settings_changed() -> void:
	_update_preview()


func is_visible() -> bool:
	return _preview != null and _preview.visible


func show() -> void:
	_preview.show()


func hide() -> void:
	_preview.hide()



func set_atomic_number(in_atomic_number: int) -> void:
	_atomic_number = in_atomic_number
	_update_preview()


func set_transparency(transparency: float) -> void:
	_preview.transparency = transparency


func _update_preview() -> void:
	var data: ElementData = PeriodicTable.get_by_atomic_number(_atomic_number)
	var scale_factor: float = Representation.get_atom_scale_factor(_representation_settings)
	var atom_radius: float = Representation.get_atom_radius(data, _representation_settings) * scale_factor
	_preview.scale = Vector3(atom_radius, atom_radius, atom_radius)
	_material.apply_element_data(data)


func set_position(in_position: Vector3) -> void:
	_preview.position = in_position


func get_position() -> Vector3:
	return _preview.position


func apply_theme(in_theme: Theme3D) -> void:
	_material = in_theme.create_preview_ball_material()
	_preview.material_override = _material
