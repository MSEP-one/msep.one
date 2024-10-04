#include "zmq_socket.h"

#include "zmq_context.h"

void ZMQSocket::_bind_methods() {
	ClassDB::bind_method(D_METHOD("bind", "p_address"), &ZMQSocket::bind);
	ClassDB::bind_method(D_METHOD("unbind", "p_address"), &ZMQSocket::unbind);
	ClassDB::bind_method(D_METHOD("connect_to_server", "p_address"), &ZMQSocket::connect_to_server);
	ClassDB::bind_method(D_METHOD("disconnect_from_server", "p_address"), &ZMQSocket::disconnect_from_server);
	ClassDB::bind_method(D_METHOD("set_option", "p_option", "p_value"), &ZMQSocket::set_option);
	ClassDB::bind_method(D_METHOD("is_connected_to_server"), &ZMQSocket::is_connected_to_server);
	ClassDB::bind_method(D_METHOD("send_buffer", "p_buffer", "p_flags"), &ZMQSocket::send_buffer, DEFVAL(SendFlags::SEND_FLAG_NONE));
	ClassDB::bind_method(D_METHOD("send_string", "p_string", "p_flags"), &ZMQSocket::send_string, DEFVAL(SendFlags::SEND_FLAG_NONE));
	ClassDB::bind_method(D_METHOD("receive_buffer"), &ZMQSocket::receive_buffer, DEFVAL(ReceiveFlags::RECEIVE_FLAG_NONE));
	ClassDB::bind_method(D_METHOD("receive_string"), &ZMQSocket::receive_string, DEFVAL(ReceiveFlags::RECEIVE_FLAG_NONE));
	ClassDB::bind_method(D_METHOD("receive_multipart_string"), &ZMQSocket::receive_multipart_string, DEFVAL(ReceiveFlags::RECEIVE_FLAG_NONE));
	ClassDB::bind_method(D_METHOD("has_more"), &ZMQSocket::has_more);
	
	ClassDB::bind_method(D_METHOD("close"), &ZMQSocket::close);
	ClassDB::bind_static_method("ZMQSocket", D_METHOD("create", "p_context", "p_type"), &ZMQSocket::_create_ZMQSocket);

	// Type
	BIND_ENUM_CONSTANT(TYPE_REQUEST);
	BIND_ENUM_CONSTANT(TYPE_REPLY);
	BIND_ENUM_CONSTANT(TYPE_DEALER);
	BIND_ENUM_CONSTANT(TYPE_ROUTER);
	BIND_ENUM_CONSTANT(TYPE_PUB);
	BIND_ENUM_CONSTANT(TYPE_SUB);
	BIND_ENUM_CONSTANT(TYPE_XPUB);
	BIND_ENUM_CONSTANT(TYPE_XSUB);
	BIND_ENUM_CONSTANT(TYPE_PUSH);
#if defined(ZMQ_BUILD_DRAFT_API) && ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 2, 0)
	BIND_ENUM_CONSTANT(TYPE_PULL);
	BIND_ENUM_CONSTANT(TYPE_SERVER);
	BIND_ENUM_CONSTANT(TYPE_CLIENT);
	BIND_ENUM_CONSTANT(TYPE_RADIO);
	BIND_ENUM_CONSTANT(TYPE_DISH);
	BIND_ENUM_CONSTANT(TYPE_GATHER);
	BIND_ENUM_CONSTANT(TYPE_SCATTER);
	BIND_ENUM_CONSTANT(TYPE_DGRAM);
#endif
#if defined(ZMQ_BUILD_DRAFT_API) && ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 3, 3)
	BIND_ENUM_CONSTANT(TYPE_PEER);
	BIND_ENUM_CONSTANT(TYPE_CHANNEL);
#endif
#if ZMQ_VERSION_MAJOR >= 4
	BIND_ENUM_CONSTANT(TYPE_STREAM);
#endif
	BIND_ENUM_CONSTANT(TYPE_PAIR);

	// SendFlags
	BIND_ENUM_CONSTANT(SEND_FLAG_NONE);
	BIND_ENUM_CONSTANT(SEND_FLAG_DONTWAIT);
	BIND_ENUM_CONSTANT(SEND_FLAG_SNDMORE);

	//ReceiveFlags
	BIND_ENUM_CONSTANT(RECEIVE_FLAG_NONE);
	BIND_ENUM_CONSTANT(RECEIVE_FLAG_DONT_WAIT);

	BIND_ENUM_CONSTANT(OPT_SUBSCRIBE);
}

ZMQSocket::ZMQSocket()
{
	ERR_PRINT("Default constructor is unsupported, use ZMQSocket.create(ZMQContext, ZMQSocket::Type) instead");
	_ptr = new zmq::socket_t();
}

ZMQSocket::ZMQSocket(Ref<ZMQContext> out_context, Type p_type) {
#ifdef ZMQ_CPP11
	_ptr = new zmq::socket_t(*(out_context->ptr()), static_cast<zmq::socket_type>(p_type));
#else
	_ptr = new zmq::socket_t(*(out_context->ptr()), static_cast<int>(p_type));
#endif
}

ZMQSocket::~ZMQSocket() {
	close();
	delete _ptr;
}

void ZMQSocket::bind(const String &p_address) {
	_ptr->bind(p_address.utf8().get_data());
}

void ZMQSocket::unbind(const String &p_address) {
	_ptr->unbind(p_address.utf8().get_data());
}

void ZMQSocket::connect_to_server(const String &p_address) {
	_ptr->connect(p_address.utf8().get_data());
}

void ZMQSocket::disconnect_from_server(const String &p_address) {
	_ptr->disconnect(p_address.utf8().get_data());
}

void ZMQSocket::set_option(SocketOptions p_option, const String &p_value) {
	switch (p_option)
	{
	case SocketOptions::OPT_SUBSCRIBE:
		_ptr->set(zmq::sockopt::subscribe, p_value.utf8().get_data());
		break;
	default:
		ERR_PRINT(String("Unsupported option {}").format(p_option));
		break;
	}
}

int ZMQSocket::send_buffer(const PackedByteArray &p_buffer, SendFlags p_flags) {
	zmq::const_buffer buf(p_buffer.ptr(), p_buffer.size());
	zmq::send_result_t result = _ptr->send(buf, static_cast<zmq::send_flags>(p_flags));
	
	return result.has_value() ? result.value() : -1;
}

int ZMQSocket::send_string(const String &p_string, SendFlags p_flags)
{
	zmq::message_t msg = CastTo::message_t(p_string);
	zmq::send_result_t result = _ptr->send(msg, static_cast<zmq::send_flags>(p_flags));

	return result.has_value() ? result.value() : -1;
}

PackedByteArray ZMQSocket::receive_buffer(ReceiveFlags p_flags)
{
	// Receive the message
	zmq::message_t message;
	zmq::recv_result_t result = _ptr->recv(message, static_cast<zmq::recv_flags>(p_flags));
	if (!result.has_value() || result.value() == -1) {
		if (p_flags != ReceiveFlags::RECEIVE_FLAG_DONT_WAIT) {
			Array format_args;
			format_args.push_back(zmq_errno());
			ERR_PRINT(String("Failed to obtain buffer with error {}").format(format_args));
		}
		return PackedByteArray();
	}
	zmq::const_buffer buffer(message.data(), message.size());

	// Check if there are more frames to receive
	more = _ptr->get(zmq::sockopt::rcvmore);

	// Process the received frame
	int size = message.size();
	PackedByteArray response;
	response.resize(size);
	const char* buffer_ptr = static_cast<const char*>(buffer.data());
	for (int i = 0; i < size; ++i) {
		response.write[i] = buffer_ptr[i];
	}

	return response;
}

String ZMQSocket::receive_string(ReceiveFlags p_flags)
{
	// Receive the message
	zmq::message_t message;
	zmq::recv_result_t result = _ptr->recv(message, static_cast<zmq::recv_flags>(p_flags));
	if (!result.has_value() || result.value() == -1) {
		if (p_flags != ReceiveFlags::RECEIVE_FLAG_DONT_WAIT) {
			Array format_args;
			format_args.push_back(zmq_errno());
			ERR_PRINT(String("Failed to obtain buffer with error {}").format(format_args));
		}
		return String();
	}

	// Check if there are more frames to receive
	more = _ptr->get(zmq::sockopt::rcvmore);

	// Process the received frame
	return CastTo::ToString(message);
}

PackedStringArray ZMQSocket::receive_multipart_string(ReceiveFlags p_flags)
{
	PackedStringArray messages;
	while (true) {
		// Receive the message
		zmq::message_t message;
		zmq::recv_result_t result = _ptr->recv(message, static_cast<zmq::recv_flags>(p_flags));
		if (!result.has_value() || result.value() == -1) {
			ERR_PRINT(String("Failed to obtain message with error {}").format(zmq_errno()));
			return messages;
		}

		// Check if there are more frames to receive
		more = _ptr->get(zmq::sockopt::rcvmore);

		// Process the received frame
		messages.push_back(CastTo::ToString(message));

		if (!more) {
			break;
		}
	}
	return messages;
}

Ref<ZMQSocket> ZMQSocket::_create_ZMQSocket(Ref<ZMQContext> out_context, Type p_type) {
	return memnew(ZMQSocket(out_context, p_type));
}