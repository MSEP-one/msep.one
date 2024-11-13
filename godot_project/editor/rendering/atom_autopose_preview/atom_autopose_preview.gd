class_name AtomAutoposePreview extends Control


class AtomCandidate:
	var structrure_id: int
	var atom_ids: PackedInt32Array
	var atom_position: Vector3
	var pos_2d_cache: Vector2 = Vector2.ONE * -15


var _new_atomic_number: int = PeriodicTable.ATOMIC_NUMBER_HYDROGEN
var _new_bond_order: int = 1 # NOTE: Ignored at the moment
var _candidates: Array[AtomCandidate]
var _hovered_candidate: AtomCandidate
var _camera: Camera3D
var _camera_last_transform: Transform3D


func set_atomic_number(in_atomic_number: int) -> void:
	_new_atomic_number = in_atomic_number
	queue_redraw()


func set_bond_order(in_bond_order: int) -> void:
	_new_bond_order = in_bond_order
	queue_redraw()


func set_candidates(in_candidates: Array[AtomCandidate]) -> void:
	_candidates = in_candidates
	queue_redraw()


func get_hovered_candidate_or_null() -> AtomCandidate:
	return _hovered_candidate


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouse:
		var hovered: AtomCandidate = null
		var hovered_distance_sqrd: float = INF
		const MIN_DISTANCE_SQRD: float = 15*15
		for candidate: AtomCandidate in _candidates:
			var distance_sqrd: float = event.position.distance_squared_to(candidate.pos_2d_cache)
			if distance_sqrd < MIN_DISTANCE_SQRD:
				if distance_sqrd < hovered_distance_sqrd:
					hovered_distance_sqrd = distance_sqrd
					hovered = candidate
		if hovered != _hovered_candidate:
			_hovered_candidate = hovered
			queue_redraw()


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	if visible and is_instance_valid(_camera) and _camera.global_transform != _camera_last_transform:
		_camera_last_transform = _camera.global_transform
		queue_redraw()


# Visual language:
# Line: bond in near connected atom plane
# Wedges (slim triagles): atoms above the connected atom plane
# Dashes: atoms below the connected atom plane
func _draw() -> void:
	# If control is being drawn we assume candidates belongs to the current workspace context
	var font: Font = get_theme_font(&"default_font")
	_camera = get_viewport().get_camera_3d()
	var camera_up_vector: Vector3 = _camera.basis.y
	var curr_atom_data: ElementData = PeriodicTable.get_by_atomic_number(_new_atomic_number)
	const CARBON: int = 6
	var carbon_data: ElementData = PeriodicTable.get_by_atomic_number(CARBON)
	const NITROGEN: int = 7
	var nitrogen_data: ElementData = PeriodicTable.get_by_atomic_number(NITROGEN)
	const OXIGEN: int = 8
	var oxygen_data: ElementData = PeriodicTable.get_by_atomic_number(OXIGEN)
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
	var context: StructureContext = null
	var atomic_structure: AtomicStructure = null
	var candidate_element: ElementData
	for candidate: AtomCandidate in _candidates:
		if context == null or context.nano_structure.int_guid != candidate.structrure_id:
			# OPTIMIZATION: Candidates are meant to be grouped by structure,
			# so this if condition should not be needed to run often
			context = workspace_context.get_structure_context(candidate.structrure_id)
			atomic_structure = context.nano_structure as AtomicStructure
		var pos_2d: Vector2 = _camera.unproject_position(candidate.atom_position)
		candidate.pos_2d_cache = pos_2d
		if not get_rect().grow(15).has_point(pos_2d):
			# clip out of the view
			continue
		match candidate.atom_ids.size():
			1: # Whatever user selected
				candidate_element = curr_atom_data
			2: # Merging 2 candidates, use Oxygen
				candidate_element = oxygen_data
			3: # Merging 3 candidates, use Nitrogen
				candidate_element = nitrogen_data
			4, _: # Merging 4 or more candidates, use Carbon
				candidate_element = carbon_data
		var atom_color: Color = Color.WHITE if _hovered_candidate == candidate else candidate_element.color
		var bond_color: Color = Color.WHITE if _hovered_candidate == candidate else candidate_element.bond_color
		var label_color: Color = Color.DIM_GRAY if _hovered_candidate == candidate else candidate_element.font_color
		for source: int in candidate.atom_ids:
			var atom_pos: Vector3 = atomic_structure.atom_get_position(source)
			var atom_pos_2d: Vector2 = _camera.unproject_position(atom_pos)
			var atom_floor_plane := Plane(camera_up_vector, atom_pos)
			var candidate_projected: Vector3 = atom_floor_plane.project(candidate.atom_position)
			var atom_to_projection_dir: Vector3 = atom_pos.direction_to(candidate_projected)
			var angle: float = Vector3.RIGHT.signed_angle_to(atom_to_projection_dir, Vector3.UP)
			if abs(angle) < PI / 3:
				# Close to the atom plane, draw a line
				_draw_line_connection(atom_pos_2d, pos_2d, bond_color)
			elif angle < 0:
				# negative angle, candidate is abobe the original atom, draw a Wedge
				_draw_wedge_connection(atom_pos_2d, pos_2d, bond_color)
			else:
				# positive angle, candidate is below the original atom, draw dashes
				_draw_dashed_connection(atom_pos_2d, pos_2d, bond_color)
		draw_circle(pos_2d, 15.0, atom_color)
		draw_string(font, pos_2d, candidate_element.symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, label_color)


func _draw_line_connection(in_from: Vector2, in_to: Vector2, in_color: Color) -> void:
	draw_line(in_from, in_to, in_color, 2)



func _draw_wedge_connection(in_from: Vector2, in_to: Vector2, in_color: Color) -> void:
	var dir: Vector2 = in_from.direction_to(in_to)
	var offset_dir: Vector2 = Vector2(dir.y, -dir.x)
	var points: PackedVector2Array = [
		in_from,
		in_to + offset_dir * 3,
		in_to - offset_dir * 3
	]
	var indexes: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	var polygon: PackedVector2Array = []
	var colors: PackedColorArray = []
	for i: int in indexes:
		polygon.append(points[i])
		colors.append(in_color)
	draw_polygon(polygon, colors)


func _draw_dashed_connection(in_from: Vector2, in_to: Vector2, in_color: Color) -> void:
	var distance: float = in_from.distance_to(in_to)
	var dashes_count: int = ceil(distance/3.0)
	var step: float = distance / dashes_count
	var dir: Vector2 = in_from.direction_to(in_to)
	var offset_dir: Vector2 = Vector2(dir.y, -dir.x)
	for i: int in dashes_count:
		var mid_point: Vector2 = in_from + dir * step * i
		var half_dash_lenght: float = (6.0 / 2.0) * (float(i) / float(dashes_count))
		draw_line(
			mid_point - offset_dir * half_dash_lenght,
			mid_point + offset_dir * half_dash_lenght,
			in_color, -1, true)
