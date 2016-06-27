//: Playground - noun: a place where people can play

import Swift;
import Foundation;

let BYTE_COLON: UInt8 = 58;
let BYTE_LC_E: UInt8 = 101;

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

func decodeString(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> String {
  position = start;
  
  let lengthStr = readString(fromBytes: bytes, startAt: position, stopBefore: BYTE_COLON);
  position += getLength(ofString: lengthStr) + 1;
  
  let length = Int.init(lengthStr)!;
  let string = readString(fromBytes: bytes, startAt: position, stopAfterLength: length);
  position += getLength(ofString: string);
  
  return string;
}

func decodeInteger(fromBytes bytes: Array<UInt8>, startIndex start: Int, inout nextIndex position: Int) -> Int {
  position = start + 1;
  
  let integerStr = readString(fromBytes: bytes, startAt: position, stopBefore: BYTE_LC_E);
  let integer = Int.init(integerStr)!;
  position += getLength(ofString: integerStr) + 2;

  return integer;
}

func decode(data: NSData!) -> BEncoded {
  let bytes = data!.getBytes();

  var nextAt = 0;
  decodeString(fromBytes: bytes, startIndex: 11, nextIndex: &nextAt);
  nextAt;
  
  decodeInteger(fromBytes: bytes, startIndex: 473, nextIndex: &nextAt);
  nextAt;
  
  bytes[4];
  bytes[5];
  bytes[8];
  
  return BEncoded.String("lala");
}

let path = "/Users/billy/Projects/btplayground/test.torrent";
var encoding: UInt = 0;

// NSASCIIStringEncoding
// NSUTF8StringEncoding

let data = NSData.init(contentsOfFile: path);
let str = String.init(data: data!, encoding: NSASCIIStringEncoding);
print(str!);

decode(data);
