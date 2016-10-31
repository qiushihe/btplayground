//
//  action.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerAction {
  enum Action: UInt32 {
    case Connect = 0;
    case Announce = 1;
    case Scrape = 2;
    case Error = 3;
  }
}
