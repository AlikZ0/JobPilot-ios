import SwiftUI

struct VacancyRow: View {
    let vacancy: Vacancy
    var nextAction: Date? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            RoundedRectangle(cornerRadius: 13)
                .fill(JobStyle.accent.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay(Text(String(vacancy.company.prefix(1)).uppercased())
                    .font(.headline.weight(.bold)).foregroundStyle(JobStyle.accent))
            VStack(alignment: .leading, spacing: 5) {
                Text(vacancy.role).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(2)
                Text(vacancy.company).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    StatusPill(status: vacancy.vacancyStatus)
                    if vacancy.vacancyPriority == .high {
                        Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
                            .accessibilityLabel("Высокий приоритет")
                    }
                }
                if let nextAction {
                    Label(nextAction.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
