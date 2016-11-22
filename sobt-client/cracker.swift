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
  private var checkedRanges: Array<(Int, Int)>;

  init(alphabet: Array<String>, maxLength: Int) {
    self.alphabet = alphabet;
    self.maxLength = maxLength;
    self.checkedRanges = Array<(Int, Int)>();
  }

  func start(target: String) {

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
