//
//  crypto.swift
//  sobt
//
//  Created by Billy He on 2016-08-05.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.Helper {
  struct Crypto {
    static func SHA1(data: NSData) -> Array<UInt8> {
      var digest = Array<UInt8>(count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0);
      CC_SHA1(data.bytes, CC_LONG(data.length), &digest);
      return digest;
    }

    static func SHA1(data: NSData) -> Swift.String {
      let digest: Array<UInt8> = self.SHA1(data);
      let output = NSMutableString(capacity: Int(CC_SHA1_DIGEST_LENGTH));

      for byte in digest {
        output.appendFormat("%02x", byte);
      }
      
      return output as Swift.String;
    }
  }
}
