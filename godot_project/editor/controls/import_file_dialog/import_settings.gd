extends VBoxContainer

# <FIXME> 2023-07-14 by @msuligoy: post process options are not working as intended,
# because of this I opted by removing the options until they are fixed
@onready var _check_autogenerate_bonds: CheckBox = %CheckAutogenerateBonds
@onready var _check_add_missing_hydrogens: CheckBox = %CheckAddMissingHydrogens
@onready var _check_remove_waters: CheckBox = %CheckRemoveWaters
# </FIXME>

@onready var _check_create_new_group: CheckBox = %CheckCreateNewGroup
@onready var _option_button_placement: OptionButton = %OptionButtonPlacement


func is_autogenerate_bonds_enabled() -> bool:
	return _check_autogenerate_bonds.visible and _check_autogenerate_bonds.button_pressed


func is_add_missing_hydrogens_enabled() -> bool:
	return _check_add_missing_hydrogens.visible and _check_add_missing_hydrogens.button_pressed


func is_remove_waters_enabled() -> bool:
	return _check_remove_waters.visible and _check_remove_waters.button_pressed


func is_create_new_group_enabled() -> bool:
	return _check_create_new_group.visible and _check_create_new_group.button_pressed


func get_desired_placement() -> int:
	return _option_button_placement.selected

