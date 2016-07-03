//
//  bencoding-json.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-07-01.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

func indentsWithSpace(level: Int) -> String {
  return String(count: level * 2, repeatedValue: Character(" "));
}

func bEncodedToJsonString(encoded: BEncoded, _ level: Int, _ noIndent: Bool, _ withNewLine: Bool) -> String {
  switch encoded {
  case .String(let stringValue):
    return indentsWithSpace(noIndent ? 0 : level)
      + "\"" + stringValue.stringByReplacingOccurrencesOfString("\"", withString: "\\\"") + "\""
      + (withNewLine ? "\n" : "");
  case .Integer(let integerValue):
    return indentsWithSpace(noIndent ? 0 : level)
      + Swift.String.init(integerValue)
      + (withNewLine ? "\n" : "");
  case .List(let listValue):
    if (listValue.isEmpty) {
      return "[]" + (withNewLine ? "\n" : "");
    } else {
      var jsonString = indentsWithSpace(noIndent ? 0 : level) + "[\n";
      for (index, value) in listValue.enumerate() {
        jsonString += bEncodedToJsonString(value, level + 1, false, index >= listValue.count - 1);
        if (index < listValue.count - 1) {
          jsonString += ",\n";
        }
      }
      return jsonString
        + indentsWithSpace(level) + "]"
        + (withNewLine ? "\n" : "");
    }
  case .Dictionary(let dictionaryValue):
    if (dictionaryValue.isEmpty) {
      return "{}" + (withNewLine ? "\n" : "");
    } else {
      var jsonString = indentsWithSpace(noIndent ? 0 : level) + "{\n";
      for (index, (key, value)) in dictionaryValue.enumerate() {
        jsonString += indentsWithSpace(level + 1) + "\"" + key + "\": "
          + bEncodedToJsonString(value, level + 1, true, index >= dictionaryValue.count - 1);
        if (index < dictionaryValue.count - 1) {
          jsonString += ",\n";
        }
      }
      return jsonString
        + indentsWithSpace(level) + "}"
        + (withNewLine ? "\n" : "");
    }
  }
}

func bEncodedToJsonString(encoded: BEncoded) -> String {
  return bEncodedToJsonString(encoded, 0, false, true);
}

func bEncodedToJsonObject(encoded: BEncoded) -> NSDictionary? {
  do {
    return try NSJSONSerialization.JSONObjectWithData(
      bEncodedToJsonString(encoded).dataUsingEncoding(NSUTF8StringEncoding)!,
      options: [.AllowFragments]) as? NSDictionary;
  } catch _ {
    return nil;
  }
}
