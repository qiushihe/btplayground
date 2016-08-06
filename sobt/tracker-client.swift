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
  }
}