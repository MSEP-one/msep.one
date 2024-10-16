extends ResourceFormatSaver

## PDB format saver
##
## Uses OpenMM to do the actual export


func _recognize(resource: Resource) -> bool:
	return resource is Workspace


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	var extensions := PackedStringArray()
	extensions.push_back("pdb")
	return extensions


func _save(in_resource: Resource, in_path: String, _flags: int) -> Error:
	var workspace_context: WorkspaceContext = MolecularEditorContext.get_workspace_context(in_resource)
	if not is_instance_valid(workspace_context):
		return ERR_INVALID_DATA
	
	var promise: Promise = OpenMM.request_export(in_path, workspace_context)
	await promise.wait_for_fulfill()
	
	if promise.has_error():
		var error_string: String = "Failed to export %s:\n%s" % [in_path, promise.get_error()]
		Editor_Utils.get_editor().prompt_error_msg(error_string)
		return ERR_BUG
	return OK
