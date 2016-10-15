//
//  number.swift
//  sobt
//
//  Created by Billy He on 2016-10-09.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Helper {
  struct Number {
    static func GetRandomNumber() -> UInt32 {
      let num = arc4random() as UInt32;
      return num;
    }
  }
}
