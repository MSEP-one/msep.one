
#include "register_types.h"

#include "core/object/class_db.h"

#include "zmq_context.h"
#include "zmq_socket.h"



void initialize_zeromq_module(ModuleInitializationLevel p_level) {
	if (p_level != ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_CORE) {
		return;
	}
	ClassDB::register_class<ZMQContext>();
	ClassDB::register_class<ZMQSocket>();
}

void uninitialize_zeromq_module(ModuleInitializationLevel p_level) {
}
