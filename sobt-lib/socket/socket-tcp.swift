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

extension SobtLib.Socket {
  class TCPSocket: Socket {
    override init(options: SocketOptions) {
      super.init(options: options);

      if (options.descriptor == nil || options.address == nil) {
        self.setupSocket(self.type == SocketType.Server || self.type == SocketType.Reply);
      }
    }

    func setListener(listener: (SocketDataEvent) -> ()) {
      // Create a GCD thread that can listen for network events.
      self.dispatchSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_READ,
        UInt(self.descriptor),
        0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
      );

      guard self.dispatchSource != nil else {
        close(self.descriptor);
        assertionFailure("Can not create dispath source: \(self.getErrorDescription(errno))");
        return;
      };

      // Register the event handler for cancellation.
      dispatch_source_set_cancel_handler(dispatchSource!) {
        close(self.descriptor);
        assertionFailure("Event handler cancelled: \(self.getErrorDescription(errno))");
      };

      // Register the event handler for incoming packets.
      dispatch_source_set_event_handler(dispatchSource!) {
        guard let source = self.dispatchSource else { return };
        let inSocket = Int32(dispatch_source_get_handle(source));

        if (self.type == SocketType.Server) {
          // Accept the incoming connection
          var requestAddress = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
          var requestAddressLength = socklen_t(sizeof(sockaddr));
          let requestDescriptor = accept(inSocket, &requestAddress, &requestAddressLength);

          let (ipAddress, servicePort) = Socket.GetSocketHostAndPort(&requestAddress);
          let message = "Accepted connection from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
          print(message);

          // Create a reply socket for the incoming connection
          var requestSocketOptions = SocketOptions();
          requestSocketOptions.descriptor = requestDescriptor;
          requestSocketOptions.address = requestAddress;
          requestSocketOptions.type = SocketType.Reply;

          // Set listener on the reply socket
          let requestSocket = TCPSocket(options: requestSocketOptions);
          requestSocket.setListener(listener);
        } else {
          // TODO: Continue to read (i.e. in a loop) until there is nothing left to read
          let buffer = [UInt8](count: 4096, repeatedValue: 0);
          let bytesRead = recv(self.descriptor, UnsafeMutablePointer<Void>(buffer), buffer.count, 0);
          let socketClosed = bytesRead <= 0;

          let dataEvent = SocketDataEvent(
            socket: self,
            inIp: nil,
            inPort: nil,
            data: socketClosed ? Array<UInt8> () : Array<UInt8>(buffer[0..<bytesRead]),
            closed: socketClosed
          );

          listener(dataEvent);

          if (socketClosed) {
            self.closeSocket();
          }
        }
      };

      // Start the listener thread
      dispatch_resume(self.dispatchSource!);
    }

    private func setupSocket(bindAndListen: Bool) {
      self.descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

      guard self.descriptor >= 0 else {
        return assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
      }

      if (bindAndListen) {
        // Server mode socket requires binding and listening
        let bindErr = bind(
          self.descriptor,
          &self.socketAddress!,
          self.socketAddressLength
        );

        guard bindErr == 0 else {
          return assertionFailure("Could not bind socket: \(getErrorDescription(errno))!");
        }

        let connectionBufferCount: Int32 = 10; // TODO: Move this to a variable
        let listenErr = listen(self.descriptor, connectionBufferCount);

        guard listenErr == 0 else {
          return assertionFailure("Could not listen on socket: \(getErrorDescription(errno))!");
        }
      } else {
        // Client mode socket requires connection
        let connectErr = connect(
          self.descriptor,
          &self.socketAddress!,
          self.socketAddressLength
        );
        
        guard connectErr == 0 else {
          return assertionFailure("Could not connect: \(getErrorDescription(errno))");
        }
      }
      
      self.onReady?(self);
    }
  }
}
