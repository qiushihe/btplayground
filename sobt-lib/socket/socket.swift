//
//  socket.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.Socket {
  enum SocketType {
    case Client, Server, Reply
  }

  struct SocketOptions {
    var type: SocketType? = nil;

    var port: UInt16? = nil;
    var host: String? = nil;
    var descriptor: Int32? = nil;
    var address: sockaddr? = nil;

    var onReady: ((Socket) -> ())? = nil;
    var onClose: ((Socket) -> ())? = nil;
  }

  struct SocketDataEvent {
    var inSocket: Socket;
    var inIp: String?;
    var inPort: String?;

    var closed: Bool;
    var data: Array<UInt8>;

    var outSocket: Socket?;

    init(outSocket: Socket?, inSocket: Socket, inIp: String?, inPort: String?, data: Array<UInt8>, closed: Bool = false) {
      self.inSocket = inSocket;
      self.outSocket = outSocket;

      self.inIp = inIp;
      self.inPort = inPort;

      self.data = data;
      self.closed = closed;
    }

    init(socket: Socket, inIp: String?, inPort: String?, data: Array<UInt8>, closed: Bool = false) {
      self.init(outSocket: socket, inSocket: socket, inIp: inIp, inPort: inPort, data: data, closed: closed);
    }
  }

  class Socket {
    class func CastSocketAddress(address: UnsafePointer<sockaddr_storage>) -> UnsafePointer<sockaddr> {
      return UnsafePointer<sockaddr>(address);
    }

    class func CastSocketAddress(address: UnsafePointer<sockaddr_in>) -> UnsafePointer<sockaddr> {
      return UnsafePointer<sockaddr>(address);
    }

    class func GetSocketHostAndPort(addr: UnsafePointer<sockaddr>) -> (String?, String?) {
      var host : String?
      var port : String?

      var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0);
      var portBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue: 0);

      let err = getnameinfo(
        addr,
        socklen_t(addr.memory.sa_len),
        &hostBuffer,
        socklen_t(hostBuffer.count),
        &portBuffer,
        socklen_t(portBuffer.count),
        NI_NUMERICHOST | NI_NUMERICSERV
      );

      if err == 0 {
        host = String.fromCString(hostBuffer);
        port = String.fromCString(portBuffer);
      }

      return (host, port);
    }

    class func GetSocketAddress(port: UInt16, host: String?) -> sockaddr_in {
      var address: sockaddr_in = sockaddr_in();
      memset(&address, 0, Int(socklen_t(sizeof(sockaddr_in))));

      if (host == nil) {
        // For server mode there is no `host`.
        address.sin_len = __uint8_t(sizeofValue(address));
        address.sin_family = sa_family_t(AF_INET);
        address.sin_port = SobtLib.Helper.Network.HostToNetwork(port);
        address.sin_addr.s_addr = in_addr_t(0);
      } else {
        // For client mode, we need to resolve the host info to obtain the adress data
        // from the given `host` string, which could be either an domain like "www.apple.ca"
        // or an IP address like "17.178.96.7".
        let cfHost = CFHostCreateWithName(nil, host!).takeRetainedValue();
        CFHostStartInfoResolution(cfHost, .Addresses, nil);

        var success: DarwinBoolean = false;
        // TODO: Handle when address resolution fails.
        let addresses = CFHostGetAddressing(cfHost, &success)?.takeUnretainedValue() as NSArray?;

        // TODO: Loop through to actually find an usable address instead of alaways taking the
        // first entry in the array.
        let data = addresses![0];

        data.getBytes(&address, length: data.length);
        address.sin_port = SobtLib.Helper.Network.HostToNetwork(port);
        // TODO: Assert for valid address.sin_family
      }

      return address;
    }

    let type: SocketType;

    var socketAddress: sockaddr? = nil;
    var socketAddressLength: UInt32 = UInt32(sizeof(sockaddr));
    var descriptor: Int32 = -1;
    var dispatchSource: dispatch_source_t? = nil;

    var onReady: ((Socket) -> ())? = nil;
    var onClose: ((Socket) -> ())? = nil;

    init(options: SocketOptions) {
      self.onReady = options.onReady;
      self.onClose = options.onClose;
      self.type = options.type!;

      if (options.descriptor != nil && options.address != nil) {
        self.descriptor = options.descriptor!;
        self.socketAddress = options.address!;
        self.socketAddressLength = socklen_t(sizeofValue(options.address!));
      } else {
        var address = Socket.GetSocketAddress(options.port == nil ? 0 : options.port!, host: options.host);
        self.socketAddress = Socket.CastSocketAddress(&address).memory;
        self.socketAddressLength = UInt32(sizeofValue(address));
      }
    }

    func getErrorDescription(errorNumber: Int32) -> String {
      return "\(errorNumber) - \(String.fromCString(strerror(errorNumber)))";
    }

    func sendData(data: NSData) {
      var bytesSent = 0;

      if (self.type == SocketType.Server || self.type == SocketType.Reply) {
        bytesSent = sendto(
          self.descriptor,
          data.bytes,
          data.length,
          0,
          &self.socketAddress!,
          self.socketAddressLength
        );
      } else {
        bytesSent = sendto(
          self.descriptor,
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
      close(self.descriptor);
      self.onClose?(self);
    }
  }
}
