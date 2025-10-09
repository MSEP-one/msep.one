"@abstract_class"
class_name VideoRecorder extends RefCounted


func has_error() -> bool:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return false


func get_error() -> String:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
	return ""


func add_frame(_in_image: Image) -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)

func finish() -> void:
	assert(false, ClassUtils.ABSTRACT_FUNCTION_MSG)
