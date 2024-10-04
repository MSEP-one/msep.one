@tool
extends Control

@export_category("Theme")
@export var background_stylebox: StyleBoxFlat
@export var general_label_settings: LabelSettings
@export var symbol_label_settings: LabelSettings
@export_subgroup("Exposed Information", "visible_")
@export var visible_atomic_number: bool = true:
	set(v):
		visible_atomic_number = v
		if !is_instance_valid(number):
			await ready
		number.visible = v
@export var visible_symbol: bool = true:
	set(v):
		visible_symbol = v
		if !is_instance_valid(symbol):
			await ready
		symbol.visible = v
@export var visible_element_name: bool = true:
	set(v):
		visible_element_name = v
		if !is_instance_valid(element_name):
			await ready
		element_name.visible = v
@export var visible_mass: bool = true:
	set(v):
		visible_mass = v
		if !is_instance_valid(mass):
			await ready
		mass.visible = v
@export var visible_unknown_vdw_radii_notice: bool = false:
	set(v):
		visible_unknown_vdw_radii_notice = v
		if !is_instance_valid(label_render_warning):
			await ready
		_update_unknown_vdw_radii_notice()


@onready var number: Label = %Number
@onready var symbol: Label = %Symbol
@onready var element_name: Label = %ElementName
@onready var mass: Label = %Mass
@onready var label_render_warning: Label = %LabelRenderWarning

var _atomic_number: int
var _is_render_radii_known: bool = true
var _is_vdw_radii_known: bool = true


func set_element_number(in_atomic_number: int) -> void:
	_atomic_number = in_atomic_number
	if !is_instance_valid(number):
		await ready
	number.text = str(_atomic_number)
	set_element_data(PeriodicTable.get_by_atomic_number(_atomic_number))


func set_element_data(in_data: ElementData) -> void:
	if !is_instance_valid(symbol):
		# Called before ready, early return
		return
	if !is_instance_valid(in_data):
		symbol.text = "?"
		element_name.text = "Unknown"
		mass.text = "0.0"
		background_stylebox.bg_color = Color.BLACK
		general_label_settings.font_color = Color.WHITE
		symbol_label_settings.font_color = Color.WHITE
		_is_vdw_radii_known = false
	else:
		symbol.text = in_data.symbol
		element_name.text = in_data.name
		mass.text = str(in_data.mass)
		background_stylebox.bg_color = in_data.color
		general_label_settings.font_color = in_data.font_color
		symbol_label_settings.font_color = in_data.font_color
		_is_vdw_radii_known = in_data.is_contact_radius_known
		_is_render_radii_known = in_data.is_render_radius_known
		if _is_vdw_radii_known or _is_render_radii_known:
			background_stylebox.border_color = Color.BLACK
		else:
			background_stylebox.border_color = Color.DARK_RED
	_update_unknown_vdw_radii_notice()


func _ready() -> void:
	number.label_settings = general_label_settings
	symbol.label_settings = symbol_label_settings
	element_name.label_settings = general_label_settings
	mass.label_settings = general_label_settings
	label_render_warning.label_settings = general_label_settings


func _update_unknown_vdw_radii_notice() -> void:
	if visible_unknown_vdw_radii_notice:
		label_render_warning.visible = !_is_vdw_radii_known
		label_render_warning.text = "🚫" if !_is_render_radii_known else "⚠️"
		label_render_warning.tooltip_text = (
			"The Van Der Waals Radius and physical radius of this element is unknown.\n" +
			"This element cannot be created because it cannot be represented."
			if !_is_render_radii_known else
			"The Van Der Waals Radius of this element is unknown.\n" +
			"The visual representation of this atom in 3D space will be innacurate."
		)
	else:
		label_render_warning.visible = false
