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
  private var peers: Dictionary<String, SobtLib.Socket.TCPSocket>;
  private let cracker: Cracker;
  private var targetHash: String? = nil;

  init(id: String, port: UInt16) {
    self.peerId = id;
    self.port = port;
    self.peers = Dictionary<String, SobtLib.Socket.TCPSocket>();
    self.cracker = Cracker(alphabet: Array<String>([
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
      "!", " "
    ]), maxLength: 12);
  }

  func start() {
    var tcpSocketOptions = SobtLib.Socket.SocketOptions();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = nil;
    tcpSocketOptions.type = SobtLib.Socket.SocketType.Server;

    self.tcpSocket = SobtLib.Socket.TCPSocket(options: tcpSocketOptions);
    self.tcpSocket!.setListener(self.handleSocketData);

    print("Peer node \(self.peerId!) listening on port \(self.port)...");

    if (self.targetHash != nil) {
      self.cracker.start(self.targetHash!);
    }
  }

  func stop() {
    self.tcpSocket?.closeSocket();
  }

  func setTargetHash(targetHash: String?) {
    self.targetHash = targetHash;
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

    if (
      self.handlePing(socket, message: dataString!) ||
      self.handlePong(socket, message: dataString!)
    ) {
      return;
    }

    print("Peer node received message: \(dataString)");
  }

  private func handlePing(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "PING ([^\\s]*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    if (matches[1] == self.peerId) {
      print("Ignored self ping");
    } else {
      self.peers[matches[1]] = socket;
      print("Registered peer \(matches[1])");

      let pongMsg = "PONG \(self.peerId!)";
      socket.sendData(pongMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }

    return true;
  }

  private func handlePong(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "PONG ([^\\s]*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    self.peers[matches[1]] = socket;
    print("Registered peer \(matches[1])");

    return true;
  }
}
