//
//  action.swift
//  sobt
//
//  Created by Billy He on 8/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerClient {
  enum Action: UInt32 {
    case Connect = 0;
    case Announce = 1;
    case Scrape = 2;
    case Error = 3;
    
    static func Parse(data: Array<UInt8>) -> Action? {
      return Action(rawValue: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])));
    }
  }
}
