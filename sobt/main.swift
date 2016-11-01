//
//  main.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-06-26.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation;

let trackerClient = Sobt.TrackerClient.TrackerClient();

// trackerClient.addManifest(fromPath: "/Users/billy/Projects/btplayground/test.torrent");
trackerClient.addManifest(fromMegnetLink: "magnet:?xt=urn:btih:f36ccb2248d556663e18490d679b5d914a7e8f63&tr=udp://127.0.0.1:4242");

trackerClient.setPort(4321);

Sobt.Helper.RunLoop.StartRunLoopWithTrap(
  before: {() in
    trackerClient.autoUpdate(5);
  },
  after: {() in
    trackerClient.stopAutoUpdate();
  }
);
