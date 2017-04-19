//
//  main.swift
//  Perfect Unscrambler
//
//  Created by Rockford Wei on 4/17/17.
//	Copyright (C) 2017 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2017 - 2018 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectWebSockets

/// any valid word list file given each word per line.
let dictionaryURL = "https://raw.githubusercontent.com/dwyl/english-words/master/words.txt"

/// server port to start with
let port = 9999

/// word groups
let words = WordGroups(dictionaryURL)

/// validate the input string
func sanitizedInput(_ raw: String, _ size: Int = 32) -> String {
  var buf = Array(raw.lowercased().utf8.filter { $0 > 96 && $0 < 123 }.prefix(size))
  buf.append(0)
  return String(cString: buf)
}//end validInput

public class PuzzleHandler: WebSocketSessionHandler {

  public let socketProtocol : String? = "puzzle"

  // This function is called by the WebSocketHandler once the connection has been established.
  public func handleSession(request: HTTPRequest, socket: WebSocket) {

    socket.readStringMessage { raw, _, _ in

      guard let raw = raw else {
        // This block will be executed if, for example, the browser window is closed.
        socket.close()
        return
      }//end guard

      let string = sanitizedInput(raw)
      let solution = words.solve(scramble: string).map { "\($0)\n" }.joined()

      socket.sendStringMessage(string: solution, final: true) {
        self.handleSession(request: request, socket: socket)
      }//end send
    }//end readStringMessage
  }//end handleSession
}//end Puzzle

/// api handler: will return a json solution for the puzzle
func socketHandler(data: [String:Any]) throws -> RequestHandler {
	return {
		request, response in

    WebSocketHandler(handlerProducer: { (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in

      guard protocols.contains("puzzle") else {
        return nil
      }//end guard

      return PuzzleHandler()
    }).handleRequest(request: request, response: response)
  }//end return
}//end handler

// default home page for jQuery+Reactive-Extension demo
let homePageWithReativeExtensionJS = "<html><head><title>Unscrambler</title>\n" +
  "<script language=javascript type='text/javascript'>\nvar input, output;\n" +
  "function init()\n { input=document.getElementById('textInput'); \noutput=document.getElementById('results');\n" +
  "sock=new WebSocket('ws://' + window.location.host + '/puzzle', 'puzzle');\n" +
  "sock.onmessage=function(evt) { output.innerText = evt.data; } }\n" +
  "function send() { sock.send(input.value); } \n" +
  "window.addEventListener('load', init, false);\n" +
  "</script></head><body><H1>Perfect Unscrambler</H1><H2>(WebSocket Version)</H2>\n" +
  "<p><input type=text id=textInput size=32 onkeyup='send()' placeholder='Enter Query...'>\n" +
  "</p><ul id=results></ul></body></html>"

/// page handler: will print a input form with the solution list below
func handler(data: [String:Any]) throws -> RequestHandler {
  return {
    request, response in
    response.setHeader(.contentType, value: "text/html")
    response.appendBody(string: homePageWithReativeExtensionJS)
    response.completed()
  }//end return
}//end handler

/// favicon
func favicon(data: [String:Any]) throws -> RequestHandler {
  return {
    request, response in
    response.completed()
  }//end return
}//end handler

let confData = [
	"servers": [
		[
			"name":"localhost",
			"port":port,
			"routes":[
				["method":"get", "uri":"/", "handler":handler],
				["method":"get", "uri":"/favicon.ico", "handler":favicon],
        ["method":"get", "uri":"/puzzle", "handler":socketHandler]
			]
		]
	]
]

do {
	// Launch the servers based on the configuration data.
	try HTTPServer.launch(configurationData: confData)
} catch {
	fatalError("\(error)") // fatal error launching one of the servers
}
