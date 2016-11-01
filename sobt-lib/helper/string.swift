//
//  string.swift
//  sobt
//
//  Created by Billy He on 8/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.Helper {
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
    
    // http://stackoverflow.com/a/40040472
    static func MatchingStrings(string: Swift.String, regex: Swift.String) -> Array<Array<Swift.String>> {
      guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return []; }
      
      let nsString = string as NSString;
      let results  = regex.matchesInString(string, options: [], range: NSMakeRange(0, nsString.length));
      
      return results.map {(result) in
        return (0..<result.numberOfRanges).map {
          return result.rangeAtIndex($0).location != NSNotFound
            ? nsString.substringWithRange(result.rangeAtIndex($0))
            : "";
        };
      }
    }
    
    // http://stackoverflow.com/a/26502285
    static func HexStringToNSData(string: Swift.String) -> NSData? {
      let data = NSMutableData(capacity: string.characters.count / 2);
      let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .CaseInsensitive);
      
      regex.enumerateMatchesInString(string, options: [], range: NSMakeRange(0, string.characters.count)) {(match, flags, stop) in
        let byteString = (string as NSString).substringWithRange(match!.range);
        var num = UInt8(byteString, radix: 16);
        data?.appendBytes(&num, length: 1);
      }
      
      return data
    }
    
    // http://stackoverflow.com/a/26502285
    static func NSDataToHexString(data: NSData) -> Swift.String {
      var string = "";
      var byte: UInt8 = 0;
      
      for index in 0 ..< data.length {
        data.getBytes(&byte, range: NSMakeRange(index, 1));
        string += Swift.String(format: "%02x", byte);
      }
      
      return string
    }
  }
}
