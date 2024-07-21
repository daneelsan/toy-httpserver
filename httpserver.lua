-- load namespace
local socket = require("socket")

--------------------------------------------------------------------------------
--- HTTPServer
--------------------------------------------------------------------------------

status_codes = {
	200 = "OK",
	404 =  "Not Found",
	501 = "Not Implemented",
}

HTTPServer = {

}

--------------------------------------------------------------------------------
--- HTTPRequest
--------------------------------------------------------------------------------
HTTPRequest = {
	method = nil,
	uri = nil,
	http_version = "1.1",
}

function HTTPRequest:new(t)
	t = t or {}
	setmetatable(t, self)
	self.__index = self
	return t
end

function HTTPRequest:parse(data)
	if data:sub(-1)~="\n" then data=data.."\n" end
	local iter = data:gmatch("(.-)\n")
	self.method = iter()
	self.uri = iter()
	self.http_version = iter()
end

--------------------------------------------------------------------------------

-- create a TCP socket and bind it to the local host, at any port
local server = assert(socket.bind("*", 8888))

-- find out which port the OS chose for us
local ip, port = server:getsockname()

-- print a message informing what's up
print("Please telnet to localhost on port " .. port)
print("After connecting, you have 10s to enter a line to be echoed")

-- loop forever waiting for clients
while 1 do
	-- wait for a connection from any client
	local client = server:accept()

	-- make sure we don't block waiting for this client's line
	client:settimeout(10)

	-- receive the line
	local line, err = client:receive()

	-- if there was no error, send it back to the client
	if not err then client:send(line .. "\n") end

	-- done with client, close the object
	client:close()
  end
