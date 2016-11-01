//
//  number.swift
//  sobt
//
//  Created by Billy He on 2016-10-09.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.Helper {
  struct Number {
    static func GetRandomNumber() -> UInt32 {
      let num = arc4random() as UInt32;
      return num;
    }
    
    // http://stackoverflow.com/a/26550169
    static func GetRandomNumber() -> UInt64 {
      var rnd : UInt64 = 0
      arc4random_buf(&rnd, sizeofValue(rnd));
      return rnd;
    }
  }
}
