//
//  main.swift
//  sobt-client
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation;

let peerId: String = "M4-20-8-" + SobtLib.Helper.String.RandomStringWithLength(12);
let peerPort: UInt16 = 4321;

let peerNode = PeerNode(id: peerId, port: peerPort)
let trackerClient = TrackerClient(id: peerId, port: peerPort);

// trackerClient.addManifest(fromPath: "/Users/billy/Projects/btplayground/test.torrent");
trackerClient.addManifest(fromMegnetLink: "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242");

SobtLib.Helper.RunLoop.StartRunLoopWithTrap(
  before: {() in
    peerNode.start();
    trackerClient.autoUpdate(5);
  },
  after: {() in
    trackerClient.stopAutoUpdate();
    peerNode.stop();
  }
);
