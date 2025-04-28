class_name VideoTutorialsDialog
extends AcceptDialog


const VIDEO_FOLDER_PATH: String = "res://documentation/video_tutorials/"
const DEFAULT_VIDEO_ICON = preload("res://editor/icons/icon_video.svg")


var _videos: Dictionary = {} # item_index<int> : video_path<String>
var _selected_item: int
var _play_button: Button

@onready var _item_list: ItemList = $ItemList
@onready var _video_player: VideoPlayer = $VideoPlayer



func _ready() -> void:
	_item_list.item_activated.connect(_on_item_activated)
	_item_list.item_selected.connect(_on_item_selected)
	_play_button = get_ok_button()
	_play_button.pressed.connect(_on_play_button_pressed)
	_update_item_list()


func _update_item_list() -> void:
	_item_list.clear()
	_videos.clear()
	_play_button.disabled = true
	
	for file: String in DirAccess.get_files_at(VIDEO_FOLDER_PATH):
		if file.get_extension() != "ogv":
			continue
		var base_name: String = file.get_file().get_basename()
		var formatted_name: String = _format_name(base_name)
		var icon_path: String = VIDEO_FOLDER_PATH.path_join(base_name + ".png")
		var icon: Texture2D = load(icon_path)
		if not icon:
			icon = DEFAULT_VIDEO_ICON
		var index: int = _item_list.add_item(formatted_name, icon)
		var full_path: String = VIDEO_FOLDER_PATH.path_join(file)
		_videos[index] = full_path


func _play_video(index: int) -> void:
	assert(_videos.has(index), "No video exists for item " + str(index))
	_video_player.set_video(_videos.get(index, ""))
	_video_player.popup_centered_ratio(0.6)


func _format_name(base_name: String) -> String:
	var tutorial_number: String = base_name.get_slice("_", 0)
	var tutorial_name: String = base_name.trim_prefix(tutorial_number + "_")
	return "Tutorial %s: %s" % [tutorial_number, tutorial_name.capitalize()] 


func _on_item_activated(index: int) -> void:
	_play_video(index)


func _on_item_selected(index: int) -> void:
	_selected_item = index
	_play_button.disabled = false


func _on_play_button_pressed() -> void:
	_play_video(_selected_item)
