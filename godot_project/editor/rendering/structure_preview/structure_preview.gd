class_name StructurePreview
extends Node3D


const AtomicStructureRendererScn = preload("res://editor/rendering/atomic_structure_renderer/atomic_structure_renderer.tscn")
const WorkspaceContextScn: String = "uid://xof5f45xkn2n"
const StructureContextScn = preload("res://project_workspace/workspace_context/structure_context/structure_context.tscn")

const DEFAULT_PREVIEW_TRANSPARENCY: float = 0.35
const UNIFORM_BASE_SCALE: StringName = &"base_scale"
const UNIFORM_ATOM_SCALE: StringName = &"atom_scale"

var _atomic_structure_renderer: AtomicStructureRenderer = null
var _transparency: float = DEFAULT_PREVIEW_TRANSPARENCY

## If [code]true[/code], this preview will automatically match the current
## object create mode. If [code]false[/code], the preview will only be updated
## by calling [code]set_structure[/code].
var _auto_update_preview: bool = true 

var _preview_workspace_context: WorkspaceContext
var _preview_workspace: Workspace
var _preview_structure_context: StructureContext
var _enabled_on_preview_viewport: bool = false


func _ready() -> void:
	hide()
	_ready_deferred.call_deferred()


func _ready_deferred() -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
	assert(workspace_context)
	workspace_context.started_creating_object.connect(_on_workspace_context_started_creating_object.bind(workspace_context))
	workspace_context.aborted_creating_object.connect(_on_workspace_context_aborted_creating_object)
	var representation_settings: RepresentationSettings = workspace_context.workspace.representation_settings
	representation_settings.changed.connect(_on_representation_settings_changed.bind(representation_settings))


func enable_on_preview_viewport() -> void:
	assert(get_viewport() is PreviewViewport3D)
	_enabled_on_preview_viewport = true


func set_structure(in_structure: NanoStructure) -> void:
	if get_viewport() is PreviewViewport3D and not _enabled_on_preview_viewport:
		# Structure Previews are never shown in preview viewports (used to show selected objects)
		return
	if not is_instance_valid(in_structure) or not in_structure is AtomicStructure:
		if is_instance_valid(_atomic_structure_renderer):
			_atomic_structure_renderer.queue_free()
		return
	if is_instance_valid(_atomic_structure_renderer):
		_atomic_structure_renderer.queue_free()
	_atomic_structure_renderer = AtomicStructureRendererScn.instantiate() as AtomicStructureRenderer
	add_child(_atomic_structure_renderer)
	
	if is_instance_valid(_preview_workspace_context):
		_preview_workspace_context.queue_free()
	if is_instance_valid(_preview_structure_context):
		_preview_structure_context.queue_free()
	
	var structure_copy: NanoStructure = NanoMolecularStructure.new()
	structure_copy.apply_state_snapshot(in_structure.create_state_snapshot())
	structure_copy.set_representation_settings(in_structure.get_representation_settings())
	_preview_workspace_context = load(WorkspaceContextScn).instantiate()
	_preview_workspace = Workspace.new()
	_preview_workspace.representation_settings = in_structure.get_representation_settings()
	_preview_workspace.add_structure(structure_copy)
	add_child(_preview_workspace_context)
	_preview_workspace_context.initialize(_preview_workspace)
	_preview_structure_context = _preview_workspace_context.get_nano_structure_context(structure_copy)
	
	var representation_settings: RepresentationSettings = in_structure.get_representation_settings()
	_atomic_structure_renderer.build(_preview_structure_context, representation_settings.get_rendering_representation())
	_atomic_structure_renderer.set_transparency(_transparency)
	
	var display_labels: bool = representation_settings.get_display_atom_labels()
	if display_labels:
		_atomic_structure_renderer.ensure_label_rendering_on()
	else:
		_atomic_structure_renderer.ensure_label_rendering_off()
	
	_atomic_structure_renderer.apply_theme(representation_settings.get_theme())


func update(in_delta: float) -> void:
	if is_instance_valid(_atomic_structure_renderer):
		_atomic_structure_renderer.update(in_delta)


func set_transparency(in_transparency: float) -> void:
	_transparency = in_transparency
	if is_instance_valid(_atomic_structure_renderer):
		_atomic_structure_renderer.set_transparency(in_transparency)


func set_auto_update(enabled: bool) -> void:
	_auto_update_preview = enabled


func _on_representation_settings_changed(in_representation_settings: RepresentationSettings) -> void:
	if is_instance_valid(_atomic_structure_renderer):
		_atomic_structure_renderer.change_representation(in_representation_settings.get_rendering_representation())


func _on_workspace_context_started_creating_object(workspace_context: WorkspaceContext) -> void:
	if not _auto_update_preview:
		return
	var peek_new_object: Callable = func(in_context: StructureContext) -> bool:
		set_structure(in_context.nano_structure)
		return true
	workspace_context.peek_context_of_object_being_created(peek_new_object)


func _on_workspace_context_aborted_creating_object() -> void:
	if not _auto_update_preview:
		return
	if is_instance_valid(_atomic_structure_renderer):
		_atomic_structure_renderer.queue_free()
