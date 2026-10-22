import SwiftUI

struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.subheadline)
                .accessibilityIdentifier(AID.Common.errorBanner)
            Spacer()
            Button("Retry", action: retry).buttonStyle(.bordered)
                .accessibilityIdentifier(AID.Common.retry)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading…").accessibilityIdentifier(AID.Common.loading)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

extension DeviceStatus {
    var color: Color {
        switch self {
        case .online: .green
        case .offline: .gray
        case .updating: .blue
        case .failed: .red
        }
    }
}

extension DeploymentStatus {
    var color: Color {
        switch self {
        case .scheduled: .orange
        case .inProgress: .blue
        case .completed: .green
        case .failed: .red
        case .cancelled: .gray
        }
    }
}

extension Int {
    var grouped: String { formatted(.number.grouping(.automatic)) }
}
