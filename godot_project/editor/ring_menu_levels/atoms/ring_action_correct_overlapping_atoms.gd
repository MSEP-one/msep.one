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
	with_validation(_can_correct_atoms)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_model_validator.queue_free()


func _can_correct_atoms() -> bool:
	return _workspace_context.has_valid_atoms()


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_fix_overlap.svg"))


func _execute_action() -> void:
	_ring_menu.close()
	_workspace_context.clear_alerts()
	var editor_viewport_container: EditorViewportContainer = _workspace_context.get_editor_viewport_container()
	await _model_validator.validate_atomic_model(AtomicStructure.AtomSet.ALL)
	if _model_validator.has_overlapping_atoms():
		_model_validator.fix_overlapping_atoms()
		_workspace_context.show_alerts_panel()
		var alerts_panel: AlertsPanel = _workspace_context.get_alerts_panel()
		alerts_panel.toggle_all(false)
		alerts_panel.toggle_fixed(true)
		editor_viewport_container.show_info_in_message_bar(tr("Fixed overlapping atoms. See the alerts panel for details."))
	else:
		editor_viewport_container.show_info_in_message_bar(tr("No overlapping atoms found."))
