class_name RingInnerCircle extends Node3D
## Responsible for the visualisation of the RingMenu circle

## indicates RingInnerCircle title should be refreshed
signal title_refresh_requested


var _pop_animator: AnimationPlayer
var _lvl_change_animator: AnimationPlayer
var _title: Label
var _category: Label
var _page_animator: AnimationPlayer


var _current_category: String = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_pop_animator = $PopAnimator
		_lvl_change_animator = $LevelChangeAnimator
		_title = $VBoxContainer/Name
		_category = $VBoxContainer/Category
		_page_animator = $PageAnimator
	if what == NOTIFICATION_READY:
		hide()


func popup(in_category_name: String) -> void:
	_current_category = in_category_name
	show()
	_category.text = in_category_name
	_title.text = ""


func lvl_up(in_category_name: String) -> void:
	_current_category = in_category_name
	_lvl_change_animator.play("lvl_up")


func lvl_down(in_category_name: String) -> void:
	_current_category = in_category_name
	_lvl_change_animator.play("lvl_down")


# Called from "lvl_down" and "lvl_up" animations by AnimationPlayer
func _apply_texts() -> void:
	_category.text = _current_category
	_title.text = ""
	title_refresh_requested.emit()


func set_title(new_title: String) -> void:
	_title.text = new_title


func indicate_next_page() -> void:
	_page_animator.play("next_page")


func indicate_prev_page() -> void:
	_page_animator.play("prev_page")


func set_dimmed(in_dimmed: bool) -> void:
	_title.modulate.a = 0.5 if in_dimmed else 1.0
