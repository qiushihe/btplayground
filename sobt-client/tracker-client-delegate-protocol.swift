//
//  tracker-client-delegate-protocol.swift
//  sobt
//
//  Created by Billy He on 11/2/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

protocol TrackerClientDelegate {
  func trackerClientReceivedPeer(infoHash: String, peers: Array<SobtLib.TrackerAction.Announce.Peer>);
}
