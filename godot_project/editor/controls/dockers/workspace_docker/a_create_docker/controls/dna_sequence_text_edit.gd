@tool
extends TextEdit

const ACCEPTED_CHARS: String = "ACGTacgt"

@onready var clipboard_error_label: Label = %ClipboardErrorLabel


var _clipboard_error_tween: Tween


func _draw() -> void:
	if text.is_empty():
		return
	var font: Font = get_theme_font("font", theme_type_variation)
	var font_size: int = get_theme_font_size("font_size", theme_type_variation)
	var char_offset := Vector2(0, -font_size * 1.8)
	var last_y: float = get_pos_at_line_column(0, 0).y
	for l in get_line_count():
		var line: String = get_line(l)
		for col in line.length():
			var char_pos: Vector2 = get_pos_at_line_column(l, col + 1)
			# HACK: char_pos returns the next line one character early when wrapping the line, so this would ideally fix that
			if last_y != char_pos.y:
				last_y = char_pos.y
				char_pos = get_pos_at_line_column(l, col + 0)
				const CHAR_SEPARATION = -3
				char_pos.x += font.get_string_size(line[col-1]).x + CHAR_SEPARATION
			var compliment: String = DnaBuilder.DNA_COMPLEMENT.get(line[col], "?")
			char_pos += char_offset
			var color: Color = Color.WHITE
			if syntax_highlighter != null:
				color = syntax_highlighter.get_char_color(compliment)
			color.a = 0.5
			draw_string(
				font,
				char_pos,
				compliment,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				color
			)


func _handle_unicode_input(unicode_char: int, _in_caret_index: int) -> void:
	if char(unicode_char) in ACCEPTED_CHARS:
		if has_selection():
			delete_selection()
			insert_text_at_caret(char(unicode_char).to_upper())
		elif is_overtype_mode_enabled():
			set_block_signals(true)
			for i in get_caret_count():
				var line: String = get_line(get_caret_line(i))
				var col: int = get_caret_column(i)
				line[col] = char(unicode_char).to_upper()
				set_line(get_caret_line(i), line)
				set_caret_column(col + 1, true, i)
			set_block_signals(false)
		else:
			insert_text_at_caret(char(unicode_char).to_upper())

func _paste(in_caret_index: int) -> void:
	_handle_paste(DisplayServer.clipboard_get(), in_caret_index)


func _paste_primary_clipboard(in_caret_index: int) -> void:
	_handle_paste(DisplayServer.clipboard_get_primary(), in_caret_index)


func _handle_paste(in_text: String, in_caret_index: int) -> void:
	for k: String in in_text:
		if not k in ACCEPTED_CHARS:
			if in_caret_index in [0, -1]:
				_show_invalid_clipboard_message()
			return
	insert_text_at_caret(in_text.to_upper(), in_caret_index)


func _show_invalid_clipboard_message() -> void:
	# Note: clipboard error label is a toplevel node, so we set it's global position
	var pos: Vector2 = get_caret_draw_pos(0)
	var global_pos: Vector2 = get_global_rect().position + pos
	const Y_OFFSET = 22
	global_pos.y -= (clipboard_error_label.size.y + Y_OFFSET)
	if global_pos.x + clipboard_error_label.size.x > get_viewport_rect().size.x:
		global_pos.x -= clipboard_error_label.size.x
	clipboard_error_label.position = global_pos
	if _clipboard_error_tween != null:
		_clipboard_error_tween.kill()
	clipboard_error_label.self_modulate.a = 1
	_clipboard_error_tween = create_tween()
	_clipboard_error_tween.tween_property(clipboard_error_label, ^"self_modulate:a", 0, 0.2).set_delay(1)


func _gui_input(in_event: InputEvent) -> void:
	if in_event is InputEventKey:
		# block non unicode characters
		if in_event.keycode in [KEY_TAB, KEY_ENTER]:
			get_viewport().set_input_as_handled()
