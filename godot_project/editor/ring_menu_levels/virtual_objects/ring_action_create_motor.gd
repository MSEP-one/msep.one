class_name RingActionCreateMotor extends RingMenuAction


const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _motor_type: NanoVirtualMotorParameters.Type = NanoVirtualMotorParameters.Type.UNKNOWN


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu, in_motor_type: NanoVirtualMotorParameters.Type) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	_motor_type = in_motor_type
	match _motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			super._init(
				tr("Rotary Motor"),
				_execute_action,
				tr("Create a motor that will make particles orbit around it's axis.")
			)
		NanoVirtualMotorParameters.Type.LINEAR:
			super._init(
				tr("Linear Motor"),
				_execute_action,
				tr("Create a motor that will move particles along it's axis.")
			)
		_:
			assert(false, "Invalid motor type %d" % _motor_type)
			pass


func get_icon() -> RingMenuIcon:
	match _motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_rotary_motor_x128.svg"))
		NanoVirtualMotorParameters.Type.LINEAR:
			return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_virtual_objects/icons/icon_linear_motor_x128.svg"))
		_:
			assert(false, "Invalid motor type %d" % _motor_type)
			return null
	


func _execute_action() -> void:
	match _motor_type:
		NanoVirtualMotorParameters.Type.ROTARY:
			_workspace_context.create_object_parameters.set_selected_virtual_motor_parameters(
				_workspace_context.create_object_parameters.new_rotary_motor_parameters)
		NanoVirtualMotorParameters.Type.LINEAR:
			_workspace_context.create_object_parameters.set_selected_virtual_motor_parameters(
				_workspace_context.create_object_parameters.new_linear_motor_parameters)
		_:
			assert(false, "Invalid motor type %d" % _motor_type)
			pass
	_workspace_context.create_object_parameters.set_create_mode_type(
			CreateObjectParameters.CreateModeType.CREATE_VIRTUAL_MOTORS)
	MolecularEditorContext.request_workspace_docker_focus(CreateDocker.UNIQUE_DOCKER_NAME, &"Virtual Motors")
	_ring_menu.close()


