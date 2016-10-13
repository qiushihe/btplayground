//
//  main.swift
//  sobt-tracker
//
//  Created by Billy He on 10/13/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

print("Hello, World!")

let path = "/Users/billy/Projects/btplayground/test.torrent";
let data = NSData(contentsOfFile: path);
let decoder = Sobt.Bencoding.BEncodingDecoder(data: data!);
let decoded = decoder.decode();
let jsonObject = Sobt.Bencoding.Json.bEncodedToJsonObject(decoded);
print(jsonObject);
