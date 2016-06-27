//
//  main.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Swift;
import Foundation;

let BYTE_COLON: UInt8 = 58;
let BYTE_LC_E: UInt8 = 101;

let BYTE_ZERO: UInt8 = 48;
let BYTE_NINE: UInt8 = 57;
let BYTE_LC_I: UInt8 = 105;
let BYTE_LC_L: UInt8 = 108;
let BYTE_LC_D: UInt8 = 100;

extension NSData {
  func getBytes() -> Array<UInt8> {
    let size = sizeof(UInt8);
    let count = self.length / size;
    var bytes = Array<UInt8>.init(count: count, repeatedValue: 0);
    self.getBytes(&bytes, length:count * size);
    return bytes;
  }
}

enum BEncoded {
  case String(Swift.String)
  case Integer(Swift.Int)
  case List(Swift.Array<BEncoded>)
  case Dictionary(Swift.Dictionary<Swift.String, BEncoded>)
  
  var type: Swift.String {
    switch(self) {
    case .String: return "string";
    case .Integer: return "integer";
    case .List: return "list";
    case .Dictionary: return "dictionary";
    }
  }
  
  var value: Any {
    switch(self) {
    case .String(let stringValue): return stringValue;
    case .Integer(let integerValue): return integerValue;
    case .List(let listValue): return listValue;
    case .Dictionary(let dictionaryValue): return dictionaryValue;
    }
  }
  
  func pp(level: Int = 0, noIndent: Bool = false) {
    switch(self) {
    case .String(let stringValue):
      let indents = Swift.String.init(count: level * 2, repeatedValue: Character(" "));
      let ppString = "\"" + stringValue + "\"";
      print(noIndent ? ppString : indents + ppString);
      break;
    case .Integer(let integerValue):
      let indents = Swift.String.init(count: level * 2, repeatedValue: Character(" "));
      let ppString = Swift.String.init(integerValue);
      print(noIndent ? ppString : indents + ppString);
      break;
    case .List(let listValue):
      let rootIndents = Swift.String.init(count: level * 2, repeatedValue: Character(" "));
      print(noIndent ? "[" : rootIndents + "[");
      for value in listValue {
        value.pp(level + 1);
      }
      print(rootIndents + "]");
      break;
    case .Dictionary(let dictionaryValue):
      let rootIndents = Swift.String.init(count: level * 2, repeatedValue: Character(" "));
      let valueIndents = Swift.String.init(count:(level + 1) * 2, repeatedValue: Character(" "));
      print(noIndent ? "{" : rootIndents + "{");
      for (key, value) in dictionaryValue {
        print(valueIndents + "\"" + key + "\": ", terminator: "");
        value.pp(level + 1, noIndent: true);
      }
      print(rootIndents + "}");
      break;
    }
  }
}

func getString(fromByte byte: UInt8) -> String {
  return String.init(Character(UnicodeScalar(byte)));
}

func getLength(ofString string: String) -> Int {
  return string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding);
}

func readString(fromBytes bytes: Array<UInt8>, startAt start: Int, stopBefore stopByte: UInt8) -> String {
  var str = "";
  var position = start;
  
  while true {
    if bytes[position] == stopByte {
      break;
    }
    str += getString(fromByte: bytes[position]);
    position += 1;
  }
  
  return str;
}

func readString(fromBytes bytes: Array<UInt8>, startAt start: Int, stopAfterLength length: Int) -> String {
  return String.init(bytes: bytes[start...(start + length - 1)], encoding: NSUTF8StringEncoding)!;
}

func decodeString(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start;
  
  let lengthStr = readString(fromBytes: bytes, startAt: position, stopBefore: BYTE_COLON);
  position += getLength(ofString: lengthStr) + 1;
  
  let length = Int.init(lengthStr)!;
  let string = readString(fromBytes: bytes, startAt: position, stopAfterLength: length);
  position += getLength(ofString: string);
  
  return BEncoded.String(string);
}

func decodeInteger(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  let integerStr = readString(fromBytes: bytes, startAt: position, stopBefore: BYTE_LC_E);
  let integer = Int.init(integerStr)!;
  position += getLength(ofString: integerStr) + 1;
  
  return BEncoded.Integer(integer);
}

func decodeList(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  var list: Array<BEncoded> = [];
  
  while true {
    if bytes[position] == BYTE_LC_E {
      break;
    }
    
    let decoded: BEncoded = decode(bytes, startIndex: position, nextIndex: &position);
    list.append(decoded);
  }
  
  position += 1;
  
  return BEncoded.List(list);
}

func decodeDictionary(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  var dictionary: Dictionary<String, BEncoded> = [:];
  
  while true {
    if bytes[position] == BYTE_LC_E {
      break;
    }
    
    let key = decode(bytes, startIndex: position, nextIndex: &position);
    
    if key.value as! String == "pieces" {
      dictionary[key.value as! String] = BEncoded.String("TODO: Read sha hash");
      position += 3;
      position += 40;
    } else {
      let value = decode(bytes, startIndex: position, nextIndex: &position);
      dictionary[key.value as! String] = value;
    }
  }
  
  position += 1;
  
  return BEncoded.Dictionary(dictionary);
}

func decode(bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  let firstByte = bytes[start];
  
  if firstByte >= BYTE_ZERO && firstByte <= BYTE_NINE {
    return decodeString(fromBytes: bytes, startIndex: start, nextIndex: &position);
  } else if firstByte == BYTE_LC_I {
    return decodeInteger(fromBytes: bytes, startIndex: start, nextIndex: &position);
  } else if firstByte == BYTE_LC_L {
    return decodeList(fromBytes: bytes, startIndex: start, nextIndex: &position);
  } else if firstByte == BYTE_LC_D {
    return decodeDictionary(fromBytes: bytes, startIndex: start, nextIndex: &position);
  }
  
  return BEncoded.String("WTF");
}

func decode(data: NSData!) -> BEncoded {
  var nextAt = 0;
  let bytes = data!.getBytes();
  return decode(bytes, startIndex: 0, nextIndex: &nextAt);
}

let path = "/Users/billy/Projects/btplayground/test.torrent";
let data = NSData.init(contentsOfFile: path);
let decoded = decode(data);
decoded.pp();


