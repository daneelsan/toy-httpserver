
printSocketInfo[socket_SocketObject, msg_String] :=
	Print[msg, socket["DestinationHostname"], ":", socket["DestinationPort"]];


(* Default response headers *)
$defaultResponseHeaders = <|
	"Server" -> "ToyServer (wolfram)",
	"Content-Type" -> "text/html"
|>;


handleMethod[$Failed][request_] :=
	HTTPResponse[
		"<h1>501 Not Implemented</h1>",
		<|
			"StatusCode" -> 501,
			$defaultResponseHeaders
		|>
	];


handleMethod["GET"][request_] :=
	Module[{fileName, statusCode, body, headers = <||>},
		(* Only search files in the same directory as the script *)
		fileName = FileNameJoin[{".", request["PathString"]}];
		If[fileName =!= "." && FileExistsQ[fileName],
			statusCode = 200;
			headers["Content-Type"] = First[Import[fileName, "MIMEType"], "TEXT/HTML"];
			(* Read the contents of the file as a byte array *)
			body = ReadByteArray[fileName];
			,
			statusCode = 404;
			body = "<h1>404 Not Found</h1>";
		];
		HTTPResponse[
			body,
			<|
				"StatusCode" -> statusCode,
				$defaultResponseHeaders,
				headers
			|>
		]
	];


httpListenFun[assoc_] :=
	Module[{client, data, request, method, response, responseStr},
		WithCleanup[
			client = assoc["SourceSocket"];
			data = assoc["Data"];
			timestamp = DateString[assoc["TimeStamp"]];
			,
			(* Print info about the client that sent a request *)
			printSocketInfo[client, "Connected by (" <> timestamp <> "): "];

			(* Use ImportString to parse the string to a HTTPRequest[] object *)
			request = Quiet[ImportString[data, "HTTPRequest"], {Import::fmterr}];
			method = If[Head[request] === HTTPRequest,
				request[Method]
				,
				$Failed
			];
			(* Only handles the GET method, but could get expanded *)
			response = handleMethod[method][request];
			(* Use ExportString to convert a HTTPResponse[] object to a string *)
			responseStr = ExportString[response, "HTTPResponse"];
			WriteString[client, responseStr]
			,
			Close[client];
		]
	];

WithCleanup[
	(* Open a socket that accepts TCP connections to 127.0.0.1:8888 *)
	server = SocketOpen[{"127.0.0.1", "8888"}, "TCP"];
	(* Start listening on the server socket, asynchronously applying httpListenFun whenever data is received *)
	listener = SocketListen[server, httpListenFun];
	,
	printSocketInfo[server, "Listening at: "];
	(* Make sure the session is "alive" *)
	TaskWait[task = SessionSubmit[ScheduledTask["Staying alive", 60]]]
	,
	DeleteObject[listener];
	Close[server];
	TaskRemove[task]
]
