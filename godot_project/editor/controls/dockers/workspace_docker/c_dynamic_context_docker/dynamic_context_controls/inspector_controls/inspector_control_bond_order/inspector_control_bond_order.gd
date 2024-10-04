class_name InspectorControlBondOrder extends InspectorControl


const ITEM_ID_SINGLE_BOND = 0
const ITEM_ID_DOUBLE_BOND = 1
const ITEM_ID_TRIPLE_BOND = 2

const BOND_ORDER_TO_OPTION_IDX = {
	1 : ITEM_ID_SINGLE_BOND,
	2 : ITEM_ID_DOUBLE_BOND,
	3 : ITEM_ID_TRIPLE_BOND,
	-1 : ITEM_ID_SINGLE_BOND,
	-2 : ITEM_ID_DOUBLE_BOND,
	-3 : ITEM_ID_TRIPLE_BOND,
}

var _structure_context: StructureContext
var _bond_id: int = AtomicStructure.INVALID_BOND_ID
var _is_editable: bool

var _option_button: OptionButton


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_option_button = $"OptionButton"
	if in_what == NOTIFICATION_READY:
		assert(_bond_id != AtomicStructure.INVALID_BOND_ID, "Needs to be initalized with setup() before adding to a tree")
		pass


func setup(in_structure_context: StructureContext, in_bond_id: int, in_is_editable: bool) -> void:
	_structure_context = in_structure_context
	_bond_id = in_bond_id
	_is_editable = in_is_editable
	
	var bond: Vector3i = in_structure_context.nano_structure.get_bond(_bond_id)
	var bond_order: int = bond.z
	_option_button.select(BOND_ORDER_TO_OPTION_IDX[bond_order])


func is_editable() -> bool:
	return _is_editable


func _on_option_button_item_selected(in_index: int) -> void:
	var bond_order: int = BOND_ORDER_TO_OPTION_IDX.find_key(in_index)
	var old_order: int = _structure_context.nano_structure.get_bond(_bond_id).z
	if bond_order == old_order:
		return
	# Note: this process does not modify selection, but we want to make sure
	#+the selection is "reverted" on undo/redo operations
	_structure_context.nano_structure.start_edit()
	_structure_context.nano_structure.bond_set_order(_bond_id, bond_order)
	_structure_context.nano_structure.end_edit()
	_structure_context.workspace_context.snapshot_moment(tr("Change Bond Order"))
