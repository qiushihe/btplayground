//
//  echo-tcp.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class TCPEcho: SocketEchoer {
  private let port: UInt16;
  private let host: String?;
  private var isServer: Bool;
  
  private var tcpSocket: SobtLib.Socket.TCPSocket? = nil;
  
  init(port: UInt16, host: String? = nil) {
    self.port = port;
    self.host = host;
    self.isServer = host == nil;
  }

  func start() {
    var tcpSocketOptions = SobtLib.Socket.SocketOptions();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = self.host;
    tcpSocketOptions.type = self.host == nil ? SobtLib.Socket.SocketType.Server : SobtLib.Socket.SocketType.Client;
    
    self.tcpSocket = SobtLib.Socket.TCPSocket(options: tcpSocketOptions);
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
    
    if (self.isServer) {
      let replyStr = "Bay Area Men Wakes Up To No New Email!";
      let replySocket = evt.outSocket as! SobtLib.Socket.TCPSocket;
      replySocket.sendData(replyStr.dataUsingEncoding(NSUTF8StringEncoding)!);
      print("Server sent: \(replyStr)");
    }
  }
}
