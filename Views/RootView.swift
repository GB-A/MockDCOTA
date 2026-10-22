import SwiftUI

struct RootView: View {
    let service: DCOTAService
    let skipOnboarding: Bool
    @Environment(AppState.self) private var state
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        @Bindable var state = state
        TabView(selection: $state.selectedTab) {
            DashboardView(service: service)
                .tabItem { Label("Dashboard", systemImage: "gauge") }
                .tag(AppTab.dashboard)
                .accessibilityIdentifier(AID.Tab.dashboard)
            DevicesView(service: service)
                .tabItem { Label("Devices", systemImage: "ipad.and.iphone") }
                .tag(AppTab.devices)
                .accessibilityIdentifier(AID.Tab.devices)
            ContentView(service: service)
                .tabItem { Label("Content", systemImage: "shippingbox") }
                .tag(AppTab.content)
                .accessibilityIdentifier(AID.Tab.content)
            DeploymentsView(service: service)
                .tabItem { Label("Deployments", systemImage: "paperplane") }
                .tag(AppTab.deployments)
                .accessibilityIdentifier(AID.Tab.deployments)
        }
        .onAppear { showOnboarding = !(hasSeenOnboarding || skipOnboarding) }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
    }
}

struct OnboardingView: View {
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 56))
            Text("Welcome to MockDCOTA").font(.title.bold())
            Text("Manage content for devices in partner stores, over the air.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Get Started", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AID.Common.onboardingDismiss)
        }
        .padding(32)
        .interactiveDismissDisabled()
        .accessibilityIdentifier(AID.Common.onboarding)
    }
}
