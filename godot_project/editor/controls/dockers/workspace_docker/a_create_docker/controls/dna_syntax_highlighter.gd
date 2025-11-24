@tool
class_name DnaSyntaxHighlighter extends SyntaxHighlighter

func _get_line_syntax_highlighting(in_line: int) -> Dictionary:
	var hl: Dictionary = {}
	var text: String = get_text_edit().text.get_slice("\n", in_line)

	for c in text.length():
		hl[c] = {
			"color": get_char_color(text[c])
		}
	return hl

func get_char_color(c: String) -> Color:
	const DNA_COLORS: Dictionary = {
		"A": Color(0.627, 0.0, 0.259),   # Deep Red
		"T": Color(0.996, 0.855, 0.055),  # Yellow
		"G": Color(0.098, 1.0, 0.098),    # Bright Green
		"C": Color(0.098, 0.098, 1.0)     # Bright Blue
	}
	return DNA_COLORS.get(c, Color.WHITE)
