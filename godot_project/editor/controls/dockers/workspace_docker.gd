extends MarginContainer
class_name WorkspaceDocker


@export
var docker_tab_title: String = "":
	get = get_docker_tab_title


func _ready() -> void:
	var content_template: Dictionary = get_content_template()
	for category: StringName in content_template.keys():
		var settings: Dictionary = content_template[category]
		if !has_category(category):
			var category_created: bool = create_category(category, settings.header, settings.collapse,
					settings.start_collapsed, settings.scroll, settings.get(&"stretch_ratio", 1))
			assert(category_created)
		for control_path: String in settings.controls:
			var control: DynamicContextControl = load(control_path).instantiate() as DynamicContextControl
			assert(control, "Invalid DynamicContextControl scene path '%s' in category '%s'. \
					Did you forget to make your script extend from DynamicContextControl?" % \
					[control_path, str(category)])
			add_control_to_category(category, control)


# region: virtual
## VIRTUAL: This function will return true or false depending on the current state of the workspace.[br]
## The editor will make the docker visible or invisible depending on the returned value
func should_show(_in_workspace_context: WorkspaceContext) -> bool:
	"""This class is meant to be subclassed and this method implemented"""
	return false


func _update_internal(in_workspace_context: WorkspaceContext) -> void:
	_ensure_snapshot_history_tracked(in_workspace_context)
	for category: Category in _categories.values():
		var category_control: Control = category.category_control
		var container: VBoxContainer = category.container
		var category_visible: bool = false
		for ctrl in container.get_children():
			var control: Control = ctrl as Control
			var dynamic_control: DynamicContextControl = ctrl as DynamicContextControl
			if is_instance_valid(dynamic_control):
				if is_instance_valid(in_workspace_context):
					dynamic_control.visible = dynamic_control.should_show(in_workspace_context)
				else:
					dynamic_control.visible = false
				category_visible = category_visible || dynamic_control.visible
			elif is_instance_valid(control):
				category_visible = category_visible || control.visible
		category_control.visible = category_visible


func _ensure_snapshot_history_tracked(in_workspace_context: WorkspaceContext) -> void:
	if not in_workspace_context.history_snapshot_applied.is_connected(_on_workspace_context_history_snapshot_applied):
		in_workspace_context.history_snapshot_applied.connect(
			_on_workspace_context_history_snapshot_applied.bind(in_workspace_context))


func _on_workspace_context_history_snapshot_applied(in_workspace_context: WorkspaceContext) -> void:
	if is_instance_valid(in_workspace_context):
		_update_internal(in_workspace_context)


## VIRTUAL: Unique docker name is defined by it's author, and is used to store user preferences on what
## DockerArea to use for each docker
func get_unique_docker_name() -> StringName:
	"""This class is meant to be subclassed and this method implemented"""
#	return &"__UniqueDockerName__"
	return StringName()


## VIRTUAL: When user has not stablished a preference for a certain docker, this area will be used.[br]
## Subclasses of WorkspaceDocker can return a different value to stablish
## it's own preferred default location
func get_default_docker_area() -> int:
	"""This class is meant to be subclassed and this method implemented"""
	return DOCK_AREA_DEFAULT


func ensure_docker_area_visible() -> void:
	var parent: Node = get_parent()
	while parent != null:
		if parent is DockArea or parent is Window:
			break
		parent = parent.get_parent()
	if parent is DockArea:
		parent.user_hidden = false
	elif parent is Window:
		parent.visible = true



## VIRTUAL: Returns the text being displayed on the Tab of the Docker
## Subclasses of WorkspaceDocker can return a custom value or simply setup the default value
## of docker_tab_title property
func get_docker_tab_title() -> String:
	if Engine.is_editor_hint():
		return docker_tab_title
	return tr(docker_tab_title)


## VIRTUAL: if the doccker makes use of the create_category(...) and add_control_to_category(...) API,[br]
## this method requires to return a valid Container to layout each category
func _get_category_container() -> Container:
	return null


## VIRTUAL: Override if the scroll container is not the direct parent of the category container.
func _get_scroll_container() -> ScrollContainer:
	var category_container: Container = _get_category_container()
	if is_instance_valid(category_container):
		var parent: Control = category_container.get_parent()
		if is_instance_valid(parent) and parent is ScrollContainer:
			return parent
	return null
	

# region: public API
## Dinamically create a category to add contents to it, This will create a
## CategoryContainer, CategoryScrollableContainer, or a simple VBoxContainer
## depending on arguments passed.
## Categories without header cannot be collapsed, but can be scrolled
## In order for this method to work, you docker needs to implement the virtual
## method [code]_get_category_container() -> Container[/code][br]
## If the method returns a null Container an error will be pushed
## and return false immediately without doing any change.
## If the category Id exists, a warning will be pushed and return true without doing any change on it.
## @Returns: true if category is created or already existed, false if could not be created
func create_category(in_id: StringName,
					in_with_header: bool = true,
					in_can_collapse: bool = false,
					in_start_collapsed: bool = false,
					in_can_scroll: bool = false,
					in_stretch_ratio: float = 1) -> bool:
	var category_container: Container = _get_category_container()
	if !is_instance_valid(category_container):
		push_error("This docker does not support adding Categories: _get_category_container() returned an invalid Container")
		return false
	if in_id == StringName():
		push_error("Category id cannot be empty")
		return false
	if has_category(in_id):
		push_warning("Category '%s' already exists, and cannot be modified" % str(in_id))
		return true
	var category := Category.new(in_id, in_with_header, in_can_collapse, in_start_collapsed, in_can_scroll, in_stretch_ratio)
	category_container.add_child(category.category_control)
	_categories[in_id] = category
	return true


func has_category(in_id: StringName) -> bool:
	return _categories.has(in_id)

func highlight_category(in_id: StringName) -> void:
	assert(_categories.has(in_id))
	var category: Category = _categories[in_id] as Category
	var control: Control = category.category_control
	var overlay := Control.new()
	add_child(overlay)
	overlay.draw.connect(_on_category_control_draw.bind(control, overlay))
	
	var scroll_container: ScrollContainer = _get_scroll_container()
	if is_instance_valid(scroll_container):
		scroll_container.ensure_control_visible(control)
	
	# During highlight time, redraw the category every frame
	var _queue_redraw: Callable = func(_delta: float) -> void:
		overlay.queue_redraw()
	var tween: Tween = create_tween()
	var from: float = 0
	var to: float = 0
	var highlight_duration: float = 1.0
	tween.tween_method(_queue_redraw, from, to, highlight_duration)
	await tween.finished
	
	overlay.draw.disconnect(_on_category_control_draw)
	overlay.queue_free()


func _on_category_control_draw(category_control: Control, overlay: Control) -> void:
	@warning_ignore("integer_division")
	var flip_flop_frame_index: int = Time.get_ticks_msec() / 100
	var should_draw: bool = flip_flop_frame_index % 2 == 1
	if should_draw:
		var rect_pos: Vector2 = category_control.global_position - global_position
		rect_pos.x -= get_theme_constant(&"margin_left")
		rect_pos.y -= get_theme_constant(&"margin_top")
		var rect_size: Vector2 = category_control.size
		overlay.draw_rect(Rect2(rect_pos, rect_size).grow(4), Color.YELLOW, false, 2)


func add_control_to_category(in_category_id: StringName, in_control: DynamicContextControl) -> bool:
	var category_container: Container = _get_category_container()
	if !is_instance_valid(category_container):
		push_error("This docker does not support adding Categories: _get_category_container() returned an invalid Container")
		return false
	if in_category_id == StringName():
		push_error("Category id cannot be empty")
		return false
	if !has_category(in_category_id):
		push_error("Category '%s' doesn't exists" % str(in_category_id))
		return false
	if !is_instance_valid(in_control):
		push_warning("Cannot add a null control to category '%s'" % str(in_category_id))
		return false
	var category: Category = _categories[in_category_id] as Category
	if in_control.get_parent() != null:
		if in_control.get_parent_control() == category.container:
			# Nothing to do here
			return true
		push_warning("Control added to category already has a parent, will proceed to reparent")
		in_control.get_parent_control().remove_child(in_control)
	category.container.add_child(in_control)
	return true


# region: internal
var _container: Control
func set_container(in_new_container: Control) -> void:
	_container = in_new_container
	var current_parent: Control = get_parent_control()
	var was_tab_hidden: bool = false
	if is_instance_valid(current_parent):
		# docker is meant to stay visible
		if current_parent is TabContainer:
			var index: int = get_index()
			was_tab_hidden = current_parent.is_tab_hidden(index)
		current_parent.remove_child(self)
	
	if _container is DockerTabContainer:
		_container.add_tab(self, docker_tab_title, was_tab_hidden)
	else:
		_container.add_child(self)


func get_container() -> Control:
	return _container


# Called from MolecularEditorContext.gd
# IMPORTANT: Dockers are added and removed from the tree when should_show
# is called. This prevents to use signals connections because they only fire
# when the node is in the tree.
func _on_homepage_activated() -> void:
	_update_visibility(should_show(null))


# Called from MolecularEditorContext.gd
# IMPORTANT: Dockers are added and removed from the tree when should_show
# is called. This prevents to use signals connections because they only fire
# when the node is in the tree.
func _on_workspace_activated(in_workspace: Workspace) -> void:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_workspace)
	_update_visibility(should_show(workspace_context))


func _update_visibility(make_visible: bool) -> void:
	if make_visible:
		_update_internal(MolecularEditorContext.get_current_workspace_context())
	if !is_instance_valid(_container) || not _container.is_ancestor_of(self):
		push_error("Attempted to make the docker visible before it was assigned to a container")
		return
	if _container is DockerTabContainer:
		var index: int = get_index()
		_container.set_tab_title(index, docker_tab_title)
		_container.set_tab_hidden(index, !make_visible)
		visible = _container.get_current_tab() == index && make_visible
	else:
		visible = make_visible


## VIRTUAL: This method is used to create categories and controls for this particular instance
## on startup[br]
## Subclasses of WorkspaceDocker can return a non empty dictionary to auto spawn controls on start. [br]
## Here is an example of a valid dictionary entry:[br]
##[codeblock]
##return {
##    &"Category Name":
##    {
##        header = false,
##        scroll = false,
##        collapse = false,
##        start_collapsed = false,
##        controls = [
##            "res://path/to/some/DynamicContextControl.tscn"
##        ]
##    },
##}
##[/codeblock]
func get_content_template() -> Dictionary:
	return {
#		&"Category Name":
#		{
#			header = false,
#			scroll = false,
#			collapse = false,
#			start_collapsed = false,
#			controls = [
#				"res://path/to/some/DynamicContextControl.tscn"
#			]
#		},
	}


var _categories: Dictionary#[StringName,Category]
class Category:
	var id: StringName
	var visible_name: String
	var has_header: bool = true
	var can_collapse: bool = false
	var start_collapsed: bool = false
	var can_scroll: bool = false
	var stretch_ratio: float = 1
	var category_control: Control
	var container: VBoxContainer
	enum ContainerType {
		VBOX,
		VBOX_WITH_SCROLL,
		COLLAPSABLE_CATEGORY_CONTAINER,
		UNCOLLAPSABLE_CATEGORY_CONTAINER,
		SCROLLABLE_CATEGORY_CONTAINER
	}
	var container_type: ContainerType = Category.ContainerType.VBOX
	func _init(in_id: StringName,
					in_with_header: bool = true,
					in_can_collapse: bool = false,
					in_start_collapsed: bool = false,
					in_can_scroll: bool = false,
					in_stretch_ratio: float = 1) -> void:
		id = in_id
		visible_name = tr(str(in_id))
		has_header = in_with_header
		can_collapse = in_can_collapse
		can_scroll = in_can_scroll
		stretch_ratio = in_stretch_ratio
		if !has_header:
			container_type = Category.ContainerType.VBOX
			if can_collapse:
				push_error("Invalid argument configuration, a category cannot be collapsed without having a header")
			if can_scroll:
				container_type = Category.ContainerType.VBOX_WITH_SCROLL
		else:
			if can_collapse:
				if can_scroll:
					container_type = Category.ContainerType.SCROLLABLE_CATEGORY_CONTAINER
				else:
					container_type = Category.ContainerType.COLLAPSABLE_CATEGORY_CONTAINER
			else:
				container_type = Category.ContainerType.UNCOLLAPSABLE_CATEGORY_CONTAINER
		match container_type:
			Category.ContainerType.VBOX:
				category_control = VBoxContainer.new()
				category_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
				container = category_control
			Category.ContainerType.VBOX_WITH_SCROLL:
				category_control = ScrollContainer.new()
				category_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
				container = VBoxContainer.new()
				category_control.add_child(container)
				container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
			Category.ContainerType.SCROLLABLE_CATEGORY_CONTAINER:
				category_control = preload("res://editor/controls/category_container/CategoryScrollableContainer.tscn").instantiate()
				assert(category_control)
				container = category_control.get_node_or_null("%MainContainer")
				assert(container)
				category_control.expanded = !in_start_collapsed
				category_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				category_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
				category_control.title = visible_name
			Category.ContainerType.COLLAPSABLE_CATEGORY_CONTAINER:
				category_control = preload("res://editor/controls/category_container/CategoryContainer.tscn").instantiate()
				assert(category_control)
				container = category_control.get_node_or_null("%MainContainer")
				assert(container)
				category_control.expanded = !in_start_collapsed
				category_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				category_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
				category_control.title = visible_name
			Category.ContainerType.UNCOLLAPSABLE_CATEGORY_CONTAINER:
				category_control = preload("res://editor/controls/category_container/CategoryContainerUnexpandable.tscn").instantiate()
				assert(category_control)
				container = category_control.get_node_or_null("%MainContainer")
				assert(container)
				category_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				category_control.title = visible_name
		category_control.size_flags_stretch_ratio = stretch_ratio

enum {
	DOCK_AREA_HIDDEN = -1,
	DOCK_AREA_LEFT_TOP_LEFT,
	DOCK_AREA_LEFT_TOP_RIGHT,
	DOCK_AREA_LEFT_BOTTOM_LEFT,
	DOCK_AREA_LEFT_BOTTOM_RIGHT,
	DOCK_AREA_RIGHT_TOP_LEFT,
	DOCK_AREA_RIGHT_TOP_RIGHT,
	DOCK_AREA_RIGHT_BOTTOM_LEFT,
	DOCK_AREA_RIGHT_BOTTOM_RIGHT,
	DOCK_AREA_DEFAULT = DOCK_AREA_RIGHT_TOP_LEFT
}

