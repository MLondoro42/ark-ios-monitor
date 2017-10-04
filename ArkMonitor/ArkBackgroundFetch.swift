//
//  ArkBackgroundFetch.swift
//  Dark
//
//  Created by Andrew on 2017-09-24.
//  Copyright © 2017 Walzy. All rights reserved.
//

import Foundation
import SwiftyArk
import UserNotifications

public struct MyDelegatesResponse : Decodable {
    let success   : Bool
    let delegates : [Delegate]
}

public struct MyTransactionsResponse : Decodable {
    let success      : Bool
    let transactions : [Transaction]
}


class ArkBackgroundDownloadManager: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    
    static var shared = ArkBackgroundDownloadManager()
    
    var myNewDelegate: Delegate?
    
    var receivedTransactions : [Transaction]?
    var sentTransactions     : [Transaction]?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let identifier = session.configuration.identifier {
            switch identifier {
            case "fetchMyDelegate":
                getDelegateFrom(location)
            case "myReceivedTransactions":
                getMyReceivedTransactionsFrom(location)
            case "mySentTransactions":
                getMySentTransactions(location)
            default:
                return
            }
        }
    }
    
    public func updateNewData() {
        myNewDelegate        = nil
        receivedTransactions = nil
        sentTransactions     = nil
        
        if ArkDataManager.showTransactionNotifications == true {
            getMyReceivedTransactions()
            getMySentTransactions()
        }
        
        if ArkDataManager.showDelegateNotifications == true {
            getMyDelegate()
        }
    }
    
    
    public func getMyDelegate() {
        guard let currentAddress = ArkDataManager.currentAddress else { return }
        guard let url = URL(string: "https://node1.arknet.cloud/api/" + "accounts/delegates?address=\(currentAddress)") else { return }
        
        let config = URLSessionConfiguration.background(withIdentifier: "fetchMyDelegate")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    public func getMyReceivedTransactions() {
        guard let currentAddress = ArkDataManager.currentAddress else { return }
        guard let url = URL(string: "https://node1.arknet.cloud/api/" + "transactions?recipientId=\(currentAddress)") else { return }
        let config = URLSessionConfiguration.background(withIdentifier: "myReceivedTransactions")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    public func getMySentTransactions() {
        guard let currentAddress = ArkDataManager.currentAddress else { return }
        guard let url = URL(string: "https://node1.arknet.cloud/api/" + "transactions?senderId=\(currentAddress)") else { return }
        let config = URLSessionConfiguration.background(withIdentifier: "mySentTransactions")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    private func getMyReceivedTransactionsFrom(_ location: URL) {
        do {
            let data = try Data(contentsOf: location)
            do {
                do {
                    let myRecievedTransactions = try JSONDecoder().decode(MyTransactionsResponse.self, from: data).transactions
                    self.receivedTransactions = myRecievedTransactions
                    self.checkForNewTransactions()
                }
                catch let error {
                    print(error)
                    return
                }
            }
        } catch let error {
            print(error)
            return
        }
    }
    
    private func getMySentTransactions(_ location: URL) {
        do {
            let data = try Data(contentsOf: location)
            do {
                do {
                    let mySentTransactions = try JSONDecoder().decode(MyTransactionsResponse.self, from: data).transactions
                    self.sentTransactions = mySentTransactions
                    self.checkForNewTransactions()
                }
                catch let error {
                    print(error)
                    return
                }
            }
        } catch let error {
            print(error)
            return
        }
    }
    
    private func getDelegateFrom(_ location: URL) {
        do {
            let data = try Data(contentsOf: location)
            do {
                do {
                    if let myDelegate = try JSONDecoder().decode(MyDelegatesResponse.self, from: data).delegates.first {
                        self.myNewDelegate = myDelegate
                        ArkDataManager.checkDelegateForChanges(myDelegate)
                    }
                }
                catch let error {
                    print(error)
                    return
                }
            }
        } catch let error {
            print(error)
            return
        }
    }
    
    private func checkForNewTransactions() {
        guard let mySentTransactions     = sentTransactions,
              let myReceivedTransactions = receivedTransactions else {
                return
        }
        
        let allTransactions = (mySentTransactions + myReceivedTransactions).sorted {$0.timestamp > $1.timestamp}
        ArkDataManager.checkForNewTransactions(allTransactions)
    }
}

