//
//  main.swift
//  bencode2json
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum BEncode2Json: ErrorType {
  case InvalidArguments
}

do {
  let arguments = Process.arguments;
  if (arguments.count <= 1) {
    throw BEncode2Json.InvalidArguments;
  }

  let data = NSData(contentsOfFile: arguments[1]);
  let decoder = Sobt.Bencoding.BEncodingDecoder(data: data!);
  let decoded = decoder.decode();
  let jsonString = Sobt.Bencoding.Json.bEncodedToJsonString(decoded);
  print(jsonString);
} catch BEncode2Json.InvalidArguments {
  print("bencode2json Usage:");
  print("* bencode2json [path to bencoded file]");
}
