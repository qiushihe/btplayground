//
//  peer-node.swift
//  sobt
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class PeerNode: NSObject, TrackerClientDelegate, CrackerDelegate {
  private var peerId: String;
  private let port: UInt16;
  private var state: PeerState = PeerState.Idle;
  private var tcpSocket: SobtLib.Socket.TCPSocket? = nil;
  private var peers: Dictionary<String, SobtLib.Socket.TCPSocket> = Dictionary<String, SobtLib.Socket.TCPSocket>();
  private var updateTimer: NSTimer? = nil;
  private let updateLock: NSLock = NSLock();
  private let requestLock: NSLock = NSLock();
  private var targetHash: String? = nil;
  private let cracker: Cracker = Cracker(alphabet: Array<String>([
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "!", " "
  ]), maxLength: 4); // Max 12

  private var peerRemainCounts: Array<(String, Int)> = Array<(String, Int)>();
  private var helpRange: (Int, Int)? = nil;
  private var targetMessage: String? = nil;
  private var messageFinder: String? = nil;

  init(id: String, port: UInt16) {
    self.peerId = id;
    self.port = port;

    super.init();

    self.cracker.delegate = self;
  }

  func autoUpdate(interval: Double) {
    self.stopAutoUpdate();
    self.updateTimer = NSTimer.scheduledTimerWithTimeInterval(
      interval,
      target: self,
      selector: #selector(PeerNode.update),
      userInfo: nil,
      repeats: true
    );
  }

  func stopAutoUpdate() {
    self.updateTimer?.invalidate();
    self.tcpSocket?.closeSocket();
    self.cracker.stop();
  }

  func update() {
    while (true) {
      if (self.updateLock.tryLock()) {
        break;
      }
    }

    switch (self.state) {
    case PeerState.Idle:
      if (self.targetHash != nil && !self.cracker.isRunning()) {
        self.cracker.start(self.targetHash!);
      }
      self.startListener();
      self.state = PeerState.Ready;
      break;
    case PeerState.Ready:
      if (self.targetMessage != nil) {
        if (self.messageFinder == nil) {
          self.sendMessageFound(self.targetMessage!);
        }
        self.state = PeerState.Finish;
        break;
      }

      if (self.cracker.isRunning()) {
        self.state = PeerState.Working;
        break;
      }

      if (self.peers.isEmpty) {
        self.state = PeerState.WaitForPeers;
        break;
      }

      if (self.targetHash == nil) {
        self.sendGetTarget();
        self.state = PeerState.GetTarget;
        break;
      }

      if (self.peerRemainCounts.isEmpty) {
        self.sendGetRemainCount();
        self.state = PeerState.GetRemainCount;
        break;
      }

      if (self.helpRange == nil) {
        let (peerId, peerRemain) = self.peerRemainCounts.sort {(a, b) in
          return a.1 > b.1;
        }.first!;

        if (peerRemain > 100000) {
          self.sendOfferHelp(peerId);
          self.state = PeerState.OfferHelp;
        }
        break;
      }

      self.cracker.setRange(self.helpRange!.0, endIndex: self.helpRange!.1);
      self.cracker.start(self.targetHash!);
      self.state = PeerState.Working;
      break;
    case PeerState.WaitForPeers:
      if (!self.peers.isEmpty) {
        self.state = PeerState.Ready;
      }
      break;
    case PeerState.GetTarget:
      if (self.targetHash != nil) {
        self.state = PeerState.Ready;
      }
      break;
    case PeerState.GetRemainCount:
      if (!self.peerRemainCounts.isEmpty) {
        self.state = PeerState.Ready;
      }
      break;
    case PeerState.OfferHelp:
      if (self.helpRange != nil) {
        self.state = PeerState.Ready;
      }
      break;
    case PeerState.Working:
      break;
    default: // PeerState.Finish
      self.stopAutoUpdate();
      self.state = PeerState.Idle;
      break;
    }

    self.updateLock.unlock();
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

      let pingMsg = "PING \(self.peerId)";
      peerSocket.sendData(pingMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }
  }

  func crackerFoundMessage(message: String) {
    while (true) {
      if (self.updateLock.tryLock()) {
        break;
      }
    }

    self.targetMessage = message;
    self.state = PeerState.Ready;

    self.updateLock.unlock();
  }

  func crackerFailed() {
    while (true) {
      if (self.updateLock.tryLock()) {
        break;
      }
    }

    self.cracker.stop();
    self.helpRange = nil;
    self.peerRemainCounts.removeAll();
    self.state = PeerState.Ready;

    self.updateLock.unlock();
  }

  private func startListener() {
    var tcpSocketOptions = SobtLib.Socket.SocketOptions();
    tcpSocketOptions.port = self.port;
    tcpSocketOptions.host = nil;
    tcpSocketOptions.type = SobtLib.Socket.SocketType.Server;

    self.tcpSocket = SobtLib.Socket.TCPSocket(options: tcpSocketOptions);
    self.tcpSocket!.setListener(self.handleSocketData);

    print("Peer node \(self.peerId) listening on port \(self.port)...");
  }

  private func handleSocketData(socket: SobtLib.Socket.TCPSocket) {
    while (true) {
      if (self.updateLock.tryLock()) {
        break;
      }
    }

    var handled = false;
    var handledMsg: String? = nil;

    let dataRead = socket.readData();
    let dataString = String(data: dataRead, encoding: NSUTF8StringEncoding);

    if (dataString == nil) {
      handled = true;
      handledMsg = "Peer node received \(dataRead.length) bytes: \(dataRead)";
    }

    if (!handled && (
      self.handlePing(socket, message: dataString!) ||
      self.handlePong(socket, message: dataString!) ||
      self.handleGetTarget(socket, message: dataString!) ||
      self.handleTargetIs(socket, message: dataString!) ||
      self.handleGetRemainCount(socket, message: dataString!) ||
      self.handleRemainCountIs(socket, message: dataString!) ||
      self.handleLetMeHelp(socket, message: dataString!) ||
      self.handlePleaseHelp(socket, message: dataString!) ||
      self.handleMessageFound(socket, message: dataString!)
    )) {
      handled = true;
    }

    if (!handled) {
      handled = true;
      handledMsg = "Peer node received message: \(dataString)";
    }

    if (handledMsg != nil) {
      print(handledMsg);
    }

    self.updateLock.unlock();
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

      let pongMsg = "PONG \(self.peerId)";
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

  private func sendGetTarget() {
    for (_, peerSocket) in self.peers {
      let peerMsg = "GET TARGET";
      peerSocket.sendData(peerMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }
  }

  private func handleGetTarget(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "GET TARGET").flatten());
    if (matches.isEmpty) {
      return false;
    }

    if (self.targetHash != nil) {
      let targetIsMsg = "TARGET IS \(self.targetHash!)";
      socket.sendData(targetIsMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }

    return true;
  }

  private func handleTargetIs(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "TARGET IS ([^\\s]*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    self.targetHash = matches[1];
    print("Got target \(matches[1])");

    return true;
  }

  private func sendGetRemainCount() {
    for (_, peerSocket) in self.peers {
      let peerMsg = "GET REMAIN COUNT";
      peerSocket.sendData(peerMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }
  }

  private func handleGetRemainCount(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "GET REMAIN COUNT").flatten());
    if (matches.isEmpty) {
      return false;
    }

    if (self.cracker.isRunning()) {
      let remainCountIsMsg = "REMAIN COUNT IS \(self.peerId) \(self.cracker.getRemainCount())";
      socket.sendData(remainCountIsMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }

    return true;
  }

  private func handleRemainCountIs(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "REMAIN COUNT IS ([^\\s]*) ([^\\s]*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    let peerRemainCount = (matches[1], Int(matches[2])!);
    self.peerRemainCounts.append(peerRemainCount);
    print("Got peer remain count \(peerRemainCount)");

    return true;
  }

  private func sendOfferHelp(peerId: String) {
    let peerSocket = self.peers[peerId]!;
    let peerMsg = "LET ME HELP";
    peerSocket.sendData(peerMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
  }

  private func handleLetMeHelp(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "LET ME HELP").flatten());
    if (matches.isEmpty) {
      return false;
    }

    if (self.cracker.isRunning()) {
      let (helpStart, helpEnd) = self.cracker.divideRemaining(90);
      let remainCountIsMsg = "PLEASE HELP \(helpStart) \(helpEnd)";
      socket.sendData(remainCountIsMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }

    return true;
  }

  private func handlePleaseHelp(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "PLEASE HELP ([^\\s]*) ([^\\s]*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    self.helpRange = (Int(matches[1])!, Int(matches[2])!);
    print("Got help range \(self.helpRange)");

    return true;
  }

  private func sendMessageFound(message: String) {
    for (_, peerSocket) in self.peers {
      let peerMsg = "MESSAGE FOUND \(self.peerId) \(message)";
      peerSocket.sendData(peerMsg.dataUsingEncoding(NSUTF8StringEncoding)!);
    }
  }

  private func handleMessageFound(socket: SobtLib.Socket.TCPSocket, message: String) -> Bool {
    let matches = Array(SobtLib.Helper.String.MatchingStrings(message, regex: "MESSAGE FOUND ([^\\s]*) (.*)").flatten());
    if (matches.isEmpty) {
      return false;
    }

    self.messageFinder = matches[1];
    self.targetMessage = matches[2];
    print("Got message from \(self.messageFinder): \(self.targetMessage)");

    return true;
  }

  private enum PeerState {
    case Idle;
    case Ready;
    case WaitForPeers;
    case GetTarget;
    case GetRemainCount;
    case OfferHelp;
    case Working;
    case Finish;
  }
}
