class_name DockArea extends MarginContainer

signal docker_added(docker_name: StringName, docker_area: int)


@onready var split_main: HSplitContainer = %SplitMain
@onready var split_left: VSplitContainer = %SplitLeft
@onready var split_right: VSplitContainer = %SplitRight
@onready var docker_containers: Array[DockerTabContainer] = [
	%TabContainerTopLeft as DockerTabContainer,
	%TabContainerTopRight as DockerTabContainer,
	%TabContainerBottomLeft as DockerTabContainer,
	%TabContainerBottomRight as DockerTabContainer
]


var user_hidden: bool = false:
	set(v):
		user_hidden = v
		_update_visibility()

var has_visible_content: bool = false


func add_dock(in_docker: WorkspaceDocker, in_docker_area: int) -> void:
	if !is_instance_valid(in_docker):
		return
	var area: int = in_docker_area % 4 # ignore left/right side of the viewport
	if docker_containers[area].is_ancestor_of(in_docker):
		# Nothing to do here
		return
	in_docker.set_container(docker_containers[area])
	docker_added.emit(in_docker.get_unique_docker_name(), in_docker_area)
	_update_visibility()


func _ready() -> void:
	for container in docker_containers:
		container.tab_added.connect(_on_docker_added)
		container.tab_removed.connect(_on_docker_removed)
	_update_visibility()


func _on_docker_added(in_docker: Control) -> void:
	in_docker.visibility_changed.connect(_on_docker_visibility_changed)
	in_docker.resized.connect(_on_docker_resized)
	in_docker.minimum_size_changed.connect(_on_docker_minimum_size_changed)


func _on_docker_removed(in_docker: Control) -> void:
	if is_instance_valid(in_docker) and in_docker.visibility_changed.is_connected(_on_docker_visibility_changed):
		in_docker.visibility_changed.disconnect(_on_docker_visibility_changed)
		in_docker.resized.disconnect(_on_docker_resized)
		in_docker.minimum_size_changed.disconnect(_on_docker_minimum_size_changed)


func _on_docker_visibility_changed() -> void:
	# workaround: call_deferred() is needed since this signal is triggered also when user clicks an inactive tab 
	# (with intention to make it active) but related tab_control is still hidden, which leads to fail of the 
	# logic which changes current tab control based on it's visibility
	_update_visibility.call_deferred()


func _on_docker_resized() -> void:
	_update_split_containers_size()


func _on_docker_minimum_size_changed() -> void:
	_update_split_containers_size()


func _update_visibility(_ignore_signal_argument: Variant = null) -> void:
	has_visible_content = false
	for container in docker_containers:
		container.update_visibility()
		if container.has_visible_content():
			has_visible_content = true
	_update_split_containers_size()


func _update_split_containers_size() -> void:
	split_left.visible = %TabContainerTopLeft.visible || %TabContainerBottomLeft.visible
	split_left.custom_minimum_size.x = max(%TabContainerTopLeft.get_combined_minimum_size().x, %TabContainerBottomLeft.get_combined_minimum_size().x)
	split_right.visible = %TabContainerTopRight.visible || %TabContainerBottomRight.visible
	split_right.custom_minimum_size.x = max(%TabContainerTopRight.get_combined_minimum_size().x, %TabContainerBottomRight.get_combined_minimum_size().x)
	visible = has_visible_content and not user_hidden
