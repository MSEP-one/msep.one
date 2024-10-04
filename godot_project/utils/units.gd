class_name Units


enum DISTANCE_UNITS {
	NANOMETERS = 0,
}


enum MASS_UNITS {
	MOLAR_MASS = 0,
}


const _DISTANCE_UNITS_CONVERSION_FACTORS: Dictionary = { # DISTANCE_UNITS, float
	DISTANCE_UNITS.NANOMETERS: 1.0,
}

const _DISTANCE_UNIT_STRINGS: Dictionary = { # DISTANCE_UNITS, String
	DISTANCE_UNITS.NANOMETERS: "nm",
}

const _MASS_UNITS_CONVERSION_FACTORS: Dictionary = { # MASS_UNITS, float
	MASS_UNITS.MOLAR_MASS: 1.0,
}

const _MASS_UNIT_STRINGS: Dictionary = { # MASS_UNITS, String
	MASS_UNITS.MOLAR_MASS: "g/mol",
}


static var _selected_distance_unit: int = DISTANCE_UNITS.NANOMETERS
static var _selected_mass_unit: int = MASS_UNITS.MOLAR_MASS


static func get_distance_unit() -> int:
	return _selected_distance_unit


static func get_distance_conversion_factor() -> float:
	return _DISTANCE_UNITS_CONVERSION_FACTORS[_selected_distance_unit]


static func get_distance_unit_string() -> String:
	return _DISTANCE_UNIT_STRINGS[_selected_distance_unit]


static func get_mass_unit() -> int:
	return _selected_mass_unit


static func get_mass_conversion_factor() -> float:
	return _MASS_UNITS_CONVERSION_FACTORS[_selected_mass_unit]


static func get_mass_unit_string() -> String:
	return _MASS_UNIT_STRINGS[_selected_mass_unit]
