//
//  main.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation;

/*
let path = "/Users/billy/Projects/btplayground/test.torrent";
let data = NSData(contentsOfFile: path);
let decoder = Sobt.Bencoding.BEncodingDecoder(data: data!);
let decoded = decoder.decode();
let jsonObject = Sobt.Bencoding.Json.bEncodedToJsonObject(decoded);
print(jsonObject);
*/

// http://www.bittorrent.org/beps/bep_0003.html
// http://www.bittorrent.org/beps/bep_0015.html
// http://www.rasterbar.com/products/libtorrent/udp_tracker_protocol.html

let trackerClient = Sobt.TrackerClient.TrackerClient();
// trackerClient.addManifest(fromPath: "/Users/billy/Projects/btplayground/test.torrent");
trackerClient.addManifest(fromMegnetLink: "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242");
trackerClient.setPort(4321);
trackerClient.autoUpdate(5);

CFRunLoopRun();
