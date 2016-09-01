//
//  connect.swift
//  sobt
//
//  Created by Billy He on 8/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerClient {
  class ConnectRequest {
    private static let MagicNumber = 0x41727101980 as UInt64;

    private let transactionId: UInt32;
    
    init(transactionId: UInt32) {
      self.transactionId = transactionId;
    }
    
    func getPayload() -> NSData {
      let payload = NSMutableData();

      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(ConnectRequest.MagicNumber);
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Connect.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(self.transactionId);
      
      payload.appendBytes(&payloadConnectionId, length: 8);
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      
      return payload;
    }

    struct Response {
      let action: UInt32;
      let transactionId: UInt32;
      let connectionId: UInt64;
      
      init(_ data: Array<UInt8>) {
        self.action = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3]));
        self.transactionId = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7]));
        self.connectionId = Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...15]));
      }
    }
  }
}