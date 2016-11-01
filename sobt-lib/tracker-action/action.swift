//
//  action.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.TrackerAction {
  enum Action: UInt32 {
    case Connect = 0;
    case Announce = 1;
    case Scrape = 2;
    case Error = 3;
    
    static func ParseResponse(data: Array<UInt8>) -> Action? {
      return Action(rawValue: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])));
    }
    
    static func ParseRequest(data: Array<UInt8>) -> Action? {
      let conectionId: UInt64 = SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...7]));
      let action: UInt32 = SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11]));
      
      if (conectionId == SobtLib.TrackerAction.Connect.MagicNumber) {
        return Action.Connect;
      } else {
        return Action(rawValue: action);
      }
    }
  }
}
