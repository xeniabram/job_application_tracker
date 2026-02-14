import SwiftUI

// MARK: - Toast View
/// A reusable toast notification that appears at the top-right corner
struct ToastView: View {
    let message: String
    let icon: String
    var iconColor: Color = .green
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Toast Modifier
/// View modifier to show toast notifications
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    var iconColor: Color = .green
    var duration: TimeInterval = 2.0
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            if isPresented {
                ToastView(message: message, icon: icon, iconColor: iconColor)
                    .padding(16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.spring(response: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - View Extension
extension View {
    /// Shows a toast notification
    /// - Parameters:
    ///   - isPresented: Binding to control toast visibility
    ///   - message: The message to display
    ///   - icon: SF Symbol name for the icon
    ///   - iconColor: Color of the icon (default: .green)
    ///   - duration: How long to show the toast in seconds (default: 2.0)
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        iconColor: Color = .green,
        duration: TimeInterval = 2.0
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            icon: icon,
            iconColor: iconColor,
            duration: duration
        ))
    }
}
