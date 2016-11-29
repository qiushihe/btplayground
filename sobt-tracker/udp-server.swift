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
    self.udpSocket!.setListener(self.handleSocketData);

    print("Server listening on port \(self.port)...");
  }
  
  func stop() {
    self.udpSocket?.closeSocket();
  }
  
  private func handleSocketData(evt: SobtLib.Socket.SocketDataEvent) {
    print("Server received \(evt.data.count) bytes: \(evt.data)");

    let replySocket = evt.outSocket as! SobtLib.Socket.UDPSocket;
    let action = SobtLib.TrackerAction.Action.ParseRequest(evt.data);

    if (action == SobtLib.TrackerAction.Action.Connect) {
      let request = SobtLib.TrackerAction.Connect.DecodeRequest(evt.data);

      var connection = ConnectionData(SobtLib.Helper.Number.GetRandomNumber(), replySocket);
      connection.ip = evt.inIp?.characters.split(".").map(String.init).map() {part in
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
      let request = SobtLib.TrackerAction.Announce.DecodeRequest(evt.data);
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
