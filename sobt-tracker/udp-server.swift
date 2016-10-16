//
//  udp-server.swift
//  sobt
//
//  Created by Billy He on 2016-10-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum UDPServerError: ErrorType {
  case InvalidArguments
}

class UDPServer {
  private let port: UInt16;
  private var udpSocket: UDPSocket? = nil;

  init(port: UInt16) {
    self.port = port;
  }

  func start() {
    self.udpSocket = UDPSocket(port: self.port);
    
    self.udpSocket!.setListener({(socket: Int32) in
      self.handleSocketData(socket);
    });

    print("Server listening on port \(self.port)...");
  }
  
  func stop() {
    self.udpSocket?.closeSocket();
  }
  
  private func handleSocketData(socket: Int32) {
    var inAddress = sockaddr_storage();
    var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
    let buffer = [UInt8](count: UDPSocket.MAX_PACKET_SIZE, repeatedValue: 0);

    let bytesRead = withUnsafeMutablePointer(&inAddress) {
      recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
    };
    
    let (ipAddress, servicePort) = Socket.GetSocketHostAndPort(Socket.CastSocketAddress(&inAddress));
    let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
    print(message);
    
    let dataRead = buffer[0..<bytesRead];
    print("Server received \(bytesRead) bytes: \(dataRead)");
  }
}
