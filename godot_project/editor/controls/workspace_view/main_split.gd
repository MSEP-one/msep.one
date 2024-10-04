@tool
extends HSplitContainer

func _ready() -> void:
	# This is a child of SubViewportContainer which prevents setting layout preset from editor.
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
