
#include "gd_zmq.h"

zmq::message_t CastTo::message_t(const String &str) {
	std::string std_string = str.utf8().get_data();
	return zmq::message_t(std_string);
}

String CastTo::ToString(const zmq::message_t &msg) {
	std::string received_frame(static_cast<const char*>(msg.data()), msg.size());
	return String(received_frame.c_str());
}