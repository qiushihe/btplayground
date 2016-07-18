//
//  socket-tcp.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

// Base on:
// * http://swiftrien.blogspot.ca/2015/10/socket-programming-in-swift-part-1.html
// * https://github.com/Swiftrien/SwifterSockets

class TCPSocket: Socket {
  private let type: SocketType;
  
  private var socketAddress: sockaddr? = nil;
  private var socketAddressLength: UInt32 = UInt32(sizeof(sockaddr));
  private var tcpSocket: Int32 = -1;
  private var dispatchSource: dispatch_source_t? = nil;
  
  private var onReady: ((Socket) -> ())? = nil;
  private var onClose: ((Socket) -> ())? = nil;

  init(options: SocketOptions) {
    self.onReady = options.onReady;
    self.onClose = options.onClose;
    self.type = options.type!;

    if (options.descriptor != nil && options.address != nil) {
      self.tcpSocket = options.descriptor!;
      self.socketAddress = options.address!;
      self.socketAddressLength = socklen_t(sizeofValue(options.address!));
      
      super.init();
    } else {
      super.init();
      
      var address = Socket.GetSocketAddress(options.port == nil ? 0 : options.port!, host: options.host);
      self.socketAddress = Socket.CastSocketAddress(&address).memory;
      self.socketAddressLength = UInt32(sizeofValue(address));
      
      self.setupSocket(options.host == nil);
    }
  }
  
  func setListener(listener: (TCPSocket) -> ()) {
    // Create a GCD thread that can listen for network events.
    self.dispatchSource = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_READ,
      UInt(self.tcpSocket),
      0,
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );
    
    guard self.dispatchSource != nil else {
      close(self.tcpSocket);
      assertionFailure("Can not create dispath source: \(self.getErrorDescription(errno))");
      return;
    };
    
    // Register the event handler for cancellation.
    dispatch_source_set_cancel_handler(dispatchSource!) {
      close(self.tcpSocket);
      assertionFailure("Event handler cancelled: \(self.getErrorDescription(errno))");
    };
    
    // Register the event handler for incoming packets.
    dispatch_source_set_event_handler(dispatchSource!) {
      guard let source = self.dispatchSource else { return };
      let inSocket = Int32(dispatch_source_get_handle(source));
      
      if (self.type == SocketType.Server) {
        // Wait for an incoming connection request
        var requestAddress = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        var requestAddressLength = socklen_t(sizeof(sockaddr));
        let requestDescriptor = accept(inSocket, &requestAddress, &requestAddressLength);
        
        let (ipAddress, servicePort) = Socket.GetSocketHostAndPort(&requestAddress);
        let message = "Accepted connection from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
        print(message);
        
        // Set data listener for individual connections
        var requestSocketOptions = SocketOptions.init();
        requestSocketOptions.descriptor = requestDescriptor;
        requestSocketOptions.address = requestAddress;
        requestSocketOptions.type = SocketType.Reply;
        
        // Set listener on the request socket
        let requestSocket = TCPSocket.init(options: requestSocketOptions);
        requestSocket.setListener(listener);
      } else {
        listener(self);
      }
    };
    
    // Start the listener thread
    dispatch_resume(self.dispatchSource!);
  }
  
  func readData() -> NSData {
    let buffer = [UInt8](count: 4096, repeatedValue: 0);
    
    let bytesRead = recv(self.tcpSocket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0);
    
    if (bytesRead <= 0) {
      print("TODO: Socket closed!");
    }
    
    let dataRead = Array<UInt8>.init(buffer[0..<bytesRead]);
    
    return NSData.init(bytes: dataRead, length: bytesRead);
  }

  func sendData(data: NSData) {
    var bytesSent = 0;
    
    if (self.type == SocketType.Server || self.type == SocketType.Reply) {
      bytesSent = sendto(
        self.tcpSocket,
        data.bytes, data.length,
        0,
        &self.socketAddress!,
        self.socketAddressLength
      );
    } else {
      bytesSent = sendto(
        self.tcpSocket,
        data.bytes, data.length,
        0,
        nil,
        0
      );
    }
    
    guard bytesSent >= 0  else {
      return assertionFailure("Could not send data: \(getErrorDescription(errno))");
    }
  }
  
  func closeSocket() {
    close(self.tcpSocket);
    
    if (self.onClose != nil) {
      self.onClose!(self);
    }
  }
  
  private func setupSocket(bindAndListen: Bool) {
    self.tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    
    guard self.tcpSocket >= 0 else {
      return assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
    }

    if (bindAndListen) {
      // Server mode socket requires binding and listening
      let bindErr = bind(
        self.tcpSocket,
        &self.socketAddress!,
        self.socketAddressLength
      );
      
      guard bindErr == 0 else {
        return assertionFailure("Could not bind socket: \(getErrorDescription(errno))!");
      }
      
      let connectionBufferCount: Int32 = 10; // TODO: Move this to a variable
      let listenErr = listen(tcpSocket, connectionBufferCount);

      guard listenErr == 0 else {
        return assertionFailure("Could not listen on socket: \(getErrorDescription(errno))!");
      }
    } else {
      // Client mode socket requires connection
      let connectErr = connect(
        self.tcpSocket,
        &self.socketAddress!,
        self.socketAddressLength
      );
      
      guard connectErr == 0 else {
        return assertionFailure("Could not connect: \(getErrorDescription(errno))");
      }
    }
    
    if (self.onReady != nil) {
      self.onReady!(self);
    }
  }
}