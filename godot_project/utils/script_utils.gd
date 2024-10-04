class_name ScriptUtils
extends RefCounted


static var _is_flushing: bool = false
static var _callable_queue: Dictionary = {}
static var _callables_requested_during_flush: Dictionary = {}


## Calls a function exactly one time this frame, even if this method is invoked
## multiple times in a frame. 
static func call_deferred_once(in_callable: Callable) -> void:
	if _is_flushing:
		# call_deferred_once was executed by one of the callbacks inside _callable_queue
		# to prevent code from redundantly call each other we track this callbacks separatedly
		if _callable_queue.has(in_callable) or _callables_requested_during_flush.has(in_callable):
			# This callback was already requested before, skip it
			return
		# this callback is being requested for the first time this frame
		# invoke it immediately and track it to prevent any future invocation
		_callables_requested_during_flush[in_callable] = true
		in_callable.call()
		return
	if _callable_queue.is_empty():
		ScriptUtils._flush_queue.call_deferred()
	_callable_queue[in_callable] = true


static func is_callable_queued(in_callable: Callable) -> bool:
	return _callable_queue.get(in_callable, false)


static func flush_now(in_callable: Callable) -> void:
	assert(is_callable_queued(in_callable), "Cannot flush callable, it is not queued")
	_callable_queue.erase(in_callable)
	in_callable.call()


## Automatically called a single time at the end of the frame when call_deferred_once is used
static func _flush_queue() -> void:
	_is_flushing = true
	for c: Callable in _callable_queue.keys():
		if c.is_valid():
			c.call()
	_callable_queue.clear()
	_callables_requested_during_flush.clear()
	_is_flushing = false


static var _printed_deprecation_warnings: Dictionary = {}
static func show_deprecation_warning_once(in_alternative_codepath: String) -> void:
	if not OS.has_feature("editor"):
		return
	var stack: Array = get_stack()
	assert(stack.size() >= 2, "Could not find the origin of the operation")
	# stack[0] is _create_deprecation_warning() itself
	var deprecated_function: String = str(stack[1])
	var source_function: String = str(stack[2])
	var complete_key: StringName = StringName(deprecated_function+"<<"+source_function)
	if not complete_key in _printed_deprecation_warnings:
		_printed_deprecation_warnings[complete_key] = true
		var message: String = ("[color=YELLOW]Deprecated method: %s[/color]\n" + \
			"\t[color=YELLOW]Called from %s.[/color]") % \
		[_describe_function(stack[1]), _describe_function(stack[2])]
		if not in_alternative_codepath.is_empty():
			message += "\n\tInstead use the new method: [color=CYAN]'%s'[/color]" % in_alternative_codepath
		print_rich("%s\n" % message)

static func _describe_function(stack_frame: Dictionary) -> String:
	return "[color=ORANGE]%s[/color][color=DARK_CYAN]L%d[/color][color=DARK_GOLDENROD]::%s()[/color]" % [
			str(stack_frame.source).get_file(), stack_frame.line, stack_frame.function]


static func is_queued_for_deletion_reqursive(in_node: Node) -> bool:
	if in_node.is_queued_for_deletion():
		return true
	var parent: Node = in_node.get_parent()
	if parent != null:
		return is_queued_for_deletion_reqursive(parent)
	return false
