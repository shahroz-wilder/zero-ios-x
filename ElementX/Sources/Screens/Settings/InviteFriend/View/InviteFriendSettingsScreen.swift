import Compound
import SwiftUI

struct InviteFriendSettingsScreen: View {
    @ObservedObject var context: InviteFriendSettingsScreenViewModel.Context
    
    var body: some View {
        EmptyView()
    }
}

// MARK: - Previews

struct InviteFriendSettingsScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = {
        let userSession = UserSessionMock(
            .init(
                clientProxy: ClientProxyMock(
                    .init(userID: "@userid:example.com",
                          deviceID: "AAAAAAAAAAA"))))
        return InviteFriendSettingsScreenViewModel(userSession: userSession)
    }()

    static var previews: some View {
        InviteFriendSettingsScreen(context: viewModel.context)
    }
}
