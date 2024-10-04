extends Button


func _ready() -> void:
	pressed.connect(_on_toggle_ring_button_pressed)
	MolecularEditorContext.msep_editor_settings.changed.connect(_on_editor_settings_changed)


func _on_toggle_ring_button_pressed() -> void:
	# First ensure input can be processed:
	var main_view: WorkspaceMainView = owner
	assert(main_view != null, "main_view is not valid. Did scene structure change?")
	main_view.editor_viewport_container.editor_viewport.set_input_forwarding_enabled(true)
	
	var simulated_action := InputEventAction.new()
	simulated_action.action = &"toggle_ring_menu"
	simulated_action.pressed = true
	Input.parse_input_event(simulated_action)


func _on_editor_settings_changed() -> void:
	scale = Vector2.ONE * MolecularEditorContext.msep_editor_settings.ui_widget_scale
