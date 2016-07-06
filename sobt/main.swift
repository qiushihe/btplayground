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

func listener(socket: Int32, isServer: Bool) -> dispatch_source_t? {
  // Create a GCD thread that can listen for network events.
  guard let newResponseSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(socket), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) else {
    let errmsg = String.fromCString(strerror(errno));
    print("dispatch_source_create failed. \(errmsg)");
    close(socket);
    return nil;
  };
  
  // Register the event handler for cancellation.
  dispatch_source_set_cancel_handler(newResponseSource) {
    let errmsg = String.fromCString(strerror(errno));
    print("Cancel handler \(errmsg)");
    close(socket);
  };
  
  // Register the event handler for incoming packets.
  dispatch_source_set_event_handler(newResponseSource) {
    guard let source = responseSource else { return };
    
    var socketAddress = sockaddr_storage();
    var socketAddressLength = socklen_t(sizeof(sockaddr_storage.self));
    let response = [UInt8](count: 4096, repeatedValue: 0);
    let UDPSocket = Int32(dispatch_source_get_handle(source));
    
    let bytesRead = withUnsafeMutablePointer(&socketAddress) {
      recvfrom(UDPSocket, UnsafeMutablePointer<Void>(response), response.count, 0, UnsafeMutablePointer($0), &socketAddressLength);
    };
    
    let dataRead = response[0..<bytesRead];
    print("read \(bytesRead) bytes: \(dataRead)");
    if let dataString = String(bytes: dataRead, encoding: NSUTF8StringEncoding) {
      print("The message was: \(dataString)");
    }
    
    if (isServer) {
      let outData = Array("Greetings earthling".utf8);
      let outAddress = getSocketFromStorage(&socketAddress);
      let outAddressLength = socklen_t(sizeof(sockaddr));

      let sent = sendto(UDPSocket, outData, outData.count, 0, outAddress, outAddressLength);
      
      if sent == -1 {
        let errmsg = String.fromCString(strerror(errno));
        print("sendto failed: \(errno) \(errmsg)");
        return;
      }

      print("Just sent \(sent) bytes as \(outData)");
    }
  }
  
  dispatch_resume(newResponseSource);
  
  return newResponseSource;
}

func sender(socket: Int32) {
  guard socket >= 0  else {
    let errmsg = String.fromCString(strerror(errno));
    print("Error: Could not create socket. \(errmsg)");
    return;
  }
  
  let outData = Array("Greetings earthling".utf8);
  
  let sent = sendto(socket, outData, outData.count, 0, nil, 0);
  
  if sent == -1 {
    let errmsg = String.fromCString(strerror(errno));
    print("sendto failed: \(errno) \(errmsg)");
    return;
  }
  
  print("Just sent \(sent) bytes as \(outData)");
}

func startClient() {
  var address = getSocketAddress("127.0.0.1", port: 4242);
  let socket = getSocket(&address);
  
  responseSource = listener(socket, isServer: false);
  print("Client listening...");
  
  sleep(3);
  
  sender(socket);
  
  // close(sock);
  while true {}
}

func startServer() {
  var address = getSocketAddress(port: 4242);
  let socket = getSocket(&address);
  
  responseSource = listener(socket, isServer: true);
  print("Server listening...");
  
  while true {}
}

if (Process.arguments.count > 1) {
  if (Process.arguments[1] == "server") {
    startServer();
  } else if (Process.arguments[1] == "client") {
    startClient();
  }
} else {
  startServer();
  // startClient();
}
