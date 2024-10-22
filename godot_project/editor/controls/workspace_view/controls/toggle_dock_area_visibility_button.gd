extends Button


@export var icon_hidden: Texture2D
@export var icon_visible: Texture2D
@export_node_path("Control") var dock_area_path: NodePath

@onready var dock_area: Control = get_node_or_null(dock_area_path) #DockArea


func _ready() -> void:
	assert(dock_area != null, "Path to dock area is not valid: %s" % str(dock_area_path))
	pressed.connect(_on_toggle_visible_button_pressed)
	dock_area.visibility_changed.connect(_on_dock_area_visibility_changed)
	
	_update_toggle_button_icon()


func _on_dock_area_visibility_changed() -> void:
	visible = dock_area.has_visible_content
	_update_toggle_button_icon()


func _on_toggle_visible_button_pressed() -> void:
	dock_area.user_hidden = !dock_area.user_hidden


func _update_toggle_button_icon() -> void:
	if dock_area.user_hidden:
		icon = icon_hidden
		tooltip_text = tr("Show Docker")
	else:
		icon = icon_visible
		tooltip_text = tr("Hide Docker")
