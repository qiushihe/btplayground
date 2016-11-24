//
//  main.swift
//  sobt-client
//
//  Created by Billy He on 11/1/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation;

// ./sobt-client 4321 "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242"
// ./sobt-client 4321 "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242" 499226fde1d3c2e0729388ecf031b6a7487393dd

enum SobtClientError: ErrorType {
  case InvalidArguments
}

let peerId: String = "M4-20-8-" + SobtLib.Helper.String.RandomStringWithLength(12);
var peerNode: PeerNode? = nil;
var trackerClient: TrackerClient? = nil;

do {
  let arguments = Process.arguments;
  if (arguments.count <= 2) {
    throw SobtClientError.InvalidArguments;
  }

  let port = UInt16(arguments[1]);
  if (port == nil) {
    throw SobtClientError.InvalidArguments;
  }

  let magnetLink = arguments[2];
  if (magnetLink.isEmpty) {
    throw SobtClientError.InvalidArguments;
  }

  let targetHash: String? = arguments.count > 3 ? arguments[3] : nil;

  peerNode = PeerNode(id: peerId, port: port!);
  peerNode!.setTargetHash(targetHash);

  trackerClient = TrackerClient(id: peerId, port: port!);
  trackerClient!.delegate = peerNode;
  trackerClient!.addManifest(fromMegnetLink: magnetLink);
} catch SobtClientError.InvalidArguments {
  print("Sobt Client Usage:");
  print("  sobt-client [port] [magnet-link] [target-hash]?");
  exit(0);
}

SobtLib.Helper.RunLoop.StartRunLoopWithTrap(
  before: {() in
    peerNode?.start();
    trackerClient?.autoUpdate(5);
  },
  after: {() in
    trackerClient?.stopAutoUpdate();
    peerNode?.stop();
  }
);
