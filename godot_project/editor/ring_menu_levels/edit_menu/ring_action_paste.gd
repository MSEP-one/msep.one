class_name RingActionPaste extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	assert(_workspace_context)
	super._init(
		tr("Paste"),
		_execute_action,
		tr("Paste clipboard content")
	)
	with_validation(can_paste)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/controls/menu_bar/menu_edit/icons/icon_paste_x96.svg"))


func can_paste() -> bool:
	return is_instance_valid(_workspace_context) \
		and not MolecularEditorContext.is_clipboard_empty()


func _execute_action() -> void:
	_ring_menu.close()
	if can_paste():
		MolecularEditorContext.paste_clipboard_content(-1)

