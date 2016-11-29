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

extension SobtLib.Socket {
  class UDPSocket: Socket {
    // 65535 - 8 byte UDP header − 20 byte IP header
    static let MAX_PACKET_SIZE = 65507;

    private let type: SocketType;

    private var socketAddress: sockaddr? = nil;
    private var socketAddressLength: UInt32 = UInt32(sizeof(sockaddr));
    private var udpSocket: Int32 = -1;
    private var dispatchSource: dispatch_source_t? = nil;

    private var onReady: ((Socket) -> ())? = nil;
    private var onClose: ((Socket) -> ())? = nil;

    init(options: SocketOptions) {
      self.onReady = options.onReady;
      self.onClose = options.onClose;
      self.type = options.type!;

      if (options.descriptor != nil && options.address != nil) {
        self.udpSocket = options.descriptor!;
        self.socketAddress = options.address!;
        self.socketAddressLength = socklen_t(sizeofValue(options.address!));

        super.init();
      } else {
        super.init();

        var address = Socket.GetSocketAddress(options.port == nil ? 0 : options.port!, host: options.host);
        self.socketAddress = Socket.CastSocketAddress(&address).memory;
        self.socketAddressLength = UInt32(sizeofValue(address));

        self.setupSocket(self.type == SocketType.Server);
      }
    }

    func setListener(listener: (SocketDataEvent) -> ()) {
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

        var inAddress = sockaddr_storage();
        var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
        let readBuffer = [UInt8](count: UDPSocket.MAX_PACKET_SIZE, repeatedValue: 0);

        let bytesRead = withUnsafeMutablePointer(&inAddress) {
          recvfrom(
            inSocket,
            UnsafeMutablePointer<Void>(readBuffer),
            readBuffer.count,
            0,
            UnsafeMutablePointer($0),
            &inAddressLength
          );
        };

        let (ipAddress, servicePort) = SobtLib.Socket.Socket.GetSocketHostAndPort(SobtLib.Socket.Socket.CastSocketAddress(&inAddress));
        let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
        print(message);

        // Create a reply socket for the incoming connection
        var replySocketOptions = SocketOptions();
        replySocketOptions.descriptor = inSocket;
        replySocketOptions.address = Socket.CastSocketAddress(&inAddress).memory;
        replySocketOptions.type = SocketType.Reply;

        let replySocket: UDPSocket? = self.type == SocketType.Server
          ? UDPSocket(options: replySocketOptions)
          : nil;

        let dataEvent = SocketDataEvent(
          inSocket: self,
          inIp: ipAddress,
          inPort: servicePort,
          data: Array<UInt8>(readBuffer[0..<bytesRead]),
          outSocket: replySocket
        );

        listener(dataEvent);
      };

      // Start the listener thread
      dispatch_resume(self.dispatchSource!);
    }

    func sendData(data: NSData) {
      var bytesSent = 0;

      if (self.type == SocketType.Server || self.type == SocketType.Reply) {
        bytesSent = sendto(
          self.udpSocket,
          data.bytes,
          data.length,
          0,
          &self.socketAddress!,
          self.socketAddressLength
        );
      } else {
        bytesSent = sendto(
          self.udpSocket,
          data.bytes,
          data.length,
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
      close(self.udpSocket);
    }

    private func setupSocket(bindAndListen: Bool) {
      self.udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

      guard self.udpSocket >= 0 else {
        return assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
      }

      if (bindAndListen) {
        // Server mode socket requires binding
        let bindErr = bind(
          self.udpSocket,
          &self.socketAddress!,
          self.socketAddressLength
        );

        guard bindErr == 0 else {
          return assertionFailure("Could not bind socket: \(getErrorDescription(errno))!");
        }
      } else {
        // Client mode socket requires connection
        let connectErr = connect(
          self.udpSocket,
          &self.socketAddress!,
          self.socketAddressLength
        );
        
        guard connectErr == 0 else {
          return assertionFailure("Could not connect: \(getErrorDescription(errno))");
        }
      }
    }
  }
}
