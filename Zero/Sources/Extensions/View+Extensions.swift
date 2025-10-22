import SwiftUI

public extension View {
    func zeroList() -> some View {
        environment(\.defaultMinListRowHeight, 48)
            .scrollContentBackground(.hidden)
            .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
    }
    
    func zeroList(backgroundColor: Color) -> some View {
        environment(\.defaultMinListRowHeight, 48)
            .scrollContentBackground(.hidden)
            .background(backgroundColor.ignoresSafeArea())
    }
    
    @ViewBuilder
    func conditionalSearchable(
        if condition: Bool,
        isSearching: Binding<Bool>,
        searchQuery: Binding<String>,
        placement: SearchFieldPlacement = .automatic,
        prompt: Text? = nil
    ) -> some View {
        if condition {
            self
                .isSearching(isSearching)
                .searchable(text: searchQuery)
                .compoundSearchField()
                .disableAutocorrection(true)
        } else {
            self
        }
    }
}

extension TextField {
    func limitInputLength(_ length: Int, text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > length {
                text.wrappedValue = String(newValue.prefix(length))
            }
        }
    }
}
