class_name RingActionCorrectOverlappingAtoms extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null
var _model_validator: AtomicStructureModelValidator

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	_model_validator = AtomicStructureModelValidator.new()
	_model_validator.set_workspace_context(_workspace_context)

	super._init(
			tr("Correct Overlapping Atoms"),
			_execute_action,
			tr("Move overlapping atoms away from each other.")
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_model_validator.queue_free()


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_fix_overlap.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	await _model_validator.validate_atomic_model(false)
	_model_validator.fix_overlapping_atoms()
