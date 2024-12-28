import SwiftUI

struct SpeedTestButton: View {
    let isTesting: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16))
                .foregroundStyle(isTesting ? .gray : .yellow)
                .opacity(isTesting ? (isAnimating ? 0.5 : 1.0) : 1.0)
        }
        .disabled(isTesting)
        .onChange(of: isTesting) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                    isAnimating.toggle()
                }
            } else {
                isAnimating = false
            }
        }
    }
} 