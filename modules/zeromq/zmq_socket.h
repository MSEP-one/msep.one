#pragma once

#include "core/object/ref_counted.h"
#include "gd_zmq.h"


class ZMQContext;

class ZMQSocket : public RefCounted {
	GDCLASS(ZMQSocket, RefCounted)

protected:
	static void _bind_methods();

public:

	enum Type {
		TYPE_REQUEST = ZMQ_REQ,
		TYPE_REPLY = ZMQ_REP,
		TYPE_DEALER = ZMQ_DEALER,
		TYPE_ROUTER = ZMQ_ROUTER,
		TYPE_PUB = ZMQ_PUB,
		TYPE_SUB = ZMQ_SUB,
		TYPE_XPUB = ZMQ_XPUB,
		TYPE_XSUB = ZMQ_XSUB,
		TYPE_PUSH = ZMQ_PUSH,
		TYPE_PULL = ZMQ_PULL,
#if defined(ZMQ_BUILD_DRAFT_API) && ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 2, 0)
		TYPE_SERVER = ZMQ_SERVER,
		TYPE_CLIENT = ZMQ_CLIENT,
		TYPE_RADIO = ZMQ_RADIO,
		TYPE_DISH = ZMQ_DISH,
		TYPE_GATHER = ZMQ_GATHER,
		TYPE_SCATTER = ZMQ_SCATTER,
		TYPE_DGRAM = ZMQ_DGRAM,
#endif
#if defined(ZMQ_BUILD_DRAFT_API) && ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 3, 3)
		TYPE_PEER = ZMQ_PEER,
		TYPE_CHANNEL = ZMQ_CHANNEL,
#endif
#if ZMQ_VERSION_MAJOR >= 4
		TYPE_STREAM = ZMQ_STREAM,
#endif
		TYPE_PAIR = ZMQ_PAIR
	};

	ZMQSocket();
	ZMQSocket(Ref<ZMQContext> out_context, Type p_type);
	~ZMQSocket();

	enum SendFlags {
		SEND_FLAG_NONE = 0,
		SEND_FLAG_DONTWAIT = ZMQ_DONTWAIT,
		SEND_FLAG_SNDMORE = ZMQ_SNDMORE
	};

	enum ReceiveFlags {
		RECEIVE_FLAG_NONE = 0,
		RECEIVE_FLAG_DONT_WAIT = ZMQ_DONTWAIT
	};

	enum SocketOptions {
		OPT_SUBSCRIBE = 0,
	};

//	void zmq_set(Option p_option, int p_option_val);
//	int zmq_get(Option p_option) const;

	void bind(const String &p_address);
	void unbind(const String &p_address);
	void connect_to_server(const String &p_address);
	void disconnect_from_server(const String &p_address);
	void set_option(SocketOptions p_option, const String &p_value);
	inline bool is_connected_to_server() { return _ptr != nullptr && _ptr->handle() != nullptr; }
	int send_buffer(const PackedByteArray &p_buffer, SendFlags p_flags = SendFlags::SEND_FLAG_NONE);
	int send_string(const String &p_string, SendFlags p_flags = SendFlags::SEND_FLAG_NONE);
	PackedByteArray receive_buffer(ReceiveFlags p_flags = ReceiveFlags::RECEIVE_FLAG_NONE);
	String receive_string(ReceiveFlags p_flags = ReceiveFlags::RECEIVE_FLAG_NONE);
	PackedStringArray receive_multipart_string(ReceiveFlags p_flags = ReceiveFlags::RECEIVE_FLAG_NONE);
	inline bool has_more() const { return more; }
	inline void close() { _ptr->close(); }

	inline zmq::socket_t* ptr() const { return _ptr;}
protected:
	zmq::socket_t* _ptr = nullptr;
	static Ref<ZMQSocket> _create_ZMQSocket(Ref<ZMQContext> out_context, Type p_type);
private:
	bool more = false;
};


VARIANT_ENUM_CAST(ZMQSocket::Type);
VARIANT_ENUM_CAST(ZMQSocket::SendFlags);
VARIANT_ENUM_CAST(ZMQSocket::ReceiveFlags);
VARIANT_ENUM_CAST(ZMQSocket::SocketOptions);

