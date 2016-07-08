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
let data = NSData.init(contentsOfFile: path);
let decoder = BEncodingDecoder.init(data: data!);
let decoded = decoder.decode();
let jsonObject = bEncodedToJsonObject(decoded);

print(jsonObject);
*/

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

// https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Introduction/Introduction.html
// http://swiftrien.blogspot.ca/2015/10/socket-programming-in-swift-part-1.html
// https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man3/getaddrinfo.3.html

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
