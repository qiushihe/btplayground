//
//  cracker-delegate-protocol.swift
//  sobt
//
//  Created by Billy He on 11/24/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

protocol CrackerDelegate {
  func crackerFoundMessage(message: String);
  func crackerFailed();
}
