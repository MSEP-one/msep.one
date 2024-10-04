
#ifndef GD_ZMQ_CAST_H__
#define GD_ZMQ_CAST_H__

#include "zmq.hpp"
#include "core/string/ustring.h"

namespace CastTo {

zmq::message_t message_t(const String &str);
String ToString(const zmq::message_t &msg);

}
#endif