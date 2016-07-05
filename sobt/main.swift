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

// =================================================================================================
// http://stackoverflow.com/a/24016254

// let url = NSURL(string: (jsonObject!["announce-list"] as! Array<Array<String>>)[2][0]);
let url = NSURL(string: "http://tracker.openbittorrent.com:80");
print(url);

/* let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
  print(NSString(data: data!, encoding: NSUTF8StringEncoding));
};

task.resume(); */

// =================================================================================================
// https://gist.github.com/NeoTeo/b6195efb779d925fd7b8
//
// Other resources:
// * http://stackoverflow.com/questions/24977805/socket-server-example-with-swift
// * http://stackoverflow.com/questions/33727980/basic-tcp-ip-server-in-swift
// * http://codereview.stackexchange.com/questions/71861/pure-swift-solution-for-socket-programming
// * https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/UsingSocketsandSocketStreams.html
// * https://developer.apple.com/library/mac/samplecode/UDPEcho/Introduction/Intro.html

// Workaround for Swift not having access to the htons, htonl, and other C macros.
// This is equivalent to casting the value to the desired bitsize and then swapping the endian'ness
// of the result if the host platform is little endian. In the case of Mac OS X on Intel it is.
let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian;

// So htons casts to UInt16 and then turns into big endian (which is network byte order)
let htons = isLittleEndian ? _OSSwapInt16 : { $0 };
let htonl = isLittleEndian ? _OSSwapInt32 : { $0 };
let htonll = isLittleEndian ? _OSSwapInt64 : { $0 };
let ntohs = isLittleEndian ? _OSSwapInt16 : { $0 };
let ntohl = isLittleEndian ? _OSSwapInt32 : { $0 };
let ntohll = isLittleEndian ? _OSSwapInt64 : { $0 };

func getSocketAddress(host: String, _ port: __uint16_t) -> sockaddr_in {
  let ADDRESS_ANY = in_addr(s_addr: 0);
  
  var address = sockaddr_in(
    sin_len:    __uint8_t(sizeof(sockaddr_in)),
    sin_family: sa_family_t(AF_INET),
    sin_port:   htons(port),
    sin_addr:   ADDRESS_ANY,
    sin_zero:   ( 0, 0, 0, 0, 0, 0, 0, 0 )
  );
  
  // inet_pton turns a text presentable ip to a network/binary representation
  host.withCString({ cs in inet_pton(AF_INET, cs, &address.sin_addr) });

  return address;
}

// tracker.coppersurfer.tk
var sockAddress = getSocketAddress("62.138.0.158", 6969);
// var sockAddress = getSocketAddress("127.0.0.1", 4242);

var responseSource: dispatch_source_t?;

// 1) Create a socket.
// 2) Bind the socket.
// 3) Connect the socket (optional).
// 4) In a loop/separate thread/event listen for incoming packets.
func receiver() -> dispatch_source_t? {
  // A socket file descriptor
  let sockFd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
  
  guard sockFd >= 0 else {
    let errmsg = String.fromCString(strerror(errno));
    print("Error: Could not create socket: \(errno) (\(errmsg))!");
    return nil;
  }
  
  // Bind the socket to the address
  let bindSuccess = withUnsafePointer(&sockAddress) {
    bind(sockFd, UnsafePointer($0), socklen_t( sizeofValue(sockAddress)))
  };
  
  guard bindSuccess == 0 else {
    let errmsg = String.fromCString(strerror(errno));
    print("Error: Could not bind socket: \(errno) (\(errmsg))!");
    return nil;
  }
  
  // Connect. Since we're using UDP this isn't actually a connection but it does save us
  // from having to restate the address when we want to use the socket.
  /* let connectSuccess = withUnsafePointer(&sockAddress) {
    connect(sockFd, UnsafePointer($0), socklen_t( sizeofValue(sockAddress)));
  };

  guard connectSuccess == 0 else {
    let errmsg = String.fromCString(strerror(errno));
    print("Could not connect! \(errmsg)");
    return nil;
  } */
  
  // Create a GCD thread that can listen for network events.
  guard let newResponseSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(sockFd), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) else {
    let errmsg = String.fromCString(strerror(errno));
    print("dispatch_source_create failed. \(errmsg)");
    close(sockFd);
    return nil;
  }
  
  // Register the event handler for cancellation.
  dispatch_source_set_cancel_handler(newResponseSource) {
    let errmsg = String.fromCString(strerror(errno));
    print("Cancel handler \(errmsg)");
    close(sockFd);
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
  }
  
  dispatch_resume(newResponseSource);
  
  return newResponseSource;
}

// To send a packet on the socket.
// 1) Create a socket.
// 2) Send a message.
func sender() {
  // A file descriptor Int32
  let sockFd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
  
  guard sockFd >= 0  else {
    let errmsg = String.fromCString(strerror(errno));
    print("Error: Could not create socket. \(errmsg)");
    return;
  }
  
  let outData = Array("Greetings earthling".utf8);
  
  let sent = withUnsafePointer(&sockAddress) {
    sendto(sockFd, outData, outData.count, 0, UnsafePointer($0), socklen_t(sockAddress.sin_len));
  }

  if sent == -1 {
    let errmsg = String.fromCString(strerror(errno));
    print("sendto failed: \(errno) \(errmsg)");
    return;
  }
  
  print("Just sent \(sent) bytes as \(outData)");
  
  close(sockFd);
}

print("Receiver listening...");

responseSource = receiver();

sleep(3);

sender();

while true {}
