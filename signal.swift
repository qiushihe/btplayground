//
//  signal.swift
//  sobt
//
//  Created by Billy He on 2016-10-15.
//  Copyright © 2016 Billy He. All rights reserved.
//

/*
  Sobt.Helper.Signal.TrapSignal(Sobt.Helper.Signal.SIGNAL.INT) {(signal) in
    CFRunLoopStop(CFRunLoopGetCurrent());
  }

  // Initialization code ...

  Sobt.Helper.Signal.SendSuspendSignal();
  CFRunLoopRun();
 
  // Clean up code ...
*/

import Foundation

extension Sobt.Helper {
  struct Signal {
    enum SIGNAL:Int32 {
      case HUP    = 1
      case INT    = 2
      case QUIT   = 3
      case ABRT   = 6
      case KILL   = 9
      case ALRM   = 14
      case TERM   = 15
    };
    
    static func TrapSignal(signal: SIGNAL, action: @convention(c) Int32 -> ()) {
      var signalAction = sigaction(
        __sigaction_u: unsafeBitCast(action, __sigaction_u.self),
        sa_mask: 0,
        sa_flags: 0
      );
      sigaction(signal.rawValue, &signalAction, nil);
    }
    
    static func SendSuspendSignal() {
      sigsuspend(nil);
    }
  }
}
