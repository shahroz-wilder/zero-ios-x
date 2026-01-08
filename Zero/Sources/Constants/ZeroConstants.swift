import Foundation

enum ZeroConstants {
    /// Change app environment here and respective values will be applied everywhere .i.e. `DevServer()` or `ProdServer()`
    static let appServer: AppServer = ProdServer()
    
    static let accountProvider: String = ZeroConstants.appServer.matrixHomeServerUrl.replacingOccurrences(of: "https://", with: "")
    static let ZERO_APP_STORE_APP_ID = "6476882926"
    
    /// Channel Constants
    static let ZERO_CHANNEL_PREFIX = "0://"
    
    /// Wallet Constants
    static let ZERO_WALLET_ADDRESS_PREFIX = "0x"
    static let ZERO_WALLET_ZSCAN_LIVE_URL = "https://zscan.live/"
    
    /// Subscription Constants
    static let ZERO_PRO_SUBSCRIPTION_USD: Double = 14.99
}

protocol AppServer {
    var matrixHomeServerUrl: String { get }
    var matrixHomeServerPostfix: String { get }
    var zeroRootUrl: String { get }
    var walletConnectProjectId: String { get }
    var pushGateway: String { get }
}

struct DevServer: AppServer {
    let matrixHomeServerUrl = "https://synapse-dev.zero.tech"
    let matrixHomeServerPostfix = "zero-synapse-development.zer0.io"
    let zeroRootUrl = "https://zos-api-development-fb2c513ffa60.herokuapp.com/"
    let walletConnectProjectId = ZeroSecrets.walletConnectProjectId
    let pushGateway = "https://push-gateway-dev.zero.tech"
}

struct ProdServer: AppServer {
    let matrixHomeServerUrl = "https://synapse.zero.tech"
    let matrixHomeServerPostfix = "zos-home-2.zero.tech"
    let zeroRootUrl = "https://zosapi.zero.tech/"
    let walletConnectProjectId = ZeroSecrets.walletConnectProjectId
    let pushGateway = "https://push-gateway.zero.tech"
}
