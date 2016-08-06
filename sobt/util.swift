//
//  util.swift
//  sobt
//
//  Created by Billy He on 2016-08-05.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt {
  class Util {
    class func NSDataToArray(data: NSData) -> Array<UInt8> {
      let size = sizeof(UInt8);
      let count = data.length / size;
      
      var _bytes = Array<UInt8>.init(count: count, repeatedValue: 0);
      data.getBytes(&_bytes, length:count * size);
      
      return _bytes;
    }
  }
}