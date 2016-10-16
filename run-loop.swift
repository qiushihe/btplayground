//
//  run-loop.swift
//  sobt
//
//  Created by Billy He on 2016-10-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Helper {
  struct RunLoop {
    static func StartRunLoopWithTrap(before beforeRunLoop: () -> (), after afterRunLoop: () -> ()) {
      Sobt.Helper.Signal.TrapSignal(Sobt.Helper.Signal.SIGNAL.INT) {(signal) in
        CFRunLoopStop(CFRunLoopGetCurrent());
      }
      
      beforeRunLoop();
      
      CFRunLoopRun();

      afterRunLoop();
    }
  }
}
