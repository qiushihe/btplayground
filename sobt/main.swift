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


// https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Introduction/Introduction.html
// https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man3/getaddrinfo.3.html

// http://swiftrien.blogspot.ca/2015/10/socket-programming-in-swift-part-1.html
// https://github.com/Swiftrien/SwifterSockets

// Returns the (host, service) tuple for a given sockaddr
func sockaddrDescription(addr: UnsafePointer<sockaddr>) -> (String?, String?) {
  var host : String?
  var service : String?
  
  var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0);
  var serviceBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue: 0);
  
  let err = getnameinfo(
    addr,
    socklen_t(addr.memory.sa_len),
    &hostBuffer,
    socklen_t(hostBuffer.count),
    &serviceBuffer,
    socklen_t(serviceBuffer.count),
    NI_NUMERICHOST | NI_NUMERICSERV
  );

  if err == 0 {
    host = String.fromCString(hostBuffer);
    service = String.fromCString(serviceBuffer);
  }

  return (host, service);
}

func initServerSocket(port port: UInt16, connectionBufferCount: Int32) -> Int32? {
  var address: sockaddr_in = sockaddr_in();
  memset(&address, 0, Int(socklen_t(sizeof(sockaddr_in))));
  
  address.sin_len = __uint8_t(sizeofValue(address));
  address.sin_family = sa_family_t(AF_INET);
  address.sin_port = htons(port);
  address.sin_addr.s_addr = INADDR_ANY;
  
  let socketAddress = castSocketAddress(&address);
  let socketAddressLength = UInt32(sizeofValue(address));
  
  let tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  
  guard tcpSocket >= 0 else {
    assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
    return -1;
  }

  // Server mode socket requires binding
  let bindErr = bind(
    tcpSocket,
    socketAddress,
    socketAddressLength
  );

  guard bindErr == 0 else {
    assertionFailure("Could not bind socket: \(getErrorDescription(errno))!");
    return -1;
  }
  
  let listenErr = listen(tcpSocket, connectionBufferCount);
  
  guard listenErr == 0 else {
    assertionFailure("Could not listen on socket: \(getErrorDescription(errno))!");
    return -1;
  }
  
  return tcpSocket;
}

// Client ==========================================================================================

func initClientSocket(host host: String, port: UInt16) -> Int32? {
  var address: sockaddr_in = sockaddr_in();
  memset(&address, 0, Int(socklen_t(sizeof(sockaddr_in))));
  
  // For client mode, we need to resolve the host info to obtain the adress data
  // from the given `host` string, which could be either an domain like "www.apple.ca"
  // or an IP address like "17.178.96.7".
  let cfHost = CFHostCreateWithName(nil, host).takeRetainedValue();
  CFHostStartInfoResolution(cfHost, .Addresses, nil);
  
  var success: DarwinBoolean = false;
  // TODO: Handle when address resolution fails.
  let addresses = CFHostGetAddressing(cfHost, &success)?.takeUnretainedValue() as NSArray?;
  
  // TODO: Loop through to actually find an usable address instead of alaways taking the
  // first entry in the array.
  let data = addresses![0];
  
  data.getBytes(&address, length: data.length);
  address.sin_port = htons(port);
  // TODO: Assert for valid address.sin_family
  
  let socketAddress = castSocketAddress(&address);
  let socketAddressLength = UInt32(sizeofValue(address));
  
  let tcpSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  
  guard tcpSocket >= 0 else {
    assertionFailure("Could not create socket: \(getErrorDescription(errno))!");
    return -1;
  }
  
  // Client mode socket requires connection
  let connectErr = connect(
    tcpSocket,
    socketAddress,
    socketAddressLength
  );
  
  guard connectErr == 0 else {
    assertionFailure("Could not connect: \(getErrorDescription(errno))");
    return -1;
  }
  
  return tcpSocket;
}

// Send data =======================================================================================

func sendData(data: NSData, socket: Int32, address: UnsafeMutablePointer<sockaddr> = nil) -> Int {
  let bytesSent = sendto(
    socket,
    data.bytes, data.length,
    0,
    address != nil ? address : nil,
    address != nil ? socklen_t(sizeofValue(address)) : 0
  );
  
  return bytesSent;
}

// Process socket data =============================================================================

func processSocketData(socket: Int32, isServer: Bool, address: UnsafeMutablePointer<sockaddr> = nil) {
  let buffer = [UInt8](count: 4096, repeatedValue: 0);
  
  let bytesRead = recv(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0);
  
  let dataRead = buffer[0..<bytesRead];
  if let dataString = String(bytes: dataRead, encoding: NSUTF8StringEncoding) {
    print("\(isServer ? "Server" : "Client") received message: \(dataString)");
  } else {
    print("\(isServer ? "Server" : "Client") received \(bytesRead) bytes: \(dataRead)");
  }
  
  if (isServer) {
    let replyString = "{\"Reply\":true}";
    let replyData = replyString.dataUsingEncoding(NSUTF8StringEncoding)!;
    
    let bytesSent = sendData(replyData, socket: socket, address: address);
    print("Reply sent: " + String(bytesSent));
  }
}

// =================================================================================================

let serverSocket = initServerSocket(port: 4141, connectionBufferCount: 10);

if serverSocket == nil {
  print("serverSocket is nil!!!");
  exit(-1);
}

var dispatchServerSource: dispatch_source_t? = nil;
func setServerListener(socket: Int32, listener: (Int32) -> ()) {
  // Create a GCD thread that can listen for network events.
  dispatchServerSource = dispatch_source_create(
    DISPATCH_SOURCE_TYPE_READ,
    UInt(socket),
    0,
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
  );
  
  guard dispatchServerSource != nil else {
    close(socket);
    assertionFailure("Can not create dispath source: \(getErrorDescription(errno))");
    return;
  };
  
  // Register the event handler for cancellation.
  dispatch_source_set_cancel_handler(dispatchServerSource!) {
    close(socket);
    assertionFailure("Event handler cancelled: \(getErrorDescription(errno))");
  };
  
  // Register the event handler for incoming packets.
  dispatch_source_set_event_handler(dispatchServerSource!) {
    guard let source = dispatchServerSource else { return };
    let inSocket = Int32(dispatch_source_get_handle(source));
    listener(inSocket);
  };
  
  // Start the listener thread
  dispatch_resume(dispatchServerSource!);
}

setServerListener(serverSocket!) {(socket: Int32) in
  // Incoming connections will be executed in this queue (in parallel)
  let connectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

  // Wait for an incoming connection request
  var connectedAddrInfo = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
  var connectedAddrInfoLength = socklen_t(sizeof(sockaddr));
  let requestDescriptor = accept(socket, &connectedAddrInfo, &connectedAddrInfoLength);
  
  let (ipAddress, servicePort) = sockaddrDescription(&connectedAddrInfo);
  let message = "Accepted connection from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
  print(message);
  
  // Request processing of the connection request in a different dispatch queue
  dispatch_async(connectionQueue, {
    processSocketData(requestDescriptor, isServer: true, address: &connectedAddrInfo);
  });
};

print("Server listening ...");
sleep(3);

let clientSocket = initClientSocket(host: "127.0.0.1", port: 4141);
print("clientSocket: " + String(clientSocket));

var dispatchSource: dispatch_source_t? = nil;
func setListener(socket: Int32, listener: (Int32) -> ()) {
  // Create a GCD thread that can listen for network events.
  dispatchSource = dispatch_source_create(
    DISPATCH_SOURCE_TYPE_READ,
    UInt(socket),
    0,
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
  );
  
  guard dispatchSource != nil else {
    close(socket);
    assertionFailure("Can not create dispath source: \(getErrorDescription(errno))");
    return;
  };
  
  // Register the event handler for cancellation.
  dispatch_source_set_cancel_handler(dispatchSource!) {
    close(socket);
    assertionFailure("Event handler cancelled: \(getErrorDescription(errno))");
  };
  
  // Register the event handler for incoming packets.
  dispatch_source_set_event_handler(dispatchSource!) {
    guard let source = dispatchSource else { return };
    let inSocket = Int32(dispatch_source_get_handle(source));
    listener(inSocket);
  };

  // Start the listener thread
  dispatch_resume(dispatchSource!);
}

if (clientSocket != nil) {
  setListener(clientSocket!) {(socket: Int32) in
    processSocketData(socket, isServer: false);
  };
  
  print("Client listening ...");
  sleep(3);

  let transmitString = "{\"Parameter\":true}";
  let transmitData = transmitString.dataUsingEncoding(NSUTF8StringEncoding)!;
  
  let bytesSent = sendData(transmitData, socket: clientSocket!);
  print("Client sent: " + String(bytesSent));
}

while true {}
// close(clientSocket!);
