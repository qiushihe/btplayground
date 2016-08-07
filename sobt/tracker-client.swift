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
      // Queue connections
      for (_, (uuid, _)) in self.manifests.enumerate() {
        for (_, url) in self.getTrackers(uuid).enumerate() {
          let connectionKey = uuid + "@" + url;
          if (self.connections[connectionKey] == nil) {
            self.connections[connectionKey] = ConnectionData(uuid, url);
          }
        }
      }
      
      print(self.connections);
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
    
    struct ManifestData {
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

    struct ConnectionData {
      let uuid: String;
      let url: String;
      var status: ConnectionStatus = ConnectionStatus.Idle;

      init(_ uuid: String, _ url: String) {
        self.uuid = uuid;
        self.url = url;
      }
    }
    
    enum ConnectionStatus {
      case Idle;
      case Active;
      case Stale;
    }
  }
}