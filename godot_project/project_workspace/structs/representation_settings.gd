class_name RepresentationSettings extends Resource


signal representation_changed(new_representation: Rendering.Representation)
signal balls_and_sticks_size_factor_changed(new_factor: float)
signal balls_and_sticks_size_source_changed(new_source: RepresentationSettings.UserAtomSizeSource)
signal bond_visibility_changed(are_visible: bool)
signal hydrogen_visibility_changed(are_visible: bool)
signal atom_labels_visibility_changed(are_visible: bool)
signal theme_changed()
signal color_schema_changed(new_color_schema: PeriodicTable.ColorSchema)

const LABELS_VISIBLE_BY_DEFAULT = false
const HYDROGENS_VISIBLE_BY_DEFAULT = true
const BONDS_VISIBLE_BY_DEFAULT = true
const ATOMS_AUTO_POSING_VISIBLE_BY_DEFAULT = true

enum UserAtomSizeSource {
	PHYSICAL_RADIUS,
	VAN_DER_WAALS_RADIUS
}

@export var _rendering_representation := Rendering.Representation.BALLS_AND_STICKS


@export var _balls_and_sticks_size_source := UserAtomSizeSource.VAN_DER_WAALS_RADIUS


@export var _balls_and_sticks_size_factor: float = 0.3


@export var _hydrogens_visible: bool = HYDROGENS_VISIBLE_BY_DEFAULT


@export var _display_bonds: bool = BONDS_VISIBLE_BY_DEFAULT


@export var _display_atom_labels: bool = LABELS_VISIBLE_BY_DEFAULT


@export var _display_auto_posing: bool = ATOMS_AUTO_POSING_VISIBLE_BY_DEFAULT


@export var _custom_selection_outline_color_enabled: bool = false


@export var _custom_selection_outline_color: Color


@export var _custom_background_color_enabled: bool = false


@export var _custom_background_color: Color


@export var _theme: Theme3D = load("res://theme/theme_3d/available_themes/modern_theme/modern_theme.tres")


@export var _color_schema: PeriodicTable.ColorSchema = PeriodicTable.ColorSchema.MSEP


func set_balls_and_sticks_size_source(in_size_souce: UserAtomSizeSource) -> void:
	_balls_and_sticks_size_source = in_size_souce
	balls_and_sticks_size_source_changed.emit(_balls_and_sticks_size_source)
	emit_changed()


func get_balls_and_sticks_size_source() -> UserAtomSizeSource:
	return _balls_and_sticks_size_source


func set_balls_and_sticks_size_factor(new_balls_and_sticks_size_factor: float) -> void:
	if _balls_and_sticks_size_factor == new_balls_and_sticks_size_factor:
		return
	_balls_and_sticks_size_factor = new_balls_and_sticks_size_factor
	balls_and_sticks_size_factor_changed.emit(_balls_and_sticks_size_factor)
	emit_changed()


func get_balls_and_sticks_size_factor() -> float:
	return _balls_and_sticks_size_factor


func set_hydrogens_visible(new_hydrogens_visibility: bool) -> void:
	_hydrogens_visible = new_hydrogens_visibility
	emit_changed()


func get_hydrogens_visible() -> bool:
	return _hydrogens_visible


func set_display_bonds(new_display_bonds: bool) -> void:
	_display_bonds = new_display_bonds
	emit_changed()


func get_display_bonds() -> bool:
	return _display_bonds


func set_display_atom_labels(new_display_atom_labels: bool) -> void:
	_display_atom_labels = new_display_atom_labels
	emit_changed()


func get_display_atom_labels() -> bool:
	return _display_atom_labels


func set_display_auto_posing(new_display_auto_posing: bool) -> void:
	_display_auto_posing = new_display_auto_posing
	emit_changed()


func get_display_auto_posing() -> bool:
	return _display_auto_posing


func set_bond_visibility_and_notify(new_bond_visibility: bool) -> void:
	if _display_bonds == new_bond_visibility:
		return
	_display_bonds = new_bond_visibility
	bond_visibility_changed.emit(_display_bonds)


func set_hydrogen_visibility_and_notify(new_hydrogen_visibility: bool) -> void:
	if _hydrogens_visible == new_hydrogen_visibility:
		return
	_hydrogens_visible = new_hydrogen_visibility
	hydrogen_visibility_changed.emit(_hydrogens_visible)


func set_atom_labels_visibility_and_notify(new_label_visibility: bool) -> void:
	if _display_atom_labels == new_label_visibility:
		return
	_display_atom_labels = new_label_visibility
	atom_labels_visibility_changed.emit(_display_atom_labels)


func set_rendering_representation(new_representation: Rendering.Representation) -> void:
	if new_representation == _rendering_representation:
		return
	_rendering_representation = new_representation
	representation_changed.emit(new_representation)
	emit_changed()


func get_rendering_representation() -> Rendering.Representation:
	return _rendering_representation


func set_custom_selection_outline_color_enabled(p_value: bool) -> void:
	_custom_selection_outline_color_enabled = p_value
	changed.emit()


func get_custom_selection_outline_color_enabled() -> bool:
	return _custom_selection_outline_color_enabled


func set_custom_selection_outline_color(p_color: Color) -> void:
	_custom_selection_outline_color = p_color
	changed.emit()


func get_custom_selection_outline_color() -> Color:
	return _custom_selection_outline_color


func set_custom_background_color_enabled(p_value: bool) -> void:
	_custom_background_color_enabled = p_value
	changed.emit()


func get_custom_background_color_enabled() -> bool:
	return _custom_background_color_enabled


func set_custom_background_color(p_color: Color) -> void:
	_custom_background_color = p_color
	changed.emit()


func get_custom_background_color() -> Color:
	return _custom_background_color


func set_theme(new_theme: Theme3D) -> void:
	_theme = new_theme
	theme_changed.emit()


func get_theme() -> Theme3D:
	return _theme


func set_color_schema(new_color_schema: PeriodicTable.ColorSchema) -> void:
	if _color_schema != new_color_schema:
		_color_schema = new_color_schema
		color_schema_changed.emit(new_color_schema)


func get_color_schema() -> PeriodicTable.ColorSchema:
	return _color_schema


func deep_copy() -> RepresentationSettings:
	var copy := RepresentationSettings.new()
	copy._rendering_representation = _rendering_representation
	copy._balls_and_sticks_size_source = _balls_and_sticks_size_source
	copy._balls_and_sticks_size_factor = _balls_and_sticks_size_factor
	copy._hydrogens_visible = _hydrogens_visible
	copy._display_bonds = _display_bonds
	copy._display_atom_labels = _display_atom_labels
	copy._custom_selection_outline_color_enabled = _custom_selection_outline_color_enabled
	copy._custom_selection_outline_color = _custom_selection_outline_color
	copy._custom_background_color_enabled = _custom_background_color_enabled
	copy._custom_background_color = _custom_background_color
	copy._theme = _theme.duplicate(true)
	copy._color_schema = _color_schema
	return copy
	

func create_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		#structures are already snapshoted by StructureContext, with exception there is edge case where structure is being removed / merged
		"_rendering_representation" : _rendering_representation,
		"_balls_and_sticks_size_source" : _balls_and_sticks_size_source,
		"_balls_and_sticks_size_factor" : _balls_and_sticks_size_factor,
		"_hydrogens_visible" : _hydrogens_visible,
		"_display_bonds" : _display_bonds,
		"_display_atom_labels" : _display_atom_labels,
		"_custom_selection_outline_color_enabled" : _custom_selection_outline_color_enabled,
		"_custom_selection_outline_color" : _custom_selection_outline_color,
		"_custom_background_color_enabled" : _custom_background_color_enabled,
		"_custom_background_color" : _custom_background_color,
		"_theme.path" : _theme.resource_path,
		"_color_schema" : _color_schema,
		
	}
	return snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	_rendering_representation = in_state_snapshot["_rendering_representation"]
	_balls_and_sticks_size_source = in_state_snapshot["_balls_and_sticks_size_source"]
	_balls_and_sticks_size_factor = in_state_snapshot["_balls_and_sticks_size_factor"]
	_hydrogens_visible = in_state_snapshot["_hydrogens_visible"]
	_display_bonds = in_state_snapshot["_display_bonds"]
	_display_atom_labels = in_state_snapshot["_display_atom_labels"]
	_custom_selection_outline_color_enabled = in_state_snapshot["_custom_selection_outline_color_enabled"]
	_custom_selection_outline_color = in_state_snapshot["_custom_selection_outline_color"]
	_custom_background_color_enabled = in_state_snapshot["_custom_background_color_enabled"]
	_custom_background_color = in_state_snapshot["_custom_background_color"]
	_theme = load(in_state_snapshot["_theme.path"])
	_color_schema = in_state_snapshot["_color_schema"]
