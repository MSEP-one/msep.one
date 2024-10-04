import time
import zmq

class bcolors:
	HEADER = '\033[95m'
	OKBLUE = '\033[94m'
	OKCYAN = '\033[96m'
	OKGREEN = '\033[92m'
	WARNING = '\033[93m'
	FAIL = '\033[91m'
	ENDC = '\033[0m'
	BOLD = '\033[1m'
	UNDERLINE = '\033[4m'

if __name__ == '__main__':
	context = zmq.Context(2)
	socket = context.socket(zmq.REP)
	socket.bind("tcp://*:5555")
	print(f"{bcolors.HEADER}Listening to port: 5555{bcolors.ENDC}")

	while True:
		message_type = socket.recv()
		match message_type:
			case b"A":	# String Message
				message = socket.recv()
				print(f"{bcolors.OKBLUE}Server received a Message: {message}{bcolors.ENDC}")
				# send the reply to the client
				socket.send("World".encode('utf-8'))
			case b"B":	# Binary buffer
				buffer = socket.recv()
				# duplicate to ensure uniqueness of the buffer
				print(f"{bcolors.OKBLUE}Server received a Bynary Buffer: {str(list(buffer))}{bcolors.ENDC}")
				buffer += bytes([1, 2, 3])
				socket.send(buffer)
			case b"C":	# Multipart string data
				messages = socket.recv_multipart()
				# duplicate to ensure uniqueness of the buffer
				print(f"{bcolors.OKBLUE}Server received a Multipart string Request:'{bcolors.ENDC}")
				as_strings = []
				for msg in messages:
					print(f"{bcolors.OKBLUE}\t'{msg}'{bcolors.ENDC}")
					as_strings += msg.decode('utf-8')
				response = [
					"Re: '" + " ".join(as_strings) + "'",
					"Hello", "back", "from", "the", "other", "side", "."
				]
				last: int = len(response)-1
				for i in range(len(response)):
					frame = response[i]
					flag  = 0 if i == last else zmq.SNDMORE
					socket.send_string(frame, flag)

"""
		#  Wait for next request from client
		frame = socket.recv(copy=False)
		msg = frame.bytes
		mesages = [msg]
		while frame.get(zmq.SNDMORE):
			frame = socket.recv(copy=False)
			msg = frame.bytes
			mesages += msg

		print(f"Received request: {messages}")

		#  Do some 'work'
		time.sleep(1)

		#  Send reply back to client
		socket.send_string("World")
"""