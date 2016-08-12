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
            self.connections[connectionUUID] = ConnectionData(connectionUUID, url);
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
      
      self.updating = false;
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
        var payloadAction = htonl(TrackerAction.Connect.rawValue);
        var payloadTransactionId = htonl(connectionData.transactionId);
        
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
      } else {
        print("Unhandled action: \(action)");
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
      let url: String;
      var status: ConnectionStatus = ConnectionStatus.Idle;
      var udpSocket: UDPSocket? = nil;
      var connectionId: UInt64 = 0;
      var transactionId: UInt32 = 0;

      init(_ uuid: String, _ url: String) {
        self.uuid = uuid;
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
