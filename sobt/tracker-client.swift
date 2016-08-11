//
//  tracker-client.swift
//  sobt
//
//  Created by Billy He on 2016-08-06.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt {
  class TrackerClient {
    private var manifests = Dictionary<String, ManifestData>();
    private var connections = Dictionary<String, ConnectionData>();
    private var updating = false;
    
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
          let connectionKey = uuid + "@" + url;
          if (self.connections[connectionKey] == nil) {
            self.connections[connectionKey] = ConnectionData(uuid, url);
          }
        }
      }
      
      // Activate idle connections
      for (_, (uuid, data)) in self.connections.enumerate() {
        let isIdle = data.status == ConnectionStatus.Idle;
        let hasConnected = data.connectionId <= 0;

        if (isIdle && hasConnected) {
          self.establishConnection(uuid);
        }
      }
      
      self.updating = false;
    }
    
    private func establishConnection(connectionUUID: String) {
      var connectionData = self.connections[connectionUUID]!;
      let url = NSURL(string: connectionData.url)!;

      if (url.host == "tracker.coppersurfer.tk") {
        print(url);
        print(url.host);
        print(url.port);
        
        connectionData.udpSocket = UDPSocket(port: UInt16(url.port!.integerValue), host: url.host);
        
        connectionData.udpSocket!.setListener({(socket: Int32) in
          self.onSocketData(socket);
        });
        
        connectionData.transactionId = Sobt.Util.GetRandomNumber();
        
        let payload = NSMutableData();
        
        // Magic number 0x41727101980
        var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(0x41727101980 as UInt64);
        var payloadAction = htonl(TrackerAction.Connect.rawValue);
        var payloadTransactionId = htonl(connectionData.transactionId);
        
        payload.appendBytes(&payloadConnectionId, length: 8);
        payload.appendBytes(&payloadAction, length: 4);
        payload.appendBytes(&payloadTransactionId, length: 4);
        
        print("Payload \(payload.length) bytes: \(Sobt.Util.NSDataToArray(payload))");
        
        connectionData.status = ConnectionStatus.Active;
        self.connections[connectionUUID] = connectionData;

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
    
    private func onSocketData(socket: Int32) {
      var inAddress = sockaddr_storage();
      var inAddressLength = socklen_t(sizeof(sockaddr_storage.self));
      let buffer = [UInt8](count: 4096, repeatedValue: 0);
      
      let bytesRead = withUnsafeMutablePointer(&inAddress) {
        recvfrom(socket, UnsafeMutablePointer<Void>(buffer), buffer.count, 0, UnsafeMutablePointer($0), &inAddressLength);
      };
      
      let (ipAddress, servicePort) = Socket.GetSocketHostAndPort(Socket.CastSocketAddress(&inAddress));
      let message = "Got data from: " + (ipAddress ?? "nil") + ", from port:" + (servicePort ?? "nil");
      print(message);

      let dataRead = buffer[0..<bytesRead];
      self.handleSocketData(Array<UInt8>(dataRead));
    }
    
    private func handleSocketData(data: Array<UInt8>) {
      print("Handle \(data.count) bytes of data: \(data)");

      let action = TrackerAction(rawValue: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])));
      
      if (action == TrackerAction.Connect) {
        let transactionId: UInt32 = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7]));
        
        let result = self.connections.filter({(_, connection) in
          return connection.transactionId == transactionId;
        });
        
        print(result);
        
        if (!result.isEmpty) {
          var (uuid, connectionData) = result.first!;

          connectionData.connectionId = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...15]));
          connectionData.status = ConnectionStatus.Idle;

          self.connections[uuid] = connectionData;
          print("connectionData: \(connectionData)");
        }
      } else {
        print("action: \(action)");
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
