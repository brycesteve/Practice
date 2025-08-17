//
//  ConnectivityBridge.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//


import Foundation
import WatchConnectivity
import WidgetKit
import OSLog

final class ConnectivityBridge: NSObject, WCSessionDelegate {
    static let shared = ConnectivityBridge()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: Sending

    func send(payload: [String: Any]) {
        #if os(iOS)
        guard WCSession.default.isPaired || WCSession.default.isReachable else { return }
        #else
        guard WCSession.default.isReachable else { return }
        #endif

        // Try immediate if reachable, else queue it
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                Logger.default.error("sendMessage error: \(error.localizedDescription)")
            })
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    // MARK: Receiving

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncoming(userInfo)
    }

    private func handleIncoming(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String, type == "readinessUpdate" else { return }
        guard let score = dict["score"] as? Int else { return }

        // Save in local App Group and refresh local widgets/complications
        SharedReadinessStore.save(score: score)
        Logger.default.debug("Received readinessUpdate \(score)")
    }

    // MARK: WCSessionDelegate minimal

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error { Logger.default.error("WC activation error: \(error.localizedDescription)") }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
