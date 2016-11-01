//
//  connect.swift
//  sobt
//
//  Created by Billy He on 10/31/16.
//  Copyright © 2016 Billy He. All rights reserved.
//

import Foundation

extension SobtLib.TrackerAction {
  struct Connect {
    static let MagicNumber = 0x41727101980 as UInt64;
    
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

    static func EncodeRequest(transactionId transactionId: UInt32) -> NSData {
      let payload = NSMutableData();
      
      var payloadConnectionId = SobtLib.Helper.Network.HostToNetwork(MagicNumber);
      var payloadAction = SobtLib.Helper.Network.HostToNetwork(Action.Connect.rawValue);
      var payloadTransactionId = SobtLib.Helper.Network.HostToNetwork(transactionId);
      
      payload.appendBytes(&payloadConnectionId, length: 8);
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      
      return payload;
    }
    
    static func DecodeRequest(data: Array<UInt8>) -> Request {
      return Request(
        connectionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...7])),
        action: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[8...11])),
        transactionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[12...15]))
      );
    }
    
    static func EncodeResponse(transactionId transactionId: UInt32, connectionId: UInt64) -> NSData {
      let payload = NSMutableData();
      
      var payloadAction = SobtLib.Helper.Network.HostToNetwork(Action.Connect.rawValue);
      var payloadTransactionId = SobtLib.Helper.Network.HostToNetwork(transactionId);
      var payloadConnectionId = SobtLib.Helper.Network.HostToNetwork(connectionId);
      
      payload.appendBytes(&payloadAction, length: 4);
      payload.appendBytes(&payloadTransactionId, length: 4);
      payload.appendBytes(&payloadConnectionId, length: 8);

      return payload;
    }

    static func DecodeResponse(data: Array<UInt8>) -> Response {
      return Response(
        action: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[0...3])),
        transactionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[4...7])),
        connectionId: SobtLib.Helper.Network.NetworkToHost(Array<UInt8>(data[8...15]))
      );
    }
  }
}
