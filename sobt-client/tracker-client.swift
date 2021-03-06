//
//  tracker-client.swift
//  sobt
//
//  Created by Billy He on 2016-08-06.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class TrackerClient : NSObject {
  var delegate: TrackerClientDelegate? = nil;

  private var peerId: String? = nil;
  private var port: UInt16? = nil;
  private var manifests = Dictionary<String, ManifestData>();
  private var connections = Dictionary<String, ConnectionData>();
  private var updateTimer: NSTimer? = nil;
  private let updateLock: NSLock = NSLock();

  init(id: String, port: UInt16) {
    self.peerId = id;
    self.port = port;
  }

  func addManifest(fromPath path: String) {
    print("Adding manifest from \(path)");

    let sourceData: NSData? = NSData(contentsOfFile: path);
    let decoder = SobtLib.Bencoding.BEncodingDecoder(data: sourceData!);
    let decodedData: SobtLib.Bencoding.BEncoded = decoder.decode();
    let infoData: NSData = decoder.getInfoValue();

    self.addManifest(withInfoHash: SobtLib.Helper.Crypto.SHA1(infoData), andTrackers: self.getTrackers(decodedData));
  }

  func addManifest(fromMegnetLink link: String) {
    print("Adding manifest from \(link)");

    let (infoHash, trackers) = SobtLib.Helper.MagnetLink.Parse(link);

    if (infoHash != nil && !trackers.isEmpty) {
      self.addManifest(withInfoHash: infoHash!, andTrackers: trackers);
    }
  }

  func addManifest(withInfoHash infoHash: String, andTracker tracker: String) {
    self.addManifest(withInfoHash: infoHash, andTrackers: Array<String>(arrayLiteral: tracker));
  }

  func addManifest(withInfoHash infoHash: String, andTrackers trackers: Array<String>) {
    let manifest = ManifestData(infoHash, trackers);
    self.manifests[manifest.infoHash] = manifest;

    print("Added manifest:");
    print("* Info hash: \(manifest.infoHash)");
    print("* Trackers: \(manifest.trackers)");
  }

  func autoUpdate(interval: Double) {
    self.stopAutoUpdate();
    self.updateTimer = NSTimer.scheduledTimerWithTimeInterval(
      interval,
      target: self,
      selector: #selector(TrackerClient.update),
      userInfo: nil,
      repeats: true
    );
  }

  func stopAutoUpdate() {
    self.updateTimer?.invalidate();
  }

  func update() {
    while (true) {
      if (self.updateLock.tryLock()) {
        break;
      }
    }

    // Queue connections
    for (_, (infoHash, manifest)) in self.manifests.enumerate() {
      for (url) in manifest.trackers {
        let connectionUUID = infoHash + "@" + url;
        if (self.connections[connectionUUID] == nil) {
          self.connections[connectionUUID] = ConnectionData(connectionUUID, infoHash, url);
        }
      }
    }

    // Activate idle connections
    for (_, (uuid, data)) in self.connections.enumerate() {
      let isIdle = data.status == ConnectionStatus.Idle;
      let hasConnected = data.connectionId > 0;

      // TODO: If no response to a request is received within 15 seconds, resend the request.
      // TODO: If no reply has been received after 60 seconds, stop retrying.

      if (isIdle && !hasConnected) {
        self.establishConnection(uuid);
      }
    }

    // Accounce
    for (_, (uuid, data)) in self.connections.enumerate() {
      let isIdle = data.status == ConnectionStatus.Idle;
      let hasConnected = data.connectionId > 0;
      let hasAnnounced = data.peers != nil;

      // TODO: If no response to a request is received within 15 seconds, resend the request.
      // TODO: If no reply has been received after 60 seconds, stop retrying.

      if (isIdle && hasConnected && !hasAnnounced) {
        self.announceToTracker(uuid);
      }
    }

    self.updateLock.unlock();
  }

  private func announceToTracker(connectionUUID: String) {
    var connectionData = self.connections[connectionUUID]!;
    let manifest = self.manifests[connectionData.infoHash]!;

    connectionData.transactionId = SobtLib.Helper.Number.GetRandomNumber();
    connectionData.status = ConnectionStatus.Active;

    self.connections[connectionUUID] = connectionData;

    print("Accouncing to \(connectionData.url)");
    let requestPayload = SobtLib.TrackerAction.Announce.EncodeRequest(
      connectionId: connectionData.connectionId,
      transactionId: connectionData.transactionId,
      infoHash: manifest.infoHash,
      peerId: self.peerId!,
      downloaded: 0,
      left: 0,
      uploaded: 0,
      event: 0,
      ip: 0,
      key: SobtLib.Helper.Number.GetRandomNumber(),
      numWant: 9999,
      port: self.port!,
      extensions: 0
    );
    connectionData.udpSocket!.sendData(requestPayload);
  }

  private func establishConnection(connectionUUID: String) {
    var connectionData = self.connections[connectionUUID]!;
    let url = NSURL(string: connectionData.url)!;

    // if (url.host != "tracker.coppersurfer.tk") { return; }

    var udpSocketOptions = SobtLib.Socket.SocketOptions();
    udpSocketOptions.host = url.host;
    udpSocketOptions.port = UInt16(url.port!.integerValue);
    udpSocketOptions.type = SobtLib.Socket.SocketType.Client;

    connectionData.udpSocket = SobtLib.Socket.UDPSocket(options: udpSocketOptions);
    connectionData.udpSocket!.setListener(self.handleSocketData);

    connectionData.transactionId = SobtLib.Helper.Number.GetRandomNumber();
    connectionData.status = ConnectionStatus.Active;

    self.connections[connectionUUID] = connectionData;

    print("Connecting to \(connectionData.url)");
    let requestPayload = SobtLib.TrackerAction.Connect.EncodeRequest(transactionId: connectionData.transactionId);
    connectionData.udpSocket!.sendData(requestPayload);
  }

  private func getTrackers(data: SobtLib.Bencoding.BEncoded) -> Array<String> {
    let manifest = data.value as! Dictionary<String, SobtLib.Bencoding.BEncoded>;

    var trackers = Array<String>();

    let announce = manifest["announce"];
    if (announce != nil) {
      trackers.append(announce!.value as! String);
    }

    let announceList = manifest["announce-list"];
    if (announceList != nil) {
      for (_, tier) in (announceList!.value as! Array<SobtLib.Bencoding.BEncoded>).enumerate() {
        for (_, url) in (tier.value as! Array<SobtLib.Bencoding.BEncoded>).enumerate() {
          if (trackers.indexOf(url.value as! String) == nil) {
            trackers.append(url.value as! String);
          }
        }
      }
    }

    return trackers;
  }

  private func handleSocketData(evt: SobtLib.Socket.SocketDataEvent) {
    let action = SobtLib.TrackerAction.Action.ParseResponse(evt.data);

    if (action == SobtLib.TrackerAction.Action.Connect) {
      let response = SobtLib.TrackerAction.Connect.DecodeResponse(evt.data);
      let result = self.connections.filter({(_, connection) in
        return connection.transactionId == response.transactionId;
      });

      if (!result.isEmpty) {
        var (uuid, connectionData) = result.first!;

        connectionData.connectionId = response.connectionId;
        connectionData.status = ConnectionStatus.Idle;

        print("Got connection ID \(connectionData.connectionId) for transaction \(response.transactionId) for connection \(connectionData.uuid)");
        self.connections[uuid] = connectionData;
      } else {
        print("No connection found for transaction \(response.transactionId)");
      }
    } else if (action == SobtLib.TrackerAction.Action.Announce) {
      let response = SobtLib.TrackerAction.Announce.DecodeResponse(evt.data);
      let result = self.connections.filter({(_, connection) in
        return connection.transactionId == response.transactionId;
      });

      if (!result.isEmpty) {
        var (uuid, connectionData) = result.first!;

        connectionData.announceInterval = response.interval;
        connectionData.peers = response.peers;
        connectionData.status = ConnectionStatus.Idle;

        print("Got peers \(response.peers) for transaction \(response.transactionId) for connection \(connectionData.uuid)");
        self.connections[uuid] = connectionData;
        self.delegate?.trackerClientReceivedPeer(connectionData.infoHash, peers: response.peers);
      } else {
        print("No connection found for transaction \(response.transactionId)");
      }
    } else {
      print("Unhandled action: \(action) with data: \(evt.data)");
    }
  }

  private struct ManifestData {
    var infoHash: String;
    var trackers: Array<String>;

    init(_ infoHash: String, _ trackers: Array<String>) {
      self.infoHash = infoHash;
      self.trackers = trackers;
    }
  }

  private struct ConnectionData {
    let uuid: String;
    let infoHash: String;
    let url: String;
    var status: ConnectionStatus = ConnectionStatus.Idle;
    var udpSocket: SobtLib.Socket.UDPSocket? = nil;
    var connectionId: UInt64 = 0;
    var transactionId: UInt32 = 0;
    var announceInterval: UInt32 = 0;
    var peers: Array<SobtLib.TrackerAction.Announce.Peer>? = nil;

    init(_ uuid: String, _ infoHash: String, _ url: String) {
      self.uuid = uuid;
      self.infoHash = infoHash;
      self.url = url;
    }
  }

  private enum ConnectionStatus {
    case Idle;
    case Active;
    case Stale;
  }
}
