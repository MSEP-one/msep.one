@tool
extends VBoxContainer

@export
var expanded_icon: Texture2D

@export
var collapsed_icon: Texture2D

@export
var expanded: bool = false:
	set(v):
		expanded = v
		if !is_instance_valid(expand_collapse_button):
			return # Too early, wait for _ready()
		if v:
			_expand(true)
		else:
			_collapse(true)


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


@onready var expand_collapse_button: Button = %ExpandCollapseButton
@onready var icon_texture_rect: TextureRect = %IconTextureRect
@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var main_container: VBoxContainer = %MainContainer
@onready var internal_childs: Array = [
	expand_collapse_button,
	scroll_container
]
var _tween: Tween

func _ready() -> void:
	expand_collapse_button.text = title
	icon_texture_rect.texture = category_icon
	icon_texture_rect.visible = category_icon != null
	expand_collapse_button.pressed.connect(_on_expand_collapse_button_pressed)
	child_entered_tree.connect(_on_child_entered_tree)
	if expanded:
		_expand(false)
	else:
		_collapse(false)


func _on_child_entered_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		return
	if child in internal_childs:
		return
	# Move the child inside the main container
	remove_child(child)
	main_container.add_child(child)


func _on_expand_collapse_button_pressed() -> void:
	expanded = !expanded


func _expand(in_animated: bool) -> void:
	expand_collapse_button.icon = expanded_icon
	scroll_container.show()
	if !in_animated || Engine.is_editor_hint():
		size_flags_vertical = SIZE_EXPAND_FILL
		return
	if size_flags_vertical == SIZE_EXPAND_FILL:
		# Nothing to do here
		return
	size_flags_vertical = SIZE_EXPAND_FILL
	get_parent_control().notification(NOTIFICATION_SORT_CHILDREN)
	var target_height: float = get_rect().size.y
	size_flags_vertical = SIZE_FILL
	get_parent_control().notification(NOTIFICATION_SORT_CHILDREN)
	
	var on_complete: Callable = func() -> void:
		size_flags_vertical = SIZE_EXPAND_FILL
		custom_minimum_size.y = 0
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, NodePath(&"custom_minimum_size"), Vector2(0, target_height), 0.2)
	_tween.tween_callback(on_complete)
	_tween.play()
	


func _collapse(in_animated: bool) -> void:
	expand_collapse_button.icon = collapsed_icon
	if !in_animated || Engine.is_editor_hint():
		size_flags_vertical = SIZE_FILL
		scroll_container.hide()
		return
	if size_flags_vertical == SIZE_FILL:
		# Nothing to do here
		return
	
	custom_minimum_size.y = get_rect().size.y
	size_flags_vertical = SIZE_FILL
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, NodePath(&"custom_minimum_size"), Vector2(), 0.2)
	_tween.tween_callback(scroll_container.hide)
	_tween.play()


