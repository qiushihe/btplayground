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

let urlString = "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242";
let trackerClient = Sobt.TrackerClient.TrackerClient();
trackerClient.addManifest(fromPath: "/Users/billy/Projects/btplayground/test.torrent");
// trackerClient.addManifest(fromMegnetLink: urlString);
trackerClient.setPort(4321);
trackerClient.autoUpdate(5);

// Use CFRunLoopStop(CFRunLoopGetCurrent()) to stop
CFRunLoopRun();

// =================================================================================================
// http://stackoverflow.com/a/24016254
/*
// let url = NSURL(string: (jsonObject!["announce-list"] as! Array<Array<String>>)[2][0]);
let url = NSURL(string: "http://tracker.openbittorrent.com:80");
print(url);

let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
  print(NSString(data: data!, encoding: NSUTF8StringEncoding));
};

task.resume();
*/

/*
var echo: UDPEcho?;

if (Process.arguments.count > 1) {
  do {
    echo = try UDPEcho(argv: Process.arguments);
  } catch UDPEchoError.InvalidArguments {
    print("UDP Echo Usage:");
    print("* Server mode: sobt server [port]");
    print("* Client mode: sobt client [port] [host]");
  }
} else {
  echo = UDPEcho(port: 4242);
  // echo = UDPEcho(port: 4242, host: "127.0.0.1");
}

trapSignal(Signal.INT) {(signal) in
  echo?.stop();
  exit(0);
};

if (echo != nil) {
  echo!.start();
  sendSuspendSignal();
}
*/

/*var echo: TCPEcho?;

if (Process.arguments.count > 1) {
  do {
    echo = try TCPEcho(argv: Process.arguments);
  } catch TCPEchoError.InvalidArguments {
    print("TCP Echo Usage:");
    print("* Server mode: sobt server [port]");
    print("* Client mode: sobt client [port] [host]");
  }
} else {
  echo = TCPEcho(port: 4141);
  // echo = TCPEcho(port: 4141, host: "127.0.0.1");
}

trapSignal(Signal.INT) {(signal) in
  echo?.stop();
  exit(0);
};

if (echo != nil) {
  echo!.start();
  sendSuspendSignal();
}
*/
