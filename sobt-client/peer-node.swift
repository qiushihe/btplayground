//
//  peer-node.swift
//  sobt
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class PeerNode: TrackerClientDelegate {
  private var peerId: String? = nil;
  private let port: UInt16;
  private var tcpSocket: SobtLib.Socket.TCPSocket? = nil;

  init(id: String, port: UInt16) {
    self.peerId = id;
    self.port = port;
  }

  func start() {
    var tcpSocketOptions = SobtLib.Socket.SocketOptions();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = nil;
    tcpSocketOptions.type = SobtLib.Socket.SocketType.Server;

    self.tcpSocket = SobtLib.Socket.TCPSocket(options: tcpSocketOptions);
    self.tcpSocket!.setListener(self.handleSocketData);

    print("Peer node listening on port \(self.port)...");
  }

  func stop() {
    self.tcpSocket?.closeSocket();
  }

  func trackerClientReceivedPeer(infoHash: String, peers: Array<SobtLib.TrackerAction.Announce.Peer>) {
    for peer in peers {
      let peerIp = peer.ip.map() {part in return "\(part)";}.joinWithSeparator(".");
      let peerPort = peer.port;
      
      var peerSocketOption = SobtLib.Socket.SocketOptions();
      peerSocketOption.port = peerPort;
      peerSocketOption.host = peerIp;
      peerSocketOption.type = SobtLib.Socket.SocketType.Client;

      let peerSocket = SobtLib.Socket.TCPSocket(options: peerSocketOption);
      peerSocket.setListener(self.handleSocketData);

      print("Peer node opened socket to \(peerIp) on \(peerPort)...");

      let pingMsg = "PING \(self.peerId!)";
      peerSocket.sendData(pingMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }
  }

  private func handleSocketData(socket: SobtLib.Socket.TCPSocket) {
    let dataRead = socket.readData();
    let dataString = String(data: dataRead, encoding: NSUTF8StringEncoding);

    if (dataString == nil) {
      print("Peer node received \(dataRead.length) bytes: \(dataRead)");
      return;
    }

    let pingMatches = Array(SobtLib.Helper.String.MatchingStrings(dataString!, regex: "PING ([^\\(\\)]*)").flatten());
    if (!pingMatches.isEmpty) {
      let pingPeerId = pingMatches[1];
      if (pingPeerId == self.peerId) {
        print("Self ping -- ignored.");
        return;
      }
    }

    print("Peer node received message: \(dataString)");
  }
}
