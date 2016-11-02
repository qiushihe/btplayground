//
//  peer-node.swift
//  sobt
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class PeerNode {
  private var peerId: String? = nil;
  private let port: UInt16;
  private var tcpSocket: SobtLib.Socket.TCPSocket? = nil;

  init(id: String, port: UInt16) {
    self.peerId = id;
    self.port = port;
  }

  func start() {
    var tcpSocketOptions = SobtLib.Socket.SocketOptions();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = nil;
    tcpSocketOptions.type = SobtLib.Socket.SocketType.Server;

    self.tcpSocket = SobtLib.Socket.TCPSocket(options: tcpSocketOptions);
    self.tcpSocket!.setListener(self.handleSocketData);

    print("Peer server listening on port \(self.port)...");
  }

  func stop() {
    self.tcpSocket?.closeSocket();
  }

  private func handleSocketData(dataSocket: SobtLib.Socket.TCPSocket) {
    let dataRead = dataSocket.readData();
    print("Peer server received \(dataRead.length) bytes: \(dataRead.bytes)");
  }
}
