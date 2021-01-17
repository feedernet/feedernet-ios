//
//  FeederTableViewController.swift
//  FeederNet
//
//  Created by Marc Billow on 1/2/21.
//

import UIKit
import CoreBluetooth

let statusMap = [
    "STATUS_WIFI_FOUND": "Discovered WiFi Network",
    "STATUS_WIFI_CONN": "Successfully Joined Network",
    "STATUS_WIFI_IP": "Received IP Address",
    "STATUS_ACN_CONN": "Registering with FeederNet",
    "STATUS_PN_CONN": "Discovering FeederNet Server",
    "STATUS_SUCCESS": "Connected to FeederNet",
    "ERROR_MQTT_CONN": "Broker Connection Failed",
    "ERROR_ACN_CONN": "Unable to Connect to FeederNet",
    "ERROR_WIFI_FOUND": "WiFi Network Not Found",
    "ERROR_WIFI_CONN": "Error Connecting to WiFi"
]

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

class FeederTableViewController: UITableViewController, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    //MARK: Properties
    @IBOutlet weak var barButtonItem: UIBarButtonItem!
    private var centralManager: CBCentralManager!
    private var peripherals = Array<CBPeripheral>()
    private var selectedIndexPath: IndexPath!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate CoreBluetoothCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    // MARK: CoreBluetooth Central Manager
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Device bluetooth state update.")
        if central.state != .poweredOn {
            barButtonItem.title = "Bluetooth Unavilable"
            print("Device bluetooth is not available!")
        } else {
            startBluetoothScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // Save the peripheral instance
        peripheral.delegate = self
        if !self.peripherals.contains(peripheral) {
            self.peripherals += [peripheral]
            print("Found new peripheral: ", peripheral)
            self.tableView.reloadData()
            
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral)")
        self.tableView.reloadData()
        peripheral.discoverServices([FeederPeripheral.secondGenerationServiceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == FeederPeripheral.secondGenerationServiceUUID {
                    print("Second generation feeder service found")
                    //Start discovery of characteristics
                    peripheral.discoverCharacteristics(
                        [
                            FeederPeripheral.deviceIdCharacteristicUUID,
                            FeederPeripheral.statusUpdateCharacteristicUUID,
                            FeederPeripheral.wifiCredentialsCharacteristicUUID
                        ], for: service)
                    return
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == FeederPeripheral.deviceIdCharacteristicUUID {
                    print("DeviceID characteristic found")
                } else if characteristic.uuid == FeederPeripheral.statusUpdateCharacteristicUUID {
                    print("StatusUpdate characteristic found, subscribing to updates")
                    peripheral.setNotifyValue(true, for: characteristic)
                    self.tableView.reloadData()
                } else if characteristic.uuid == FeederPeripheral.wifiCredentialsCharacteristicUUID {
                    print("WiFiCrentials characteristic found.")
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let rxData = characteristic.value
        if let rxData = rxData {
            let numberOfBytes = rxData.count
            var rxByteArray = [UInt8](repeating: 0, count: numberOfBytes)
            (rxData as NSData).getBytes(&rxByteArray, length: numberOfBytes)
            if let string = String(bytes: rxByteArray, encoding: .utf8) {
                print("Refreshing status for \(peripheral.name!): \(string)")
            }
        }
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "FeederTableViewCell"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? FeederTableViewCell  else {
            fatalError("The dequeued cell is not an instance of FeederTableViewCell.")
        }
        
        // Fetch the appropriate feeder for the data source layout.
        let peripheral = self.peripherals[indexPath.row]
        
        cell.peripheralName.text = "Smart Feeder"
        cell.peripheralIdentity.text = peripheral.name
        
        let statusCharacteristic = retrieveCredentialFromFeeder(peripheral: peripheral, characteristicUuid: FeederPeripheral.statusUpdateCharacteristicUUID)
        if statusCharacteristic != nil {
            let rxData = statusCharacteristic!.value
            if let rxData = rxData {
                let numberOfBytes = rxData.count
                var rxByteArray = [UInt8](repeating: 0, count: numberOfBytes)
                (rxData as NSData).getBytes(&rxByteArray, length: numberOfBytes)
                if let string = String(bytes: rxByteArray, encoding: .utf8) {
                    cell.statusLabel.text = statusMap[string] ?? "Unknown Status \(string)"
                    cell.statusColor.textColor = string.contains("ERROR") ? .systemRed : .systemOrange
                    if string == "STATUS_SUCCESS" {
                        cell.statusColor.textColor = .systemGreen
                        cell.activityIndicator.stopAnimating()
                    }
                }
            }
        } else if [CBPeripheralState.disconnected, CBPeripheralState.connecting].contains(peripheral.state) {
            cell.statusLabel.text = "Bluetooth Disconnected"
            cell.statusColor.textColor = .systemRed
            cell.activityIndicator.stopAnimating()
        } else {
            cell.statusLabel.text = "Connected to Device"
            cell.statusColor.textColor = .systemOrange
            cell.activityIndicator.stopAnimating()
        }

        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedIndexPath = indexPath
    
        let cell:FeederTableViewCell = tableView.cellForRow(at: indexPath) as! FeederTableViewCell
        cell.activityIndicator.startAnimating()
        
        let targetPeripheral = self.peripherals[indexPath.row]
        
        
        // We need to make sure that we actually have the right services and characteristics discovered.
        // Theoretically, the cell should be disabled until we find these, but it never hurts to double
        // check.
        let wifiCharacteristic = retrieveCredentialFromFeeder(peripheral: targetPeripheral, characteristicUuid: FeederPeripheral.wifiCredentialsCharacteristicUUID)
        if wifiCharacteristic == nil {
            let alert = UIAlertController(
                title: "Device Not Ready!",
                message: "Please wait a few more seconds before attemping to communicate.",
                preferredStyle: .alert)
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Create alert prompt for credentials collection
        let alert = UIAlertController(
            title: "WiFi Credentials",
            message: "Please enter the credentials to send to \(targetPeripheral.name ?? "Unknown Device").",
            preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Network SSID"
        }
        alert.addTextField { (textField) in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        let confirmAction = UIAlertAction(title: "Save", style: .default) { [weak alert] _ in
            guard let alert = alert, let ssidField = alert.textFields?.first, let passField = alert.textFields?[1] else { return }
            
            let creds = self.credentialsProcessor(ssid: ssidField.text!, password: passField.text!)
            print("Sending credentials to feeder")
            self.writeWiFiCredentialsToChar(withPeripheral: targetPeripheral, withCharacteristic: wifiCharacteristic!, withCredentials: creds)
            
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        alert.addAction(confirmAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.tableView.deselectRow(at: indexPath, animated: true)
            cell.activityIndicator.stopAnimating()
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
        
    }
    
    // MARK: Private Functions
    private func startBluetoothScan() {
        self.peripherals = []
        self.tableView.reloadData()
        barButtonItem.title = "Scanning for devices..."
        print("Scanning for", FeederPeripheral.secondGenerationServiceUUID);
        centralManager.scanForPeripherals(withServices: [FeederPeripheral.secondGenerationServiceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    private func writeWiFiCredentialsToChar(withPeripheral peripheral: CBPeripheral, withCharacteristic characteristic: CBCharacteristic, withCredentials credentials: [[UInt8]]) {
        if characteristic.properties.contains(.writeWithoutResponse) {
            for transmission in credentials {
                peripheral.writeValue(Data(transmission), for: characteristic, type: .withoutResponse)
            }
        }
    }
    
    private func credentialsProcessor(ssid: String, password: String, token: String = "foobar", chunkSize: Int = 20) -> [[UInt8]] {
        let RECORD_SEPARATOR: UInt8 = 30
        let TRANSMISSION_BEGIN: UInt8 = 2
        let TRANSMISSION_END_FINAL: UInt8 = 4
        let TRANSMISSION_END_BLOCK: UInt8 = 23
        
        let base64SSID = ssid.data(using: .utf8)!.base64EncodedString()
        let base64Pass = password.data(using: .utf8)!.base64EncodedString()
        let base64Token = token.data(using: .utf8)!.base64EncodedString()
        
        var credentialByteArray: [UInt8] = [TRANSMISSION_BEGIN]
        credentialByteArray += Array(base64SSID.utf8)
        credentialByteArray += [RECORD_SEPARATOR]
        credentialByteArray += Array(base64Pass.utf8)
        credentialByteArray += [RECORD_SEPARATOR]
        credentialByteArray += Array(base64Token.utf8)
        credentialByteArray += [TRANSMISSION_END_FINAL]
        
        var chunkedData = credentialByteArray.chunked(into: 19)
        for i in 0 ..< chunkedData.count - 1 {
            chunkedData[i] += [TRANSMISSION_END_BLOCK]
            
        }
        return chunkedData
    }
    
    private func retrieveCredentialFromFeeder(peripheral: CBPeripheral, characteristicUuid: CBUUID) -> CBCharacteristic? {
        guard let services = peripheral.services, let serviceIdx = services.firstIndex(
                where: { $0.uuid == FeederPeripheral.secondGenerationServiceUUID }
        ) else {
            return nil
        }
        
        guard let characteristics = services[serviceIdx].characteristics, let wifiCharIdx = characteristics.firstIndex(
            where: { $0.uuid == characteristicUuid }
        ) else {
            return nil
        }
        
        
        
        return peripheral.services![serviceIdx].characteristics![wifiCharIdx]
    }
}
