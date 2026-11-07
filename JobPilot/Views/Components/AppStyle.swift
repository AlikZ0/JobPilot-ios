import SwiftUI

enum JobStyle {
    static let accent = Color(red: 0.12, green: 0.41, blue: 0.88)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondary = Color.secondary
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JobStyle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold())
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPill: View {
    let status: VacancyStatus
    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(statusColor)
            .background(statusColor.opacity(0.12), in: Capsule())
            .accessibilityLabel("Статус: \(status.title)")
    }
    private var statusColor: Color {
        switch status {
        case .saved: return .secondary
        case .applied: return JobStyle.accent
        case .interview: return .orange
        case .offer: return .green
        case .rejected: return .red
        }
    }
}

struct PlaceholderView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(JobStyle.accent)
                .padding(16)
                .background(JobStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 18)
    }
}

struct ErrorNotice: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    init(_ error: Error, title: String = "Не удалось выполнить действие") {
        self.title = title
        detail = error.localizedDescription
    }
    init(title: String, detail: String) { self.title = title; self.detail = detail }
}

extension View {
    func jobScreen() -> some View {
        self.background(JobStyle.background.ignoresSafeArea())
            .tint(JobStyle.accent)
    }
}
