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
    self.udpSocket = SobtLib.Socket.UDPSocket(port: self.port, host: self.host);

    self.udpSocket!.setListener({(socket: Int32) in
      self.handleSocketData(socket);
    });
    
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
  
  private func handleSocketData(socket: Int32) {
    var inAddress = sockaddr_storage();
    var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
    let buffer = [UInt8](count: 4096, repeatedValue: 0);
    
    let bytesRead = withUnsafeMutablePointer(&inAddress) {
      recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
    };
    
    let (ipAddress, servicePort) = SobtLib.Socket.Socket.GetSocketHostAndPort(SobtLib.Socket.Socket.CastSocketAddress(&inAddress));
    let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
    print(message);
    
    let dataRead = buffer[0..<bytesRead];
    if let dataString = String(bytes: dataRead, encoding: NSUTF8StringEncoding) {
      print("\(self.isServer ? "Server" : "Client") received message: \(dataString)");
    } else {
      print("\(self.isServer ? "Server" : "Client") received \(bytesRead) bytes: \(dataRead)");
    }
    
    if (self.isServer) {
      let replyStr = "Bay Area Men Wakes Up To No New Email!";
      let replyData = replyStr.dataUsingEncoding(NSUTF8StringEncoding)!;
      
      let replySocket = SobtLib.Socket.UDPSocket(socket: socket, address: SobtLib.Socket.Socket.CastSocketAddress(&inAddress), addressLength: inAddressLength);
      replySocket.sendData(replyData);
      
      print("Server sent: \(replyStr)");
    }
  }
}
