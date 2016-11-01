//
//  bencoding.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.Bencoding {
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
  
  class BEncodingReader {
    private let bytes: Array<UInt8>;
    private var position: Int;
    private let bytesCount: Int;
    
    init(bytes: Array<UInt8>) {
      self.bytes = bytes;
      self.position = 0;
      self.bytesCount = bytes.count;
    }
    
    convenience init(data: NSData) {
      let size = sizeof(UInt8);
      let count = data.length / size;
      var _bytes = Array<UInt8>(count: count, repeatedValue: 0);
      data.getBytes(&_bytes, length:count * size);
      self.init(bytes: _bytes);
    }
    
    func read(count: Int = 1) -> Array<UInt8> {
      let endPosition = self.position + count - 1;
      if (endPosition <= self.bytesCount - 1) {
        let bytesRange = self.bytes[self.position...endPosition];
        self.position = endPosition + 1;
        return Array<UInt8>(bytesRange);
      } else {
        return [];
      }
    }
    
    func peek() -> UInt8 {
      return self.bytes[self.position];
    }
    
    func advance(count: Int = 1) {
      self.position += count;
    }
    
    func getPosition() -> Int {
      return self.position;
    }
    
    func getRange(start: Int, _ end: Int) -> Array<UInt8> {
      return Array<UInt8>(self.bytes[start...end]);
    }
  }
  
  class BEncodingDecoder {
    private let data: NSData;
    private let reader: BEncodingReader;
    
    private var infoValueStart: Int = -1;
    private var infoValueEnd: Int = -1;
    
    init(data: NSData) {
      self.data = data;
      self.reader = BEncodingReader(data: data);
    }
    
    func decode() -> BEncoded {
      let dtByte = BEncodedDataTypeByte(rawValue: self.reader.peek());
      switch dtByte!.dataType {
      case BEncodedDataType.String:
        return self.decodeString();
      case BEncodedDataType.Integer:
        return self.decodeInteger();
      case BEncodedDataType.List:
        return self.decodeList();
      case BEncodedDataType.Dictionary:
        return self.decodeDictionary();
      }
    }
    
    func getInfoValue() -> NSData {
      var range: Array<UInt8> = self.reader.getRange(self.infoValueStart, self.infoValueEnd);
      return NSData(bytes: &range, length: range.count);
    }
    
    func getInfoValue() -> String {
      var range: Array<UInt8> = self.reader.getRange(self.infoValueStart, self.infoValueEnd);
      let data = NSData(bytes: &range, length: range.count);
      let str = String(data: data, encoding: NSASCIIStringEncoding);
      return str != nil ? str! : "";
    }
    
    private func decodeString() -> BEncoded {
      let lengthStr = self.readString(BEncodedSeparator.Colon, andAdvance: 1);
      let length = Int(lengthStr)!;
      let string = self.readString(length);
      return BEncoded.String(string);
    }
    
    private func decodeInteger() -> BEncoded {
      let integerStr = self.advanceBeforeAndAfter(1) {() in
        return self.readString(BEncodedSeparator.End);
        } as! String;
      let integer = Int(integerStr)!;
      return BEncoded.Integer(integer);
    }
    
    private func decodeList() -> BEncoded {
      let list = self.advanceBeforeAndAfter(1) {() in
        var result: Array<BEncoded> = [];
        
        while true {
          if BEncodedSeparator(rawValue: self.reader.peek()) == BEncodedSeparator.End {
            break;
          }
          result.append(self.decode());
        }
        
        return result;
        } as! Array<BEncoded>;
      
      return BEncoded.List(list);
    }
    
    private func decodeDictionary() -> BEncoded {
      let dictionary = self.advanceBeforeAndAfter(1) {() in
        var result: Dictionary<String, BEncoded> = [:];
        
        while true {
          if BEncodedSeparator(rawValue: self.reader.peek()) == BEncodedSeparator.End {
            break;
          }
          
          let key = self.decode();
          let keyString = key.value as! String;
          
          if keyString == "info" {
            self.infoValueStart = self.reader.getPosition();
          }
          
          if keyString == "pieces" {
            result[key.value as! String] = self.decodePieces();
          } else {
            result[key.value as! String] = self.decode();
          }
          
          if keyString == "info" {
            self.infoValueEnd = self.reader.getPosition() - 1;
          }
        }
        
        return result;
        } as! Dictionary<String, BEncoded>;
      
      return BEncoded.Dictionary(dictionary);
    }
    
    private func decodePieces() -> BEncoded {
      let lengthStr = self.readString(BEncodedSeparator.Colon, andAdvance: 1);
      let length = Int(lengthStr)!;
      let pieces = self.readPieces(20, pieceCount: length / 20);
      
      return BEncoded.List(pieces.map({(piece: String)
        in return BEncoded.String(piece);
      }));
    }
    
    private func readPieces(pieceLength: Int, pieceCount: Int) -> Array<String> {
      var pieces: Array<String> = [];
      
      while true {
        if pieces.count >= pieceCount {
          break;
        }
        
        let pieceBytes = self.reader.read(pieceLength);
        let pieceData = NSData(bytes: pieceBytes, length: pieceLength);
        pieces.append(pieceData.base64EncodedStringWithOptions([]));
      }
      
      return pieces;
    }
    
    private func readString(length: Int, andAdvance: Int = 0) -> String {
      let bytesStr = String(bytes: self.reader.read(length), encoding: NSUTF8StringEncoding);
      self.reader.advance(andAdvance);
      return bytesStr != nil ? bytesStr! : "";
    }
    
    private func readString(stopBefore: BEncodedSeparator, andAdvance: Int = 0) -> String {
      var str = "";
      
      while true {
        if BEncodedSeparator(rawValue: self.reader.peek()) == stopBefore {
          break;
        }
        
        let byteStr = String(bytes: self.reader.read(), encoding: NSUTF8StringEncoding);
        str += byteStr != nil ? byteStr! : "";
      }
      
      self.reader.advance(andAdvance);
      
      return str;
    }
    
    private func advanceBeforeAndAfter(advancement: Int = 1, block: () -> Any) -> Any {
      self.reader.advance(advancement);
      let result = block();
      self.reader.advance(advancement);
      return result;
    }
  }
}
