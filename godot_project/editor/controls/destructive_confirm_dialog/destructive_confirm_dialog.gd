class_name DestructiveConfirmDialog extends ConfirmationDialog
## Responsible for making the user explicitly confirm a destructive action, optionally by typing a phrase.


signal confirmed_with_reason(reason: String)


const DEFAULT_REASON_TEXT: String = "Reason (optional)"

@onready var _message_label: Label = %MessageLabel
@onready var _phrase_container: VBoxContainer = %PhraseContainer
@onready var _phrase_label: Label = %PhraseLabel
@onready var _phrase_line_edit: LineEdit = %PhraseLineEdit
@onready var _reason_label: Label = %ReasonLabel
@onready var _reason_text_edit: TextEdit = %ReasonTextEdit

var _required_phrase: String = ""


func ask(in_title: String, in_message: String, in_confirm_text: String, in_required_phrase: String = "",
		in_reason_prompt: String = "") -> void:
	title = in_title
	ok_button_text = in_confirm_text
	_message_label.text = in_message
	_required_phrase = in_required_phrase
	var requires_phrase: bool = not in_required_phrase.is_empty()
	_phrase_container.visible = requires_phrase
	_phrase_label.text = tr("Type %s to confirm") % in_required_phrase
	_phrase_line_edit.text = ""
	_reason_label.text = tr(DEFAULT_REASON_TEXT) if in_reason_prompt.is_empty() else in_reason_prompt
	_reason_text_edit.text = ""
	_update_ok_button()
	reset_size()
	popup_centered()


func _update_ok_button() -> void:
	var phrase_matches: bool = _phrase_line_edit.text == _required_phrase
	get_ok_button().disabled = not phrase_matches


func _on_phrase_line_edit_text_changed(_in_text: String) -> void:
	_update_ok_button()


func _on_confirmed() -> void:
	confirmed_with_reason.emit(_reason_text_edit.text.strip_edges())
