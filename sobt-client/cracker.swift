//
//  cracker.swift
//  sobt
//
//  Created by Billy He on 11/21/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

class Cracker {
  private let alphabet: Array<String>;
  private let maxLength: Int;
  private let maxIndex: Int;
  private var endIndex: Int;
  private var startIndex: Int = 0;
  private var curIndex: Int = 0;
  private let operationLock: NSLock = NSLock();
  private var running: Bool = false;

  init(alphabet: Array<String>, maxLength: Int) {
    self.alphabet = alphabet;
    self.maxLength = maxLength;
    self.maxIndex = Int(pow(Double(self.alphabet.count), Double(self.maxLength))) - 1;
    self.endIndex = self.maxIndex;
  }

  func start(target: String) {
    self.running = true;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
      var lastMessageTime = Int(NSDate().timeIntervalSince1970);
      while (true) {
        if (!self.operationLock.tryLock()) {
          continue;
        }

        var shouldBreak = false;
        var attemptMessage: String? = nil;

        if (self.curIndex >= self.endIndex) {
          shouldBreak = true;
          attemptMessage = "Max index reached :(";
        }

        if (!shouldBreak) {
          let message = self.itemAtIndex(self.curIndex);
          let hash = SobtLib.Helper.Crypto.SHA1(message.dataUsingEncoding(NSUTF8StringEncoding)!) as String;

          let nowTime = Int(NSDate().timeIntervalSince1970);
          if (nowTime - lastMessageTime > 5) {
            attemptMessage = "Attempting [\(self.curIndex)]: \(hash) - \(message) ...";
            lastMessageTime = nowTime;
          }

          if (hash == target) {
            shouldBreak = true;
            attemptMessage = "Message found: \(message).";
          }
        }

        if (!shouldBreak && !self.running) {
          shouldBreak = true;
          attemptMessage = "Stopped.";
        }

        if (attemptMessage != nil) {
          dispatch_async(dispatch_get_main_queue()) {
            print(attemptMessage!);
          }
        }

        self.curIndex = self.curIndex + 1;
        self.operationLock.unlock();

        if (shouldBreak) {
          self.running = false;
          break;
        }
      }
    }
  }

  func stop() {
    self.running = false;
  }

  func isRunning() -> Bool {
    return self.running;
  }

  func getRemainCount() -> Int {
    while (true) {
      if (self.operationLock.tryLock()) {
        break;
      }
    }

    let remainCount = self.endIndex - self.curIndex;

    self.operationLock.unlock();
    return remainCount;
  }

  func divideRemaining() -> (Int, Int) {
    while (true) {
      if (self.operationLock.tryLock()) {
        break;
      }
    }

    let otherEndIndex = self.endIndex;
    self.endIndex = self.curIndex + ((self.endIndex - self.curIndex) / 2);
    let otherStartIndex = self.endIndex;

    print("New end set to \(self.endIndex). Currently at \(self.curIndex). Remaining [\(otherStartIndex)..\(otherEndIndex)].");
    self.operationLock.unlock();
    return (otherStartIndex, otherEndIndex);
  }

  func setRange(startIndex: Int, endIndex: Int) {
    while (true) {
      if (self.operationLock.tryLock()) {
        break;
      }
    }

    self.startIndex = startIndex >= 0 ? startIndex : 0;
    self.endIndex = endIndex <= self.maxIndex ? endIndex : self.maxIndex;
    self.curIndex = self.curIndex < self.startIndex ? self.startIndex : self.curIndex;
    self.curIndex = self.curIndex > self.endIndex ? self.endIndex : self.curIndex;

    print("Range set to [\(self.startIndex)..\(self.endIndex)]. Currently at \(self.curIndex).");
    self.operationLock.unlock();
  }

  private func itemAtIndex(index: Int) -> String {
    var result = Array<String>();

    var rest = index;
    while (true) {
      let remainder = rest % self.alphabet.count;
      rest = rest / self.alphabet.count;

      result.append(self.alphabet[remainder]);

      if (rest == 0) {
        break;
      }
    }

    return result.reverse().joinWithSeparator("");
  }
}
