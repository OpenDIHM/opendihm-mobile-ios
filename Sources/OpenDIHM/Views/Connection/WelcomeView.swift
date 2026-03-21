import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Bottom anchored content
                VStack(alignment: .leading, spacing: 20) {
                    Image("LogoHorizontal")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 50)
                        .padding(.bottom, 20)
                    
                    Text("Welcome!")
                        .font(Theme.Typography.heading(size: 40))
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Set up your digital in-line holographic microscope to start exploring.")
                        .font(Theme.Typography.body(size: 16))
                        .foregroundStyle(Theme.neutral)
                        .padding(.trailing, 40)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer().frame(height: 50)
                    
                    Button(action: {
                        router.beginSetup()
                    }) {
                        Text("Get Started")
                            .font(Theme.Typography.heading(size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: Theme.primary.opacity(0.2), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
            }
        }
    }
}
