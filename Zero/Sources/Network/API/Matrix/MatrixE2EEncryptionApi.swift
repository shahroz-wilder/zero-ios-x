//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Alamofire
import Foundation

protocol MatrixE2EEncryptionApiProtocol {
    func getBackupVersion() async throws -> Result<MatrixBackupVersion, Error>
    func deleteBackupVersion(version: String) async throws -> Result<Void, Error>
}

class MatrixE2EEncryptionApi: MatrixE2EEncryptionApiProtocol {
    private let matrixAccessToken: String
    
    init(matrixAccessToken: String) {
        self.matrixAccessToken = matrixAccessToken
    }
    
    func getBackupVersion() async throws -> Result<MatrixBackupVersion, any Error> {
        let headers = getAuthorizationHeader()
        let result: Result<MatrixBackupVersion, Error> = try await APIManager.shared.request(E2EEncryptionEndPoints.backupVersionEndpoint,
                                                                                             method: .get,
                                                                                             headers: headers)
        switch result {
        case .success(let backupVersion):
            return .success(backupVersion)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func deleteBackupVersion(version: String) async throws -> Result<Void, any Error> {
        let headers = getAuthorizationHeader()
        let url = E2EEncryptionEndPoints.deleteBackupEndpoint.replacingOccurrences(of: E2EEncryptionConstants.version_path_parameter, with: version)
        let result: Result<Void, Error> = try await APIManager.shared.request(url,
                                                                              method: .delete,
                                                                              headers: headers)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func getAuthorizationHeader() -> HTTPHeaders {
        HTTPHeaders(["Authorization": "Bearer \(matrixAccessToken)"])
    }
                                           
    
    // MARK: - Constants
    
    private enum E2EEncryptionEndPoints {
        private static let hostURL = ZeroConstants.appServer.matrixHomeServerUrl
        
        static let backupVersionEndpoint = "\(hostURL)/_matrix/client/v3/room_keys/version"
        static let deleteBackupEndpoint = "\(hostURL)/_matrix/client/v3/room_keys/version/\(E2EEncryptionConstants.version_path_parameter)"
    }
    
    private enum E2EEncryptionConstants {
        static let version_path_parameter = "{version}"
    }
}
