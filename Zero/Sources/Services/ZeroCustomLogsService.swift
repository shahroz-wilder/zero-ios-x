//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import FirebaseFirestore

class ZeroCustomLogsService {
    static let shared = ZeroCustomLogsService()
    
    private let db = Firestore.firestore()
    
    private var isLoggingEnabled: Bool {
        RemoteConfigManager.shared.customLogsEnabled
    }
    private var userId: String? = nil
    private var userName: String? = nil
            
    private init() { }
    
    func setup(userId: String, userName: String) {
        self.userId = userId
        self.userName = userName
    }
    
    func feedScreenEvent(parameters: [String: Any]) {
        logEvent("FEED", category: "SCREEN", parameters: parameters)
    }
    
    func feedApiEvent(parameters: [String: Any]) {
        logEvent("FEED", category: "API", parameters: parameters)
    }
    
    func walletScreenEvent(parameters: [String: Any]) {
        logEvent("WALLET", category: "SCREEN", parameters: parameters)
    }
    
    func walletApiEvent(parameters: [String: Any]) {
        logEvent("WALLET", category: "API", parameters: parameters)
    }
    
    private lazy var logId: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm" 
        return formatter.string(from: Date())
    }()
    
    func logEvent(_ eventName: String, category: String, parameters: [String: Any]? = nil) {
        guard isLoggingEnabled else {
            return  // Logging disabled from remote configs
        }
        guard let userId = userId, userId.lowercased() != "placeholder_id" else { return }
        
        let mUserId = if let name = userName {
            "\(name)(\(userId))".trim()
        } else {
            userId
        }
        db.collection("zero_logs")
            .document(mUserId)
            .collection(logId)
            .document(eventName)
            .collection(category)
            .addDocument(data: parameters ?? [:]) { error in
                if let error = error {
                    print("Failed to log event: \(error.localizedDescription)")
                }
            }
    }
}
