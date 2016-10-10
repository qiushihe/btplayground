//
//  announce.swift
//  sobt
//
//  Created by Billy He on 8/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerClient {
  class AnnounceRequest {
    private let connectionId: UInt64;
    private let transactionId: UInt32;
    private let infoHash: String;
    private let peerId: String;
    private let port: UInt16;

    init(connectionId: UInt64, transactionId: UInt32, infoHash: String, peerId: String, port: UInt16) {
      self.connectionId = connectionId;
      self.transactionId = transactionId;
      self.infoHash = infoHash;
      self.peerId = peerId;
      self.port = port;
    }
    
    func getPayload() -> NSData {
      let payload = NSMutableData();
      
      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(self.connectionId);
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Announce.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(self.transactionId);
      var payloadInfoHash = self.infoHash;
      var payloadPeerId = self.peerId;
      var payloadDownloaded = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadLeft = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadUploaded = Sobt.Helper.Network.HostToNetwork(0 as UInt64);
      var payloadEvent = Sobt.Helper.Network.HostToNetwork(0 as UInt32);
      var payloadIp = Sobt.Helper.Network.HostToNetwork(0 as UInt32);
      var payloadKey = Sobt.Helper.Network.HostToNetwork(Sobt.Helper.Number.GetRandomNumber());
      var payloadNumWant = Sobt.Helper.Network.HostToNetwork(9999 as UInt32);
      var payloadPort = Sobt.Helper.Network.HostToNetwork(self.port);
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

      return payload;
    }
    
    struct Response {
      private static let PeerChunkLength: Int = 6;
      private static let PeerChunksStartIndex: Int = 20;

      let action: UInt32;
      let transactionId: UInt32;
      let interval: UInt32;
      let leechers: UInt32;
      let seeders: UInt32;
      let peers: Array<Peer>;

      init(_ data: Array<UInt8>) {
        self.action = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3]));
        self.transactionId = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7]));
        self.interval = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11]));
        self.leechers = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15]));
        self.seeders = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[16...19]));
        self.peers = Response.DecodePeers(data);
      }

      private static func DecodePeers(data: Array<UInt8>) -> Array<Peer> {
        var offset = 0;
        var peers = Array<Peer>();
        let peerData = Array<UInt8>(data[PeerChunksStartIndex...(data.count - 1)]);

        while true {
          let peerChunkEnd = offset + PeerChunkLength - 1;
          if (peerChunkEnd > (peerData.count - 1)) {
            break;
          }

          let peerChunk = Array<UInt8>(peerData[offset...peerChunkEnd]);
          
          peers.append(Peer(
            ip: Array<UInt8>(peerChunk[0...3]),
            port: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(peerChunk[4...5]))
          ));

          offset = offset + PeerChunkLength;
        }

        return peers;
      }
      
      struct Peer {
        let ip: Array<UInt8>;
        let port: UInt16;
        
        init(ip: Array<UInt8>, port: UInt16) {
          self.ip = ip;
          self.port = port;
        }
      }
    }
  }
}
