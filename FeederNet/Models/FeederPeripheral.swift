//
//  FeederPeripheral.swift
//  FeederNet
//
//  Created by Marc Billow on 12/13/20.
//

import UIKit
import CoreBluetooth

class FeederPeripheral: NSObject {
    public static let secondGenerationServiceUUID     = CBUUID.init(string: "5FB90001-1178-45F0-A8CB-FD25B4F8D9DC")
    
    public static let deviceIdCharacteristicUUID   = CBUUID.init(string: "5FB90004-1178-45F0-A8CB-FD25B4F8D9DC")
    public static let statusUpdateCharacteristicUUID = CBUUID.init(string: "5FB90003-1178-45F0-A8CB-FD25B4F8D9DC")
    public static let wifiCredentialsCharacteristicUUID  = CBUUID.init(string: "5FB90002-1178-45F0-A8CB-FD25B4F8D9DC")

}
