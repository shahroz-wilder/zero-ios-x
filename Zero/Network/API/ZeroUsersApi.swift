import Alamofire
import Foundation

protocol ZeroUsersApiProtocol {
    func fetchUsers(fromMatrixIds ids: [String]) async throws -> Result<[ZMatrixUser], any Error>
}

class ZeroUsersApi: ZeroUsersApiProtocol {
    private let appSettings: AppSettings
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }
    
    // MARK: - Public
    
    func fetchUsers(fromMatrixIds ids: [String]) async throws -> Result<[ZMatrixUser], any Error> {
        let localUsers = appSettings.zeroMatrixUsers ?? []
        
        let parameters: Parameters = [
            "matrixIds": ids
        ]
        
        let result: Result<[ZMatrixUser], Error> = try await APIManager
            .shared
            .authorisedRequest(
                UserEndPoints.matrixUsersEndPoint,
                method: .post,
                appSettings: appSettings,
                parameters: parameters
            )
        
        switch result {
        case .success(let matrixUsers):
            var cacheUsers: Set<ZMatrixUser> = []
            cacheUsers.formUnion(localUsers)
            cacheUsers.formUnion(matrixUsers)
            
            let users = Array(cacheUsers)
            appSettings.zeroMatrixUsers = users
            
            return .success(users)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Constants
    
    private struct UserEndPoints {
        static let matrixUsersEndPoint = "\(APIConfigs.zeroURLRoot)matrix/users/zero"
    }
}
