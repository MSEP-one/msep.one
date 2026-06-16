class_name AlignSelectionPreview extends Control

## This enum is used for debug purposes,
## Set the value of DRAW_TRANSFORM_AT constant to enable it
enum DrawTransformAt {
	None = 0x0,
	BoxOrigin = 0x1 << 0,
	LowlightedFace = 0x1 << 1,
	HighlightedFace = 0x1 << 2,
	All = BoxOrigin | HighlightedFace | LowlightedFace,
}
const DRAW_TRANSFORM_AT: DrawTransformAt = DrawTransformAt.None
const FACE_HIGHLIGHT_TEXTURE: Texture2D = preload("res://editor/controls/dockers/workspace_docker/a_create_docker/controls/icons/stripes.svg")
const FACE_HIGHLIGHT_OPACITY: float = 0.35
const FACE_LOWLIGHT_OPACITY: float = 0.15

const AlignSelectionGroupingPolicy = AlignSelectionParameters.AlignSelectionGroupingPolicy
const AlignRelativeTo = AlignSelectionParameters.AlignRelativeTo
const BoxFace = AlignSelectionParameters.BoxFace


var _camera: Camera3D
var _camera_last_transform: Transform3D
var _camera_last_zoom: float
var _camera_last_projection: Camera3D.ProjectionType

var _highlight_color: Color
var _highlight_thickness: float = -1.0
var _lowlight_color: Color
var _lowlight_thickness: float = -1.0


var _workspace_context: WorkspaceContext
var _align_selection_parameters: AlignSelectionParameters


func _ready() -> void:
	set_process(false)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_camera = get_viewport().get_camera_3d()
	_ready_deferred.call_deferred()
	
	var window: Window = get_tree().root as Window
	window.dpi_changed.connect(_adjust_lines_thickness)
	_adjust_lines_thickness()


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
	const OPPOSITE_FACE: Dictionary[BoxFace, BoxFace] = {
		BoxFace.UNDEFINED: BoxFace.UNDEFINED,
		BoxFace.FRONT: BoxFace.BACK,
		BoxFace.BACK: BoxFace.FRONT,
		BoxFace.TOP: BoxFace.BOTTOM,
		BoxFace.BOTTOM: BoxFace.TOP,
		BoxFace.LEFT: BoxFace.RIGHT,
		BoxFace.RIGHT: BoxFace.LEFT,
	}
	if not is_processing() or _align_selection_parameters == null:
		return
	
	var alignable_boxes: Array[AlignableOBB] = _align_selection_parameters.get_alignable_boxes()
	var highlighted_obb: OBB = _align_selection_parameters.get_align_obb_target()
	for obb: AlignableOBB in alignable_boxes:
		if obb == null or obb == highlighted_obb:
			continue
		_draw_obb_face(obb, obb.selected_face, false, true)
		if _align_selection_parameters.is_align_depth_enabled():
			_draw_obb_face(obb, OPPOSITE_FACE[obb.selected_face], false, false)
		_draw_obb_reference_point(obb, obb.selected_face, false)
		_draw_transform(obb.transform, obb.box.size * 0.25, false)
	if highlighted_obb != null:
		if _align_selection_parameters.is_align_depth_enabled():
			_draw_obb_face(highlighted_obb, OPPOSITE_FACE[highlighted_obb.align_to_face], false)
		_draw_obb_face(highlighted_obb, highlighted_obb.align_to_face, true)
		_draw_obb_reference_point(highlighted_obb, highlighted_obb.align_to_face, true)


func _draw_transform(t: Transform3D, handle_size: Vector3, is_highlighted_face: bool) -> void:
	var from: Vector3 = t.origin
	var from2d: Vector2 = _camera.unproject_position(from)
	const COLORS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
	if is_highlighted_face and (DRAW_TRANSFORM_AT & DrawTransformAt.HighlightedFace == 0):
		return
	if (not is_highlighted_face) and (DRAW_TRANSFORM_AT & DrawTransformAt.LowlightedFace == 0):
		return
	if (not is_highlighted_face) and (DRAW_TRANSFORM_AT & DrawTransformAt.BoxOrigin == 0):
		return
	for i in 3:
		var to: Vector3 = from + t.basis[i] * max(handle_size[i], 0.1)
		var to2d: Vector2 = _camera.unproject_position(to)
		var col: Color = COLORS[i]
		if !is_highlighted_face:
			col *= 0.75
		draw_line(from2d, to2d, col, _lowlight_thickness)


func _draw_obb_face(in_obb: AlignableOBB, in_face: BoxFace, in_highlighted: bool = false, in_filled: bool = in_highlighted) -> void:
	if in_obb == null or in_face == BoxFace.UNDEFINED:
		return
	
	var face_corners: PackedVector3Array
	match in_face:
		BoxFace.TOP:
			face_corners = in_obb.get_face_corners(Vector3.UP)
		BoxFace.BOTTOM:
			face_corners = in_obb.get_face_corners(Vector3.DOWN)
		BoxFace.FRONT:
			face_corners = in_obb.get_face_corners(Vector3.BACK)
		BoxFace.BACK:
			face_corners = in_obb.get_face_corners(Vector3.FORWARD)
		BoxFace.LEFT:
			face_corners = in_obb.get_face_corners(Vector3.LEFT)
		BoxFace.RIGHT:
			face_corners = in_obb.get_face_corners(Vector3.RIGHT)
		
	# Draw half transparent face
	var polygon := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector3 in face_corners:
		var screen_pos: Vector2 = _camera.unproject_position(corner)
		polygon.push_back(screen_pos)
		var uv: Vector2 = screen_pos / DisplayServer.screen_get_dpi()
		if not in_highlighted:
			# squash texture more to differentiate faces easier
			uv *= 5.0
		uvs.push_back(uv)
	var color: Color = _highlight_color if in_highlighted else _lowlight_color
	var thickness: float = _highlight_thickness if in_highlighted else _lowlight_thickness
	var face_size: Vector3 = in_obb.get_face_size(in_face)
	var has_surface: bool = face_size.x * face_size.y > 0
	if in_filled and has_surface:
		var opacity: float = FACE_HIGHLIGHT_OPACITY if in_highlighted else FACE_LOWLIGHT_OPACITY
		draw_colored_polygon(polygon, Color(_highlight_color, opacity), uvs, FACE_HIGHLIGHT_TEXTURE)
	for i: int in polygon.size():
		var from: Vector2 = polygon[i]
		var to: Vector2 = polygon[(i + 1) % polygon.size()]
		draw_line(from, to, color, thickness)


func _draw_obb_reference_point(in_obb: AlignableOBB, in_face: BoxFace, in_highlighted: bool) -> void:
	if in_face == BoxFace.UNDEFINED:
		return
	if _align_selection_parameters.is_advanced_settings_enabled():
		var basis: Basis = in_obb.get_face_basis(in_face)
		var origin: Vector3 = in_obb.transform.origin
		var face_size: Vector3 = in_obb.get_face_size(in_face)
		var ref_point: Vector3 = origin
		ref_point += basis.x * (in_obb.offset_ratio_h * face_size.x)
		ref_point += basis.y * (in_obb.offset_ratio_v * face_size.y)
		var no_depth_ref_point: Vector3 = ref_point
		if _align_selection_parameters.is_align_depth_enabled():
			ref_point += basis.z * (in_obb.offset_ratio_d * face_size.z)
		else:
			ref_point += basis.z * (face_size.z * 0.5)
		var ref_point_2d: Vector2 = _camera.unproject_position(ref_point)
		var _h_dir_2d: Vector2 = (_camera.unproject_position(ref_point + basis[0] * 200) - ref_point_2d).normalized()
		var _v_dir_2d: Vector2 = (_camera.unproject_position(ref_point + basis[1] * 200) - ref_point_2d).normalized()
		var draw_h_from: Vector2 = ref_point_2d - _h_dir_2d * 20
		var draw_h_to: Vector2 = ref_point_2d + _h_dir_2d * 20
		var draw_v_from: Vector2 = ref_point_2d - _v_dir_2d * 20
		var draw_v_to: Vector2 = ref_point_2d + _v_dir_2d * 20
		if _align_selection_parameters.is_align_depth_enabled():
			var depth_line_from: Vector3 = no_depth_ref_point + basis.z * (face_size.z * 0.5)
			var depth_line_to: Vector3 = no_depth_ref_point - basis.z * (face_size.z * 0.5)
			var depth_line_from_2d: Vector2 = _camera.unproject_position(depth_line_from)
			var depth_line_to_2d: Vector2 = _camera.unproject_position(depth_line_to)
			draw_dashed_line(depth_line_from_2d, depth_line_to_2d, Color.BLUE, 2, 15)
		var thickness: float = _highlight_thickness if in_highlighted else _lowlight_thickness
		draw_line(draw_h_from, draw_h_to, Color.RED, thickness)
		draw_line(draw_v_from, draw_v_to, Color.GREEN, thickness)
	
	if DRAW_TRANSFORM_AT & (DrawTransformAt.HighlightedFace | DrawTransformAt.LowlightedFace) != 0:
		var basis: Basis = in_obb.get_face_basis(in_face)
		var origin: Vector3 = in_obb.transform.origin
		var face_transform := Transform3D(basis, origin)
		face_transform.origin += basis.z * (in_obb.get_face_size(in_face).z * 0.5)
		var font := get_theme_font(&"Label", &"HeaderLarge")
		var center: Vector2 = _camera.unproject_position(face_transform.origin)
		var face_name: String = str(BoxFace.find_key(in_face))
		face_name = face_name.capitalize().replace(" ", "/")
		var text_size: Vector2 = font.get_string_size(face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
		center -= text_size / 2.0
		for x: float in [-2, 2]:
			for y: float in [-2, 2]:
				draw_string(font, center + Vector2(x, y), face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.DARK_SLATE_GRAY)
		draw_string(font, center, face_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.FLORAL_WHITE)
		_draw_transform(face_transform, in_obb.box.size * 0.25, in_highlighted)


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


func _adjust_lines_thickness() -> void:
	# NOTE: This formula is a best effort to get line thickness in different monitor sizes and resolutions
	# We cannot use DisplayServer.get_screen_dpi() because is reported to be unreliable
	# and has already produced wrong results in some of our machines
	# So we calculate the thickness for a 15.5 inches monitor, which is more or less the median value
	# for notebooks systems (ranging from 13 to 24 inches)
	# In desktop systems using bigger monitors line will look thinner,
	# but screen space will be larger, so should be noticeble enough
	var screen_index: int = DisplayServer.window_get_current_screen()
	var resolution: Vector2 = DisplayServer.screen_get_size(screen_index)
	const ASSUMED_MONITOR_SIZE_INCHES := 15.5
	const INCHES_TO_MILLIMETERS := 25.4
	var dpm: float = resolution.length() / (ASSUMED_MONITOR_SIZE_INCHES * INCHES_TO_MILLIMETERS)
	const LOWLIGHT_THICKNESS_MILLIMETERS: float = 0.55
	const HIGHLIGHT_THICKNESS_MILLIMETERS: float = 0.7
	_lowlight_thickness = dpm * LOWLIGHT_THICKNESS_MILLIMETERS
	_highlight_thickness = dpm * HIGHLIGHT_THICKNESS_MILLIMETERS
