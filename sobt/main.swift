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

func fdSet(fd: Int32, inout set: fd_set) {
  let intOffset = Int(fd / 32)
  let bitOffset = fd % 32
  let mask = 1 << bitOffset
  switch intOffset {
  case 0: set.fds_bits.0 = set.fds_bits.0 | mask
  case 1: set.fds_bits.1 = set.fds_bits.1 | mask
  case 2: set.fds_bits.2 = set.fds_bits.2 | mask
  case 3: set.fds_bits.3 = set.fds_bits.3 | mask
  case 4: set.fds_bits.4 = set.fds_bits.4 | mask
  case 5: set.fds_bits.5 = set.fds_bits.5 | mask
  case 6: set.fds_bits.6 = set.fds_bits.6 | mask
  case 7: set.fds_bits.7 = set.fds_bits.7 | mask
  case 8: set.fds_bits.8 = set.fds_bits.8 | mask
  case 9: set.fds_bits.9 = set.fds_bits.9 | mask
  case 10: set.fds_bits.10 = set.fds_bits.10 | mask
  case 11: set.fds_bits.11 = set.fds_bits.11 | mask
  case 12: set.fds_bits.12 = set.fds_bits.12 | mask
  case 13: set.fds_bits.13 = set.fds_bits.13 | mask
  case 14: set.fds_bits.14 = set.fds_bits.14 | mask
  case 15: set.fds_bits.15 = set.fds_bits.15 | mask
  case 16: set.fds_bits.16 = set.fds_bits.16 | mask
  case 17: set.fds_bits.17 = set.fds_bits.17 | mask
  case 18: set.fds_bits.18 = set.fds_bits.18 | mask
  case 19: set.fds_bits.19 = set.fds_bits.19 | mask
  case 20: set.fds_bits.20 = set.fds_bits.20 | mask
  case 21: set.fds_bits.21 = set.fds_bits.21 | mask
  case 22: set.fds_bits.22 = set.fds_bits.22 | mask
  case 23: set.fds_bits.23 = set.fds_bits.23 | mask
  case 24: set.fds_bits.24 = set.fds_bits.24 | mask
  case 25: set.fds_bits.25 = set.fds_bits.25 | mask
  case 26: set.fds_bits.26 = set.fds_bits.26 | mask
  case 27: set.fds_bits.27 = set.fds_bits.27 | mask
  case 28: set.fds_bits.28 = set.fds_bits.28 | mask
  case 29: set.fds_bits.29 = set.fds_bits.29 | mask
  case 30: set.fds_bits.30 = set.fds_bits.30 | mask
  case 31: set.fds_bits.31 = set.fds_bits.31 | mask
  default: break
  }
}

func initServerSocket(servicePortNumber servicePortNumber: String, maxNumberOfConnectionsBeforeAccept: Int32) -> Int32? {
  var status: Int32 = 0
  
  // ==================================================================
  // Retrieve the information necessary to create the socket descriptor
  // ==================================================================
  
  // Protocol configuration, used to retrieve the data needed to create the socket descriptor
  var hints = addrinfo(
    ai_flags: AI_PASSIVE,       // Assign the address of the local host to the socket structures
    ai_family: AF_UNSPEC,       // Either IPv4 or IPv6
    ai_socktype: SOCK_STREAM,   // TCP
    ai_protocol: 0,
    ai_addrlen: 0,
    ai_canonname: nil,
    ai_addr: nil,
    ai_next: nil);
  
  // For the information needed to create a socket (result from the getaddrinfo)
  var servinfo: UnsafeMutablePointer<addrinfo> = nil;
  
  // Get the info we need to create our socket descriptor
  status = getaddrinfo(
    nil,                        // Any interface
    servicePortNumber,          // The port on which will be listenend
    &hints,                     // Protocol configuration as per above
    &servinfo);                 // The created information
  
  if status != 0 {
    let strError = String(UTF8String: gai_strerror(status)) ?? "Unknown error code";
    let message = "Getaddrinfo Error \(status) (\(strError))";
    print(message);
    return nil;
  }

  // Print a list of the found IP addresses
  if (servinfo != nil) {
    var info = servinfo;
    while true {
      if (info == nil) {
        break;
      }
      
      let (clientIp, service) = sockaddrDescription(info.memory.ai_addr);
      let message = "HostIp: " + (clientIp ?? "?") + " at port: " + (service ?? "?");
      print(message);
      
      info = info.memory.ai_next;
    }
  }

  // ============================
  // Create the socket descriptor
  // ============================
  let socketDescriptor = socket(
    servinfo.memory.ai_family,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    servinfo.memory.ai_socktype,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    servinfo.memory.ai_protocol);   // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
  
  print("Socket value: \(socketDescriptor)");
  
  if socketDescriptor == -1 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code";
    let message = "Socket creation error \(errno) (\(strError))";
    print(message);
    freeaddrinfo(servinfo)
    return nil;
  }
  
  // ========================================================================
  // Set the socket options (specifically: prevent the "socket in use" error)
  // ========================================================================
  var optval: Int = 1; // Use 1 to enable the option, 0 to disable
  
  status = setsockopt(
    socketDescriptor,               // The socket descriptor of the socket on which the option will be set
    SOL_SOCKET,                     // Type of socket options
    SO_REUSEADDR,                   // The socket option id
    &optval,                        // The socket option value
    socklen_t(sizeof(Int)));        // The size of the socket option value
  
  if status == -1 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code";
    let message = "Setsockopt error \(errno) (\(strError))";
    print(message);
    freeaddrinfo(servinfo);
    close(socketDescriptor);        // Ignore possible errors
    return nil;
  }
  
  // ====================================
  // Bind the socket descriptor to a port
  // ====================================
  
  status = bind(
    socketDescriptor,               // The socket descriptor of the socket to bind
    servinfo.memory.ai_addr,        // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    servinfo.memory.ai_addrlen);    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
  
  print("Status from binding: \(status)");
  
  if status != 0 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code";
    let message = "Binding error \(errno) (\(strError))";
    print(message);
    freeaddrinfo(servinfo);
    close(socketDescriptor);        // Ignore possible errors
    return nil;
  }
  
  // ===============================
  // Don't need the servinfo anymore
  // ===============================
  freeaddrinfo(servinfo);
  
  // ========================================
  // Start listening for incoming connections
  // ========================================
  status = listen(
    socketDescriptor,                     // The socket on which to listen
    maxNumberOfConnectionsBeforeAccept);  // The number of connections that will be allowed before they are accepted
  
  print("Status from listen: " + status.description);
  
  if status != 0 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code";
    let message = "Listen error \(errno) (\(strError))";
    print(message);
    close(socketDescriptor);        // Ignore possible errors
    return nil;
  }

  return socketDescriptor;
}

// Client ==========================================================================================

func initClientSocket(address address: String, port: String) -> Int32? {
  var status: Int32 = 0;
  
  var hints = addrinfo(
    ai_flags: AI_PASSIVE,       // Assign the address of the local host to the socket structures
    ai_family: AF_UNSPEC,       // Either IPv4 or IPv6
    ai_socktype: SOCK_STREAM,   // TCP
    ai_protocol: 0,
    ai_addrlen: 0,
    ai_canonname: nil,
    ai_addr: nil,
    ai_next: nil);
  
  var servinfo: UnsafeMutablePointer<addrinfo> = nil;
  
  status = getaddrinfo(
    address,              // The IP or URL of the server to connect to
    port,                 // The port to which will be transferred
    &hints,               // Protocol configuration as per above
    &servinfo);           // The created information
  
  if status != 0 {
    var strError: String
    if status == EAI_SYSTEM {
      strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
    } else {
      strError = String(UTF8String: gai_strerror(status)) ?? "Unknown error code"
    }
    print(strError);
    return nil;
  }
  
  var socketDescriptor: Int32?
  var info = servinfo;
  while info != nil {
    socketDescriptor = socket(
      info.memory.ai_family,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
      info.memory.ai_socktype,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
      info.memory.ai_protocol);   // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    
    if socketDescriptor == -1 {
      let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
      print(strError);
      continue;
    }
    
    let (address, service) = sockaddrDescription(info.memory.ai_addr);
    let laddress = address ?? "nil";
    let lservice = service ?? "nil";
    print("Trying to connect to \(laddress) at port \(lservice)");
    
    // Attempt to connect
    status = connect(socketDescriptor!, info.memory.ai_addr, info.memory.ai_addrlen);
    print("Result of 'connect' is \(status)");
    
    // Break if successful, log on failure.
    if status == 0 {
      print("Connection established");
      break
    } else {
      let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
      print(strError);
    }
    
    // Close the socket that was opened, the next attempt must create a new socket descriptor because the protocol family may have changed
    close(socketDescriptor!);
    socketDescriptor = nil; // Set to nil to prevent a double closing in case the last connect attempt failed
    
    // Setup for the next try
    info = info.memory.ai_next;
  }
  
  if status != 0 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
    freeaddrinfo(servinfo);
    if socketDescriptor != nil { close(socketDescriptor!) }
    print(strError);
    return nil;
  }
  
  if socketDescriptor == nil {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
    freeaddrinfo(servinfo);
    print(strError);
    return nil;
  }
  
  // Don't need the servinfo anymore
  freeaddrinfo(servinfo)
  
  // Set the socket option: prevent SIGPIPE exception
  var optval = 1;
  
  status = setsockopt(
    socketDescriptor!,
    SOL_SOCKET,
    SO_NOSIGPIPE,
    &optval,
    socklen_t(sizeof(Int)));
  
  if status == -1 {
    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
    close(socketDescriptor!);
    print(strError);
    return nil;
  }
  
  return socketDescriptor!;
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
    let replyString = "{\"Reply\":true}";
    let replyData = replyString.dataUsingEncoding(NSUTF8StringEncoding)!;
    
    let bytesSent = sendData(replyData, socket: socket, address: address);
    print("Reply sent: " + String(bytesSent));
  }
}

// =================================================================================================

let serverSocket = initServerSocket(
  servicePortNumber: "4141",
  maxNumberOfConnectionsBeforeAccept: 10);

if serverSocket == nil {
  print("serverSocket is nil!!!");
  exit(-1);
}

let acceptQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

func acceptConnectionRequests(socketDescriptor: Int32, isServer: Bool) {
  // Incoming connections will be executed in this queue (in parallel)
  let connectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  
  // ========================
  // Start the "endless" loop
  // ========================
  ACCEPT_LOOP: while true {
    // Wait for an incoming connection request
    var connectedAddrInfo = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
    var connectedAddrInfoLength = socklen_t(sizeof(sockaddr));
    let requestDescriptor = accept(socketDescriptor, &connectedAddrInfo, &connectedAddrInfoLength);
    
    if requestDescriptor == -1 {
      let strerr = String(UTF8String: strerror(errno)) ?? "Unknown error code"
      let message = "Accept error \(errno) " + strerr
      print(message);
      continue;
    }
    
    let (ipAddress, servicePort) = sockaddrDescription(&connectedAddrInfo);
    let message = "Accepted connection from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
    print(message);
    
    // Request processing of the connection request in a different dispatch queue
    dispatch_async(connectionQueue, {
      processSocketData(requestDescriptor, isServer: isServer, address: &connectedAddrInfo);
    });
  }
}

dispatch_async(acceptQueue, { acceptConnectionRequests(serverSocket!, isServer: true) });

print("Server listening ...");
sleep(3);

let clientSocket = initClientSocket(address: "127.0.0.1", port: "4141");
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
