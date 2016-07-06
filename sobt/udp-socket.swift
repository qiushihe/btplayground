//
//  udp-socket.swift
//  sobt
//
//  Created by Billy He on 7/5/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

// https://developer.apple.com/library/mac/samplecode/UDPEcho/Introduction/Intro.html

// Workaround for Swift not having access to the htons, htonl, and other C macros.
// This is equivalent to casting the value to the desired bitsize and then swapping the endian'ness
// of the result if the host platform is little endian. In the case of Mac OS X on Intel it is.
// So htons casts to UInt16 and then turns into big endian (which is network byte order)
// https://gist.github.com/NeoTeo/b6195efb779d925fd7b8
let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian;
let htons = isLittleEndian ? _OSSwapInt16 : { $0 };
let htonl = isLittleEndian ? _OSSwapInt32 : { $0 };
let htonll = isLittleEndian ? _OSSwapInt64 : { $0 };
let ntohs = isLittleEndian ? _OSSwapInt16 : { $0 };
let ntohl = isLittleEndian ? _OSSwapInt32 : { $0 };
let ntohll = isLittleEndian ? _OSSwapInt64 : { $0 };

let INADDR_ANY = in_addr_t(0);

func getErrorDescription(errorNumber: Int32) -> String {
  return "\(errorNumber) - \(String.fromCString(strerror(errorNumber)))";
}

func getSocketFromStorage(storage: UnsafeMutablePointer<sockaddr_storage>) -> UnsafeMutablePointer<sockaddr> {
  return UnsafeMutablePointer<sockaddr>(storage);
}

func getSocketAddress(ip: String? = nil, port: UInt16) -> sockaddr_in {
  var addr: sockaddr_in = sockaddr_in();
  memset(&addr, 0, Int(socklen_t(sizeof(sockaddr_in))));
  
  if (ip == nil) {
    addr.sin_len = __uint8_t(sizeofValue(addr));
    addr.sin_family = sa_family_t(AF_INET);
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;
  } else {
    let host = CFHostCreateWithName(nil, ip!).takeRetainedValue();
    CFHostStartInfoResolution(host, .Addresses, nil);
    
    var success: DarwinBoolean = false;
    let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?;
    let data = addresses![0];
    
    data.getBytes(&addr, length: data.length);
    addr.sin_port = htons(port);
  }

  return addr;
}

func getSocket(inout addr: sockaddr_in) -> Int32 {
  let sock: Int32 = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  
  guard sock >= 0 else {
    print("Error: Could not create socket: \(getErrorDescription(errno))!");
    return errno;
  }

  if (addr.sin_addr.s_addr == 0) {
    let bindSuccess = withUnsafePointer(&addr) {
      bind(sock, UnsafePointer($0), socklen_t(sizeofValue(addr)));
    };
    
    guard bindSuccess == 0 else {
      print("Error: Could not bind socket: \(getErrorDescription(errno))!");
      return errno;
    }
  } else {
    let connectSuccess = withUnsafePointer(&addr) {
      connect(sock, UnsafePointer($0), socklen_t(sizeofValue(addr)));
    };
    
    guard connectSuccess == 0 else {
      print("Error: Could not connect: \(getErrorDescription(errno))!");
      return errno;
    }
  }
  
  var flags: Int32;
  flags = fcntl(sock, F_GETFL);

  guard fcntl(sock, F_SETFL, flags | O_NONBLOCK) == 0 else {
    print("Error: Could not set socket flag!");
    return errno;
  }

  return sock;
}
