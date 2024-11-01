class_name SelectionPreview extends SubViewport
## Responsible for delivering the selection preview texture

const MIN_CAMERA_DISTANCE_TO_PIVOT: float = 0.55

# workarounds issues with wrong placement of elements in the selection preview
const NMB_OF_FRAMES_TO_RENDER_ON_REFRESH = 2

@onready var _preview_camera_pivot: Node3D
@onready var _camera_3d: Camera3D

var _workspace_context: WorkspaceContext

var _frames_left_to_render: int = NMB_OF_FRAMES_TO_RENDER_ON_REFRESH


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_preview_camera_pivot = $PreviewCameraPivot as Node3D
		_camera_3d = $PreviewCameraPivot/Camera3D as Camera3D
		assert(_camera_3d.cull_mask == 0, "Ensure preview camera cull_mask is defined in one place")
		_camera_3d.set_cull_mask_value(Rendering.SELECTION_PREVIEW_LAYER_BIT, true)


func init(in_workspace_context: WorkspaceContext) -> void:
	_workspace_context = in_workspace_context


func set_preview_camera_pivot_position(in_global_position: Vector3) -> void:
	if _preview_camera_pivot == null:
		# Too early, let's wait for ready
		await ready
	if !_preview_camera_pivot.is_inside_tree():
		await tree_entered
	_preview_camera_pivot.global_position = in_global_position


func set_preview_camera_distance_to_pivot(in_distance_to_pivot: float) -> void:
	_camera_3d.position.z = in_distance_to_pivot


func _process(_delta: float) -> void:
	if _frames_left_to_render > 0:
		_frames_left_to_render -= 1
		return
	# workaround to godot #23729 issue (it's impossible to set Subviewport update mode reliably
	# when it's inside SubViewport container)
	var stop_preview_rerendering: bool = render_target_update_mode == SubViewport.UPDATE_ALWAYS
	if stop_preview_rerendering:
		render_target_update_mode = SubViewport.UPDATE_ONCE


func refresh() -> void:
	if not _workspace_context.has_selection():
		return
	
	_frames_left_to_render = NMB_OF_FRAMES_TO_RENDER_ON_REFRESH
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var aabb: AABB = _workspace_context.get_selection_aabb()
	var distance_to_pivot: float = max(aabb.get_longest_axis_size() * 3.0, MIN_CAMERA_DISTANCE_TO_PIVOT)
	var aabb_center: Vector3 = aabb.get_center()
	set_preview_camera_pivot_position(aabb_center)
	set_preview_camera_distance_to_pivot(distance_to_pivot)
