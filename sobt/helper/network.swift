//
//  network.swift
//  sobt
//
//  Created by Billy He on 2016-08-09.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Helper {
  struct Network {
    private static let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian;
    
    static func HostToNetwork(integer: UInt16) -> UInt16 {
      return self.isLittleEndian ? _OSSwapInt16(integer) : integer;
    }
    
    static func HostToNetwork(integer: UInt32) -> UInt32 {
      return self.isLittleEndian ? _OSSwapInt32(integer) : integer;
    }
    
    static func HostToNetwork(integer: UInt64) -> UInt64 {
      return self.isLittleEndian ? _OSSwapInt64(integer) : integer;
    }
    
    static func NetworkToHost(integer: UInt16) -> UInt16 {
      return self.isLittleEndian ? _OSSwapInt16(integer) : integer;
    }
    
    static func NetworkToHost(integer: UInt32) -> UInt32 {
      return self.isLittleEndian ? _OSSwapInt32(integer) : integer;
    }
    
    static func NetworkToHost(integer: UInt64) -> UInt64 {
      return self.isLittleEndian ? _OSSwapInt64(integer) : integer;
    }
    
    static func NetworkToHost(bytes: Array<UInt8>) -> UInt16 {
      var value: UInt16 = 0;
      let data = NSData(bytes: bytes, length: 2);
      data.getBytes(&value, length: 2);
      return self.NetworkToHost(value);
    }
    
    static func NetworkToHost(bytes: Array<UInt8>) -> UInt32 {
      var value: UInt32 = 0;
      let data = NSData(bytes: bytes, length: 4);
      data.getBytes(&value, length: 4);
      return self.NetworkToHost(value);
    }
    
    static func NetworkToHost(bytes: Array<UInt8>) -> UInt64 {
      var value: UInt64 = 0;
      let data = NSData(bytes: bytes, length: 8);
      data.getBytes(&value, length: 8);
      return self.NetworkToHost(value);
    }
  }
}
