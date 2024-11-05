class_name SelectionInfo extends Object

const InspectorControlVector3Scene = preload("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/inspector_controls/inspector_control_vector3/inspector_control_vector3.tscn")
const InspectorControlBondOrderScene = preload("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/inspector_controls/inspector_control_bond_order/inspector_control_bond_order.tscn")

const MAX_VISIBLE_ATOM_POSITIONS = 20
const MAX_VISIBLE_BONDS = 10
const CHARACTER_A = 65
const CHARACTER_ALPHA = 945 # α (greek small alpha)

enum Type {
	RAW,
	READ_ONLY_PROPERTIES,
	READ_WRITE_PROPERTIES
}

static func create_selection_info(structure_context: StructureContext, in_info_type: Type) -> Dictionary:
	var nano_structure: NanoStructure = structure_context.nano_structure
	
	var info: Dictionary = {}
	
	var mass_unit: String = " (%s)" % Units.get_mass_unit_string()
	var distance_unit: String = " (%s)" % Units.get_distance_unit_string()
	# Shape Properties
	if nano_structure is NanoShape and nano_structure.get_shape() != null and structure_context.is_shape_selected():
		var shape_dimensions: Dictionary = {}
		info["Type"] = nano_structure.get_type()
		var position_prop := NanoShapeUtils.ShapeProperty.new("Position", nano_structure.get_position, nano_structure.set_position)
		position_prop.with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		info["Position" + distance_unit] = {"": _create_virtual_object_position_property(in_info_type, structure_context)}
		info["Rotation (degrees)"] = nano_structure.get_transform().basis.get_euler()
		info["Dimensions"] = shape_dimensions
		var shape_properties: Dictionary = NanoShapeUtils.get_reference_shape_properties(nano_structure.get_shape())
		assert(shape_properties.size() > 0, "Failed to obtain reference shape's size properties")
		for prop_name: StringName in shape_properties.keys():
			var property: NanoShapeUtils.ShapeProperty = shape_properties[prop_name]
			assert(property != null)
			var suffix: String = "" if property.unit.is_empty() else (" (%s)" % property.unit)
			match in_info_type:
				Type.RAW:
					shape_dimensions[prop_name.capitalize() + suffix] = property.get_value()
				Type.READ_ONLY_PROPERTIES:
					var editor: Control = NanoShapeUtils.create_shape_property_editor(property, false)
					if editor is Range:
						editor.editable = false
					elif editor is Button:
						editor.disabled = true
					shape_dimensions[prop_name.capitalize() + suffix] = editor
				Type.READ_WRITE_PROPERTIES:
					var editor: Control = NanoShapeUtils.create_shape_property_editor(property, true)
					shape_dimensions[prop_name.capitalize() + suffix] = editor
	elif nano_structure is NanoVirtualMotor and structure_context.is_motor_selected():
		info["Position" + distance_unit] = {"": _create_virtual_object_position_property(in_info_type, structure_context)}
		info["Rotation (degrees)"] = nano_structure.get_transform().basis.get_euler()
	elif nano_structure is NanoVirtualAnchor and structure_context.is_anchor_selected():
		info["Position" + distance_unit] = {"": _create_virtual_object_position_property(in_info_type, structure_context)}
	# Atom Info by atom type
	var selection: Array = structure_context.get_selected_atoms()
	var atomic_numbers: PackedInt32Array = []
	for atom_id: int in selection:
		var atomic_number: int = nano_structure.atom_get_atomic_number(atom_id)
		if !atomic_numbers.has(atomic_number):
			atomic_numbers.push_back(atomic_number)
	match atomic_numbers.size():
		0:
			pass
		1:
			var data: ElementData = PeriodicTable.get_by_atomic_number(atomic_numbers[0])
			info["Element"] = "%s (%s)" % [data.symbol, data.name]
			info["Count"] = selection.size()
			if selection.size() == 1:
				info["Mass" + mass_unit] = data.mass
				info["Position" + distance_unit] = {"": _create_position_property(in_info_type, structure_context, selection[0])}
			else:
				info["Mass (Total)" + mass_unit] = "%.3f %.3f" % \
					[data.mass * Units.get_mass_conversion_factor(),
					data.mass * selection.size() * Units.get_mass_conversion_factor()]
				if selection.size() > MAX_VISIBLE_ATOM_POSITIONS:
					info["Positions"] = "Number of elements exceeds display maximum."
				else:
					var positions: Array = Array()
					info["Positions" + distance_unit] = positions
					for atom_id: int in selection:
						positions.push_back(_create_position_property(in_info_type, structure_context, atom_id))
		_: # More than 1
			info["Total Atoms Count"] = selection.size()
			atomic_numbers.sort()
			var types: Dictionary = Dictionary()
			info["Info by Type"] = types
			for atomic_number in atomic_numbers:
				var is_atom_of_atomic_number: Callable = func(atom_id: int, atomic_number: int) -> bool:
					var atom_atomic_number: int = nano_structure.atom_get_atomic_number(atom_id)
					return atom_atomic_number == atomic_number
				var instances: PackedInt32Array = selection.filter(is_atom_of_atomic_number.bind(atomic_number))
				var data: ElementData = PeriodicTable.get_by_atomic_number(atomic_number)
				var desc: String = "%s (%s)" % [data.symbol, data.name]
				var element_info: Dictionary = Dictionary()
				types[desc] = element_info
				element_info["Count"] = instances.size()
				
				if instances.size() == 1:
					element_info["Mass" + mass_unit] = data.mass * Units.get_mass_conversion_factor()
					element_info["Position"] = {"": _create_position_property(in_info_type, structure_context, instances[0])}
				else:
					element_info["Mass (Total)" + mass_unit] = ("%.3f %.3f" %
						[data.mass * Units.get_mass_conversion_factor(),
						data.mass * instances.size() * Units.get_mass_conversion_factor()])
					if selection.size() > MAX_VISIBLE_ATOM_POSITIONS:
						info["Positions"] = "Number of elements exceeds display maximum."
					else:
						var positions: Array = Array()
						element_info["Positions"] = positions
						for idx in instances:
							positions.push_back(_create_position_property(in_info_type, structure_context, idx))
	
	# Bonds info
	var selected_bonds: PackedInt32Array = structure_context.get_selected_bonds()
	if selected_bonds.size() == 0:
		return info
	
	if selected_bonds.size() == 1:
		
		#
		var bond_id: int = selected_bonds[0]
		var selected_bond: Vector3i = nano_structure.get_bond(bond_id)
		var first_bonded_atom_id: int = selected_bond.x
		var second_bonded_atom_id: int = selected_bond.y
		var first_bonded_atom_position: Vector3 = nano_structure.atom_get_position(first_bonded_atom_id)
		var second_bonded_atom_position: Vector3 = nano_structure.atom_get_position(second_bonded_atom_id)
		var bond_length: float = first_bonded_atom_position.distance_to(second_bonded_atom_position)
		var bond_ui: InspectorControlBondOrder = InspectorControlBondOrderScene.instantiate()
		var is_bond_editable: bool = in_info_type == Type.READ_WRITE_PROPERTIES
		bond_ui.setup(structure_context, bond_id, is_bond_editable)
		
		info["Bond length%s: " % distance_unit] = bond_length
		info["Order: "] = bond_ui
		return info
	
	var bond_name_char_idx: int = CHARACTER_A
	var bond_type_str: Array[String] = ["ø", "-", "=", "≡"]
	var bonds_info: Dictionary = Dictionary()
	var lengths: Dictionary = Dictionary()
	bonds_info["Count"] = selected_bonds.size()
	bonds_info["Lengths" + distance_unit] = lengths
	info["Bonds"] = bonds_info
	if selected_bonds.size() > MAX_VISIBLE_BONDS:
		bonds_info["Lengths" + distance_unit] = "Too many bonds..."
	else:
		for bond_id in selected_bonds:
			var bond: Vector3i = nano_structure.get_bond(bond_id)
			var from_element: int = nano_structure.atom_get_atomic_number(bond.x)
			var to_element: int = nano_structure.atom_get_atomic_number(bond.y)
			var order: int = bond.z
			var bond_name: String = char(bond_name_char_idx)
			var bond_from: String = PeriodicTable.get_by_atomic_number(from_element).symbol
			var bond_symbol: String = bond_type_str[order]
			var bond_to: String = PeriodicTable.get_by_atomic_number(to_element).symbol
			var desc: String = "%s -> %s%s%s" % [bond_name, bond_from, bond_symbol, bond_to]
			var pos_from: Vector3 = nano_structure.atom_get_position(bond.x)
			var pos_to: Vector3 = nano_structure.atom_get_position(bond.y)
			lengths[desc] = pos_from.distance_to(pos_to) * Units.get_distance_conversion_factor()
			bond_name_char_idx += 1
		if selected_bonds.size() > 1:
			var connected_pairs: Array[Vector2i] = _find_connected_bonds(selected_bonds, nano_structure)
			if connected_pairs.size() > 0:
				bonds_info["Angles (degrees)"] = _collect_angles_info(connected_pairs, selected_bonds, nano_structure)
	return info


static func _create_position_property(in_info_type: Type, in_structure_context: StructureContext, atom_idx: int) -> Variant:
	var nano_structure: NanoStructure = in_structure_context.nano_structure
	match in_info_type:
		Type.RAW:
			return nano_structure.atom_get_position(atom_idx)
		Type.READ_ONLY_PROPERTIES, Type.READ_WRITE_PROPERTIES, _:
			var vector3_ui: InspectorControlVector3 = InspectorControlVector3Scene.instantiate()
			var setter_helper := SetNanostructureAtomPositionHelper.new(in_structure_context, atom_idx)
			vector3_ui.set_meta(&"setter_helper", setter_helper) # keep setter_helper reference alive
			vector3_ui.setup(
				# getter
				nano_structure.atom_get_position.bind(atom_idx),
				# setter
				setter_helper.set_position,
				# property_changed_signal
				nano_structure.atoms_moved
			)
			vector3_ui.set_editable(in_info_type == Type.READ_WRITE_PROPERTIES)
			return vector3_ui


static func _create_virtual_object_position_property(in_info_type: Type, in_structure_context: StructureContext) -> Variant:
	match in_info_type:
		Type.RAW:
			if in_structure_context.nano_structure is NanoVirtualMotor:
				return in_structure_context.nano_structure.get_transform().origin
			else:
				return in_structure_context.nano_structure.get_position()
		Type.READ_ONLY_PROPERTIES, Type.READ_WRITE_PROPERTIES, _:
			var vector3_ui: InspectorControlVector3 = InspectorControlVector3Scene.instantiate()
			var setter_helper := SetVirtualObjectPositionHelper.new(in_structure_context)
			vector3_ui.set_meta(&"setter_helper", setter_helper) # keep setter_helper reference alive
			vector3_ui.setup(
				# getter
				setter_helper.get_position,
				# setter
				setter_helper.set_position,
				# property_changed_signal
				setter_helper.changed_signal
			)
			vector3_ui.set_editable(in_info_type == Type.READ_WRITE_PROPERTIES)
			return vector3_ui


static func _find_connected_bonds(in_selected_bonds: PackedInt32Array,
			in_nano_structure: NanoStructure) -> Array[Vector2i]:
	var out_pairs: Array[Vector2i] = []
	for i in range(1, in_selected_bonds.size()):
		for j in range(i):
			var b1_id: int = in_selected_bonds[i]
			var b2_id: int = in_selected_bonds[j]
			var b1: Vector3i = in_nano_structure.get_bond(b1_id)
			var b2: Vector3i = in_nano_structure.get_bond(b2_id)
			if b1.x in [b2.x, b2.y] || b1.y in [b2.x, b2.y]:
				out_pairs.push_back(Vector2i(i, j))
	return out_pairs


static func _collect_angles_info(in_connected_bond_pairs: Array[Vector2i], in_selected_bonds: PackedInt32Array,
			in_nano_structure: NanoStructure) -> Dictionary:
	
	if in_connected_bond_pairs.size() == 0:
		return {}
	
	var out_angles_info: Dictionary = Dictionary()
	var angle_name_char_idx: int = CHARACTER_ALPHA
	for pair in in_connected_bond_pairs:
		var b1_id: int = in_selected_bonds[pair.x]
		var b2_id: int = in_selected_bonds[pair.y]
		var b1: Vector3i = in_nano_structure.get_bond(b1_id)
		var b2: Vector3i = in_nano_structure.get_bond(b2_id)
		var common_atom: int = b1.x if b1.x in [b2.x, b2.y] else b1.y
		var other_1: int = b1.y if common_atom == b1.x else b1.x
		var other_2: int = b2.y if common_atom == b2.x else b2.x
		var pos_common: Vector3 = in_nano_structure.atom_get_position(common_atom)
		var pos_other_1: Vector3 = in_nano_structure.atom_get_position(other_1)
		var pos_other_2: Vector3 = in_nano_structure.atom_get_position(other_2)
		var vec1: Vector3 = pos_other_1 - pos_common
		var vec2: Vector3 = pos_other_2 - pos_common
		var angle_degrees: float = rad_to_deg(vec1.angle_to(vec2))
		var angle_name: String = char(angle_name_char_idx)
		angle_name_char_idx += 1
		var bond_name_1: String = char(CHARACTER_A + pair.y)
		var bond_name_2: String = char(CHARACTER_A + pair.x)
		var desc: String = "%s -> %s^%s" % [angle_name, bond_name_1, bond_name_2]
		out_angles_info[desc] = angle_degrees
	return out_angles_info


class SetNanostructureAtomPositionHelper:
	var _structure_context: StructureContext = null
	var _atom_id: int = AtomicStructure.INVALID_ATOM_ID
	
	
	func _init(in_structure_context: StructureContext, in_atom_id: int) -> void:
		_structure_context = in_structure_context
		_atom_id = in_atom_id
	
	
	func set_position(in_new_position: Vector3) -> void:
		var nano_structure: NanoStructure = _structure_context.nano_structure
		nano_structure.start_edit()
		nano_structure.atom_set_position(_atom_id, in_new_position)
		nano_structure.end_edit()
	
	
	func store_undo_snapshot() -> void:
		var snapshot_name: String = "Set Atom %d Pos" % (_atom_id)
		_structure_context.workspace_context.snapshot_moment(snapshot_name)


class SetVirtualObjectPositionHelper:
	enum Type {
		SHAPE,
		MOTOR,
		ANCHOR,
	}
	
	var changed_signal: Signal
	
	var _type: Type
	var _structure_context: StructureContext
	
	func _init(out_structure_context: StructureContext) -> void:
		if out_structure_context.nano_structure is NanoShape:
			_type = Type.SHAPE
			changed_signal = out_structure_context.nano_structure.transform_changed
		elif out_structure_context.nano_structure is NanoVirtualMotor:
			_type = Type.MOTOR
			changed_signal = out_structure_context.nano_structure.transform_changed
		elif out_structure_context.nano_structure is NanoVirtualAnchor:
			_type = Type.ANCHOR
			changed_signal = out_structure_context.nano_structure.position_changed
		else:
			assert(false, "Unknown type of Virtual Object")
		_structure_context = out_structure_context
	
	
	func get_position() -> Vector3:
		match _type:
			Type.MOTOR:
				var motor: NanoVirtualMotor = _structure_context.nano_structure as NanoVirtualMotor
				return motor.get_transform().origin
			Type.ANCHOR, Type.SHAPE:
				return _structure_context.nano_structure.get_position()
			_:
				return Vector3()
	
	func set_position(in_new_position: Vector3) -> void:
		match _type:
			Type.SHAPE:
				var shape: NanoShape = _structure_context.nano_structure as NanoShape
				shape.set_position(in_new_position)
			Type.MOTOR:
				var motor: NanoVirtualMotor = _structure_context.nano_structure as NanoVirtualMotor
				var transform: Transform3D = motor.get_transform()
				transform.origin = in_new_position
				motor.set_transform(transform)
			Type.ANCHOR:
				var anchor: NanoVirtualAnchor = _structure_context.nano_structure as NanoVirtualAnchor
				anchor.set_position(in_new_position)
	
	func store_undo_snapshot() -> void:
		const MESSAGE_PER_TYPE: Dictionary = {
			Type.SHAPE: "Set Shape Position",
			Type.MOTOR: "Set Motor Position",
			Type.ANCHOR: "Set Anchor Position",
		}
		var snapshot_name: String = MESSAGE_PER_TYPE[_type]
		_structure_context.workspace_context.snapshot_moment(snapshot_name)
