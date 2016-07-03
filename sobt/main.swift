//
//  main.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation;

let path = "/Users/billy/Projects/btplayground/test.torrent";
let data = NSData.init(contentsOfFile: path);
let decoder = BEncodingDecoder.init(data: data!);
let decoded = decoder.decode();
let jsonObject = bEncodedToJsonObject(decoded);

print(jsonObject);
print(Mirror(reflecting: jsonObject).subjectType);