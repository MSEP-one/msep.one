extends VBoxContainer

@export
var title: String:
	set(v):
		title = v
		if is_instance_valid(title_label):
			title_label.text = v
@export var category_icon: Texture2D = null:
	set(v):
		category_icon = v
		if is_instance_valid(icon_texture_rect):
			icon_texture_rect.texture = v
			icon_texture_rect.visible = v != null


@onready var title_button: Button = %TitleButton
@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var title_label: Label = %TitleLabel
@onready var main_container: VBoxContainer = %MainContainer
@onready var panel_container: PanelContainer = %PanelContainer
@onready var internal_childs: Array = [
	title_button,
	panel_container
]


func _ready() -> void:
	title_label.text = title
	icon_texture_rect.texture = category_icon
	icon_texture_rect.visible = category_icon != null
	child_entered_tree.connect(_on_child_entered_tree)


func _on_child_entered_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		return
	if child in internal_childs:
		return
	# Move the child inside the main container
	remove_child(child)
	main_container.add_child(child)
