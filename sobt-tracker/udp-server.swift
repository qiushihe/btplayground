//
//  udp-server.swift
//  sobt
//
//  Created by Billy He on 2016-10-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class UDPServer {
  private let port: UInt16;
  private var udpSocket: SobtLib.Socket.UDPSocket? = nil;
  private var connections = Dictionary<UInt64, ConnectionData>();

  init(port: UInt16) {
    self.port = port;
  }

  func start() {
    self.udpSocket = SobtLib.Socket.UDPSocket(port: self.port);
    
    self.udpSocket!.setListener({(socket: Int32) in
      self.handleSocketData(socket);
    });

    print("Server listening on port \(self.port)...");
  }
  
  func stop() {
    self.udpSocket?.closeSocket();
  }
  
  private func handleSocketData(socket: Int32) {
    var inAddress = sockaddr_storage();
    var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
    let buffer = [UInt8](count: SobtLib.Socket.UDPSocket.MAX_PACKET_SIZE, repeatedValue: 0);

    let bytesRead = withUnsafeMutablePointer(&inAddress) {
      recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
    };

    let (ipAddress, servicePort) = SobtLib.Socket.Socket.GetSocketHostAndPort(SobtLib.Socket.Socket.CastSocketAddress(&inAddress));
    let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
    print(message);
    
    let data = Array(buffer[0..<bytesRead]);
    print("Server received \(data.count) bytes: \(data)");

    let action = SobtLib.TrackerAction.Action.ParseRequest(data);
    if (action == SobtLib.TrackerAction.Action.Connect) {
      let request = SobtLib.TrackerAction.Connect.DecodeRequest(data);
      let replySocket = SobtLib.Socket.UDPSocket(socket: socket, address: SobtLib.Socket.Socket.CastSocketAddress(&inAddress), addressLength: inAddressLength);
      let connection = ConnectionData(SobtLib.Helper.Number.GetRandomNumber(), replySocket);
      
      self.connections[connection.connectionId] = connection;
      print("Created connection \(connection.connectionId) for transaction ID \(request.transactionId)");

      let responsePayload = SobtLib.TrackerAction.Connect.EncodeResponse(
        transactionId: request.transactionId,
        connectionId: connection.connectionId
      );
      replySocket.sendData(responsePayload);
    } else if (action == SobtLib.TrackerAction.Action.Announce) {
      let request = SobtLib.TrackerAction.Announce.DecodeRequest(data);
      print(request);
    }
  }
  
  private struct ConnectionData {
    var connectionId: UInt64 = 0;
    var status: ConnectionStatus = ConnectionStatus.Idle;
    var udpSocket: SobtLib.Socket.UDPSocket? = nil;
    
    init(_ connectionId: UInt64, _ udpSocket: SobtLib.Socket.UDPSocket) {
      self.connectionId = connectionId;
      self.udpSocket = udpSocket;
    }
  }
  
  private enum ConnectionStatus {
    case Idle;
    case Active;
    case Stale;
  }
}
