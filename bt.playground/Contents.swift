//: Playground - noun: a place where people can play

import Swift;
import Foundation;

extension NSData {
    func getBytes() -> Array<UInt8> {
        let size = sizeof(UInt8);
        let count = self.length / size;
        var bytes = Array<UInt8>.init(count: count, repeatedValue: 0);
        self.getBytes(&bytes, length:count * size);
        return bytes;
    }
}

enum BDecoded {
    case String(Swift.String)
    case Integer(Swift.Int)
    case List(Swift.Array<BDecoded>)
    case Dictionary(Swift.Dictionary<Swift.String, BDecoded>)
    
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

func decode(data: NSData!) throws -> BDecoded {
    return BDecoded.String("lala");
}

let path = "/Users/billy/Google Drive/Personal/SyncOverBT/test.torrent";
var encoding: UInt = 0;

// NSASCIIStringEncoding
// NSUTF8StringEncoding

let data = NSData.init(contentsOfFile: path);
let str = String.init(data: data!, encoding: NSASCIIStringEncoding);
print(str!);

let bytes = data!.getBytes();

bytes[0...0]

bytes[4];
bytes[5];
bytes[8];

try decode(data);
