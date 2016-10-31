//
//  magnet-link.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.Helper {
  struct MagnetLink {
    static func Parse(link: Swift.String) -> (Swift.String?, Array<Swift.String>) {
      var infoHash: Swift.String? = nil;
      var trackers: Array<Swift.String> = Array<Swift.String>();

      let matches = Array(Sobt.Helper.String.MatchingStrings(link, regex: "^magnet:(\\?[^\\?&]*)?(&[^&]*)*").flatten());
      if (!matches.isEmpty) {
        matches[1...(matches.count - 1)].forEach {(match) in
          let infoHashMatches = Array(Sobt.Helper.String.MatchingStrings(match, regex: "^(\\?|&)xt=urn:btih:(.*)").flatten());
          if (!infoHashMatches.isEmpty) {
            infoHash = infoHashMatches[2];
          }
          
          let trackerMatches = Array(Sobt.Helper.String.MatchingStrings(match, regex: "^(\\?|&)tr=(.*)").flatten());
          if (!trackerMatches.isEmpty) {
            trackers.append(trackerMatches[2]);
          }
        }
      }

      return (infoHash, trackers);
    }
  }
}
