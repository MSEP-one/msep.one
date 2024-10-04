class_name NodeHolder extends Node
## Helper, Agregator for (usually the same type) nodes


var _main_instance_placeholder: InstancePlaceholder = null


func _notification(in_what: int) -> void:
	if in_what == NOTIFICATION_READY:
		var placeholders: Array[Node] = []
		for child in get_children():
			if child is InstancePlaceholder:
				if _main_instance_placeholder == null:
					_main_instance_placeholder = child
				placeholders.append(child)
		for child in placeholders:
			remove_child(child)
			add_child(child, false, InternalMode.INTERNAL_MODE_FRONT)


func new_named_instance(in_name: StringName) -> Node:
	assert(_main_instance_placeholder, "To instance with a name you need to define
			InstancePlaceholder as a child of NodeHolder at editor time")
	var instance: Node = _main_instance_placeholder.create_instance()
	instance.set_name(in_name)
	return instance


func add_child_with_name(new_node: Node, in_name: StringName) -> void:
	new_node.name = in_name
	add_child(new_node)


func first_or_null() -> Node:
	if get_child_count() > 0:
		return get_child(0)
	return null


func first() -> Node:
	return get_child(0)


func replace(in_old: Node, in_new: Node) -> void:
	var index_to_use: int = -1
	if in_old.get_parent() == self:
		index_to_use = in_old.get_index()
		remove_child(in_old)
	add_child(in_new)
	if index_to_use != -1:
		move_child(in_new, index_to_use)
