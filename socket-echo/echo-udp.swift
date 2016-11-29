//
//  echo-udp.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-07-06.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum UDPEchoError: ErrorType {
  case InvalidArguments
}

class UDPEcho: SocketEchoer {
  private let port: UInt16;
  private let host: String?;
  private var isServer: Bool;
  
  private var udpSocket: SobtLib.Socket.UDPSocket? = nil;
  
  init(port: UInt16, host: String? = nil) {
    self.port = port;
    self.host = host;
    self.isServer = host == nil;
  }
  
  init(argv: Array<String>) throws {
    guard argv.count > 2 else { throw UDPEchoError.InvalidArguments; }
    
    let type = argv[1];
    let argPort: UInt16? = UInt16(argv[2]);
    
    guard argPort != nil else { throw UDPEchoError.InvalidArguments; }
    self.port = argPort!;
    
    if (type == "server") {
      self.host = nil;
      self.isServer = true;
    } else if (type == "client") {
      guard argv.count > 3 else { throw UDPEchoError.InvalidArguments; }
      self.host = argv[3];
      self.isServer = false;
    } else {
      throw UDPEchoError.InvalidArguments;
    }
  }

  func start() {
    var udpSocketOptions = SobtLib.Socket.SocketOptions();
    udpSocketOptions.port = self.port;
    udpSocketOptions.host = self.host;
    udpSocketOptions.type = self.host == nil ? SobtLib.Socket.SocketType.Server : SobtLib.Socket.SocketType.Client;

    self.udpSocket = SobtLib.Socket.UDPSocket(options: udpSocketOptions);
    self.udpSocket!.setListener(self.handleSocketData);
    
    print("\(self.isServer ? "Server" : "Client") listening ...");
    
    if (!self.isServer) {
      let str = "Holy Shit! Men on the Fucking Moon!";
      self.udpSocket!.sendData(str.dataUsingEncoding(NSUTF8StringEncoding)!);
      print("Client sent: \(str)");
    }
  }
  
  func stop() {
    self.udpSocket?.closeSocket();
  }

  private func handleSocketData(evt: SobtLib.Socket.SocketDataEvent) {
    if (evt.closed) {
      print("\(self.isServer ? "Client" : "Server") closed socket");
      return;
    }

    if let dataString = String(bytes: evt.data, encoding: NSUTF8StringEncoding) {
      print("\(self.isServer ? "Server" : "Client") received message: \(dataString)");
    } else {
      print("\(self.isServer ? "Server" : "Client") received \(evt.data.count) bytes: \(evt.data)");
    }

    if (self.isServer && evt.outSocket != nil) {
      let replyStr = "Bay Area Men Wakes Up To No New Email!";
      let replyData = replyStr.dataUsingEncoding(NSUTF8StringEncoding)!;
      let replySocket = evt.outSocket as! SobtLib.Socket.UDPSocket;

      replySocket.sendData(replyData);
      
      print("Server sent: \(replyStr)");
    }
  }
}
