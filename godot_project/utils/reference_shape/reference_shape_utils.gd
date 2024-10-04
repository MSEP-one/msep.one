class_name NanoShapeUtils extends Object

const InspectorControlSpinBox = preload("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/inspector_controls/inspector_control_range/inspector_control_spin_box.tscn")
const InspectorControlHSlider = preload("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/inspector_controls/inspector_control_range/inspector_control_hslider.tscn")
const InspectorControlCheckButton = preload("res://editor/controls/dockers/workspace_docker/c_dynamic_context_docker/dynamic_context_controls/inspector_controls/inspector_control_range/inspector_control_spin_box.tscn")


static func get_reference_shape_properties(in_shape: PrimitiveMesh) -> Dictionary:
	var properties: Dictionary = {}
	match in_shape.get_shape_name():
		&"Plane":
			var get_size_component: Callable = func(in_axis_index: int) -> float:
				return in_shape.size[in_axis_index]
			var set_size_component: Callable = func(in_size: float, in_axis_index: int) -> void:
				in_shape.size[in_axis_index] = in_size
				match in_axis_index:
					Vector2.AXIS_X:
						in_shape.subdivide_width = ceil(in_size)
					Vector2.AXIS_Y:
						in_shape.subdivide_height = ceil(in_size)
					_:
						pass
			var prop := ShapeProperty.new("Plane width", get_size_component.bind(Vector3.AXIS_X), set_size_component.bind(Vector3.AXIS_X))
			properties[&"width"] = prop.with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			prop = ShapeProperty.new("Plane length", get_size_component.bind(Vector3.AXIS_Y), set_size_component.bind(Vector3.AXIS_Y))
			properties[&"length"] = prop.with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Cylinder":
			properties[&"height"] = ShapeProperty.new("Cylinder height", in_shape.get_height, in_shape.set_height).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			var set_radius: Callable = func(in_radius: float) -> void:
				in_shape.top_radius = in_radius
				in_shape.bottom_radius = in_radius
			properties[&"radius"] = ShapeProperty.new("Cylinder radius", in_shape.get_top_radius, set_radius).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Box":
			var get_size_component: Callable = func(in_axis_index: int) -> float:
				return in_shape.size[in_axis_index]
			var set_size_component: Callable = func(in_size: float, in_axis_index: int) -> void:
				in_shape.size[in_axis_index] = in_size
				match in_axis_index:
					Vector3.AXIS_X:
						in_shape.subdivide_width = ceil(in_size)
					Vector3.AXIS_Y:
						in_shape.subdivide_height = ceil(in_size)
					Vector3.AXIS_Z:
						in_shape.subdivide_depth = ceil(in_size)
			properties[&"width"] = ShapeProperty.new("Box width", get_size_component.bind(Vector3.AXIS_X), set_size_component.bind(Vector3.AXIS_X)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"height"] = ShapeProperty.new("Box height", get_size_component.bind(Vector3.AXIS_Y), set_size_component.bind(Vector3.AXIS_Y)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"depth"] = ShapeProperty.new("Box depth", get_size_component.bind(Vector3.AXIS_Z), set_size_component.bind(Vector3.AXIS_Z)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Cone":
			properties[&"height"] = ShapeProperty.new("Cone height", in_shape.get_height, in_shape.set_height).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"radius"] = ShapeProperty.new("Cone radius", in_shape.get_bottom_radius, in_shape.set_bottom_radius).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Pyramid":
			properties[&"sides"] = ShapeProperty.new("Pyramid sides", in_shape.get_sides, in_shape.set_sides).\
					with_range(3, 10, 1)
			properties[&"base_size"] = ShapeProperty.new("Pyramid base size", in_shape.get_base_size, in_shape.set_base_size).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"height"] = ShapeProperty.new("Pyramid height", in_shape.get_height, in_shape.set_height).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Sphere":
			var set_radius: Callable = func(in_radius: float) -> void:
				in_shape.radius = in_radius
				in_shape.height = in_radius * 2.0
			properties[&"radius"] = ShapeProperty.new("Sphere radius", in_shape.get_radius, set_radius).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Capsule":
			properties[&"height"] = ShapeProperty.new("Capsule height", in_shape.get_height, in_shape.set_height).\
				with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"radius"] = ShapeProperty.new("Capsule radius", in_shape.get_radius, in_shape.set_radius).\
				with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Torus":
			var max_inner_radius: Callable = func() -> float:
				return in_shape.get_outer_radius() - 0.001
			var min_outer_radius: Callable = func() -> float:
				return in_shape.get_inner_radius() + 0.001
			properties[&"inner_radius"] = ShapeProperty.new("Torus inner radius", in_shape.get_inner_radius, in_shape.set_inner_radius).\
				with_min_value(0.05).with_max_value(max_inner_radius).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"outer_radius"] = ShapeProperty.new("Torus outer radius", in_shape.get_outer_radius, in_shape.set_outer_radius).\
				with_min_value(min_outer_radius).with_step(0.001).with_unit(Units.get_distance_unit_string())
		&"Prism":
			var get_size_component: Callable = func(in_axis_index: int) -> float:
				return in_shape.size[in_axis_index]
			var set_size_component: Callable = func(in_size: float, in_axis_index: int) -> void:
				in_shape.size[in_axis_index] = in_size
			properties[&"width"] = ShapeProperty.new("Prism width", get_size_component.bind(Vector3.AXIS_X), set_size_component.bind(Vector3.AXIS_X)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"height"] = ShapeProperty.new("Prism height", get_size_component.bind(Vector3.AXIS_Y), set_size_component.bind(Vector3.AXIS_Y)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"depth"] = ShapeProperty.new("Prism depth", get_size_component.bind(Vector3.AXIS_Z), set_size_component.bind(Vector3.AXIS_Z)).\
					with_min_value(0.05).with_step(0.001).with_unit(Units.get_distance_unit_string())
			properties[&"left_to_right"] = ShapeProperty.new("Prism left to right ratio", in_shape.get_left_to_right, in_shape.set_left_to_right).\
					with_range(0, 1, 0.001).make_slider().with_unit("ratio")
		_:
			assert(false, "Unhandled shape type: %s" % in_shape.get_shape_name())
			pass # assert is stripped out in release, pass is needed to prevent compile errors
	
	return properties

class ShapeProperty:
	var property_name: String
	var getter: Callable
	var setter: Callable
	# min_value and max_value could be eighter float or Callable
	var min_value: Variant = 0.001
	var max_value: Variant = 9999999999999.0
	var step: float = 0.0000001
	var is_slider: bool = false
	var unit: String = ""
	func is_read_only() -> bool:
		return !setter.is_valid()
	func set_value(v: Variant) -> void:
		if setter.is_valid():
			if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
				var min_v: float = min_value if not min_value is Callable else min_value.call()
				var max_v: float = max_value if not max_value is Callable else max_value.call()
				v = clamp(v, min_v, max_v)
			setter.call(v)
			return
		push_error("ShapeProperty is read only!")
	func get_value() -> Variant:
		return getter.call()
	func with_min_value(in_min: Variant) -> ShapeProperty:
		assert(typeof(in_min) in [TYPE_FLOAT, TYPE_CALLABLE],
			"min_value can only be of type float or Callable")
		min_value = in_min
		return self
	func with_max_value(in_max: Variant) -> ShapeProperty:
		assert(typeof(in_max) in [TYPE_FLOAT, TYPE_CALLABLE],
			"min_value can only be of type float or Callable")
		max_value = in_max
		return self
	func with_range(in_min: float, in_max: float, in_step: float = 0) -> ShapeProperty:
		min_value = in_min
		max_value = in_max
		if in_step != 0:
			step = in_step
		return self
	func with_step(in_step: float) -> ShapeProperty:
		step = in_step
		return self
	func with_unit(in_unit: String) -> ShapeProperty:
		unit = in_unit
		return self
	func make_slider() -> ShapeProperty:
		is_slider = true
		return self
	func _init(in_property_name: String, in_getter: Callable, in_setter: Callable = Callable()) -> void:
		assert(in_getter.is_valid())
		property_name = in_property_name
		getter = in_getter
		setter = in_setter

static func create_shape_property_editor(in_property: NanoShapeUtils.ShapeProperty, in_with_undo_support: bool) -> InspectorControl:
	match typeof(in_property.get_value()):
		TYPE_BOOL:
			return NanoShapeUtils._create_switch_property_editor(in_property, in_with_undo_support)
		_:
			return NanoShapeUtils._create_range_property_editor(in_property, in_with_undo_support)


static func _create_switch_property_editor(
		in_property: NanoShapeUtils.ShapeProperty,
		in_with_undo_support: bool) -> Control:
	var switch := CheckButton.new()
	switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	switch.focus_mode = Control.FOCUS_NONE
	switch.button_pressed = in_property.get_value()
	switch.toggled.connect(
		NanoShapeUtils._on_shape_switch_toggled.bind(in_property, in_with_undo_support))
	return switch


static func _on_shape_switch_toggled(
		in_button_pressed: bool,
		out_property: NanoShapeUtils.ShapeProperty,
		in_with_undo_support: bool) -> void:
	out_property.set_value(in_button_pressed)
	if in_with_undo_support:
		# Assuming a change can only occur from UI while workspace is active
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
		workspace_context.snapshot_moment("Shape: Set " + out_property.property_name)


static func _create_range_property_editor(
		in_property: NanoShapeUtils.ShapeProperty,
		in_with_undo_support: bool) -> InspectorControl:
	var range_control: InspectorControlRange = null
	if in_property.is_slider:
		range_control = InspectorControlHSlider.instantiate()
	else:
		range_control = InspectorControlSpinBox.instantiate()
	if in_property.min_value is Callable:
		range_control.range_control.min_value = in_property.min_value.call()
		var update_min: Callable = func(_in_event: InputEvent) -> void:
			range_control.range_control.min_value = in_property.min_value.call()
		range_control.gui_input.connect(update_min)
	else:
		range_control.range_control.min_value = in_property.min_value
	if in_property.max_value is Callable:
		range_control.range_control.max_value = in_property.max_value.call()
		var update_max: Callable = func(_in_event: InputEvent) -> void:
			range_control.range_control.max_value = in_property.max_value.call()
		range_control.gui_input.connect(update_max)
	else:
		range_control.range_control.max_value = in_property.max_value
	range_control.range_control.step = in_property.step
	var spinbox: SpinBox = range_control.range_control as SpinBox
	if spinbox != null:
		spinbox.custom_arrow_step = in_property.step
	range_control.range_control.value = in_property.get_value()
	range_control.setup(in_property.getter, in_property.setter)
	range_control.range_control.value_confirmed.connect(
		NanoShapeUtils._on_range_control_value_confirmed.bind(in_property, in_with_undo_support))
	if !in_property.is_slider:
		range_control.range_control.set_slider_visible(false)
	return range_control

static func _on_range_control_value_confirmed(
		in_value: float,
		out_property: NanoShapeUtils.ShapeProperty,
		in_with_undo_support: bool) -> void:
	out_property.set_value(in_value)
	if in_with_undo_support:
		# Assuming a change can only occur from UI while workspace is active
		var workspace_context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context() as WorkspaceContext
		workspace_context.snapshot_moment("Shape: Set " + out_property.property_name)
