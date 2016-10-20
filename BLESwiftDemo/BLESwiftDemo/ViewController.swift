//
//  ViewController.swift
//  BLESwiftDemo
//
//  Created by yuxindianzhi on 16/10/20.
//  Copyright © 2016年 coderYK. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation


// 提示:适配 iOS10 别忘了配置申请权限

class ViewController: UIViewController {
    // 懒加载
    lazy var centralManager : CBCentralManager  = CBCentralManager()
    lazy var peripherals : [CBPeripheral] = [CBPeripheral]()
    lazy var peripheralADs : [String] = [String]()
    lazy var peripheralRSSIs : [NSNumber] = [NSNumber]()
    let cellID = String("cellID")
    var tableView = UITableView()
    var curPeripheral : CBPeripheral?
    var writeCharacterist : CBCharacteristic?
    var isConnect : Bool?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUI()
        self.centralManager.delegate = self;
        self.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        scanForPeripherals()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

// 私有方法
extension ViewController {
    
    func remindToOpenBLE() {
        let alertView : UIAlertView = UIAlertView(title: "蓝牙未开启",
                                                  message: "请打开蓝牙,才能连接外设",
                                                  delegate: nil,
                                                  cancelButtonTitle: "知道了")
        
        alertView.show()
    }
    
    // 扫描外设
    func scanForPeripherals() -> () {
        var options = [String : Any]()
        options[CBCentralManagerScanOptionAllowDuplicatesKey] = false
        
        self.centralManager.scanForPeripherals(withServices: nil, options: options)
    }
    
    // 刷新
    func reScanPeripherals() {
        self.peripherals.removeAll()
        self.peripheralADs.removeAll()
        self.peripheralADs.removeAll()
        self.tableView.reloadData()
        scanForPeripherals()
        SVProgressHUD.show(withStatus: "刷新列表")
    }
    
    // 写数据
    func writeValueForPeripheral(peripheral: CBPeripheral, writeCharactist: CBCharacteristic, value: NSData?) {
        if writeCharactist.properties == .writeWithoutResponse {
            peripheral.writeValue(value as! Data, for: writeCharactist, type: .withoutResponse)
        } else {
            peripheral.writeValue(value as! Data, for: writeCharactist, type: .withResponse)
        }
        
        self.centralManager.cancelPeripheralConnection(peripheral) // 断开时机看需求而定
    }
    
    // 摇一摇
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            if self.isConnect! &&
                self.curPeripheral != nil &&
                self.writeCharacterist != nil {
                
                writeValueForPeripheral(peripheral: self.curPeripheral!, writeCharactist: self.writeCharacterist!, value: "12345678".data(using: .utf8) as NSData?)
                
                return
            }
            
            if self.centralManager.state == .poweredOff {
                remindToOpenBLE()
                return
            }
            
            reScanPeripherals()
        }
    }
}

extension ViewController: CBCentralManagerDelegate {
    
    // 状态更新
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if central.state == .poweredOff {
            print("关闭状态")
            remindToOpenBLE() // 提示开启蓝牙
            
        } else if central.state == .poweredOn {
            scanForPeripherals()
        }
        
    }
    
    // 发现外设
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 判断外设是否已在数组中
        if self.peripherals.contains(peripheral) == false {
            var IndexPaths = [IndexPath]()
            let indexPath = IndexPath.init(row: self.peripherals.count, section: 0)
            IndexPaths.append(indexPath)
            
            self.peripherals.append(peripheral)
            SVProgressHUD.dismiss()
            let localName : String = advertisementData["kCBAdvDataLocalName"] as! String
            self.peripheralADs.append(localName)
            
            self.peripheralRSSIs.append(RSSI)
            
            // TODO : 插入列表
            self.tableView.insertRows(at: IndexPaths, with: .automatic)
        }
    }
    
    // 连接成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        SVProgressHUD.showSuccess(withStatus: "\(peripheral.name!)连接成功")
        self.isConnect = true
    }
    
    // 连接失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        SVProgressHUD.showError(withStatus: error.debugDescription)
        self.isConnect = false
    }
    
    // 断开连接
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            SVProgressHUD.showError(withStatus: error.debugDescription)
        }
        
        self.isConnect = false
    }
}


extension ViewController : CBPeripheralDelegate {
    
    // 发现服务
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error != nil else {
            for service in peripheral.services! {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            return
        }
    }
    
    // 发现特征
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error != nil else {
            
            for characterist in service.characteristics! {
                
                self.curPeripheral?.setNotifyValue(true, for: characterist)
                
                if characterist.properties == .write ||
                    characterist.properties == .writeWithoutResponse {
                    self.curPeripheral?.setNotifyValue(false, for: characterist)
                    self.writeCharacterist = characterist
                }
            }
            
            return
        }
    }
    
    // 监听的值更新
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        peripheral.setNotifyValue(false, for: characteristic)
        self.centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // 写入成功的协议方法(特征的属性是 response 才会调用)
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        self.centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    // UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: cellID!)
        if (cell == nil) {
            cell = UITableViewCell.init(style: .value1, reuseIdentifier: cellID)
        }
        var localName = self.peripheralADs[indexPath.row] as String?
        guard (localName != nil) else {
            let peripheral = self.peripherals[indexPath.row] as CBPeripheral
            localName = peripheral.name
            cell?.textLabel?.text = localName
            
            return cell!
        }
        
        let RSSI = self.peripheralRSSIs[indexPath.row] as NSNumber
        
        cell?.detailTextLabel?.text = "RSSI:\(RSSI)"
        
        cell?.textLabel?.text = localName
        
        return cell!
    }
    
    
    // UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if self.curPeripheral !=  nil {
            self.centralManager.cancelPeripheralConnection(self.curPeripheral!)
        }
        
        let peripheral = self.peripherals[indexPath.row]
        self.curPeripheral = peripheral
        self.centralManager.connect(self.curPeripheral!, options: nil)
    }
}

// UI
extension ViewController {
    
    func setUI() {
        
        setupTableView()
    }
    
    func setupTableView() {
        let tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        self.view.addSubview(tableView)
        self.tableView = tableView
    }
}







