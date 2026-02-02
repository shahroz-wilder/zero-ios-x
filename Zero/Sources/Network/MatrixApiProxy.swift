//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

protocol MatrixApiProxyProtocol {
    var e2eEncryptionApi: MatrixE2EEncryptionApiProtocol { get }
}

class MatrixApiProxy: MatrixApiProxyProtocol {
    let e2eEncryptionApi: MatrixE2EEncryptionApiProtocol
    
    init?(matrixClient: ClientProtocol) {
        guard let sessionInfo = try? matrixClient.session() else { return nil }
        
        e2eEncryptionApi = MatrixE2EEncryptionApi(matrixAccessToken: sessionInfo.accessToken)
    }
}
