//
//  socket.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Socket {
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
        address.sin_port = Sobt.Helper.Network.HostToNetwork(port);
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
        address.sin_port = Sobt.Helper.Network.HostToNetwork(port);
        // TODO: Assert for valid address.sin_family
      }

      return address;
    }
    
    func getErrorDescription(errorNumber: Int32) -> String {
      return "\(errorNumber) - \(String.fromCString(strerror(errorNumber)))";
    }
  }
}
