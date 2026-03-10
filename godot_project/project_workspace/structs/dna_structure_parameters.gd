class_name DnaStructureParameters extends Resource


enum StrandPolicy {
	A,
	B,
	DOUBLE
}

enum BackboneColorPolicy {
	BACKBONE_NO_COLORS,
	BACKBONE_PER_STRAND,
}
enum SugarsColorPolicy {
	SUGAR_SAME_AS_BACKBONE,
	SUGAR_SAME_AS_BASES,
}
enum BasesColorPolicy {
	BASES_NO_COLORS,
	BASES_PER_STRAND,
	BASES_MAJOR_MINOR_GROOVE,
	BASES_PER_TYPE,
}
const BasesColorSchema = DnaBaseColorPalette.Schema


@export var bases_per_turn: float = 10.0
@export var rise_nanometers: float = 0.34
@export var dna_radius_nanometers: float = 1.0
@export var initial_twist_rad: float = 0.0
@export var strand_policy := StrandPolicy.DOUBLE
@export var backbone_color_policy := BackboneColorPolicy.BACKBONE_NO_COLORS
@export var sugar_color_policy := SugarsColorPolicy.SUGAR_SAME_AS_BACKBONE
@export var bases_color_policy := BasesColorPolicy.BASES_NO_COLORS
@export var backbone_strand_colors: Dictionary[StringName, Color]
@export var bases_strand_colors: Dictionary[StringName, Color]
@export var major_groove_color := DnaBaseColorPalette.DEFAULT_MAJOR_GROOVE
@export var minor_groove_color := DnaBaseColorPalette.DEFAULT_MINOR_GROOVE
@export var bases_color_schema := BasesColorSchema.STANDARD
@export var bases_custom_colors: Dictionary[StringName, Color] = DnaBaseColorPalette.get_schema_colors_or_empty(BasesColorSchema.STANDARD)


var _is_read_only: bool = false


func set_read_only(in_read_only: bool) -> void:
	_is_read_only = in_read_only


func _set(property: StringName, _value: Variant) -> bool:
	if _is_read_only and property in [&"bases_per_turn", &"rise_nanometers", &"dna_radius_nanometers", &"initial_twist_rad",
			&"strand_policy", &"include_hydrogens", &"backbone_color_policy", &"sugar_color_policy",
			&"bases_color_policy", &"major_groove_color", &"minor_groove_color", &"bases_color_schema"]:
		assert(!_is_read_only)
		pass
	return false


func create_state_snapshot() -> Dictionary:
	var state_snapshot: Dictionary = {}
	state_snapshot["bases_per_turn"] = bases_per_turn
	state_snapshot["rise_nanometers"] = rise_nanometers
	state_snapshot["dna_radius_nanometers"] = dna_radius_nanometers
	state_snapshot["initial_twist_rad"] = initial_twist_rad
	state_snapshot["strand_policy"] = strand_policy
	state_snapshot["backbone_color_policy"] = backbone_color_policy
	state_snapshot["sugar_color_policy"] = sugar_color_policy
	state_snapshot["bases_color_policy"] = bases_color_policy
	state_snapshot["backbone_strand_colors"] = backbone_strand_colors.duplicate()
	state_snapshot["bases_strand_colors"] = bases_strand_colors.duplicate()
	state_snapshot["major_groove_color"] = major_groove_color
	state_snapshot["minor_groove_color"] = minor_groove_color
	state_snapshot["bases_color_schema"] = bases_color_schema
	state_snapshot["bases_custom_colors"] = bases_custom_colors.duplicate()
	return state_snapshot


func apply_state_snapshot(in_state_snapshot: Dictionary) -> void:
	bases_per_turn = in_state_snapshot["bases_per_turn"]
	rise_nanometers = in_state_snapshot["rise_nanometers"]
	dna_radius_nanometers = in_state_snapshot["dna_radius_nanometers"]
	initial_twist_rad = in_state_snapshot["initial_twist_rad"]
	strand_policy = in_state_snapshot["strand_policy"]
	backbone_color_policy = in_state_snapshot["backbone_color_policy"]
	sugar_color_policy = in_state_snapshot["sugar_color_policy"]
	bases_color_policy = in_state_snapshot["bases_color_policy"]
	backbone_strand_colors = in_state_snapshot["backbone_strand_colors"].duplicate()
	bases_strand_colors = in_state_snapshot["bases_strand_colors"].duplicate()
	major_groove_color = in_state_snapshot["major_groove_color"]
	minor_groove_color = in_state_snapshot["minor_groove_color"]
	bases_color_schema = in_state_snapshot["bases_color_schema"]
	bases_custom_colors = in_state_snapshot["bases_custom_colors"].duplicate()
