//
//  string.swift
//  sobt
//
//  Created by Billy He on 8/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Helper {
  struct String {
    // http://stackoverflow.com/a/36438273
    static func RandomStringWithLength(length: Int) -> Swift.String {
      let charactersString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      let charactersArray : [Character] = Array(charactersString.characters);
      
      var string = "";
      for _ in 0..<length {
        string.append(charactersArray[Int(arc4random()) % charactersArray.count]);
      }
      
      return string;
    }
  }
}
