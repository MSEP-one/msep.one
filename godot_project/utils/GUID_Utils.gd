@tool
extends Object
class_name GUID_Utils


const _CHAR_A = 97  # 'a'
const _CHAR_Z = 122 # 'z'
const _CHAR_0 = 48  # '0'
const _CHAR_9 = 57  # '9'
const _CHAR_COUNT =         (122 - 97) # ('z' - 'a')
const _BASE = _CHAR_COUNT + (57 - 48)  # ('9' - '0')


static func int_to_guid(int_guid: int) -> StringName:
	var txt: String = ""
	var int_id: int = int_guid
	while(int_id):
		var c: int = int_id % _BASE
		if c < _CHAR_COUNT:
			txt = char(_CHAR_A + c) + txt
		else:
			txt = char(_CHAR_0 + (c - _CHAR_COUNT)) + txt
		int_id /= _BASE
	return StringName(txt)


static func guid_to_int(guid: StringName) -> int:
	assert(guid != StringName(), "Invalid unique ID")
	var txt := String(guid)
	var l: int = txt.length()
	var int_id: = 0
	for i in range(l):
		int_id *= _BASE
		var c: String = txt[i]
		var char_c: int = c.to_ascii_buffer()[0]
		if char_c >= _CHAR_A && char_c <= _CHAR_Z:
			int_id += (char_c - _CHAR_A)
		elif char_c >= _CHAR_0 && char_c <= _CHAR_9:
			int_id += (char_c - _CHAR_0 + _CHAR_COUNT);
		else:
			return -1
	return int_id
