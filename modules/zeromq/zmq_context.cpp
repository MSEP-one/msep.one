#include "zmq_context.h"

ZMQContext::ZMQContext() {
	_ptr = new zmq::context_t();
}

ZMQContext::ZMQContext(int p_io_threads, int p_max_sockets) {
	_ptr = new zmq::context_t(p_io_threads, p_max_sockets);
}

ZMQContext::~ZMQContext() {
	delete _ptr;
}

void ZMQContext::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("zmq_set", "p_option", "p_option_val"), &ZMQContext::zmq_set);
	ClassDB::bind_method(D_METHOD("zmq_get", "p_option"), &ZMQContext::zmq_get);
	ClassDB::bind_method(D_METHOD("close"), &ZMQContext::close);
	ClassDB::bind_method(D_METHOD("shutdown"), &ZMQContext::shutdown);
	
#ifdef ZMQ_BLOCKY
	BIND_ENUM_CONSTANT(OPTION_BLOCKY);
#endif
#ifdef ZMQ_IO_THREADS
	BIND_ENUM_CONSTANT(OPTION_IO_THREADS);
#endif
#ifdef ZMQ_THREAD_SCHED_POLICY
	BIND_ENUM_CONSTANT(OPTION_THREAD_SCHED_POLICY);
#endif
#ifdef ZMQ_THREAD_PRIORITY
	BIND_ENUM_CONSTANT(OPTION_THREAD_PRIORITY);
#endif
#ifdef ZMQ_THREAD_AFFINITY_CPU_ADD
	BIND_ENUM_CONSTANT(OPTION_THREAD_AFFINITY_CPU_ADD);
#endif
#ifdef ZMQ_THREAD_AFFINITY_CPU_REMOVE
	BIND_ENUM_CONSTANT(OPTION_THREAD_AFFINITY_CPU_REMOVE);
#endif
#ifdef ZMQ_THREAD_NAME_PREFIX
	BIND_ENUM_CONSTANT(OPTION_THREAD_NAME_PREFIX);
#endif
#ifdef ZMQ_MAX_MSGSZ
	BIND_ENUM_CONSTANT(OPTION_MAX_MSGSZ);
#endif
#ifdef ZMQ_ZERO_COPY_RECV
	BIND_ENUM_CONSTANT(OPTION_ZERO_COPY_RECV);
#endif
#ifdef ZMQ_MAX_SOCKETS
	BIND_ENUM_CONSTANT(OPTION_MAX_SOCKETS);
#endif
#ifdef ZMQ_SOCKET_LIMIT
	BIND_ENUM_CONSTANT(OPTION_SOCKET_LIMIT);
#endif
#ifdef ZMQ_IPV6
	BIND_ENUM_CONSTANT(OPTION_IPV6);
#endif
#ifdef ZMQ_MSG_T_SIZE
	BIND_ENUM_CONSTANT(OPTION_MSG_T_SIZE);
#endif
}

void ZMQContext::zmq_set(Option p_option, int p_option_val) {
#ifndef ZMQ_CPP11
	ERR_PRINT("ZeroMQ was built without the ZMQ_CPP11 flag. `set()` method is not available");
	return;
#endif
	_ptr->set(static_cast<zmq::ctxopt>(p_option), p_option_val);
}

int ZMQContext::zmq_get(Option p_option) const {
#ifndef ZMQ_CPP11
	ERR_PRINT("ZeroMQ was built without the ZMQ_CPP11 flag. `set()` method is not available");
	return 0;
#endif
	return _ptr->get(static_cast<zmq::ctxopt>(p_option));
}