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

// print(jsonObject);

// =================================================================================================
// http://www.bittorrent.org/beps/bep_0003.html
// http://www.bittorrent.org/beps/bep_0015.html
// http://www.rasterbar.com/products/libtorrent/udp_tracker_protocol.html
// udp://tracker.coppersurfer.tk:6969

func handleData(socket: Int32) {
  var inAddress = sockaddr_storage();
  var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
  let buffer = [UInt8](count: 4096, repeatedValue: 0);
  
  let bytesRead = withUnsafeMutablePointer(&inAddress) {
    recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
  };
  
  let (ipAddress, servicePort) = Socket.GetSocketHostAndPort(Socket.CastSocketAddress(&inAddress));
  let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
  print(message);
  
  let dataRead = buffer[0..<bytesRead];
  print("Received \(bytesRead) bytes: \(dataRead)");
}

let udpSocket = UDPSocket.init(port: 6969, host: "tracker.coppersurfer.tk");

udpSocket.setListener({(socket: Int32) in
  handleData(socket);
});

let connectData = NSMutableData.init();
var connectConnectionId = htonll(0x41727101980 as UInt64); // Magic number 0x41727101980
var connectAction = htonl(0 as UInt32);
var connectTransactionId = htonl(arc4random() as UInt32);

connectData.appendBytes(&connectConnectionId, length: 8);
connectData.appendBytes(&connectAction, length: 4);
connectData.appendBytes(&connectTransactionId, length: 4);

print("Connect Data \(connectData.length) bytes: \(Sobt.Util.NSDataToArray(connectData))");
// udpSocket.sendData(connectData);
// while (true) {}

// Connect Data 16 bytes: [0, 0, 4, 23, 39, 16, 25, 128, 0, 0, 0, 0, 46, 58, 70, 9]
// Got data from: 62.138.0.158, from port:6969
// Received 16 bytes: [0, 0, 0, 0, 46, 58, 70, 9, 219, 71, 130, 124, 190, 98, 121, 245]

let infoValue: String = decoder.getInfoValue();
print(infoValue);

let infoData: NSData = decoder.getInfoValue();
print(Sobt.Crypto.SHA1(infoData) as String);

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
    echo = try UDPEcho.init(argv: Process.arguments);
  } catch UDPEchoError.InvalidArguments {
    print("UDP Echo Usage:");
    print("* Server mode: sobt server [port]");
    print("* Client mode: sobt client [port] [host]");
  }
} else {
  echo = UDPEcho.init(port: 4242);
  // echo = UDPEcho.init(port: 4242, host: "127.0.0.1");
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
    echo = try TCPEcho.init(argv: Process.arguments);
  } catch TCPEchoError.InvalidArguments {
    print("TCP Echo Usage:");
    print("* Server mode: sobt server [port]");
    print("* Client mode: sobt client [port] [host]");
  }
} else {
  echo = TCPEcho.init(port: 4141);
  // echo = TCPEcho.init(port: 4141, host: "127.0.0.1");
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
