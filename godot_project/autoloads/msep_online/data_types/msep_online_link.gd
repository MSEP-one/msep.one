class_name MsepOnlineLink extends RefCounted
## Responsible for recognizing MSEP Online version and project links in text typed by the user.


enum Kind {
	NONE,
	VERSION,
	PROJECT,
}


const _UUID_PATTERN: String = "^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"
const _VERSION_SEGMENT: String = "v"
const _PROJECTS_SEGMENT: String = "projects"
const _URL_PREFIXES: PackedStringArray = ["https://", "http://"]


var kind: Kind = Kind.NONE
var version_uuid: String = ""
var project_namespace: String = ""
var project_name: String = ""


## Accepts a bare version UUID, a version link (.../v/<uuid>) or a project link (.../<namespace>/projects/<name>).
static func parse(in_text: String) -> MsepOnlineLink:
	var link := MsepOnlineLink.new()
	var text: String = in_text.strip_edges()
	if _is_uuid(text):
		link.kind = Kind.VERSION
		link.version_uuid = text
		return link
	var segments: PackedStringArray = _get_path_segments(text)
	var is_version_link: bool = segments.size() >= 2 and segments[0] == _VERSION_SEGMENT and _is_uuid(segments[1])
	if is_version_link:
		link.kind = Kind.VERSION
		link.version_uuid = segments[1]
		return link
	var is_project_link: bool = segments.size() >= 3 and segments[1] == _PROJECTS_SEGMENT
	if is_project_link:
		link.kind = Kind.PROJECT
		link.project_namespace = segments[0]
		link.project_name = segments[2]
	return link


static func _is_uuid(in_text: String) -> bool:
	var regex := RegEx.create_from_string(_UUID_PATTERN)
	return regex.search(in_text) != null


static func _get_path_segments(in_text: String) -> PackedStringArray:
	var has_url_prefix: bool = false
	var remainder: String = in_text
	for prefix: String in _URL_PREFIXES:
		if in_text.begins_with(prefix):
			has_url_prefix = true
			remainder = in_text.trim_prefix(prefix)
	if not has_url_prefix:
		return PackedStringArray()
	var query_start: int = remainder.find("?")
	if query_start != -1:
		remainder = remainder.left(query_start)
	var fragment_start: int = remainder.find("#")
	if fragment_start != -1:
		remainder = remainder.left(fragment_start)
	var segments: PackedStringArray = remainder.split("/", false)
	if segments.is_empty():
		return segments
	# The first segment is the host
	segments.remove_at(0)
	for index: int in segments.size():
		segments[index] = segments[index].uri_decode()
	return segments
