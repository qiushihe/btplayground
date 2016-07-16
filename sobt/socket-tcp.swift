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

class TCPSocket {
  private let port: UInt16;
  private let host: String?
  private let isServer: Bool;
  
  private var socketAddress: UnsafePointer<sockaddr> = nil;
  private var socketAddressLength: UInt32 = UInt32(sizeof(sockaddr));
  private var tcpSocket: Int32 = -1;
  private var dispatchSource: dispatch_source_t? = nil;

  init(port: UInt16, host: String? = nil) {
    self.port = port;
    self.host = host;
    self.isServer = self.host == nil;
    
    self.setupAddress();
    self.setupSocket();
  }
  
  init(socket: Int32, address: UnsafePointer<sockaddr>, addressLength: UInt32) {
    self.port = 0;
    self.host = nil;
    self.isServer = true;
    
    self.tcpSocket = socket;
    self.socketAddress = address;
    self.socketAddressLength = addressLength;
  }
  
  func setListener(listener: (Int32) -> ()) {
    // Create a GCD thread that can listen for network events.
    self.dispatchSource = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_READ,
      UInt(self.tcpSocket),
      0,
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );
    
    guard self.dispatchSource != nil else {
      close(self.tcpSocket);
      assertionFailure("Can not create dispath source: \(getErrorDescription(errno))");
      return;
    };
    
    // Register the event handler for cancellation.
    dispatch_source_set_cancel_handler(dispatchSource!) {
      close(self.tcpSocket);
      assertionFailure("Event handler cancelled: \(getErrorDescription(errno))");
    };
    
    // Register the event handler for incoming packets.
    dispatch_source_set_event_handler(dispatchSource!) {
      guard let source = self.dispatchSource else { return };
      let inSocket = Int32(dispatch_source_get_handle(source));
      listener(inSocket);
    };
    
    // Start the listener thread
    dispatch_resume(self.dispatchSource!);
  }

  func sendData(data: NSData) {
    let bytesSent = sendto(
      self.tcpSocket,
      data.bytes, data.length,
      0,
      self.isServer ? self.socketAddress : nil,
      self.isServer ? self.socketAddressLength : 0
    );
    
    guard bytesSent >= 0  else {
      return assertionFailure("Could not send data: \(getErrorDescription(errno))");
    }
  }
  
  func closeSocket() {
    close(self.tcpSocket);
  }
  
  func setupAddress() {
    var address: sockaddr_in = sockaddr_in();
    memset(&address, 0, Int(socklen_t(sizeof(sockaddr_in))));

    if (self.isServer) {
      // For server mode there is no `host`.
      address.sin_len = __uint8_t(sizeofValue(address));
      address.sin_family = sa_family_t(AF_INET);
      address.sin_port = htons(port);
      address.sin_addr.s_addr = INADDR_ANY;
    } else {
      // For client mode, we need to resolve the host info to obtain the adress data
      // from the given `host` string, which could be either an domain like "www.apple.ca"
      // or an IP address like "17.178.96.7".
      let cfHost = CFHostCreateWithName(nil, self.host!).takeRetainedValue();
      CFHostStartInfoResolution(cfHost, .Addresses, nil);
      
      var success: DarwinBoolean = false;
      // TODO: Handle when address resolution fails.
      let addresses = CFHostGetAddressing(cfHost, &success)?.takeUnretainedValue() as NSArray?;
      
      // TODO: Loop through to actually find an usable address instead of alaways taking the
      // first entry in the array.
      let data = addresses![0];
      
      data.getBytes(&address, length: data.length);
      address.sin_port = htons(port);
      // TODO: Assert for valid address.sin_family
    }

    self.socketAddress = castSocketAddress(&address);
    self.socketAddressLength = UInt32(sizeofValue(address));
  }
  
  func setupSocket() {
    self.tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    
    guard self.tcpSocket >= 0 else {
      return assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
    }
    
    if (self.isServer) {
      // Server mode socket requires binding and listening
      let bindErr = bind(
        self.tcpSocket,
        self.socketAddress,
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
        self.socketAddress,
        self.socketAddressLength
      );
      
      guard connectErr == 0 else {
        return assertionFailure("Could not connect: \(getErrorDescription(errno))");
      }
    }
  }
}