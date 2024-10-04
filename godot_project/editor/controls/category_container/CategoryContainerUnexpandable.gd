extends VBoxContainer

@export
var title: String:
	get:
		if is_instance_valid(title_button):
			return title_button.text
		return _title
	set(v):
		_title = v
		if is_instance_valid(title_button):
			title_button.text = v
var _title: String = "Title"

@onready var title_button: Button = %TitleButton
@onready var main_container: VBoxContainer = %MainContainer
@onready var panel_container: PanelContainer = %PanelContainer
@onready var internal_childs: Array = [
	title_button,
	panel_container
]

func _ready() -> void:
	title_button.text = _title
	child_entered_tree.connect(_on_child_entered_tree)


func _on_child_entered_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		return
	if child in internal_childs:
		return
	# Move the child inside the main container
	remove_child(child)
	main_container.add_child(child)
