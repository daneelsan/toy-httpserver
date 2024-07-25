const std = @import("std");

pub fn main() !void {
    // Resolve the IP address and port for the server
    const address = try std.net.Address.resolveIp("127.0.0.1", 8888);
    // Create a listener socket and bind it to the address and port
    var listener = try address.listen(.{ .reuse_address = true });
    std.debug.print("Listening at ({})\n", .{listener.listen_address});
    // Accept incoming connections in a loop
    while (listener.accept()) |conn| {
        defer conn.stream.close();
        std.debug.print("Connected by ({})\n", .{conn.address});
        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;
        // Read data from the connection in a loop
        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            // Break if no more data is read
            if (recv_len == 0) break;
            recv_total += recv_len;
            // Check for the end of the HTTP headers
            if (std.mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
                break;
            }
        } else |read_err| {
            return read_err;
        }
        const recv_data = recv_buf[0..recv_total];
        if (recv_data.len == 0) {
            std.debug.print("Got connection but no header!\n", .{});
            continue;
        }
        // Parse the HTTP request from the received data
        const http_request = try HTTPRequest.parse(recv_data);
        // Handle the HTTP request
        _ = try http_request.handle(conn);
    } else |err| {
        std.debug.print("error in accept: {}\n", .{err});
    }
}

// Define custom error types for HTTP request handling
const ServeFileError = error{
    HeaderMalformed,
    MethodNotSupported,
    VersionNotSupported,
    UnknownMimeType,
};

// Define an enum for HTTP methods
const HTTPMethod = enum {
    GET,
    // POST,
};

const HTTPRequest = struct {
    method: HTTPMethod,
    uri: []const u8 = "/",
    version: []const u8 = "HTTP/1.1",

    /// Function to parse an HTTP request from a buffer
    pub fn parse(buffer: []const u8) !HTTPRequest {
        var http_request = HTTPRequest{
            .method = undefined,
        };
        // Create an iterator over the buffer
        var buffer_iter = std.mem.tokenizeSequence(u8, buffer, "\r\n");
        // Parse the request line
        const request_line = buffer_iter.next() orelse return ServeFileError.HeaderMalformed;
        var request_line_iter = std.mem.tokenizeScalar(u8, request_line, ' ');
        const method_buf = request_line_iter.next().?;
        http_request.method = std.meta.stringToEnum(HTTPMethod, method_buf) orelse return ServeFileError.MethodNotSupported;
        if (request_line_iter.next()) |uri| {
            http_request.uri = uri;
        }
        if (request_line_iter.next()) |version| {
            if (!std.mem.eql(u8, version, "HTTP/1.1")) return ServeFileError.VersionNotSupported;
            http_request.version = version;
        }
        // TODO: Parse and store the request headers here
        return http_request;
    }

    /// Function to handle an HTTP request
    pub fn handle(http_request: HTTPRequest, conn: std.net.Server.Connection) !void {
        switch (http_request.method) {
            .GET => try handle_GET(http_request, conn),
        }
    }

    /// Function to handle HTTP GET requests
    fn handle_GET(http_request: HTTPRequest, conn: std.net.Server.Connection) !void {
        var local_path: []const u8 = undefined;
        if (std.mem.eql(u8, http_request.uri, "/")) {
            local_path = "index.html";
        } else {
            local_path = http_request.uri[1..];
        }
        // Open the requested file
        const file = std.fs.cwd().openFile(local_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                // Send a 404 Not Found response if the file is not found
                const response = "HTTP/1.1 404 NOT FOUND \r\n" ++
                    "Connection: close\r\n" ++
                    "Content-Type: text/html; charset=utf8\r\n" ++
                    "Content-Length: 9\r\n" ++
                    "\r\n" ++
                    "NOT FOUND";
                _ = try conn.stream.writer().print(response, .{});
                return;
            },
            else => return err,
        };
        defer file.close();
        // Guess the MIME type of the file
        const mime = guess_mime_type(local_path);
        // Read the file contents
        const memory = std.heap.page_allocator;
        const maxSize = std.math.maxInt(usize);
        const file_contents = try file.readToEndAlloc(memory, maxSize);
        // Send a 200 OK response with the file contents
        // TODO: get the response line and headers from other utility functions
        const response = "HTTP/1.1 200 OK \r\n" ++
            "Connection: close\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n";
        _ = try conn.stream.writer().print(response, .{ mime, file_contents.len });
        _ = try conn.stream.writer().write(file_contents);
    }
};

// Define a table of MIME types
const mime_types = .{
    .{ ".html", "text/html" },
    .{ ".css", "text/css" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".gif", "image/gif" },
};

/// Function to guess the MIME type of a file based on its extension
pub fn guess_mime_type(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (mime_types) |kv| {
        if (std.mem.eql(u8, extension, kv[0])) {
            return kv[1];
        }
    }
    return "text/html";
}
