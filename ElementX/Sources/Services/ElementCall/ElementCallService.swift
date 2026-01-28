//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import CallKit
import Combine
import Foundation
import MatrixRustSDK
import PushKit
import UIKit

/// Keep this class testable
struct TimeProvider {
    var clock: any Clock<Duration>
    var now: () -> Date
}

class ElementCallService: NSObject, ElementCallServiceProtocol, PKPushRegistryDelegate, CXProviderDelegate {
    private struct CallID: Equatable {
        let callKitID: UUID
        let roomID: String
        let rtcNotificationID: String?
    }
    
    private let pushRegistry: PKPushRegistry
    private let callController = CXCallController()
    private let callProvider: CXProviderProtocol
    private let timeProvider: TimeProvider
    
    private weak var clientProxy: ClientProxyProtocol? {
        didSet {
            // There's a race condition where a call starts when the app has been killed and the
            // observation set in `incomingCallID` occurs *before* the user session is restored.
            // So observe when the client proxy is set to fix this (the method guards for the call).
            Task { await observeIncomingCall() }
        }
    }
    
    private var incomingCallRoomInfoCancellable: AnyCancellable?
    private var incomingCallID: CallID? {
        didSet {
            Task { await observeIncomingCall() }
        }
    }
    
    private var endUnansweredCallTask: Task<Void, Never>?
    
    private var ongoingCallID: CallID? {
        didSet { ongoingCallRoomIDSubject.send(ongoingCallID?.roomID) }
    }
    
    let ongoingCallRoomIDSubject = CurrentValueSubject<String?, Never>(nil)
    var ongoingCallRoomIDPublisher: CurrentValuePublisher<String?, Never> {
        ongoingCallRoomIDSubject.asCurrentValuePublisher()
    }
    
    private let actionsSubject: PassthroughSubject<ElementCallServiceAction, Never> = .init()
    var actions: AnyPublisher<ElementCallServiceAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private var declineListenerHandle: TaskHandle?
    
    init(callProvider: CXProviderProtocol? = nil, timeProvider: TimeProvider? = nil) {
        pushRegistry = PKPushRegistry(queue: nil)
        
        self.timeProvider = timeProvider ?? TimeProvider(clock: ContinuousClock(), now: Date.init)
        
        if let callProvider {
            self.callProvider = callProvider
        } else {
            let configuration = CXProviderConfiguration()
            configuration.supportsVideo = true
            configuration.includesCallsInRecents = true
            
            if let callKitIcon = UIImage(named: "ZeroAppIcon") {
                configuration.iconTemplateImageData = callKitIcon.pngData()
            }
            
            // https://stackoverflow.com/a/46077628/730924
            configuration.supportedHandleTypes = [.generic]
            
            self.callProvider = CXProvider(configuration: configuration)
        }
        
        super.init()

        OSLogger.shared.debug("[CALL-DEBUG] ElementCallService init: Setting up PKPushRegistry...")
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        OSLogger.shared.debug("[CALL-DEBUG] ElementCallService init: PKPushRegistry configured for VoIP")

        self.callProvider.setDelegate(self, queue: nil)
        OSLogger.shared.debug("[CALL-DEBUG] ElementCallService init: CXProvider delegate set")
        OSLogger.shared.debug("[CALL-DEBUG] ElementCallService init: Ready to receive VoIP pushes!")
    }
    
    func setClientProxy(_ clientProxy: any ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }
    
    func setupCallSession(roomID: String, roomDisplayName: String) async {
        // Drop any ongoing calls when starting a new one
        if ongoingCallID != nil {
            tearDownCallSession()
        }
        
        // If this starting from a ring reuse those identifiers
        // Make sure the roomID matches
        let callID = if let incomingCallID, incomingCallID.roomID == roomID {
            incomingCallID
        } else {
            CallID(callKitID: UUID(), roomID: roomID, rtcNotificationID: nil)
        }
        
        incomingCallID = nil
        ongoingCallID = callID
        
        // Don't bother starting another CallKit session as it won't work properly
        // https://developer.apple.com/forums//thread/767949?answerId=812951022#812951022
        
        // let handle = CXHandle(type: .generic, value: roomDisplayName)
        // let startCallAction = CXStartCallAction(call: callID.callKitID, handle: handle)
        // startCallAction.isVideo = true
        
        // do {
        //     try await callController.request(CXTransaction(action: startCallAction))
        // } catch {
        //     OSLogger.shared.debug("Failed requesting start call action with error: \(error)")
        // }
    }
    
    func tearDownCallSession() {
        tearDownCallSession(sendEndCallAction: true)
    }
    
    func setAudioEnabled(_ enabled: Bool, roomID: String) {
        guard let ongoingCallID else {
            OSLogger.shared.debug("Failed toggling call microphone, no calls running")
            return
        }
        
        guard ongoingCallID.roomID == roomID else {
            OSLogger.shared.debug("Failed toggling call microphone, rooms don't match: \(ongoingCallID.roomID) != \(roomID)")
            return
        }
        
        let transaction = CXTransaction(action: CXSetMutedCallAction(call: ongoingCallID.callKitID, muted: !enabled))
        callController.request(transaction) { error in
            if let error {
                OSLogger.shared.debug("Failed toggling call microphone with error: \(error)")
            }
        }
    }

    // MARK: - PKPushRegistryDelegate
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) { }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 1: pushRegistry didReceiveIncomingPushWith called!")
        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 1: payload = \(payload.dictionaryPayload)")

        guard let roomID = payload.dictionaryPayload[ElementCallServiceNotificationKey.roomID.rawValue] as? String else {
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 2: FAILED - Missing room identifier")
            OSLogger.shared.debug("[CALL-DEBUG] MainApp: Full payload: \(payload.dictionaryPayload)")
            completion()
            return
        }

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 2: Got roomID = \(roomID)")

        guard let rtcNotificationID = payload.dictionaryPayload[ElementCallServiceNotificationKey.rtcNotifyEventID.rawValue] as? String else {
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 2: FAILED - Missing rtc notification event identifier")
            completion()
            return
        }

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 2: Got rtcNotificationID = \(rtcNotificationID)")

        guard ongoingCallID?.roomID != roomID else {
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 3: Call already ongoing for room \(roomID), ignoring")
            completion()
            return
        }

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 3: No ongoing call, proceeding...")

        let callID = CallID(callKitID: UUID(), roomID: roomID, rtcNotificationID: rtcNotificationID)
        incomingCallID = callID

        // expirationDate is passed as TimeInterval from NSE to survive IPC serialization
        guard let expirationTimeInterval = payload.dictionaryPayload[ElementCallServiceNotificationKey.expirationDate.rawValue] as? TimeInterval else {
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 4: FAILED - Missing or invalid expiration timestamp")
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 4: expirationDate value = \(String(describing: payload.dictionaryPayload[ElementCallServiceNotificationKey.expirationDate.rawValue]))")
            completion()
            return
        }

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 4: Got expirationTimeInterval = \(expirationTimeInterval)")

        let expirationDate = Date(timeIntervalSince1970: expirationTimeInterval)
        let nowDate = timeProvider.now()

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 4: expirationDate = \(expirationDate), nowDate = \(nowDate)")

        guard nowDate < expirationDate else {
            OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 5: FAILED - Call expired, nowDate >= expirationDate")
            completion()
            return
        }

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 5: Call not expired, proceeding...")

        let ringDuration: Duration = .seconds(min(expirationDate.timeIntervalSince1970 - nowDate.timeIntervalSince1970, 90))
        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 5: ringDuration = \(ringDuration)")

        let roomDisplayName = payload.dictionaryPayload[ElementCallServiceNotificationKey.roomDisplayName.rawValue] as? String
        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 5: roomDisplayName = \(roomDisplayName ?? "nil")")

        let update = CXCallUpdate()
        update.hasVideo = true
        update.localizedCallerName = roomDisplayName
        update.remoteHandle = .init(type: .generic, value: roomID)

        OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 6: Calling callProvider.reportNewIncomingCall...")

        callProvider.reportNewIncomingCall(with: callID.callKitID, update: update) { [weak self] error in
            if let error {
                OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 6: FAILED - reportNewIncomingCall error: \(error)")
            } else {
                OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 6: SUCCESS - reportNewIncomingCall completed!")
                OSLogger.shared.debug("[CALL-DEBUG] MainApp Step 7: CallKit should now show incoming call UI!")
            }

            self?.actionsSubject.send(.receivedIncomingCallRequest)

            completion()
        }

        endUnansweredCallTask = Task { [weak self] in
            try? await self?.timeProvider.clock.sleep(for: ringDuration)

            guard let self, !Task.isCancelled else {
                return
            }

            if let incomingCallID, incomingCallID.callKitID == callID.callKitID {
                OSLogger.shared.debug("[CALL-DEBUG] MainApp: Call unanswered, ending call")
                callProvider.reportCall(with: incomingCallID.callKitID, endedAt: nil, reason: .unanswered)
            }
        }
    }
    
    // MARK: - CXProviderDelegate
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        OSLogger.shared.debug("Call provider did activate audio session")
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        OSLogger.shared.debug("Call provider did deactivate audio session")
    }
    
    func providerDidReset(_ provider: CXProvider) {
        OSLogger.shared.debug("Call provider did reset: \(provider)")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let incomingCallID else {
            OSLogger.shared.debug("Failed answering incoming call, missing incomingCallID")
            return
        }
        
        // Fixes broken videos on EC web when a CallKit session is established.
        //
        // Reporting an ongoing call through `reportNewIncomingCall` + `CXAnswerCallAction`
        // or `reportOutgoingCall:connectedAt:` will give exclusive access for media to the
        // ongoing process, which is different than the WKWebKit is running on, making EC
        // unable to aquire media streams.
        // Reporting the call as ended imediately after answering it works around that
        // as EC gets access to media again and EX builds the right UI in `setupCallSession`
        //
        // https://developer.apple.com/forums//thread/767949?answerId=812951022#812951022
        //
        // https://github.com/element-hq/element-x-ios/issues/3041
        // https://forums.developer.apple.com/forums/thread/685268
        // https://stackoverflow.com/questions/71483732/webrtc-running-from-wkwebview-avaudiosession-development-roadblock
        
        // First fullfill the action
        action.fulfill()
        
        // And delay ending the call so that the app has enough time
        // to get deeplinked into
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Then end the and call rely on `setupCallSession` to create a new one
            provider.reportCall(with: incomingCallID.callKitID, endedAt: nil, reason: .remoteEnded)
            
            self.actionsSubject.send(.startCall(roomID: incomingCallID.roomID, isVoiceCall: true))
            self.endUnansweredCallTask?.cancel()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let ongoingCallID {
            actionsSubject.send(.setAudioEnabled(!action.isMuted, roomID: ongoingCallID.roomID))
        } else {
            OSLogger.shared.debug("Failed muting/unmuting call, missing ongoingCallID")
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        #if targetEnvironment(simulator)
        // This gets called for no reason on simulators, where CallKit
        // isn't even supported, ignore it.
        #else
        if let ongoingCallID {
            actionsSubject.send(.endCall(roomID: ongoingCallID.roomID))
        }
        
        if let incomingCallID {
            Task {
                await sendDeclineCallEvent(incomingCallID)
            }
        }
        
        tearDownCallSession(sendEndCallAction: false)
        
        action.fulfill()
        #endif
    }
    
    // MARK: - Private
    
    private func tearDownCallSession(sendEndCallAction: Bool = true) {
        if sendEndCallAction, let ongoingCallID {
            let transaction = CXTransaction(action: CXEndCallAction(call: ongoingCallID.callKitID))
            callController.request(transaction) { error in
                if let error {
                    OSLogger.shared.debug("Failed transaction with error: \(error)")
                }
            }
        }
        
        ongoingCallID = nil
    }
    
    private func sendDeclineCallEvent(_ incomingCallID: CallID) async {
        guard let rtcNotificationID = incomingCallID.rtcNotificationID else {
            OSLogger.shared.debug("No rtc notification event to decline.")
            return
        }
        
        guard let clientProxy else {
            OSLogger.shared.debug("A ClientProxy is needed to fetch the room.")
            return
        }
        
        guard case let .joined(roomProxy) = await clientProxy.roomForIdentifier(incomingCallID.roomID) else {
            OSLogger.shared.debug("Failed to fetch a joined room for the incoming call.")
            return
        }
        
        _ = await roomProxy.declineCall(notificationID: rtcNotificationID)
    }
    
    private func observeIncomingCall() async {
        incomingCallRoomInfoCancellable = nil
        
        guard let incomingCallID else {
            OSLogger.shared.debug("No incoming call to observe for.")
            return
        }
        
        guard let clientProxy else {
            OSLogger.shared.debug("A ClientProxy is needed to fetch the room.")
            return
        }
        
        guard case let .joined(roomProxy) = await clientProxy.roomForIdentifier(incomingCallID.roomID) else {
            OSLogger.shared.debug("Failed to fetch a joined room for the incoming call.")
            return
        }
        
        roomProxy.subscribeToRoomInfoUpdates()
        
        incomingCallRoomInfoCancellable = roomProxy
            .infoPublisher
            .compactMap { ($0.hasRoomCall, $0.activeRoomCallParticipants) }
            .removeDuplicates { $0 == $1 }
            .drop { hasRoomCall, _ in
                // Filter all updates before hasRoomCall becomes `true`. Then we can correctly
                // detect its change to `false` to stop ringing when the caller hangs up.
                !hasRoomCall
            }
            .sink { [weak self] hasOngoingCall, activeRoomCallParticipants in
                guard let self else { return }
                
                let participants: [String] = activeRoomCallParticipants
                
                if !hasOngoingCall {
                    OSLogger.shared.debug("Call cancelled by remote")
                    reportEndedCall(incomingCallID: incomingCallID, reason: .remoteEnded)
                } else if participants.contains(roomProxy.ownUserID) {
                    OSLogger.shared.debug("Call answered elsewhere")
                    reportEndedCall(incomingCallID: incomingCallID, reason: .answeredElsewhere)
                }
            }
        
        guard let rtcNotificationID = incomingCallID.rtcNotificationID else {
            OSLogger.shared.debug("Decline: No RTC notification ID found for the incoming call.")
            return
        }
        
        OSLogger.shared.debug("Observe decline events for notification \(rtcNotificationID)")
        
        let listener: CallDeclineListener = SDKListener { [weak self] senderID in
            guard let self else { return }
            
            MXLog.debug("Call declined event received from \(senderID)")
            
            if senderID == roomProxy.ownUserID {
                // Stop ringing!
                MXLog.debug("Call declined elsewhere")
                reportEndedCall(incomingCallID: incomingCallID, reason: .declinedElsewhere)
            }
        }
        
        guard case let .success(handle) = roomProxy.subscribeToCallDeclineEvents(rtcNotificationEventID: rtcNotificationID, listener: listener) else {
            OSLogger.shared.debug("Unable to listen for decline events.")
            return
        }
        
        declineListenerHandle = handle
    }
    
    private func reportEndedCall(incomingCallID: CallID, reason: CXCallEndedReason) {
        declineListenerHandle?.cancel()
        declineListenerHandle = nil
        endUnansweredCallTask?.cancel()
        callProvider.reportCall(with: incomingCallID.callKitID, endedAt: nil, reason: reason)
    }
}
