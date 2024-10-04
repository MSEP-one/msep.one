#pragma once

#include "core/object/ref_counted.h"
#include "gd_zmq.h"


class ZMQContext : public RefCounted {
	GDCLASS(ZMQContext, RefCounted)

protected:
	static void _bind_methods();

public:
	ZMQContext();
	ZMQContext(int p_io_threads, int p_max_sockets = ZMQ_MAX_SOCKETS_DFLT);
	~ZMQContext();

enum Option {
#ifdef ZMQ_BLOCKY
	OPTION_BLOCKY = ZMQ_BLOCKY,
#endif
#ifdef ZMQ_IO_THREADS
	OPTION_IO_THREADS = ZMQ_IO_THREADS,
#endif
#ifdef ZMQ_THREAD_SCHED_POLICY
	OPTION_THREAD_SCHED_POLICY = ZMQ_THREAD_SCHED_POLICY,
#endif
#ifdef ZMQ_THREAD_PRIORITY
	OPTION_THREAD_PRIORITY = ZMQ_THREAD_PRIORITY,
#endif
#ifdef ZMQ_THREAD_AFFINITY_CPU_ADD
	OPTION_THREAD_AFFINITY_CPU_ADD = ZMQ_THREAD_AFFINITY_CPU_ADD,
#endif
#ifdef ZMQ_THREAD_AFFINITY_CPU_REMOVE
	OPTION_THREAD_AFFINITY_CPU_REMOVE = ZMQ_THREAD_AFFINITY_CPU_REMOVE,
#endif
#ifdef ZMQ_THREAD_NAME_PREFIX
	OPTION_THREAD_NAME_PREFIX = ZMQ_THREAD_NAME_PREFIX,
#endif
#ifdef ZMQ_MAX_MSGSZ
	OPTION_MAX_MSGSZ = ZMQ_MAX_MSGSZ,
#endif
#ifdef ZMQ_ZERO_COPY_RECV
	OPTION_ZERO_COPY_RECV = ZMQ_ZERO_COPY_RECV,
#endif
#ifdef ZMQ_MAX_SOCKETS
	OPTION_MAX_SOCKETS = ZMQ_MAX_SOCKETS,
#endif
#ifdef ZMQ_SOCKET_LIMIT
	OPTION_SOCKET_LIMIT = ZMQ_SOCKET_LIMIT,
#endif
#ifdef ZMQ_IPV6
	OPTION_IPV6 = ZMQ_IPV6,
#endif
#ifdef ZMQ_MSG_T_SIZE
	OPTION_MSG_T_SIZE = ZMQ_MSG_T_SIZE
#endif
};

	void zmq_set(Option p_option, int p_option_val);
	int zmq_get(Option p_option) const;

	inline void close() { _ptr->close(); }
	inline void shutdown() { _ptr->shutdown(); }

	inline zmq::context_t* ptr() const { return _ptr;}
protected:
	zmq::context_t* _ptr = nullptr;
};

VARIANT_ENUM_CAST(ZMQContext::Option);

