//
//  AppEventManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 9/25/17.
//  Copyright © 2017 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit
import EmitterKit

class AppEventManager : DataServiceProtocol {

    static let sharedInstance = AppEventManager();
    var isCollecting: Bool = false;
    var launchTimestamp: Date = Date();
    var launchOptions: String = ""
    var launchId: String {
        return String(Int64(launchTimestamp.timeIntervalSince1970 * 1000))
    }
    var didLogLaunch: Bool = false;

    let storeType = "appEvent";
    let headers = ["timestamp", "launchId", "event", "msg", "d1", "d2", "d3", "d4"]
    var store: DataStorage?;
    var listeners: [Listener] = [];
    var isStoreOpen: Bool {
        return store != nil;
    }

    func didLaunch(launchOptions: [UIApplicationLaunchOptionsKey: Any]?) {
        self.launchOptions = ""
        self.launchTimestamp = Date();
        if let launchOptions = launchOptions {
            for (kind, _) in launchOptions {
                if (self.launchOptions != "") {
                    self.launchOptions = self.launchOptions + ":"
                }
                self.launchOptions = self.launchOptions + String(describing: kind)
            }
        }
        log.info("AppEvent didLaunch, launchId: \(launchId), options: \(self.launchOptions)");
    }

    /*
    func didLockUnlock(_ isLocked: Bool) {
        log.info("Lock state data changed: \(isLocked)");
        var data: [String] = [ ];
        data.append(String(Int64(Date().timeIntervalSince1970 * 1000)));
        let state: String = isLocked ? "Locked" : "Unlocked";
        data.append(state);
        data.append(String(UIDevice.current.batteryLevel));

        self.store?.store(data);
        self.store?.flush();

    }
     */

    func logAppEvent(event: String, msg: String = "", d1: String = "", d2: String = "", d3: String = "", d4: String = "") {
        if store == nil {
            return
        }
        var data: [String] = [ ];
        data.append(String(Int64(Date().timeIntervalSince1970 * 1000)));
        data.append(launchId);
        data.append(event);
        data.append(msg);
        data.append(d1)
        data.append(d2)
        data.append(d3)
        data.append(d4)


        self.store?.store(data);
        self.store?.flush();
    }

    func initCollecting() -> Bool {
        if (store != nil) {
            return true
        }
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
        if (!didLogLaunch) {
            didLogLaunch = true
            logAppEvent(event: "launch", msg: "Application launch", d1: launchOptions)
        }
        return true;
    }

    func startCollecting() {
        log.info("Turning \(storeType) collection on");
        logAppEvent(event: "collecting", msg: "Collecting Data")
        isCollecting = true
    }
    func pauseCollecting() {
        isCollecting = false
        log.info("Pausing \(storeType) collection");
        listeners = [ ];
        store!.flush();
    }
    func finishCollecting() -> Promise<Void> {
        log.info("Finish collecting \(storeType) collection");
        logAppEvent(event: "stop_collecting", msg: "Stop Collecting Data")
        pauseCollecting();
        store = nil;
        return DataStorageManager.sharedInstance.closeStore(storeType);
    }
}
