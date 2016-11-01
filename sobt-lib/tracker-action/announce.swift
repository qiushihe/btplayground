//
//  announce.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.TrackerAction {
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

    static func EncodeRequest(
      connectionId connectionId: UInt64, transactionId: UInt32, infoHash: String, peerId: String,
      downloaded: UInt64, left: UInt64, uploaded: UInt64, event: UInt32,
      ip: UInt32, key: UInt32, numWant: UInt32, port: UInt16, extensions: UInt16
    ) -> NSData {
      let payload = NSMutableData();
      
      var payloadConnectionId = SobtLib.Helper.Network.HostToNetwork(connectionId);
      var payloadAction = SobtLib.Helper.Network.HostToNetwork(Action.Announce.rawValue);
      var payloadTransactionId = SobtLib.Helper.Network.HostToNetwork(transactionId);
      let payloadInfoHash = SobtLib.Helper.String.HexStringToNSData(infoHash)!;
      let payloadPeerId = Array(peerId.utf8);
      var payloadDownloaded = SobtLib.Helper.Network.HostToNetwork(downloaded);
      var payloadLeft = SobtLib.Helper.Network.HostToNetwork(left);
      var payloadUploaded = SobtLib.Helper.Network.HostToNetwork(uploaded);
      var payloadEvent = SobtLib.Helper.Network.HostToNetwork(event);
      var payloadIp = SobtLib.Helper.Network.HostToNetwork(ip);
      var payloadKey = SobtLib.Helper.Network.HostToNetwork(key);
      var payloadNumWant = SobtLib.Helper.Network.HostToNetwork(numWant);
      var payloadPort = SobtLib.Helper.Network.HostToNetwork(port);
      var payloadExtensions = SobtLib.Helper.Network.HostToNetwork(extensions);
      
      payload.appendBytes(&payloadConnectionId, length: 8);
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(payloadInfoHash.bytes, length: 20);
      payload.appendBytes(payloadPeerId, length: 20);
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

    static func DecodeRequest(data: Array<UInt8>) -> Request {
      return Request(
        connectionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...7])),
        action: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        transactionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15])),
        infoHash: SobtLib.Helper.String.NSDataToHexString(NSData(bytes: Array<UInt8>(data[16...35]), length: 20)),
        peerId: String(bytes: Array<UInt8>(data[36...55]), encoding: NSUTF8StringEncoding)!,
        downloaded: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[56...63])),
        left: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[64...71])),
        uploaded: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[72...79])),
        event: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[80...83])),
        ip: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[84...87])),
        key: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[88...91])),
        numWant: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[92...95])),
        port: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[96...97])),
        extensions: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[98...99]))
      );
    }
    
    static func EncodeResponse(transactionId transactionId: UInt32, interval: UInt32, leechers: UInt32, seeders: UInt32, peers: Array<Peer>) -> NSData {
      let payload = NSMutableData();
      
      var payloadAction = SobtLib.Helper.Network.HostToNetwork(Action.Announce.rawValue);
      var payloadTransactionId = SobtLib.Helper.Network.HostToNetwork(transactionId);
      var payloadInterval = SobtLib.Helper.Network.HostToNetwork(interval);
      var payloadLeechers = SobtLib.Helper.Network.HostToNetwork(leechers);
      var payloadSeeders = SobtLib.Helper.Network.HostToNetwork(seeders);
      let payloadPeers = EncodePeers(peers);
      
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(&payloadInterval, length: 4);
      payload.appendBytes(&payloadLeechers, length: 4);
      payload.appendBytes(&payloadSeeders, length: 4);
      payload.appendBytes(payloadPeers.bytes, length: payloadPeers.length);
      
      return payload;
    }
    
    private static func EncodePeers(peers: Array<Peer>) -> NSData {
      let payload = NSMutableData();
      
      for peer in peers {
        let payloadIp = peer.ip;
        var payloadPort = SobtLib.Helper.Network.HostToNetwork(peer.port);

        payload.appendBytes(payloadIp, length: 4);
        payload.appendBytes(&payloadPort, length: 2);
      }
      
      return payload;
    }
    
    static func DecodeResponse(data: Array<UInt8>) -> Response {
      return Response(
        action: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])),
        transactionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7])),
        interval: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        leechers: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15])),
        seeders: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[16...19])),
        peers: DecodePeers(data)
      );
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
          port: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(peerChunk[4...5]))
        ));
        
        offset = offset + PeerChunkLength;
      }
      
      return peers;
    }
  }
}
