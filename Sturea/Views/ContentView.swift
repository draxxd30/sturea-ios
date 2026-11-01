import SwiftUI

/// Pantalla principal: la web de Sturea a pantalla completa + botón discreto de ajustes.
struct ContentView: View {
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var reloadTick = 0

    private let brand = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ZStack {
            brand.ignoresSafeArea()

            WebView(url: URL(string: "https://sturea.com")!, isLoading: $isLoading, reloadTick: reloadTick)
                .ignoresSafeArea(edges: .bottom)

            // Splash propio mientras carga por primera vez.
            if isLoading {
                ZStack {
                    brand.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                        ProgressView().tint(.white)
                    }
                }
                .transition(.opacity)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel("Ajustes")
                    .padding(.trailing, 10)
                    .padding(.top, 4)
                }
                Spacer()
            }
        }
        .animation(.easeOut(duration: 0.3), value: isLoading)
        .sheet(isPresented: $showSettings) {
            SettingsView(onReload: { reloadTick += 1 })
        }
    }
}
