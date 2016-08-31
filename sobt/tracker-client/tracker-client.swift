//
//  tracker-client.swift
//  sobt
//
//  Created by Billy He on 2016-08-06.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt {
  class TrackerClient : NSObject {
    private var manifests = Dictionary<String, ManifestData>();
    private var connections = Dictionary<String, ConnectionData>();
    private var updating = false;
    private var updateTimer: NSTimer? = nil;
    
    func addManifest(fromPath path: String) {
      var manifest = ManifestData();
      manifest.path = path;
      manifest.sourceData = NSData(contentsOfFile: path);
      
      let decoder = BEncodingDecoder(data: manifest.sourceData!);
      manifest.decodedData = decoder.decode();
      manifest.infoData = decoder.getInfoValue();
      manifest.infoValue = decoder.getInfoValue();
      manifest.infoHash = Sobt.Crypto.SHA1(manifest.infoData!);
      
      self.manifests[manifest.uuid] = manifest;
      print("Added manifest from \(path)");
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
      if (self.updating) {
        return;
      } else {
        self.updating = true;
      }

      // Queue connections
      for (_, (uuid, _)) in self.manifests.enumerate() {
        for (_, url) in self.getTrackers(uuid).enumerate() {
          let connectionUUID = uuid + "@" + url;
          if (self.connections[connectionUUID] == nil) {
            self.connections[connectionUUID] = ConnectionData(connectionUUID, uuid, url);
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
        let hasAnnounced = data.announced;
        
        // TODO: If no response to a request is received within 15 seconds, resend the request.
        // TODO: If no reply has been received after 60 seconds, stop retrying.

        if (isIdle && hasConnected && !hasAnnounced) {
          self.announceToTracker(uuid);
        }
      }
      
      self.updating = false;
    }
    
    private func announceToTracker(connectionUUID: String) {
      var connectionData = self.connections[connectionUUID]!;
      let manifest = self.manifests[connectionData.manifestUUID]!;
      
      connectionData.transactionId = Sobt.Util.GetRandomNumber();
      connectionData.status = ConnectionStatus.Active;
      
      let payload = NSMutableData();
      
      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(connectionData.connectionId);
      var payloadAction = Sobt.Helper.Network.HostToNetwork(TrackerAction.Announce.rawValue as UInt32);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(connectionData.transactionId as UInt32);
      var payloadInfoHash = manifest.infoHash!;
      var payloadPeerId = "12345678901234567890";
      var payloadDownloaded = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadLeft = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadUploaded = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadEvent = Sobt.Helper.Network.HostToNetwork(0 as UInt32);
      var payloadIp = Sobt.Helper.Network.HostToNetwork(0 as UInt32);
      var payloadKey = Sobt.Helper.Network.HostToNetwork(Sobt.Util.GetRandomNumber());
      var payloadNumWant = Sobt.Helper.Network.HostToNetwork(999 as UInt32);
      var payloadPort = Sobt.Helper.Network.HostToNetwork(4321 as UInt16);
      var payloadExtensions = Sobt.Helper.Network.HostToNetwork(0 as UInt16);
      
      payload.appendBytes(&payloadConnectionId, length: 8);
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(&payloadInfoHash, length: 20);
      payload.appendBytes(&payloadPeerId, length: 20);
      payload.appendBytes(&payloadDownloaded, length: 8);
      payload.appendBytes(&payloadLeft, length: 8);
      payload.appendBytes(&payloadUploaded, length: 8);
      payload.appendBytes(&payloadEvent, length: 4);
      payload.appendBytes(&payloadIp, length: 4);
      payload.appendBytes(&payloadKey, length: 4);
      payload.appendBytes(&payloadNumWant, length: 4);
      payload.appendBytes(&payloadPort, length: 2);
      payload.appendBytes(&payloadExtensions, length: 2);
      
      self.connections[connectionUUID] = connectionData;

      print("Accounce to \(connectionData.url)");
      connectionData.udpSocket!.sendData(payload);
    }
    
    private func establishConnection(connectionUUID: String) {
      var connectionData = self.connections[connectionUUID]!;
      let url = NSURL(string: connectionData.url)!;

      if (url.host == "tracker.coppersurfer.tk") {
        connectionData.udpSocket = UDPSocket(port: UInt16(url.port!.integerValue), host: url.host);
        connectionData.udpSocket!.setListener({(data: Array<UInt8>) in
          self.handleSocketData(data);
        })
        
        connectionData.transactionId = Sobt.Util.GetRandomNumber();
        connectionData.status = ConnectionStatus.Active;
        
        let payload = NSMutableData();
        
        // Magic number 0x41727101980
        var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(0x41727101980 as UInt64);
        var payloadAction = Sobt.Helper.Network.HostToNetwork(TrackerAction.Connect.rawValue as UInt32);
        var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(connectionData.transactionId as UInt32);
        
        payload.appendBytes(&payloadConnectionId, length: 8);
        payload.appendBytes(&payloadAction, length: 4);
        payload.appendBytes(&payloadTransactionId, length: 4);
        
        self.connections[connectionUUID] = connectionData;

        print("Connecting to \(connectionData.url)");
        connectionData.udpSocket!.sendData(payload);
      }
    }
    
    private func getTrackers(uuid: String) -> Array<String> {
      let data = self.manifests[uuid]!;
      let manifest = data.decodedData!.value as! Dictionary<String, BEncoded>;
      
      var trackers = Array<String>();
      
      let announce = manifest["announce"];
      if (announce != nil) {
        trackers.append(announce!.value as! String);
      }
      
      let announceList = manifest["announce-list"];
      if (announceList != nil) {
        for (_, tier) in (announceList!.value as! Array<BEncoded>).enumerate() {
          for (_, url) in (tier.value as! Array<BEncoded>).enumerate() {
            if (trackers.indexOf(url.value as! String) == nil) {
              trackers.append(url.value as! String);
            }
          }
        }
      }
      
      return trackers;
    }
    
    private func handleSocketData(data: Array<UInt8>) {
      let action = TrackerAction(rawValue: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])));
      
      if (action == TrackerAction.Connect) {
        let transactionId: UInt32 = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7]));
        let result = self.connections.filter({(_, connection) in
          return connection.transactionId == transactionId;
        });
        
        if (!result.isEmpty) {
          var (uuid, connectionData) = result.first!;
          
          connectionData.connectionId = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...15]));
          connectionData.status = ConnectionStatus.Idle;
          
          self.connections[uuid] = connectionData;
          print("Got connection ID \(connectionData.connectionId) for transaction \(transactionId) for connection \(connectionData.uuid)");
        } else {
          print("No connection found for transaction \(transactionId)");
        }
      } else if (action == TrackerAction.Announce) {
        let transactionId: UInt32 = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7]));
        let result = self.connections.filter({(_, connection) in
          return connection.transactionId == transactionId;
        });
        
        if (!result.isEmpty) {
          var (uuid, connectionData) = result.first!;
          
          print("Accounce data \(data)");
          /* [
           0, 0, 0, 1,        // action
           64, 169, 213, 224, // transaction_id
           0, 0, 6, 128,      // interval
           0, 0, 0, 0,        // leechers
           0, 0, 0, 1,        // seeders
           
           24, 108, 9, 247,   // ip
           16, 225            // port
          ] */
          
          connectionData.announceInterval = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11]));
          connectionData.status = ConnectionStatus.Idle;
          connectionData.announced = true;

          self.connections[uuid] = connectionData;
          // print("Got connection ID \(connectionData.connectionId) for transaction \(transactionId) for connection \(connectionData.uuid)");
        } else {
          print("No connection found for transaction \(transactionId)");
        }
      } else {
        print("Unhandled action: \(action) with data: \(data)");
      }
    }

    private struct ManifestData {
      let uuid: String;
      var path: String? = nil;
      var sourceData: NSData? = nil;
      var decodedData: BEncoded? = nil;
      var infoData: NSData? = nil;
      var infoValue: String? = nil;
      var infoHash: String? = nil;

      init() {
        self.uuid = NSUUID().UUIDString;
      }
    }

    private struct ConnectionData {
      let uuid: String;
      let manifestUUID: String;
      let url: String;
      var status: ConnectionStatus = ConnectionStatus.Idle;
      var udpSocket: UDPSocket? = nil;
      var connectionId: UInt64 = 0;
      var transactionId: UInt32 = 0;
      var announceInterval: UInt32 = 0;
      var announced = false;

      init(_ uuid: String, _ manifestUUID: String, _ url: String) {
        self.uuid = uuid;
        self.manifestUUID = manifestUUID;
        self.url = url;
      }
    }
    
    private enum ConnectionStatus {
      case Idle;
      case Active;
      case Stale;
    }
    
    private enum TrackerAction: UInt32 {
      case Connect = 0;
      case Announce = 1;
      case Scrape = 2;
      case Error = 3;
    }
  }
}
