class_name RingActionCommunityMenu extends RingMenuAction

const RingMenuSpriteIconScn = preload("res://editor/controls/ring_menu/ring_menu_icon/ring_menu_sprite_icon/ring_menu_sprite_icon.tscn")

var _workspace_context: WorkspaceContext = null
var _ring_menu: NanoRingMenu = null

func _init(in_workspace_context: WorkspaceContext, in_menu: NanoRingMenu) -> void:
	_workspace_context = in_workspace_context
	_ring_menu = in_menu
	super._init(
			tr("MSEP Community"),
			_execute_action,
			tr("Share your projects, or import projects from the Community!")
	)


func get_icon() -> RingMenuIcon:
	return RingMenuSpriteIconScn.instantiate().init(preload("uid://duksd4w2x8ulb"))


func _execute_action() -> void:
	var ring_level_file := RingLevelMsepCommunity.new(_workspace_context, _ring_menu)
	_ring_menu.add_level(ring_level_file)

