import SwiftUI

struct ClickableTextView: View {
    let text: String
    var body: some View {
        Text(LocalizedStringKey(text)).textSelection(.enabled)
    }
}

