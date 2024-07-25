local socket = require("socket")
local mimetypes = require("mimetypes")

-- Function to parse an HTTP request line
local function parse_http_request(data)
	local request_line = data
	-- Split the request line into words
	local words = {}
	for word in string.gmatch(request_line, "([^%s]+)") do
		table.insert(words, word)
	end
	-- Initialize an HTTP request table with default values
	local http_request = {
		method = nil,
		uri = nil,
		http_version = "1.1"
	}
	-- Populate the HTTP request table with the parsed values
	http_request.method = words[1]
	if #words > 1 then
		http_request.uri = words[2]
	end
	if #words > 2 then
		http_request.http_version = words[3]
	end
	return http_request
end

-- Table to map HTTP status codes to their reason phrases
local http_status_codes = {
	[200] = "OK",
	[404] = "Not Found",
	[501] = "Not Implemented"
}

-- Function to generate an HTTP response line
local function http_response_line(status_code)
	local reason = http_status_codes[status_code]
	return string.format("HTTP/1.1 %d %s\r\n", status_code, reason)
end

-- Default HTTP response headers
local http_server_headers = {
	["Server"] = "ToyServer (lua)",
	["Content-Type"] = "text/html"
}

-- Function to generate HTTP response headers
local function http_response_headers(extra_headers)
	-- Copy default headers
	local headers = {}
	for k, v in pairs(http_server_headers) do
		headers[k] = v
	end
	-- Add any extra headers
	if extra_headers then
		for k, v in pairs(extra_headers) do
			headers[k] = v
		end
	end
	-- Convert headers table to a string
	local headers_str = ""
	for k, v in pairs(headers) do
		headers_str = headers_str .. string.format("%s: %s\r\n", k, v)
	end
	return headers_str
end

-- Function to handle HTTP 501 Not Implemented response
local function http_handle_501(request)
	local response_line = http_response_line(501)
	local response_headers = http_response_headers()
	local blank_line = "\r\n"
	local response_body = "<h1>501 Not Implemented</h1>"
	return table.concat({ response_line, response_headers, blank_line, response_body })
end

-- Function to handle HTTP GET request
local function http_handle_GET(request)
	local filename = request.uri:sub(2) -- Remove the leading '/'
	local response_line, response_headers, response_body

	local file = io.open(filename, "rb")
	if file ~= nil then
		response_line = http_response_line(200)
		local content_type = mimetypes.guess(filename) or "text/html"
		response_headers = http_response_headers({ ["Content-Type"] = content_type })
		response_body = file:read("*all")
		file:close()
	else
		response_line = http_response_line(404)
		response_headers = http_response_headers()
		response_body = "<h1>404 Not Found</h1>"
	end

	local blank_line = "\r\n"
	return table.concat({ response_line, response_headers, blank_line, response_body })
end

-- Table to map HTTP methods to their corresponding handlers
local http_method_handlers = {
	["GET"] = http_handle_GET
}

-- Function to handle an HTTP request
local function handle_http_request(lines)
	local http_request = parse_http_request(lines)
	local handler = http_method_handlers[http_request.method]
	if not handler then
		handler = http_handle_501
	end
	local http_response = handler(http_request)
	return http_response
end

--------------------------------------------------------------------------------

-- Create and bind the server socket
local server = assert(socket.bind("127.0.0.1", 8888))
server:setoption("reuseaddr", true)
local server_ip, server_port = server:getsockname()
print("Listening at (" .. server_ip .. ":" .. server_port .. ")")

while true do
	-- Accept a client connection
	local client = server:accept()
	-- Set the timeout for the client socket to non-blocking mode
	client:settimeout(0)

	local client_ip, client_port = client:getpeername()
	print("Connected by (" .. client_ip .. ":" .. client_port .. ")")

	-- local data = {}
	-- while true do
	-- 	local line, err, partial = client:receive("*l")
	-- 	-- print(err .. " | " .. partial)
	-- 	if line == nil then
	-- 		break
	-- 	end
	-- 	-- print(line:len() .. "| " .. line)
	-- 	table.insert(data, line)
	-- end

	-- Receive the data from the client
	-- I used to receive multiple lines from a client and put it in a table,
	-- but that seems to be unnecessary. If the request was a POST, then simply
	-- pass the client down to the handler so that it can call client:receive()
	-- to get the content of the request.
	local data, err, part = client:receive("*l")
	if not err then
		-- Handle the HTTP request and send the response
		local http_response = handle_http_request(data)
		client:send(http_response)
	end
	-- Close the client connection
	client:close()
end
