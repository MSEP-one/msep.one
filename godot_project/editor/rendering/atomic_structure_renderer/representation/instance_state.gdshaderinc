// Holds logic to unpack flags from the color alpha value

float _unpack_flag(int value, int bitmask) {
	return float(value % (bitmask * 2) >= bitmask);
}

float is_atom_or_bond_visible(float value) {
	return _unpack_flag(int(value), 1);
}

float is_atom_or_bond_hovered(float value) {
	return _unpack_flag(int(value), 2);
}

float is_atom_or_bond_selected(float value) {
	return _unpack_flag(int(value), 4);
}

float is_atom_locked(float value) {
	return _unpack_flag(int(value), 8);
}

float is_first_atom_selected(float value) {
	return _unpack_flag(int(value), 16);
}

float is_second_atom_selected(float value) {
	return _unpack_flag(int(value), 32);
}

// Utility

float is_atom_or_bond_hidden(float value) {
	return 1.0 - is_atom_or_bond_visible(value);
}
