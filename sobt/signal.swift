//
//  signals.swift
//  sobt
//
//  Created by Qiushi (Billy) He on 2016-07-06.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

enum Signal:Int32 {
  case HUP    = 1
  case INT    = 2
  case QUIT   = 3
  case ABRT   = 6
  case KILL   = 9
  case ALRM   = 14
  case TERM   = 15
};

func trapSignal(signal: Signal, action: @convention(c) Int32 -> ()) {
  var signalAction = sigaction.init(
    __sigaction_u: unsafeBitCast(action, __sigaction_u.self),
    sa_mask: 0,
    sa_flags: 0
  );
  sigaction(signal.rawValue, &signalAction, nil);
}

func sendSuspendSignal() {
  sigsuspend(nil);
}
