//
//  socket.swift
//  sobt
//
//  Created by Billy He on 2016-07-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

// Polyfill for some missing C macros and constants in Swift
// https://gist.github.com/NeoTeo/b6195efb779d925fd7b8

let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian;
let htons = isLittleEndian ? _OSSwapInt16 : { $0 };
let htonl = isLittleEndian ? _OSSwapInt32 : { $0 };
let htonll = isLittleEndian ? _OSSwapInt64 : { $0 };
let ntohs = isLittleEndian ? _OSSwapInt16 : { $0 };
let ntohl = isLittleEndian ? _OSSwapInt32 : { $0 };
let ntohll = isLittleEndian ? _OSSwapInt64 : { $0 };

let INADDR_ANY = in_addr_t(0);

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
  
  func getErrorDescription(errorNumber: Int32) -> String {
    return "\(errorNumber) - \(String.fromCString(strerror(errorNumber)))";
  }
}
