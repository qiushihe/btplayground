//
//  echo-tcp.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum TCPEchoError: ErrorType {
  case InvalidArguments
}

class TCPEcho {
  private let port: UInt16;
  private let host: String?;
  private var isServer: Bool;
  
  private var tcpSocket: TCPSocket? = nil;
  
  init(port: UInt16, host: String? = nil) {
    self.port = port;
    self.host = host;
    self.isServer = host == nil;
  }

  init(argv: Array<String>) throws {
    guard argv.count > 2 else { throw TCPEchoError.InvalidArguments; }
    
    let type = argv[1];
    let argPort: UInt16? = UInt16(argv[2]);
    
    guard argPort != nil else { throw TCPEchoError.InvalidArguments; }
    self.port = argPort!;
    
    if (type == "server") {
      self.host = nil;
      self.isServer = true;
    } else if (type == "client") {
      guard argv.count > 3 else { throw TCPEchoError.InvalidArguments; }
      self.host = argv[3];
      self.isServer = false;
    } else {
      throw TCPEchoError.InvalidArguments;
    }
  }
  
  func start() {
    var tcpSocketOptions = SocketOptions.init();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = self.host;
    tcpSocketOptions.type = self.host == nil ? SocketType.Server : SocketType.Client;
    
    self.tcpSocket = TCPSocket.init(options: tcpSocketOptions);
    self.tcpSocket!.setListener(self.handleSocketData);
    
    print("\(self.isServer ? "Server" : "Client") listening ...");
    
    if (!self.isServer) {
      let str = "Holy Shit! Men on the Fucking Moon!";
      self.tcpSocket!.sendData(str.dataUsingEncoding(NSUTF8StringEncoding)!);
      print("Client sent: \(str)");
    }
  }
  
  func stop() {
    self.tcpSocket?.closeSocket();
  }

  private func handleSocketData(dataSocket: TCPSocket) {
    let dataRead = dataSocket.readData();
    
    if let dataString = String.init(data: dataRead, encoding: NSUTF8StringEncoding) {
      print("\(self.isServer ? "Server" : "Client") received message: \(dataString)");
    } else {
      print("\(self.isServer ? "Server" : "Client") received \(dataRead.length) bytes: \(dataRead.bytes)");
    }
    
    if (self.isServer) {
      let replyStr = "Bay Area Men Wakes Up To No New Email!";
      let replyData = replyStr.dataUsingEncoding(NSUTF8StringEncoding)!;

      dataSocket.sendData(replyData);
     
      print("Server sent: \(replyStr)");
    }
  }
}