@tool
extends VBoxContainer


@export var expanded_icon: Texture2D
@export var collapsed_icon: Texture2D

@export var expanded: bool = false:
	set(v):
		expanded = v
		if not is_instance_valid(_expand_collapse_button):
			return # Too early, wait for _ready()
		if v:
			_expand(true)
		else:
			_collapse(true)

@export var title: String:
	set(v):
		title = v
		if is_instance_valid(_expand_collapse_button):
			_expand_collapse_button.text = v

var _tween: Tween

@onready var _expand_collapse_button: Button = %ExpandCollapseButton
@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _main_container: VBoxContainer = %MainContainer


func _ready() -> void:
	_expand_collapse_button.text = title
	_expand_collapse_button.pressed.connect(_on_expand_collapse_button_pressed)
	_main_container.resized.connect(_on_main_container_resized)
	if expanded:
		_expand(false)
	else:
		_collapse(false)


func add_control(node: Control) -> void:
	_main_container.add_child(node)


func has_visible_content() -> bool:
	for child in _main_container.get_children():
		if child.visible:
			return true
	return false


func _expand(in_animated: bool) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	
	_expand_collapse_button.icon = expanded_icon
	_main_container.visible = true
	var target_size: Vector2 = _main_container.get_combined_minimum_size()
	_scroll_container.custom_minimum_size.x = target_size.x
	
	if !in_animated || Engine.is_editor_hint():
		_scroll_container.custom_minimum_size.y = target_size.y
		return
	
	_tween = create_tween()
	_tween.tween_property(_scroll_container, NodePath(&"custom_minimum_size"), target_size, 0.2)
	_tween.play()


func _collapse(in_animated: bool) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	
	_expand_collapse_button.icon = collapsed_icon
	
	if !in_animated || Engine.is_editor_hint():
		_scroll_container.custom_minimum_size.y = 0
		_main_container.hide()
		return
	
	_tween = create_tween()
	_tween.tween_property(_scroll_container, NodePath(&"custom_minimum_size"), Vector2.ZERO, 0.2)
	_tween.tween_callback(_main_container.hide)
	_tween.play()


func _on_expand_collapse_button_pressed() -> void:
	expanded = !expanded


func _on_main_container_resized() -> void:
	if expanded:
		_expand(true)
