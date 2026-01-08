//
// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Combine
import CryptoSwift
import Foundation
import ReownAppKit
import Starscream
import Web3

class WalletConnectService {
    static let shared = WalletConnectService()
    
    private init() {}
    
    private var disposeBag = Set<AnyCancellable>()
    
    private var isZeroAppAlive: Bool = true

    func configureWalletConnect() {
        let projectId: String = ZeroConstants.appServer.walletConnectProjectId
        
        Task {
            /// App Meta Data
            let metadata = AppMetadata(name: "ZERO Messenger",
                                       description: "ZERO Messenger",
                                       url: "https://zos.zero.tech/",
                                       icons: ["https://avatars.githubusercontent.com/u/37784886"],
                                       redirect: try! .init(native: "example://",
                                                            universal: nil))
            
            Networking.configure(groupIdentifier: "group.com.zero.ios.messenger",
                                 projectId: projectId,
                                 socketFactory: DefaultSocketFactory())
            
            AppKit.configure(projectId: projectId,
                             metadata: metadata,
                             crypto: DefaultCryptoProvider(),
                             authRequestParams: nil) { error in
                // Handle error
                print(error)
            }
        }
    }
    
    func presentWalletConnectModal() {
        Task {
            await disconnectAnyExistingWallet()
            await MainActor.run {
                AppKit.present()
            }
        }
    }
    
    func connectedWalletAddress() -> String? {
        AppKit.instance.getAddress()
    }
    
    private func disconnectAnyExistingWallet() async {
        do {
            try await AppKit.instance.cleanup()
            if let currentSession = AppKit.instance.getSessions().first {
                let topic = currentSession.topic
                try await AppKit.instance.disconnect(topic: topic)
            }
        } catch {
            print(error)
        }
    }
    
    func onApplicationDidBecomeActive() {
        self.isZeroAppAlive = true
//        requestPeronalSignIfNotPending()
    }
    
    func onApplicationWillResignActive() {
        self.isZeroAppAlive = false
    }
    
    func requestPersonalSign(
        withDelay: Bool = true,
        signingMessage: String = "Sign with your wallet to log in to ZERO?"
    ) {
        Task {
            if withDelay {
                try? await Task.sleep(for: .seconds(2))
            }
            await requestWalletPersonalSign(signingMessage: signingMessage)
        }
    }
    
    private func requestWalletPersonalSign(signingMessage: String) async {
        do {
            guard let address = AppKit.instance.getAddress() else { return }
            AppKit.instance.launchCurrentWallet()
            try await AppKit.instance.request(
                .personal_sign(address: address, message: signingMessage)
            )
        } catch {
            MXLog.debug("AppKit is not configured yet in walletConnectService")
        }
    }
}

extension WebSocket: @retroactive WebSocketConnecting { }

private struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        let socket = WebSocket(url: url)
        let queue = DispatchQueue(label: "com.walletconnect.sdk.sockets", attributes: .concurrent)
        socket.callbackQueue = queue
        return socket
    }
}

private struct DefaultCryptoProvider: CryptoProvider {
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let publicKey = try EthereumPublicKey(message: message.bytes,
                                              v: EthereumQuantity(quantity: BigUInt(signature.v)),
                                              r: EthereumQuantity(signature.r),
                                              s: EthereumQuantity(signature.s))
        return Data(publicKey.rawPublicKey)
    }
    
    func keccak256(_ data: Data) -> Data {
        let digest = SHA3(variant: .keccak256)
        let hash = digest.calculate(for: [UInt8](data))
        return Data(hash)
    }
}
