import Combine
import SwiftUI

typealias UserRewardsSettingsScreenViewModelType = StateStoreViewModel<UserRewardsSettingsScreenViewState, UserRewardsSettingsScreenViewAction>

class UserRewardsSettingsScreenViewModel:
    UserRewardsSettingsScreenViewModelType,
    UserRewardsSettingsScreenViewModelProtocol {
    init(userSession: UserSessionProtocol) {
        super.init(
            initialViewState: .init(
                bindings: .init(userRewards: ZeroRewards.empty())
            )
        )
        
        userSession.clientProxy.zeroClient.userRewardsPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.bindings.userRewards, on: self)
            .store(in: &cancellables)
        
        Task {
            await userSession.clientProxy.zeroClient.getUserRewards(shouldCheckRewardsIntiamtion: false)
        }
    }
}
