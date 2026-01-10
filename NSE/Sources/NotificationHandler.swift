//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import CallKit
import MatrixRustSDK
import UserNotifications

class NotificationHandler {
    private let userSession: NSEUserSession
    private let settings: CommonSettingsProtocol
    private let contentHandler: (UNNotificationContent) -> Void
    private var notificationContent: UNMutableNotificationContent
    private let tag: String
    
    private let notificationContentBuilder: NotificationContentBuilder
    
    // periphery:ignore - required for instance retention in the rust codebase
    private var roomInfoObservationToken: TaskHandle?
    
    init(userSession: NSEUserSession,
         settings: CommonSettingsProtocol,
         contentHandler: @escaping (UNNotificationContent) -> Void,
         notificationContent: UNMutableNotificationContent,
         tag: String) {
        self.userSession = userSession
        self.settings = settings
        self.contentHandler = contentHandler
        self.notificationContent = notificationContent
        self.tag = tag
        
        let eventStringBuilder = RoomMessageEventStringBuilder(attributedStringBuilder: AttributedStringBuilder(mentionBuilder: PlainMentionBuilder()),
                                                               destination: .notification)
        
        notificationContentBuilder = NotificationContentBuilder(messageEventStringBuilder: eventStringBuilder,
                                                                userSession: userSession)
    }
    
    func processEvent(_ eventID: String, roomID: String) async {
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 1: Processing event: \(eventID) in room: \(roomID)")

        // Copy over the unread information to the notification badge
        notificationContent.badge = notificationContent.unreadCount as NSNumber?
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 2: Badge value: \(notificationContent.badge?.stringValue ?? "nil")")

        guard let notificationItemProxy = await userSession.notificationItemProxy(roomID: roomID, eventID: eventID) else {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 3: FAILED - Could not retrieve notification item")
            discardNotification()
            return
        }

        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 3: Got notification item proxy")

        let result = await preprocessNotification(notificationItemProxy)
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 4: Preprocess result: \(result)")

        switch result {
        case .processedShouldDiscard:
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 5: Discarding (processedShouldDiscard)")
            discardNotification()
        case .unsupportedShouldDiscard:
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 5: Discarding (unsupportedShouldDiscard)")
            discardNotification()
        case .shouldDisplay:
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Step 5: Will display notification")
            await notificationContentBuilder.process(notificationContent: &notificationContent,
                                                     notificationItem: notificationItemProxy,
                                                     mediaProvider: userSession.mediaProvider)

            deliverNotification()
        }
    }
    
    func handleTimeExpiration() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content
        OSLogger.shared.debug("\(tag) Extension time will expire")
        deliverNotification()
    }
    
    // MARK: - Private
    
    private func deliverNotification() {
        OSLogger.shared.debug("\(tag) Delivering notification")
        contentHandler(notificationContent)
    }

    private func discardNotification() {
        OSLogger.shared.debug("\(tag) Discarding notification")
        
        let content = UNMutableNotificationContent()
        content.badge = notificationContent.unreadCount as NSNumber?
        OSLogger.shared.debug("\(tag) New badge value: \(content.badge?.stringValue ?? "nil")")
        
        contentHandler(content)
    }
    
    private func preprocessNotification(_ itemProxy: NotificationItemProxyProtocol) async -> NotificationProcessingResult {
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Starting, isNoisy=\(itemProxy.isNoisy)")

        if settings.hideQuietNotificationAlerts, !itemProxy.isNoisy {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Quiet notification, discarding")
            return .processedShouldDiscard
        }

        guard case let .timeline(event) = itemProxy.event else {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Not a timeline event, will display")
            return .shouldDisplay
        }

        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Got timeline event, eventId=\(event.eventId())")

        switch try? event.content() {
        case .messageLike(let messageContent):
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Message-like content")
            switch messageContent {
            case .poll,
                 .roomEncrypted,
                 .sticker:
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: poll/encrypted/sticker, will display")
                return .shouldDisplay
            case .roomMessage(let messageType, _):
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: roomMessage type=\(messageType)")
                switch messageType {
                case .emote, .image, .audio, .video, .file, .notice, .text, .location, .gallery:
                    return .shouldDisplay
                case .other:
                    return .unsupportedShouldDiscard
                }
            case .roomRedaction(let redactedEventID, _):
                guard let redactedEventID else {
                    MXLog.error("Unable to handle redact notification due to missing event ID")
                    return .processedShouldDiscard
                }

                let deliveredNotifications = await UNUserNotificationCenter.current().deliveredNotifications()

                if let targetNotification = deliveredNotifications.first(where: { $0.request.content.eventID == redactedEventID }) {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [targetNotification.request.identifier])
                }

                return .processedShouldDiscard
            case .rtcNotification(let notificationType, let expirationTimestamp):
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: RTC NOTIFICATION DETECTED! type=\(notificationType), expiration=\(expirationTimestamp)")
                return await handleCallNotification(notificationType: notificationType,
                                                    rtcNotifyEventID: event.eventId(),
                                                    timestamp: event.timestamp(),
                                                    expirationTimestamp: expirationTimestamp,
                                                    roomID: itemProxy.roomID,
                                                    roomDisplayName: itemProxy.roomDisplayName)
            case .callAnswer,
                 .callInvite,
                 .callHangup,
                 .callCandidates,
                 .keyVerificationReady,
                 .keyVerificationStart,
                 .keyVerificationCancel,
                 .keyVerificationAccept,
                 .keyVerificationKey,
                 .keyVerificationMac,
                 .keyVerificationDone,
                 .reactionContent:
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: Legacy call/verification event, discarding")
                return .unsupportedShouldDiscard
            }
        case .state:
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: State event, discarding")
            return .unsupportedShouldDiscard
        case .none:
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: Preprocess: No content, discarding")
            return .unsupportedShouldDiscard
        }
    }
    
    /// Handle incoming call notifications.
    /// - Returns: A boolean indicating whether the notification was handled and should now be discarded.
    private func handleCallNotification(notificationType: RtcNotificationType,
                                        rtcNotifyEventID: String,
                                        timestamp: Timestamp,
                                        expirationTimestamp: Timestamp,
                                        roomID: String,
                                        roomDisplayName: String) async -> NotificationProcessingResult {
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 1: Starting handleCallNotification")
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 1: notificationType=\(notificationType), roomID=\(roomID)")
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 1: rtcNotifyEventID=\(rtcNotifyEventID)")
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 1: timestamp=\(timestamp), expirationTimestamp=\(expirationTimestamp)")

        // Handle incoming VoIP calls, show the native OS call screen
        guard notificationType == .ring else {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 2: NOT a ring notification (type=\(notificationType)), showing as push")
            return .shouldDisplay
        }

        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 2: This IS a ring notification, proceeding...")

        // Check to see if a call is still ongoing
        if let room = userSession.roomForIdentifier(roomID) {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: Got room, hasActiveRoomCall=\(room.hasActiveRoomCall())")

            if !room.hasActiveRoomCall() {
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: No active call yet, waiting up to 5 seconds...")

                let expiringTask = ExpiringTaskRunner {
                    await withCheckedContinuation { [weak self] continuation in
                        self?.roomInfoObservationToken = room.subscribeToRoomInfoUpdates(listener: SDKListener { info in
                            if info.hasRoomCall {
                                OSLogger.shared.debug("[CALL-DEBUG] NH: HandleCall: Room info update - call is now active!")
                                continuation.resume()
                            } else {
                                OSLogger.shared.debug("[CALL-DEBUG] NH: HandleCall: Room info update - still no active call")
                            }
                        })
                    }
                }

                try? await expiringTask.run(timeout: .seconds(5))

                guard room.hasActiveRoomCall() else {
                    OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: FAILED - Room still has no active call after waiting, showing as push")
                    return .shouldDisplay
                }

                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: Room now has active call after waiting")
            }
        } else {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: Could not get room, using timestamp fallback")

            let timestampDate = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
            let timeSinceNotification = abs(timestampDate.timeIntervalSinceNow)

            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: Timestamp age = \(timeSinceNotification) seconds (max allowed: \(ElementCallServiceNotificationDiscardDelta))")

            guard timeSinceNotification < ElementCallServiceNotificationDiscardDelta else {
                OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: FAILED - Call notification too old, showing as push")
                return .shouldDisplay
            }

            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 3: Timestamp is valid, proceeding...")
        }

        // Prepare payload for CallKit - USE TimeInterval, NOT Date!
        let expirationTimeInterval = TimeInterval(expirationTimestamp / 1000)
        let payload = [ElementCallServiceNotificationKey.roomID.rawValue: roomID,
                       ElementCallServiceNotificationKey.roomDisplayName.rawValue: roomDisplayName,
                       ElementCallServiceNotificationKey.expirationDate.rawValue: expirationTimeInterval,
                       ElementCallServiceNotificationKey.rtcNotifyEventID.rawValue: rtcNotifyEventID] as [String: Any]

        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 4: Created payload for CallKit")
        OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 4: payload = \(payload)")

        do {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 5: Calling CXProvider.reportNewIncomingVoIPPushPayload...")
            try await CXProvider.reportNewIncomingVoIPPushPayload(payload)
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 5: SUCCESS - reportNewIncomingVoIPPushPayload completed!")
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 6: Returning processedShouldDiscard - CallKit should now show incoming call")
        } catch {
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 5: FAILED - reportNewIncomingVoIPPushPayload error: \(error)")
            OSLogger.shared.debug("\(tag) [CALL-DEBUG] NH: HandleCall Step 5: Error details: \(String(describing: error))")
            return .shouldDisplay
        }

        return .processedShouldDiscard
    }
    
    private enum NotificationProcessingResult: CustomStringConvertible {
        case shouldDisplay
        case processedShouldDiscard
        case unsupportedShouldDiscard

        var description: String {
            switch self {
            case .shouldDisplay: return "shouldDisplay"
            case .processedShouldDiscard: return "processedShouldDiscard"
            case .unsupportedShouldDiscard: return "unsupportedShouldDiscard"
            }
        }
    }
}
