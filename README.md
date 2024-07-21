# Toy HTTP Server in multiple languages

Implementation of a toy HTTP server in lua, python, wolfram language and zig.
The server is built on top of simple socket functionality, using TCP for the connection protocol and using localhost as the socket address.
The server currently only handles the GET method, but it could be easily be expanded.

## Usage

Start the HTTP server in various languages:

### lua (work in progress)

Tested on:
```shell
$ lua -v
Lua 5.4.6  Copyright (C) 1994-2023 Lua.org, PUC-Rio
```

Install the luasocket package (I chose `luarocks` for this):
```shell
$ luarocks install luasocket
```

Start the server:
```shell
$ lua httpserver.lua
```

### python

Tested on:
```shell
$ python3 --version
Python 3.9.6
```

Start the server:
```shell
$ python3 httpserver.py
```

### wolfram

Tested on:
```shell
$ wolframscript --version
WolframScript 1.8.0 for Mac OS X ARM (64-bit)
```

Start the server:
```shell
wolframscript -f httpserver.wl
```

### zig (work in progress)

Start the server:
```shell
zig run httpserver.zig
```

## Test

Send a HTTP request to the toy HTTP server using curl:
```shell
$ curl -i 127.0.0.1:8888/index.html
HTTP/1.1 200 OK
content-type: text/html;charset=UTF-8

<html>
    <head>
        <title>Index page</title>
    </head>
    <body>
        <h1>Index page</h1>
        <p>This is the index page.</p>
        <img src="./images/random.jpeg">
    </body>
</html>
```

Or do it via a web browser:
<image src="./images/browser_example.png" alt="Request from a browser">

A request for a non-existant file returns the following:
```shell
$ curl -i --http0.9 127.0.0.1:8888/notafile.txt
HTTP/1.1 404 Not Found
content-type: text/html;charset=UTF-8

<h1>404 Not Found</h1>⏎
```

## References

### lua

- [LuaSocket: Introduction to the core](https://lunarmodules.github.io/luasocket/introduction.html)

### python

- [Writing an HTTP server from scratch](https://bhch.github.io/posts/2017/11/writing-an-http-server-from-scratch/)
- [socket — Low-level networking interface](https://docs.python.org/3/library/socket.html)

### wolfram

- [SocketListen - Wolfram Language Documentation](http://reference.wolfram.com/language/ref/SocketListen.html)
- [SocketOpen - Wolfram Language Documentation](http://reference.wolfram.com/language/ref/SocketOpen.html)
- [SessionSubmit - Wolfram Language Documentation](http://reference.wolfram.com/language/ref/SessionSubmit.html)

### zig

- [Socket programming in Zig (YouTube)](https://www.youtube.com/watch?v=V7Jql_SZ7kY)
- [Writing a HTTP Server in Zig](https://www.pedaldrivenprogramming.com/2024/03/writing-a-http-server-in-zig/)
- [Zig Bits 0x4: Building an HTTP client/server from scratch](https://blog.orhun.dev/zig-bits-04/)
- [Creating UDP server from scratch in Zig](https://blog.reilly.dev/creating-udp-server-from-scratch-in-zig)

### other

- [An overview of HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview)