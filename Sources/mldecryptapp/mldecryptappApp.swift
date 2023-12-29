import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    
    var body: some View {
        Color.clear
            .ignoresSafeArea() // fill the entire screen
    }
}

@main
struct mldecryptappApp: App {
    @State private var isActive = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isActive {
                    ContentView()
                } else {
                    SplashScreenView(isActive: $isActive)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
