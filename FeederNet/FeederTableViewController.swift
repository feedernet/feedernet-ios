//
//  FeederTableViewController.swift
//  FeederNet
//
//  Created by Marc Billow on 1/2/21.
//

import UIKit
import CoreBluetooth

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

        // We've found it so stop scan
        self.centralManager.stopScan()

        // Save the peripheral instance
        self.peripherals += [peripheral]
        print("Found new peripheral: ", peripheral)
        self.tableView.reloadData()
        
        //self.centralManager.connect(self.peripheral, options: nil)

    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let selectedPeripheral = self.peripherals[self.selectedIndexPath.row]
        selectedPeripheral.delegate = self
        
        if peripheral == selectedPeripheral {
            print("Connected to \(peripheral)")
            self.centralManager.stopScan()
            barButtonItem.title = "Connected, checking services..."
            peripheral.discoverServices([FeederPeripheral.secondGenerationServiceUUID])
            
            // Get ViewCell for status updates.
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == FeederPeripheral.secondGenerationServiceUUID {
                    print("Second generation feeder service found")
                    barButtonItem.title = "Checking feeder characteristics..."
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
        let selectedPeripheral = self.peripherals[self.selectedIndexPath.row]
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == FeederPeripheral.deviceIdCharacteristicUUID {
                    print("DeviceID characteristic found")
                } else if characteristic.uuid == FeederPeripheral.statusUpdateCharacteristicUUID {
                    print("StatusUpdate characteristic found")
                } else if characteristic.uuid == FeederPeripheral.wifiCredentialsCharacteristicUUID {
                    print("WiFiCrentials characteristic found, prompting for credentials")
                    barButtonItem.title = "Ready for credentials."
                    let cell:FeederTableViewCell = tableView.cellForRow(at: self.selectedIndexPath) as! FeederTableViewCell
                    
                    // Create alert prompt for credentials collection
                    let alert = UIAlertController(
                        title: "WiFi Credentials",
                        message: "Please enter the credentials to send to \(selectedPeripheral.name ?? "Unknown Device").",
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
                        self.barButtonItem.title = "Sending credentials..."
                        self.writeWiFiCredentialsToChar(withCharacteristic: characteristic, withCredentials: creds)
                        
                        cell.activityIndicator.stopAnimating()
                        self.startBluetoothScan()
                        self.tableView.deselectRow(at: self.selectedIndexPath, animated: true)
                    }
                    alert.addAction(confirmAction)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        cell.activityIndicator.stopAnimating()
                        self.startBluetoothScan()
                        self.tableView.deselectRow(at: self.selectedIndexPath, animated: true)
                    }
                    alert.addAction(cancelAction)
                    present(alert, animated: true, completion: nil)
                }
            }
        }
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
        
        cell.peripheralName.text = "Smart Feeder (SF20A)"
        cell.peripheralIdentity.text = peripheral.name

        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedIndexPath = indexPath
    
        let cell:FeederTableViewCell = tableView.cellForRow(at: indexPath) as! FeederTableViewCell
        cell.activityIndicator.startAnimating()
        
        let targetPeripheral = self.peripherals[indexPath.row]
        self.centralManager.connect(targetPeripheral, options: nil)
        
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
    
    private func writeWiFiCredentialsToChar(withCharacteristic characteristic: CBCharacteristic, withCredentials credentials: Data) {
        let selectedPeripheral = self.peripherals[self.selectedIndexPath.row]
        if characteristic.properties.contains(.writeWithoutResponse) {
                selectedPeripheral.writeValue(credentials, for: characteristic, type: .withoutResponse)
        }
    }
    
    private func credentialsProcessor(ssid: String, password: String, token: String = "foobar") -> Data {
        let RECORD_SEPARATOR: UInt8 = 30
        let TRANSMISSION_BEGIN: UInt8 = 2
        let TRANSMISSION_END_BLOCK: UInt8 = 23
        let TRANSMISSION_END_FINAL: UInt8 = 4
        
        let base64SSID = ssid.data(using: .utf8)?.base64EncodedString()
        let base64Pass = password.data(using: .utf8)?.base64EncodedString()
        let base64Token = token.data(using: .utf8)?.base64EncodedString()
        
        var byteArray: [UInt8] = [TRANSMISSION_BEGIN]
        byteArray += Array(base64SSID!.utf8)
        byteArray += [RECORD_SEPARATOR]
        byteArray += Array(base64Pass!.utf8)
        byteArray += [RECORD_SEPARATOR]
        byteArray += Array(base64Token!.utf8)
        byteArray += [TRANSMISSION_END_BLOCK, TRANSMISSION_END_FINAL]
        return Data(byteArray)
    }
}
