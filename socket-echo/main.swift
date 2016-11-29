//
//  main.swift
//  socket-echo
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum SocketEchoError: ErrorType {
  case InvalidArguments
}

var echoer: SocketEchoer? = nil;

do {
  let arguments = Process.arguments;
  if (arguments.count <= 1) {
    throw SocketEchoError.InvalidArguments;
  }

  let echoerType = arguments[1];
  if (echoerType != "server" && echoerType != "client") {
    throw SocketEchoError.InvalidArguments;
  }

  if (echoerType == "client" && arguments.count < 5) {
    throw SocketEchoError.InvalidArguments;
  }

  let socketProtocol = arguments[2];
  if (socketProtocol != "tcp" && socketProtocol != "udp") {
    throw SocketEchoError.InvalidArguments;
  }

  let port = UInt16(arguments[3]);
  if (port == nil) {
    throw SocketEchoError.InvalidArguments;
  }

  let host: String? = echoerType == "server" ? nil : arguments[4];

  echoer = socketProtocol == "tcp"
    ? TCPEcho(port: port!, host: host)
    : UDPEcho(port: port!, host: host);
} catch SocketEchoError.InvalidArguments {
  print("Socker Echo Usage:");
  print("* Server mode: socket-echo server [tcp|udp] [port]");
  print("* Client mode: socket-echo client [tcp|udp] [port] [host]");
  exit(0);
}

SobtLib.Helper.RunLoop.StartRunLoopWithTrap(
  before: {() in
    echoer?.start();
  },
  after: {() in
    echoer?.stop();
  }
);
