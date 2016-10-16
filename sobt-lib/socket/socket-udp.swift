//
//  udp-socket.swift
//  sobt
//
//  Created by Billy He on 7/5/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

// Base on:
// * https://gist.github.com/NeoTeo/b6195efb779d925fd7b8
// * https://developer.apple.com/library/mac/samplecode/UDPEcho/Introduction/Intro.html

class UDPSocket: Socket {
  // 65535 - 8 byte UDP header − 20 byte IP header
  static let MAX_PACKET_SIZE = 65507;
  
  private let port: UInt16;
  private let host: String?
  private let isServer: Bool;
  
  private var socketAddress: UnsafePointer<sockaddr> = nil;
  private var socketAddressLength: UInt32 = UInt32(sizeof(sockaddr));
  private var udpSocket: Int32 = -1;
  private var dispatchSource: dispatch_source_t? = nil;
  
  init(port: UInt16, host: String? = nil) {
    self.port = port;
    self.host = host;
    self.isServer = self.host == nil;
    
    super.init();
    
    self.setupAddress();
    self.setupSocket();
  }
  
  init(socket: Int32, address: UnsafePointer<sockaddr>, addressLength: UInt32) {
    self.port = 0;
    self.host = nil;
    self.isServer = true;
    
    self.udpSocket = socket;
    self.socketAddress = address;
    self.socketAddressLength = addressLength;
  }
  
  func setListener(listener: (Int32) -> ()) {
    // Create a GCD thread that can listen for network events.
    self.dispatchSource = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_READ,
      UInt(self.udpSocket),
      0,
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    );
    
    guard self.dispatchSource != nil else {
      close(self.udpSocket);
      assertionFailure("Can not create dispath source: \(self.getErrorDescription(errno))");
      return;
    };
    
    // Register the event handler for cancellation.
    dispatch_source_set_cancel_handler(self.dispatchSource!) {
      close(self.udpSocket);
      assertionFailure("Event handler cancelled: \(self.getErrorDescription(errno))");
    };
    
    // Register the event handler for incoming packets.
    dispatch_source_set_event_handler(self.dispatchSource!) {
      guard let source = self.dispatchSource else { return };
      let inSocket = Int32(dispatch_source_get_handle(source));
      listener(inSocket);
    };
    
    // Start the listener thread
    dispatch_resume(self.dispatchSource!);
  }
  
  func setListener(listener: (Array<UInt8>) -> ()) {
    self.setListener({(socket: Int32) in
      var inAddress = sockaddr_storage();
      var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
      let readBuffer = [UInt8](count: UDPSocket.MAX_PACKET_SIZE, repeatedValue: 0);
      
      let bytesRead = withUnsafeMutablePointer(&inAddress) {
        recvfrom(
          socket,
          UnsafeMutablePointer<Void>(readBuffer),
          readBuffer.count,
          0,
          UnsafeMutablePointer($0),
          &inAddressLength
        );
      };

      listener(Array<UInt8>(readBuffer[0..<bytesRead]));
    });
  }
  
  func sendData(data: NSData) {
    let bytesSent = sendto(
      self.udpSocket,
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
    close(self.udpSocket);
  }

  private func setupAddress() {
    var address: sockaddr_in = sockaddr_in();
    memset(&address, 0, Int(socklen_t(sizeof(sockaddr_in))));
    
    if (self.isServer) {
      // For server mode there is no `host`.
      address.sin_len = __uint8_t(sizeofValue(address));
      address.sin_family = sa_family_t(AF_INET);
      address.sin_port = Sobt.Helper.Network.HostToNetwork(self.port);
      address.sin_addr.s_addr = in_addr_t(0);
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
      address.sin_port = Sobt.Helper.Network.HostToNetwork(self.port);
      // TODO: Assert for valid address.sin_family
    }
    
    self.socketAddress = Socket.CastSocketAddress(&address);
    self.socketAddressLength = UInt32(sizeofValue(address));
  }
  
  private func setupSocket() {
    self.udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    
    guard self.udpSocket >= 0 else {
      return assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
    }
    
    if (self.isServer) {
      // Server mode socket requires binding
      let bindErr = bind(
        self.udpSocket,
        self.socketAddress,
        self.socketAddressLength
      );
      
      guard bindErr == 0 else {
        return assertionFailure("Could not bind socket: \(getErrorDescription(errno))!");
      }
    } else {
      // Client mode socket requires connection
      let connectErr = connect(
        self.udpSocket,
        self.socketAddress,
        self.socketAddressLength
      );
      
      guard connectErr == 0 else {
        return assertionFailure("Could not connect: \(getErrorDescription(errno))");
      }
    }
  }
}