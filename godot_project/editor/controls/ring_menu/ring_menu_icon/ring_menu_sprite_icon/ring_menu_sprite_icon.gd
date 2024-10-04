extends RingMenuIcon

var _sprite: Sprite3D
var _color_animator: AnimationPlayer
var _fade_animator: AnimationPlayer
var _is_removal_queued: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_sprite = $Sprite3D
		_color_animator = $ColorAnimator
		_fade_animator = $FadeAnimator
	if what == NOTIFICATION_READY:
		# ensure icon rotation is correct - parallel to the parent button which is holding this icon
		# (parent button might be already rotated at time when this RingMenuIcon is being added)
		_sprite.look_at(global_position - get_parent().global_transform.basis.z, Vector3(0,1,0))


func init(in_texture: Texture2D) -> RingMenuIcon:
	_sprite.texture = in_texture
	return self


func prepare_for_usage() -> void:
	return


func pop_animation() -> void:
	return


func fade_in() -> void:
	_fade_animator.play("in")
	_fade_animator.advance(0.001)


func fade_out_and_queue_free() -> void:
	_is_removal_queued = true
	_fade_animator.play("out")
	await(_fade_animator.animation_finished)
	queue_free()


func press_in() -> void:
	_color_animator.play("in")


func press_out() -> void:
	_color_animator.play("out")


func focus_in() -> void:
	return


func focus_out() -> void:
	return


func active() -> void:
	_anim_activate()


func inactive() -> void:
	_anim_deactivate()
	

func _anim_activate() -> void:
	if _is_removal_queued:
		return
	if _color_animator.assigned_animation != "active":
		_color_animator.play("active")

func _anim_deactivate() -> void:
	if _is_removal_queued:
		return
	if _color_animator.assigned_animation != "inactive":
		_color_animator.play("inactive")
