class_name RiffFileWriter extends RefCounted


var _f: FileAccess
var _block_stack: Array[Block] = []
var _current_block: Block:
	get:
		return null if _block_stack.is_empty() else _block_stack[_block_stack.size() - 1]


func _init(in_filepath: String, in_form_type: String) -> void:
	_f = FileAccess.open(in_filepath, FileAccess.WRITE_READ)
	if is_file_valid():
		push_block("RIFF")
		store_four_cc(in_form_type)


func is_file_valid() -> bool:
	return _f != null and _f.is_open()


func get_file_access() -> FileAccess:
	return _f


func push_block(in_four_cc: String) -> void:
	var block := Block.new(in_four_cc, self)
	if _block_stack.size():
		block.finished.connect(_current_block._on_child_block_finished.bind(block))
	_block_stack.push_back(block)
	if not block.is_list():
		print_verbose("|\t".repeat(_block_stack.size()-1) + "[" + _current_block.name + "]")


func push_list_start(in_list_type: String) -> void:
	push_block("LIST")
	_current_block.store_four_cc(in_list_type)
	_current_block.name += " " + in_list_type
	print_verbose("|\t".repeat(_block_stack.size()-1) + "[" + _current_block.name + "]")



func pop_block() -> void:
	print_verbose("|\t".repeat(_block_stack.size()-1) + "-[/" + _current_block.name + " size=" + str(_current_block.get_size() - 8) + "]")
	_current_block.pop()
	_block_stack.pop_back()


func store_32(in_value: int) -> void:
	_current_block.store_32(in_value)


func store_16(in_value: int) -> void:
	_current_block.store_16(in_value)


func store_8(in_value: int) -> void:
	_current_block.store_8(in_value)

func store_four_cc(in_four_cc: String) -> void:
	_current_block.store_four_cc(in_four_cc)


func store_buffer(in_buffer: PackedByteArray) -> void:
	_current_block.store_buffer(in_buffer)


func get_position() -> int:
	return _f.get_position()


class Block:
	
	signal finished()
	
	
	var name: String
	var _writter: RiffFileWriter
	var _f: FileAccess
	var _block_size_pos: int
	var _is_list: bool = false
	var _size: int = 0
	
	
	func _init(in_four_cc: String, out_writter: RiffFileWriter) -> void:
		_writter = out_writter
		_f = _writter._f
		_is_list = in_four_cc == "LIST"
		name = in_four_cc
		store_four_cc(in_four_cc)
		_block_size_pos = _f.get_position() # will update when block closes
		store_32(0) # Reserved for block size
		_size = 0
	
	
	func store_32(in_value: int) -> void:
		_f.store_32(in_value)
		_size += 4
	
	
	func store_16(in_value: int) -> void:
		_f.store_16(in_value)
		_size += 2
	
	func store_8(in_value: int) -> void:
		_f.store_8(in_value)
		_size += 1
	
	func store_four_cc(in_four_cc: String) -> void:
		assert(in_four_cc.length() == 4)
		_f.store_buffer(in_four_cc.to_utf8_buffer())
		_size += 4
	
	
	func store_buffer(in_buffer: PackedByteArray) -> void:
		_f.store_buffer(in_buffer)
		_size += in_buffer.size()
	
	
	func get_size() -> int:
		return _size + 8 # 4 bytes for FourCC header and 4 bytes block size
	
	
	func is_list() -> bool:
		return _is_list
	
	
	func _on_child_block_finished(in_block: Block) -> void:
		_size += in_block.get_size()
	
	
	func pop() -> void:
		_f.seek(_block_size_pos)
		_f.store_32(_size)
		_f.seek_end()
		finished.emit()
