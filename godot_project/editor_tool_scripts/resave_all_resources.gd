@tool
extends EditorScript

const FILE_EXTENSIONS_TO_RESAVE: Array[String]= [
	"tscn", "scn", "tres", "res", "material", "mesh", "multimesh"
]

func _run() -> void:
	print("###  STARTED RESAVING RESOURCES  ###")
	var thread := Thread.new()
	var skipped_extensions: Dictionary[String, bool] = {}
	var when_finished_callback: Callable = _when_finished.bind(thread, self)
	thread.start(_resave_resources_recursively.bind("res://", skipped_extensions, when_finished_callback))


func _when_finished(thread: Thread, _self_ref: EditorScript) -> void:
	# _self_ref is bound to preserve instance
	thread.wait_to_finish()
	print("###  FINISHED RESAVING RESOURCES  ###")


func _resave_resources_recursively(in_path: String, skipped_extensions: Dictionary[String, bool], finished_callback := Callable()) -> void:
	for file: String in DirAccess.get_files_at(in_path):
		var full_path: String = in_path.path_join(file)
		if ResourceLoader.exists(full_path):
			var extension: String = file.get_extension()
			if not extension in FILE_EXTENSIONS_TO_RESAVE:
				if not extension in skipped_extensions:
					skipped_extensions[extension] = true
					print_rich("[color=YELLOW]· Skipped resource extension: ", extension, "[/color]")
				continue
			var resource: Resource = load(full_path)
			print_verbose("· Saving " + full_path)
			ResourceSaver.save(resource, full_path)
	for dir: String in DirAccess.get_directories_at(in_path):
		if dir.begins_with("."):
			# Ignore .godot, .git, .vs folders, etc
			continue
		_resave_resources_recursively(in_path.path_join(dir), skipped_extensions)
	if finished_callback.is_valid():
		finished_callback.call_deferred()
