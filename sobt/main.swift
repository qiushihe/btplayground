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

var responseSource: dispatch_source_t?;

func handleSocketData(socket: Int32, isServer: Bool) {
  var inAddress = sockaddr_storage();
  var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
  let buffer = [UInt8](count: 4096, repeatedValue: 0);
  
  let bytesRead = withUnsafeMutablePointer(&inAddress) {
    recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
  };
  
  let dataRead = buffer[0..<bytesRead];
  if let dataString = String(bytes: dataRead, encoding: NSUTF8StringEncoding) {
    print("\(isServer ? "Server" : "Client") received message: \(dataString)");
  } else {
    print("\(isServer ? "Server" : "Client") received \(bytesRead) bytes: \(dataRead)");
  }
  
  if (isServer) {
    let replyStr = "Bay Area Men Wakes Up To No New Email!";
    let replyData = replyStr.dataUsingEncoding(NSUTF8StringEncoding)!;
    
    let replySocket = UDPSocket(socket: socket, address: castSocketAddress(&inAddress), addressLength: inAddressLength);
    replySocket.sendData(replyData);
    
    print("Server sent: \(replyStr)");
  }
}

func startClient(host: String, port: UInt16) {
  let udpSocket = UDPSocket(port: port, host: host);
  
  udpSocket.setListener({(socket: Int32) in
    handleSocketData(socket, isServer: false);
  });
  
  print("Client listening...");
  
  let str = "Holy Shit! Men on the Fucking Moon!";
  udpSocket.sendData(str.dataUsingEncoding(NSUTF8StringEncoding)!);
  print("Client sent: \(str)");
  
  // close(sock);
  while true {}
}

func startServer(port: UInt16) {
  let udpSocket = UDPSocket(port: port);
  
  udpSocket.setListener({(socket: Int32) in
    handleSocketData(socket, isServer: true);
  });
  
  print("Server listening...");
  
  while true {}
}

if (Process.arguments.count > 1) {
  if (Process.arguments[1] == "server") {
    startServer(4242);
  } else if (Process.arguments[1] == "client") {
    startClient("127.0.0.1", port: 4242);
  }
} else {
  startServer(4242);
  // startClient("127.0.0.1", port: 4242);
}
