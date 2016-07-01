//
//  bencoding.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

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
  
  var value: Any {
    switch self {
    case .String(let stringValue): return stringValue;
    case .Integer(let integerValue): return integerValue;
    case .List(let listValue): return listValue;
    case .Dictionary(let dictionaryValue): return dictionaryValue;
    }
  }
}

func getString(byte: UInt8) -> String {
  return String.init(Character(UnicodeScalar(byte)));
}

func getLength(string: String) -> Int {
  return string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding);
}

func readString(bytes: Array<UInt8>, _ start: Int, stopBefore stopByte: BEncodedSeparator) -> String {
  var str = "";
  var position = start;
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == stopByte {
      break;
    }
    str += getString(bytes[position]);
    position += 1;
  }
  
  return str;
}

func readString(bytes: Array<UInt8>, _ start: Int, stopAfterLength length: Int) -> String {
  return String.init(bytes: bytes[start...(start + length - 1)], encoding: NSUTF8StringEncoding)!;
}

func readPieces(bytes: Array<UInt8>, _ start: Int, _ length: Int, _ count: Int) -> Array<String> {
  var pieces: Array<String> = [];
  var currentPosition = start;
  
  while true {
    if pieces.count >= count {
      break;
    }

    let pieceBytes = Array<UInt8>.init(bytes[currentPosition...(currentPosition + length - 1)]);
    let pieceData = NSData(bytes: pieceBytes, length: length);
    pieces.append(pieceData.base64EncodedStringWithOptions([]));

    currentPosition += length;
  }
  
  return pieces;
}

func bDecodePieces(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  position = start;
  
  let lengthStr = readString(bytes, position, stopBefore: BEncodedSeparator.Colon);
  position += getLength(lengthStr) + 1;

  let length = Int.init(lengthStr)!;
  let pieces = readPieces(bytes, position, 20, length / 20);
  position += length;

  return BEncoded.List(pieces.map({(piece: String)
    in return BEncoded.String(piece);
  }));
}

func bDecodeString(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  position = start;
  
  let lengthStr = readString(bytes, position, stopBefore: BEncodedSeparator.Colon);
  position += getLength(lengthStr) + 1;
  
  let length = Int.init(lengthStr)!;
  let string = readString(bytes, position, stopAfterLength: length);
  position += getLength(string);
  
  return BEncoded.String(string);
}

func bDecodeInteger(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  position = start + 1;

  let integerStr = readString(bytes, position, stopBefore: BEncodedSeparator.End);
  let integer = Int.init(integerStr)!;
  position += getLength(integerStr) + 1;
  
  return BEncoded.Integer(integer);
}

func bDecodeList(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  position = start + 1;
  
  var list: Array<BEncoded> = [];
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == BEncodedSeparator.End {
      break;
    }
    list.append(bDecode(bytes, position, &position));
  }
  
  position += 1;
  
  return BEncoded.List(list);
}

func bDecodeDictionary(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  position = start + 1;
  
  var dictionary: Dictionary<String, BEncoded> = [:];
  
  while true {
    if BEncodedSeparator(rawValue: bytes[position]) == BEncodedSeparator.End {
      break;
    }

    let key = bDecode(bytes, position, &position);

    if key.value as! String == "pieces" {
      dictionary[key.value as! String] = bDecodePieces(bytes, position, &position);
    } else {
      dictionary[key.value as! String] = bDecode(bytes, position, &position);
    }
  }
  
  position += 1;
  
  return BEncoded.Dictionary(dictionary);
}

func bDecode(bytes: Array<UInt8>, _ start: Int, inout _ position: Int) -> BEncoded {
  switch BEncodedDataTypeByte(rawValue: bytes[start])!.dataType {
  case BEncodedDataType.String:
    return bDecodeString(bytes, start, &position);
  case BEncodedDataType.Integer:
    return bDecodeInteger(bytes, start, &position);
  case BEncodedDataType.List:
    return bDecodeList(bytes, start, &position);
  case BEncodedDataType.Dictionary:
    return bDecodeDictionary(bytes, start, &position);
  }
}

func bDecode(data: NSData!) -> BEncoded {
  var nextAt = 0;
  let bytes = data!.getBytes();
  return bDecode(bytes, 0, &nextAt);
}