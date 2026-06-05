class_name AlignSelectionPreview extends Control

## This enum is used for debug purposes,
## Set the value of DRAW_TRANSFORM_AT constant to enable it
enum DrawTransformAt {
	None = 0x0,
	BoxOrigin = 0x1 << 0,
	HighlightedFace = 0x1 << 1,
	Both = BoxOrigin | HighlightedFace,
}
const DRAW_TRANSFORM_AT: DrawTransformAt = DrawTransformAt.None
const FACE_HIGHLIGHT_TEXTURE: Texture2D = preload("res://editor/controls/dockers/workspace_docker/a_create_docker/controls/icons/stripes.svg")
const FACE_HIGHLIGHT_OPACITY: float = 0.35

const AlignSelectionGroupingPolicy = AlignSelectionParameters.AlignSelectionGroupingPolicy
const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const BoxFace = AlignSelectionParameters.BoxFace


var _camera: Camera3D
var _camera_last_transform: Transform3D
var _camera_last_zoom: float
var _camera_last_projection: Camera3D.ProjectionType

var _highlight_color: Color
var _lowlight_color: Color


var _workspace_context: WorkspaceContext
var _align_selection_parameters: AlignSelectionParameters


func _ready() -> void:
	set_process(false)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_camera = get_viewport().get_camera_3d()
	_ready_deferred.call_deferred()


func _ready_deferred() -> void:
	var editor_viewport := get_viewport() as WorkspaceEditorViewport
	if editor_viewport != null:
		_workspace_context = editor_viewport.get_workspace_context()
		_align_selection_parameters = _workspace_context.align_selection_parameters
		_align_selection_parameters.alignment_tools_enabled_changed.connect(_on_alignment_tools_enabled_changed)
		_align_selection_parameters.align_relative_to_changed.connect(_on_align_relative_to_changed)
		_align_selection_parameters.redraw_preview_requested.connect(queue_redraw)
		_workspace_context.history_changed.connect(_on_history_changed)
		var representation_settings: RepresentationSettings = \
			editor_viewport.get_workspace_context().workspace.representation_settings
		representation_settings.changed.connect(_on_representation_changed.bind(representation_settings))
		representation_settings.theme_changed.connect(_on_representation_changed.bind(representation_settings))
		_on_representation_changed(representation_settings)


func is_visible_in_msep_editor() -> bool:
	# Because this node is child of a subviewport, we cannot rely on
	# `is_visible_on_tree()` because it does not care if the SubViewportContainer
	# containing this viewport is visible or not, so we have to make our own conclusions
	return get_viewport().get_parent().is_visible_in_tree()


func _process(_delta: float) -> void:
	if (not is_visible_in_msep_editor()):
		return
	# Redraw if the camera is moving
	if is_instance_valid(_camera) and (
			_camera.global_transform != _camera_last_transform
			or _camera.size != _camera_last_zoom
			or _camera_last_projection != _camera.projection):
		_camera_last_transform = _camera.global_transform
		_camera_last_zoom = _camera.size
		_camera_last_projection = _camera.projection
		queue_redraw()
		return
	if MolecularEditorContext.is_homepage_active():
		return


func _draw() -> void:
	if not is_processing() or _align_selection_parameters == null:
		return
	
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	var highlighted_obb: OBB = _align_selection_parameters.get_align_obb_target()
	for obb: AlignableOBB in alignable_boxes:
		if obb == null or not obb.box.has_surface() or obb == highlighted_obb:
			continue
		_draw_obb_face(obb, obb.selected_face)
		_draw_transform(obb.transform, obb.box.size * 0.25, false)
	if highlighted_obb != null:
		_draw_obb_face(highlighted_obb, highlighted_obb.align_to_face, true)


func _draw_obb(in_obb: OBB, in_color: Color = _lowlight_color) -> void:
	var path_width: int = 2
	var aabb: AABB = in_obb.box
	var start: Vector3 = aabb.position
	var end: Vector3 = aabb.end
	var corners: PackedVector3Array = [start, end]
	var xformed_corners: PackedVector3Array = []
	var corners_2d: PackedVector2Array = []
	for c in 3:
		var p2: Vector3 = start
		p2[c] = end[c]
		corners.append(p2)
		p2 = end
		p2[c] = start[c]
		corners.append(p2)
	for i: int in corners.size():
		xformed_corners.append(in_obb.transform * corners[i])
		corners_2d.append(_camera.unproject_position(xformed_corners[i]))
		
	var farthest_idx: int = -1
	var fathest_distance_sqrd: float = 0
	for i in corners.size():
		var corner_distance_sqrd: float = _get_distance_to_camera_sqrd(xformed_corners[i])
		if corner_distance_sqrd > fathest_distance_sqrd:
			farthest_idx = i
			fathest_distance_sqrd = corner_distance_sqrd
	corners.remove_at(farthest_idx)
	corners_2d.remove_at(farthest_idx)
	for i: int in range(corners_2d.size() - 1):
		for j: int in range(i, corners_2d.size()):
			var common: int = 0
			for c in 3:
				if corners[i][c] == corners[j][c]:
					common += 1
			if common > 1:
				draw_line(corners_2d[i], corners_2d[j], in_color, path_width)


func _draw_transform(t: Transform3D, handle_size: Vector3, is_highlighted_face: bool) -> void:
	var from: Vector3 = t.origin
	var from2d: Vector2 = _camera.unproject_position(from)
	const COLORS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
	if is_highlighted_face and (DRAW_TRANSFORM_AT & DrawTransformAt.HighlightedFace == 0):
		return
	if (not is_highlighted_face) and (DRAW_TRANSFORM_AT & DrawTransformAt.BoxOrigin == 0):
		return
	for i in 3:
		var to: Vector3 = from + t.basis[i] * handle_size[i]
		var to2d: Vector2 = _camera.unproject_position(to)
		var col: Color = COLORS[i]
		if !is_highlighted_face:
			col *= 0.75
		draw_line(from2d, to2d, col, 2)

func _draw_obb_face(in_obb: AlignableOBB, in_face: BoxFace, in_highlighted: bool = false) -> void:
	if in_obb == null or in_face == BoxFace.UNDEFINED:
		return
	
	var flat_transform: Transform3D = in_obb.transform
	var face_corners: PackedVector3Array
	match in_face:
		BoxFace.TOP_BOTTOM:
			if _camera.global_basis.z.dot(in_obb.transform.basis.y) < 0.0:
				face_corners = in_obb.get_face_corners(Vector3.DOWN)
				flat_transform.origin -= in_obb.transform.basis.y * in_obb.box.size.y * 0.5
			else:
				face_corners = in_obb.get_face_corners(Vector3.UP)
				flat_transform.origin += in_obb.transform.basis.y * in_obb.box.size.y * 0.5
		BoxFace.FRONT_BACK:
			if _camera.global_basis.z.dot(in_obb.transform.basis.z) < 0.0:
				face_corners = in_obb.get_face_corners(Vector3.FORWARD)
				flat_transform.origin -= in_obb.transform.basis.z * in_obb.box.size.z * 0.5
			else:
				face_corners = in_obb.get_face_corners(Vector3.BACK)
				flat_transform.origin += in_obb.transform.basis.z * in_obb.box.size.z * 0.5
		BoxFace.LEFT_RIGHT:
			if _camera.global_basis.z.dot(in_obb.transform.basis.x) < 0.0:
				face_corners = in_obb.get_face_corners(Vector3.LEFT)
				flat_transform.origin -= in_obb.transform.basis.x * in_obb.box.size.x * 0.5
			else:
				face_corners = in_obb.get_face_corners(Vector3.RIGHT)
				flat_transform.origin += in_obb.transform.basis.x * in_obb.box.size.x * 0.5
		
	# Draw half transparent face
	var polygon := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector3 in face_corners:
		var screen_pos: Vector2 = _camera.unproject_position(corner)
		polygon.push_back(screen_pos)
		uvs.push_back(screen_pos / DisplayServer.screen_get_dpi())
	var color: Color = _highlight_color if in_highlighted else _lowlight_color
	for i: int in polygon.size():
		var from: Vector2 = polygon[i]
		var to: Vector2 = polygon[(i + 1) % polygon.size()]
		draw_line(from, to, color)
	if in_highlighted:
		draw_colored_polygon(polygon, Color(_highlight_color, FACE_HIGHLIGHT_OPACITY), uvs, FACE_HIGHLIGHT_TEXTURE)
	
	if _align_selection_parameters.is_advanced_settings_enabled():
		var origin: Vector3 = (face_corners[0] + face_corners[1] + face_corners[2] + face_corners[3]) / 4.0
		var basis: Basis = in_obb.get_face_basis(in_face)
		var h_axis: int; var v_axis: int
		match in_face:
			BoxFace.FRONT_BACK:
				h_axis = Vector3.AXIS_X; v_axis = Vector3.AXIS_Y
			BoxFace.TOP_BOTTOM:
				h_axis = Vector3.AXIS_X; v_axis = Vector3.AXIS_Z
			BoxFace.LEFT_RIGHT:
				h_axis = Vector3.AXIS_Z; v_axis = Vector3.AXIS_Y
		origin += basis[0] * (in_obb.offset_ratio_h * in_obb.box.size[h_axis])
		origin += basis[1] * (in_obb.offset_ratio_v * in_obb.box.size[v_axis])
		var origin_2d: Vector2 = _camera.unproject_position(origin)
		var _h_dir_2d: Vector2 = (_camera.unproject_position(origin + basis[0] * 200)-origin_2d).normalized()
		var _v_dir_2d: Vector2 = (_camera.unproject_position(origin + basis[1] * 200)-origin_2d).normalized()
		var draw_h_from: Vector2 = origin_2d - _h_dir_2d * 20
		var draw_h_to: Vector2 = origin_2d + _h_dir_2d * 20
		var draw_v_from: Vector2 = origin_2d - _v_dir_2d * 20
		var draw_v_to: Vector2 = origin_2d + _v_dir_2d * 20
		draw_line(draw_h_from, draw_h_to, Color.RED, 4 if in_highlighted else 2)
		draw_line(draw_v_from, draw_v_to, Color.GREEN, 4 if in_highlighted else 2)
	
	if DRAW_TRANSFORM_AT & DrawTransformAt.HighlightedFace != 0:
		var font := get_theme_font(&"Label", &"HeaderLarge")
		var center: Vector2 = _camera.unproject_position(flat_transform.origin)
		var face_name: String = str(BoxFace.find_key(in_face))
		face_name = face_name.capitalize().replace(" ", "/")
		var text_size: Vector2 = font.get_string_size(face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
		center -= text_size / 2.0
		for x: float in [-2, 2]:
			for y: float in [-2, 2]:
				draw_string(font, center + Vector2(x, y), face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.DARK_SLATE_GRAY)
		draw_string(font, center, face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.FLORAL_WHITE)
	_draw_transform(flat_transform, in_obb.box.size * 0.25, true)


func _get_distance_to_camera_sqrd(in_global_pos: Vector3) -> float:
	if _camera.projection == Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
		return _camera.global_position.distance_squared_to(in_global_pos)
	else:
		var local_pos: Vector3 = _camera.to_local(in_global_pos)
		var depth: float = abs(local_pos.z)
		return depth * depth


func _on_alignment_tools_enabled_changed(in_enabled: bool) -> void:
	set_process(in_enabled)
	queue_redraw()


func _on_align_relative_to_changed() -> void:
	queue_redraw()


func _on_history_changed() -> void:
	queue_redraw()


func _on_representation_changed(in_representation_settings: RepresentationSettings) -> void:
	_highlight_color = in_representation_settings.get_theme().get_highlight_color()
	if in_representation_settings.get_custom_selection_outline_color_enabled():
		_highlight_color = in_representation_settings.get_custom_selection_outline_color()
	if _highlight_color.v < 0.3 or _highlight_color.s > 0.7:
		_lowlight_color = _highlight_color.lightened(0.5)
	else:
		_lowlight_color = _highlight_color.darkened(0.5)
	queue_redraw()
