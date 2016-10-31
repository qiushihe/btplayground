//
//  connect.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension Sobt.TrackerAction {
  struct Connect {
    private static let MagicNumber = 0x41727101980 as UInt64;
    
    struct Request {
      let connectionId: UInt64;
      let action: UInt32;
      let transactionId: UInt32;
    }
    
    struct Response {
      let action: UInt32;
      let transactionId: UInt32;
      let connectionId: UInt64;
    }

    static func CreateRequest(transactionId: UInt32) -> NSData {
      let payload = NSMutableData();
      
      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(MagicNumber);
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Connect.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(transactionId);
      
      payload.appendBytes(&payloadConnectionId, length: 8);
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      
      return payload;
    }
    
    static func ParseRequest(data: Array<UInt8>) -> Request {
      return Request(
        connectionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...7])),
        action: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        transactionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15]))
      );
    }
    
    static func CreateResponse(transactionId: UInt32, connectionId: UInt64) -> NSData {
      let payload = NSMutableData();
      
      var payloadAction = Sobt.Helper.Network.HostToNetwork(Action.Connect.rawValue);
      var payloadTransactionId = Sobt.Helper.Network.HostToNetwork(transactionId);
      var payloadConnectionId = Sobt.Helper.Network.HostToNetwork(connectionId);
      
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(&payloadConnectionId, length: 8);

      return payload;
    }

    static func PraseResponse(data: Array<UInt8>) -> Response {
      return Response(
        action: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])),
        transactionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7])),
        connectionId: Sobt.Helper.Network.NetworkToHost(Array<UInt8>(data[8...15]))
      );
    }
  }
}
