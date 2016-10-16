//
//  main.swift
//  sobt-tracker
//
//  Created by Billy He on 10/13/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

let server = UDPServer(port: 4242);

Sobt.Helper.RunLoop.StartRunLoopWithTrap(
  before: {() in
    server.start();
  },
  after: {() in
    server.stop();
  }
);
