class_name RingActionVideoTutorials
extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

const VIDEO_TUTORIALS_FOLDER_PATH: String = "res://documentation/video_tutorials/"


var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null


func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
		tr("Video Tutorials"),
		_execute_action,
		tr("Browse video tutorials on how to use MSEP."),
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("res://editor/icons/icon_video.svg"))


func _execute_action() -> void:
	RingActionVideoTutorials.open_video_tutorials_dialog()
	_ring_menu.close()

static func open_video_tutorials_dialog() -> void:
	var molecular_editor: MolecularEditor = Editor_Utils.get_editor()
	molecular_editor.video_tutorials_dialog.popup_centered_ratio(0.5)
