@tool
extends Resource
class_name ElementData

const NOBLE_GAS_GROUP: int = 18
const PICOMETERS_TO_NANOMETERS: float = 1.0 / 1000.0
const PROPERTY_NAME_CONTACT_RADIUS: StringName = &"contact_radius"
const PROPERTY_NAME_RENDER_RADIUS: StringName = &"render_radius"
const VAN_DER_WAALS_FALLBACK_FACTOR_SETTING: StringName = \
		&"msep/rendering/fallbacks/van_der_waals_radius_factor"

@export var number : int
@export var period : int
@export var group : int
@export var symbol : String
@export var name : String
@export var mass : float # g/mol
@export var render_radius : float # in nanometers
@export var is_render_radius_known: bool = true
@export var contact_radius : float: # in nanometers
	get = _get_contact_radius
@export var is_contact_radius_known: bool = true
@export var covalent_radius : Dictionary # in nanometers, up to 3 values
@export var valence : int
@export var stable_isotopes : int
@export var melting_point : float # in kelvin
@export var boiling_point : float # in kelvin
@export var density : float # g/cm3
@export var color : Color
@export var noise_color: Color
@export var bond_color: Color
@export var font_color : Color
@export var noise_atlas_id: float


func _init(csv_data : String) -> void:
	var data := Array(csv_data.split(","))
	assert(data.size() >= 18)
	number = data.pop_front().to_int()
	period = data.pop_front().to_int()
	group = data.pop_front().to_int()
	symbol = data.pop_front()
	name = data.pop_front()
	mass = data.pop_front().replace("~", "").to_float()
	var render_radius_str: String = data.pop_front()
	if render_radius_str.is_empty():
		is_render_radius_known = false
	else:
		render_radius = render_radius_str.to_float() * PICOMETERS_TO_NANOMETERS
	var contact_radius_str: String = data.pop_front()
	if contact_radius_str.is_empty():
		contact_radius = 0
		is_contact_radius_known = false
	else:
		contact_radius = contact_radius_str.to_float() * PICOMETERS_TO_NANOMETERS
	for order in range(1, 4):
		covalent_radius[order] = data.pop_front().to_float() * PICOMETERS_TO_NANOMETERS
	valence = data.pop_front().to_int()
	stable_isotopes = data.pop_front().to_int()
	melting_point = data.pop_front().to_float()
	boiling_point = data.pop_front().to_float()
	density = data[0].replace("*", "").to_float()
	if data.pop_front().find("*") != -1:
		# convert g/L to g/cm3
		density /= 1000
	color = Color(data.pop_front())
	noise_color = Color(data.pop_front())
	bond_color = Color(data.pop_front())
	font_color = Color(data.pop_front())
	noise_atlas_id = float(data.pop_front())


func _get_contact_radius() -> float:
	if is_contact_radius_known:
		return contact_radius
	var fallback_factor: float = ProjectSettings.get_setting(VAN_DER_WAALS_FALLBACK_FACTOR_SETTING, 1.5)
	return render_radius * fallback_factor
