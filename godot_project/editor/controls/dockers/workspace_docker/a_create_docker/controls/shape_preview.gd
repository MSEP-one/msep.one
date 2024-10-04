extends AspectRatioContainer


func update_camera_distance() -> void:
	pass


@onready var preview_viewport: PreviewViewport3D = %"3DPreviewViewport"
@onready var three_d_preview_container: SubViewportContainer = $"3DPreviewContainer"
@onready var preview_camera_pivot: Node3D = preview_viewport.get_node("%PreviewCameraPivot")
@onready var camera_3d: Camera3D = preview_viewport.get_camera_3d()


func _ready() -> void:
	three_d_preview_container.gui_input.connect(_on_three_d_preview_container_gui_input)


func _on_three_d_preview_container_gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventMouseMotion and in_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		preview_camera_pivot.rotation.y += deg_to_rad(-in_event.relative.x)


func set_preview_camera_pivot_position(in_global_position: Vector3) -> void:
	preview_viewport.set_preview_camera_pivot_position(in_global_position)

func set_preview_camera_distance_to_pivot(in_distance_to_pivot: float) -> void:
	preview_viewport.set_preview_camera_distance_to_pivot(in_distance_to_pivot)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		preview_viewport.update(delta)
