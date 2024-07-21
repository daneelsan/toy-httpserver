import mimetypes
import os
import socket


class TCPServer:
	def __init__(self, host="127.0.0.1", port=8888):
		self.host = host
		self.port = port

	def start(self):
		# create a socket object
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

		# bind the socket object to the address and port
		s.bind((self.host, self.port))
		# start listening for connections
		s.listen(5)

		print("Listening at", s.getsockname())

		while True:
			# accept any new connection
			conn, addr = s.accept()
			print("Connected by", addr)

			# read the data sent by the client
			# we'll only read the first 1024 bytes
			data = conn.recv(1024)

			response = self.handle_request(data)
			# print("Response", response)

			# send back the response to client
			succ = conn.sendall(response)
			# print("Success", succ)

			# close the connection
			conn.close()

	def handle_request(self, data):
		"""Handles incoming data and returns a response.
		Override this in subclass.
		"""
		return data


class HTTPServer(TCPServer):
	status_codes = {
		200: "OK",
		404: "Not Found",
		501: "Not Implemented",
	}

	headers = {
		"Server": "ToyServer (python)",
		"Content-Type": "text/html",
	}

	def handle_request(self, data):
		# create an instance of `HTTPRequest`
		request = HTTPRequest(data)

		# look at the request method and call the appropriate handler
		try:
			handler = getattr(self, "handle_%s" % request.method)
		except AttributeError:
			handler = self.handle_HTTP_501

		response = handler(request)
		return response

	def handle_HTTP_501(self, request):
		response_line = self.response_line(status_code=501)
		response_headers = self.response_headers()
		blank_line = b"\r\n"
		response_body = b"<h1>501 Not Implemented</h1>"
		return b"".join([response_line, response_headers, blank_line, response_body])

	def handle_GET(self, request):
		filename = request.uri.strip("/")  # remove the slash from the request URI
		if os.path.exists(filename):
			response_line = self.response_line(status_code=200)
			# find out a file's MIME type
			# if nothing is found, just send `text/html`
			content_type = mimetypes.guess_type(filename)[0] or "text/html"
			response_headers = self.response_headers({"Content-Type": content_type})
			with open(filename, "rb") as f:
				response_body = f.read()
		else:
			response_line = self.response_line(status_code=404)
			response_headers = self.response_headers()
			response_body = b"<h1>404 Not Found</h1>"
		blank_line = b"\r\n"
		response = b"".join(
			[response_line, response_headers, blank_line, response_body]
		)
		return response

	def response_line(self, status_code):
		"""Returns response line"""
		reason = HTTPServer.status_codes[status_code]
		line = "HTTP/1.1 %s %s\r\n" % (status_code, reason)
		return line.encode()  # call encode to convert str to bytes

	def response_headers(self, extra_headers=None):
		"""Returns headers
		The `extra_headers` can be a dict for sending
		extra headers for the current response
		"""
		headers_copy = HTTPServer.headers.copy()  # make a local copy of headers
		if extra_headers:
			headers_copy.update(extra_headers)

		headers = ""
		for h in headers_copy:
			headers += "%s: %s\r\n" % (h, headers_copy[h])
		return headers.encode()  # call encode to convert str to bytes


class HTTPRequest:
	def __init__(self, data):
		self.method = None
		self.uri = None
		# default to HTTP/1.1 if request doesn't provide a version
		self.http_version = "1.1"
		# call self.parse() method to parse the request data
		self.parse(data)

	def parse(self, data):
		lines = data.split(b"\r\n")
		request_line = lines[0]
		words = request_line.split(b" ")
		self.method = words[0].decode()  # call decode to convert bytes to str

		if len(words) > 1:
			# we put this in an if-block because sometimes
			# browsers don't send uri for homepage
			self.uri = words[1].decode()  # call decode to convert bytes to str
		if len(words) > 2:
			self.http_version = words[2]


if __name__ == "__main__":
	server = HTTPServer()
	server.start()
