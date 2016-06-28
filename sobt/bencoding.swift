//
//  bencoding.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Swift;
import Foundation

func identity(arg: Any?) -> Any? {
  return arg;
}

func flow(functions: Array<(Any?) -> Any?>) -> ((Any?) -> Any?) {
  return functions.count <= 0
    ? identity
    : {(arg: Any?) -> Any? in
      return flow(
        Array<(Any?) -> Any?>(functions.count == 1
          ? []
          : functions[1...(functions.count - 1)])
        )(functions[0](arg));
    };
}

extension NSData {
  func getBytes() -> Array<UInt8> {
    let size = sizeof(UInt8);
    let count = self.length / size;
    var bytes = Array<UInt8>.init(count: count, repeatedValue: 0);
    self.getBytes(&bytes, length:bytes.count * size);
    return bytes;
  }
}

enum BEncodedSeparator: UInt8 {
  case Colon = 58; // :
  case End = 101;  // e
}

enum BEncodedDataType {
  case String, Integer, List, Dictionary
}

enum BEncodedDataTypeByte: UInt8 {
  case _0 = 48, _1, _2, _3, _4, _5, _6, _7, _8, _9; // 0 - 9
  case _lc_d = 100;                                 // d
  case _lc_i = 105;                                 // i
  case _lc_l = 108;                                 // l

  var dataType: BEncodedDataType {
    switch self {
    case ._0, _1, _2, _3, _4, _5, _6, _7, _8, _9:
      return BEncodedDataType.String;
    case ._lc_i: return BEncodedDataType.Integer;
    case ._lc_l: return BEncodedDataType.List;
    case ._lc_d: return BEncodedDataType.Dictionary;
    }
  }
}

enum BEncoded {
  case String(Swift.String)
  case Integer(Swift.Int)
  case List(Swift.Array<BEncoded>)
  case Dictionary(Swift.Dictionary<Swift.String, BEncoded>)
  
  var type: Swift.String {
    switch self {
    case .String: return "string";
    case .Integer: return "integer";
    case .List: return "list";
    case .Dictionary: return "dictionary";
    }
  }
  
  var value: Any {
    switch self {
    case .String(let stringValue): return stringValue;
    case .Integer(let integerValue): return integerValue;
    case .List(let listValue): return listValue;
    case .Dictionary(let dictionaryValue): return dictionaryValue;
    }
  }
  
  func indents(level: Int = 0) -> Swift.String {
    return Swift.String.init(count: level * 2, repeatedValue: Character(" "));
  }
  
  func pp(level: Int = 0, noIndent: Bool = false) {
    switch self {
    case .String(let stringValue):
      let ppString = "\"" + stringValue + "\"";
      print(noIndent ? ppString : self.indents(level) + ppString);
      break;
    case .Integer(let integerValue):
      let ppString = Swift.String.init(integerValue);
      print(noIndent ? ppString : self.indents(level) + ppString);
      break;
    case .List(let listValue):
      print(noIndent ? "[" : self.indents(level) + "[");
      for value in listValue {
        value.pp(level + 1);
      }
      print(self.indents(level) + "]");
      break;
    case .Dictionary(let dictionaryValue):
      print(noIndent ? "{" : self.indents(level) + "{");
      for (key, value) in dictionaryValue {
        print(self.indents(level + 1) + "\"" + key + "\": ", terminator: "");
        value.pp(level + 1, noIndent: true);
      }
      print(self.indents(level) + "}");
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

func readString(fromBytes bytes: Array<UInt8>, startAt start: Int, stopBefore stopByte: BEncodedSeparator) -> String {
  var str = "";
  var position = start;
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == stopByte {
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

func bDecodeString(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start;
  
  let lengthStr = readString(fromBytes: bytes, startAt: position, stopBefore: BEncodedSeparator.Colon);
  position += getLength(ofString: lengthStr) + 1;
  
  let length = Int.init(lengthStr)!;
  let string = readString(fromBytes: bytes, startAt: position, stopAfterLength: length);
  position += getLength(ofString: string);
  
  return BEncoded.String(string);
}

func bDecodeInteger(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  let integerStr = readString(fromBytes: bytes, startAt: position, stopBefore: BEncodedSeparator.End);
  let integer = Int.init(integerStr)!;
  position += getLength(ofString: integerStr) + 1;
  
  return BEncoded.Integer(integer);
}

func bDecodeList(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  var list: Array<BEncoded> = [];
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == BEncodedSeparator.End {
      break;
    }

    let decoded: BEncoded = bDecode(bytes, startIndex: position, nextIndex: &position);
    list.append(decoded);
  }
  
  position += 1;
  
  return BEncoded.List(list);
}

func bDecodeDictionary(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  position = start + 1;
  
  var dictionary: Dictionary<String, BEncoded> = [:];
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == BEncodedSeparator.End {
      break;
    }
    
    let key = bDecode(bytes, startIndex: position, nextIndex: &position);
    
    if key.value as! String == "pieces" {
      dictionary[key.value as! String] = BEncoded.String("TODO: Read sha hash");
      position += 3;
      position += 40;
    } else {
      let value = bDecode(bytes, startIndex: position, nextIndex: &position);
      dictionary[key.value as! String] = value;
    }
  }
  
  position += 1;
  
  return BEncoded.Dictionary(dictionary);
}

func bDecode(bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> BEncoded {
  switch BEncodedDataTypeByte(rawValue: bytes[start])!.dataType {
  case BEncodedDataType.String:
    return bDecodeString(fromBytes: bytes, startIndex: start, nextIndex: &position);
  case BEncodedDataType.Integer:
    return bDecodeInteger(fromBytes: bytes, startIndex: start, nextIndex: &position);
  case BEncodedDataType.List:
    return bDecodeList(fromBytes: bytes, startIndex: start, nextIndex: &position);
  case BEncodedDataType.Dictionary:
    return bDecodeDictionary(fromBytes: bytes, startIndex: start, nextIndex: &position);
  }
}

func bDecode(data: NSData!) -> BEncoded {
  var nextAt = 0;
  let bytes = data!.getBytes();
  return bDecode(bytes, startIndex: 0, nextIndex: &nextAt);
}