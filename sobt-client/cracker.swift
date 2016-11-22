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
  private var curIndex: Int;
  private var peerIndex: Int;
  private var peerCount: Int;

  init(alphabet: Array<String>, maxLength: Int) {
    self.alphabet = alphabet;
    self.maxLength = maxLength;

    self.maxIndex = Int(pow(Double(self.alphabet.count), Double(self.maxLength))) - 1;
    self.curIndex = 0;

    self.peerIndex = 0;
    self.peerCount = 1;
  }

  func start(target: String) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
      while (true) {
        if (self.curIndex >= self.maxIndex) {
          dispatch_async(dispatch_get_main_queue()) {
            print("Max index reached :(");
          }
          break;
        }

        let message = self.itemAtIndex(self.curIndex);
        let hash = SobtLib.Helper.Crypto.SHA1(message.dataUsingEncoding(NSUTF8StringEncoding)!) as String;

        dispatch_async(dispatch_get_main_queue()) {
          // print("Attempting [\(self.curIndex)]: \(hash) - \(message)");
        }

        if (hash == target) {
          dispatch_async(dispatch_get_main_queue()) {
            print("Message found: \(message)");
          }
          break;
        }

        self.curIndex = self.curIndex + 1;
      }
    }
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
