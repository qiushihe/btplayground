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
    self.tcpSocket = TCPSocket.init(port: self.port, host: self.host);
    
    self.tcpSocket!.setListener({(socket: Int32) in
      if (self.isServer) {
        // Incoming connections will be executed in this queue (in parallel)
        let connectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        // Wait for an incoming connection request
        var connectedAddrInfo = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        var connectedAddrInfoLength = socklen_t(sizeof(sockaddr));
        let requestDescriptor = accept(socket, &connectedAddrInfo, &connectedAddrInfoLength);
        
        let (ipAddress, servicePort) = getSocketHostAndPort(&connectedAddrInfo);
        let message = "Accepted connection from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
        print(message);
        
        // Request processing of the connection request in a different dispatch queue
        dispatch_async(connectionQueue, {
          self.handleSocketData(requestDescriptor, address: &connectedAddrInfo);
        });
      } else {
        self.handleSocketData(socket);
      }
    });

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
  
  private func handleSocketData(socket: Int32, address: UnsafeMutablePointer<sockaddr> = nil) {
    let buffer = [UInt8](count: 4096, repeatedValue: 0);
    
    let bytesRead = recv(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0);
    
    let dataRead = buffer[0..<bytesRead];
    if let dataString = String(bytes: dataRead, encoding: NSUTF8StringEncoding) {
      print("\(self.isServer ? "Server" : "Client") received message: \(dataString)");
    } else {
      print("\(self.isServer ? "Server" : "Client") received \(bytesRead) bytes: \(dataRead)");
    }
    
    if (self.isServer) {
      let replyStr = "Bay Area Men Wakes Up To No New Email!";
      let replyData = replyStr.dataUsingEncoding(NSUTF8StringEncoding)!;
      
      let replySocket = TCPSocket.init(socket: socket, address: address, addressLength: UInt32(sizeofValue(address)));
      replySocket.sendData(replyData);
     
      print("Server sent: \(replyStr)");
    }
  }
}