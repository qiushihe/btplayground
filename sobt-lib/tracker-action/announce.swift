//
//  announce.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerAction {
  struct Announce {
    private static let PeerChunkLength: Int = 6;
    private static let PeerChunksStartIndex: Int = 20;
    
    struct Request {
      let connectionId: UInt64;
      let action: UInt32;
      let transactionId: UInt32;
      let infoHash: String;
      let peerId: String;
      let downloaded: UInt64;
      let left: UInt64;
      let uploaded: UInt64;
      let event: UInt32;
      let ip: UInt32;
      let key: UInt32;
      let numWant: UInt32;
      let port: UInt16;
      let extensions: UInt16;
    }

    struct Response {
      let action: UInt32;
      let transactionId: UInt32;
      let interval: UInt32;
      let leechers: UInt32;
      let seeders: UInt32;
      let peers: Array<Peer>;
    }
    
    struct Peer {
      let ip: Array<UInt8>;
      let port: UInt16;
    }

    static func CreateRequest(
      connectionId connectionId: UInt64, transactionId: UInt32, infoHash: String, peerId: String,
      downloaded: UInt64, left: UInt64, uploaded: UInt64, event: UInt32,
      ip: UInt32, key: UInt32, numWant: UInt32, port: UInt16, extensions: UInt16
    ) -> NSData {
      let payload = NSMutableData();
      
      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(connectionId);
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Announce.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(transactionId);
      var payloadInfoHash = infoHash;
      var payloadPeerId = peerId;
      var payloadDownloaded = Sobt.Helper.Network.HostToNetwork(downloaded);
      var payloadLeft = Sobt.Helper.Network.HostToNetwork(left);
      var payloadUploaded = Sobt.Helper.Network.HostToNetwork(uploaded);
      var payloadEvent = Sobt.Helper.Network.HostToNetwork(event);
      var payloadIp = Sobt.Helper.Network.HostToNetwork(ip);
      var payloadKey = Sobt.Helper.Network.HostToNetwork(key);
      var payloadNumWant = Sobt.Helper.Network.HostToNetwork(numWant);
      var payloadPort = Sobt.Helper.Network.HostToNetwork(port);
      var payloadExtensions = Sobt.Helper.Network.HostToNetwork(extensions);
      
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

    static func ParseRequest(data: Array<UInt8>) -> Request {
      return Request(
        connectionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...7])),
        action: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        transactionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15])),
        infoHash: String(bytes: Array<UInt8>(data[16...19]), encoding: NSUTF8StringEncoding)!,
        peerId: String(bytes: Array<UInt8>(data[20...23]), encoding: NSUTF8StringEncoding)!,
        downloaded: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[24...31])),
        left: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[32...39])),
        uploaded: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[40...47])),
        event: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[48...51])),
        ip: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[52...55])),
        key: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[56...59])),
        numWant: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[60...63])),
        port: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[64...65])),
        extensions: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[66...67]))
      );
    }
    
    static func CreateResponse(transactionId: UInt32, interval: UInt32, leechers: UInt32, seeders: UInt32, peers: Array<Peer>) -> NSData {
      let payload = NSMutableData();
      
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Announce.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(transactionId);
      var payloadInterval = Sobt.Helper.Network.HostToNetwork(interval);
      var payloadLeechers = Sobt.Helper.Network.HostToNetwork(leechers);
      var payloadSeeders = Sobt.Helper.Network.HostToNetwork(seeders);
      // TODO: Add peers
      
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(&payloadInterval, length: 4);
      payload.appendBytes(&payloadLeechers, length: 4);
      payload.appendBytes(&payloadSeeders, length: 4);
      // TODO: Add peers
      
      return payload;
    }
    
    static func PraseResponse(data: Array<UInt8>) -> Response {
      return Response(
        action: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])),
        transactionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7])),
        interval: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        leechers: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15])),
        seeders: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[16...19])),
        peers: ParsePeers(data)
      );
    }

    private static func ParsePeers(data: Array<UInt8>) -> Array<Peer> {
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
  }
}
