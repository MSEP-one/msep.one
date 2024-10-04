extends AcceptDialog

const COLLAPSED_DIALOG_SIZE = 0

var panel_container: PanelContainer = null
var message_label: Label = null
var expanded_text_label: RichTextLabel = null
var toggle_message_button: LinkButton = null

var _full_message: String = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		panel_container = %PanelContainer
		message_label = %MessageLabel
		expanded_text_label = %ExpandedTextLabel as RichTextLabel
		toggle_message_button = %LinkButton
		window_input.connect(_on_window_input)
		expanded_text_label.meta_clicked.connect(_on_meta_clicked)
		expanded_text_label.meta_hover_started.connect(_on_meta_hover_started)
		expanded_text_label.meta_hover_ended.connect(_on_meta_hover_ended)


func _on_window_input(in_event: InputEvent) -> void:
	if Editor_Utils.process_quit_request(in_event, self):
		return
	if in_event.is_action_pressed(&"close_view", false, true):
		hide()


func _on_link_button_pressed() -> void:
	if panel_container.visible:
		panel_container.hide()
		size.y = COLLAPSED_DIALOG_SIZE
		toggle_message_button.text = tr(&"Show more...")
	else:
		panel_container.show()
		toggle_message_button.text = tr(&"Show less...")


func set_short_message(in_short_message: String) -> void:
	message_label.text = in_short_message


func set_detailed_message(in_message: String) -> void:
	_full_message = in_message
	var traceback_start: int = in_message.findn("[b]Traceback:[/b]")
	if traceback_start == -1:
		# Error does not include traceback
		expanded_text_label.parse_bbcode(in_message)
		return
	var short_message: String = in_message.left(traceback_start)
	short_message += "[b][url=##SHOW_TRACEBACK##]%s[/url][/b]" % tr("Show extended traceback")
	expanded_text_label.parse_bbcode(short_message)


func _on_meta_clicked(meta: String) -> void:
	if meta == "##SHOW_TRACEBACK##":
		expanded_text_label.parse_bbcode(_full_message)
		return
	var parts: PackedStringArray = meta.split("@")
	if OS.has_feature("editor"):
		var project_path: String = parts[0].replace("\\", "/").replace(
			ProjectSettings.globalize_path("user://"),
			ProjectSettings.globalize_path("res://")
		)
		if FileAccess.file_exists(project_path):
			parts[0] = project_path
	if parts.size() >= 2:
		var is_windows: bool = OS.get_name().to_lower() == "windows"
		var executable_path: String = "CMD.exe" if is_windows else "sh"
		var command_arg: String = "/C" if is_windows else "-c"
		var args: Array = [command_arg, "code --version"]
		var vscode_check_result: int = OS.execute(executable_path, args)
		if vscode_check_result == OK:
			# Visual Studio Code exists, use it
			args = [command_arg, "code -g %s:%s" % [parts[0], parts[1]]]

			OS.create_process(executable_path, args)
		else:
			# Visual Studio Code is not installed, fallback to default text editor
			OS.shell_open(parts[0])
		return
	OS.shell_open(meta)

func _on_meta_hover_started(meta: String) -> void:
	if meta == "##SHOW_TRACEBACK##":
		expanded_text_label.tooltip_text = ""
	else:
		expanded_text_label.tooltip_text = meta.split("@")[0]

func _on_meta_hover_ended(_meta: String) -> void:
	expanded_text_label.tooltip_text = ""
