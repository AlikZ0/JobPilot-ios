import SwiftUI
import SwiftData
import Charts

enum ReportPeriod: String, CaseIterable, Identifiable {
    case week, month, quarter, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return "7 дней"
        case .month: return "30 дней"
        case .quarter: return "90 дней"
        case .all: return "Всё время"
        }
    }
    var startingAt: Date? {
        switch self {
        case .week: return Calendar.current.date(byAdding: .day, value: -7, to: .now)
        case .month: return Calendar.current.date(byAdding: .day, value: -30, to: .now)
        case .quarter: return Calendar.current.date(byAdding: .day, value: -90, to: .now)
        case .all: return nil
        }
    }
}

struct StatisticsView: View {
    @Query private var vacancies: [Vacancy]
    @Query private var stages: [StageEvent]
    @Query private var interviews: [Interview]
    @State private var period = ReportPeriod.month

    private func inPeriod(_ date: Date) -> Bool { period.startingAt.map { date >= $0 } ?? true }
    private var created: [Vacancy] { vacancies.filter { inPeriod($0.createdAt) } }
    private var applied: Int { vacancies.filter { $0.appliedAt.map(inPeriod) == true }.count }
    private var interviewCount: Int { interviews.filter { inPeriod($0.at) }.count }
    private var rejectionCount: Int { stages.filter { $0.newStatus == VacancyStatus.rejected.rawValue && inPeriod($0.date) }.count }
    private var offerCount: Int { stages.filter { $0.newStatus == VacancyStatus.offer.rawValue && inPeriod($0.date) }.count }
    private var statusData: [StatusCount] {
        VacancyStatus.allCases.map { status in
            StatusCount(title: status.title, count: created.filter { $0.status == status.rawValue }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Период").font(.headline)
                        Spacer()
                        Picker("Период", selection: $period) {
                            ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Text("С \(period.startingAt?.formatted(date: .abbreviated, time: .omitted) ?? "начала") по \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote).foregroundStyle(.secondary)
                    metrics
                    chartSection
                    notes
                }
                .padding(16)
            }
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .jobScreen()
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric("Новых вакансий", count: created.count, icon: "briefcase", color: JobStyle.accent)
            metric("Откликов", count: applied, icon: "paperplane", color: .blue)
            metric("Интервью", count: interviewCount, icon: "person.2", color: .orange)
            metric("Отказов", count: rejectionCount, icon: "xmark.circle", color: .red)
            metric("Офферов", count: offerCount, icon: "checkmark.seal", color: .green)
        }
    }

    private func metric(_ label: String, count: Int, icon: String, color: Color) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).foregroundStyle(color)
                Text("\(count)").font(.largeTitle.bold()).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Воронка статусов", subtitle: "Текущий статус вакансий, созданных за период")
            SurfaceCard {
                if created.isEmpty {
                    PlaceholderView(symbol: "chart.bar", title: "Недостаточно данных", message: "Добавь вакансии, чтобы увидеть распределение.")
                } else {
                    Chart(statusData) { item in
                        BarMark(x: .value("Статус", item.title), y: .value("Количество", item.count))
                            .foregroundStyle(JobStyle.accent.gradient)
                            .cornerRadius(5)
                    }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                    .frame(height: 210)
                    .accessibilityLabel("Диаграмма вакансий по статусам")
                }
            }
        }
    }

    private var notes: some View {
        Text("Статистика строится только по твоим записям. Интервью учитываются по датам встреч, отказы и офферы — по истории смены статусов. Проценты успешности не прогнозируются.")
            .font(.footnote).foregroundStyle(.secondary)
    }
}

struct StatusCount: Identifiable {
    let title: String
    let count: Int
    var id: String { title }
}
