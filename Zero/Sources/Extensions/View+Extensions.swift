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
        isPresented: Binding<Bool>,
        searchQuery: Binding<String>,
        placement: SearchFieldPlacement = .automatic,
        prompt: Text? = nil
    ) -> some View {
        // We only need to show search whenever user taps search icon
        if condition, isPresented.wrappedValue {
            self
                .isSearching(isSearching)
                .searchable(text: searchQuery, isPresented: isPresented, placement: placement, prompt: prompt)
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
