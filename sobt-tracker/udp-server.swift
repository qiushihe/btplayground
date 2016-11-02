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

    let (ipAddress, servicePort): (String?, String?) = SobtLib.Socket.Socket.GetSocketHostAndPort(SobtLib.Socket.Socket.CastSocketAddress(&inAddress));
    let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
    print(message);

    let data = Array(buffer[0..<bytesRead]);
    print("Server received \(data.count) bytes: \(data)");

    let action = SobtLib.TrackerAction.Action.ParseRequest(data);
    if (action == SobtLib.TrackerAction.Action.Connect) {
      let request = SobtLib.TrackerAction.Connect.DecodeRequest(data);
      let replySocket = SobtLib.Socket.UDPSocket(socket: socket, address: SobtLib.Socket.Socket.CastSocketAddress(&inAddress), addressLength: inAddressLength);

      var connection = ConnectionData(SobtLib.Helper.Number.GetRandomNumber(), replySocket);
      connection.ip = ipAddress?.characters.split(".").map(String.init).map() {part in
        return UInt8(part)!;
      };
      
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

      var connection = self.connections[request.connectionId]!;
      connection.port = request.port;
      connection.status = ConnectionStatus.Active;
      self.connections[connection.connectionId] = connection;
      print("Activated connection \(connection.connectionId) for transaction ID \(request.transactionId)");

      let responsePeers = self.connections.filter() {(_, connection) in
        return connection.status == ConnectionStatus.Active;
      }.map() {(_, connection) in
        return SobtLib.TrackerAction.Announce.Peer(
          ip: connection.ip!,
          port: connection.port
        );
      };

      let responsePayload = SobtLib.TrackerAction.Announce.EncodeResponse(
        transactionId: request.transactionId,
        interval: 0,
        leechers: 0,
        seeders: 0,
        peers: responsePeers
      );
      connection.udpSocket?.sendData(responsePayload);
    }
  }
  
  private struct ConnectionData {
    var connectionId: UInt64 = 0;
    var status: ConnectionStatus = ConnectionStatus.Idle;
    var udpSocket: SobtLib.Socket.UDPSocket? = nil;
    var ip: Array<UInt8>? = nil;
    var port: UInt16 = 0;
    
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
