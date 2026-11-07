import SwiftUI
import SwiftData

struct OverviewView: View {
    @Query private var vacancies: [Vacancy]
    @Query private var followUps: [FollowUp]
    @Query private var interviews: [Interview]
    @State private var showingAdd = false
    private var active: Int { vacancies.filter { $0.vacancyStatus != .rejected && $0.vacancyStatus != .offer }.count }
    private var todayTasks: [FollowUp] { followUps.filter { !$0.isDone && $0.dueAt <= Calendar.current.startOfDay(for: .now).addingTimeInterval(86400) } }
    private var upcoming: [Interview] { interviews.filter { $0.at >= .now }.sorted { $0.at < $1.at } }
    private func company(_ id: UUID) -> String { vacancies.first(where: { $0.id == id })?.company ?? "Удалённая вакансия" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    metrics
                    actions
                    pipeline
                    upcomingSection
                }
                .padding(16)
            }
            .navigationTitle("Обзор")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }.accessibilityLabel("Добавить вакансию") } }
            .sheet(isPresented: $showingAdd) { NavigationStack { VacancyFormView() } }
            .jobScreen()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ваш поиск работы").font(.largeTitle.bold()).tracking(-0.8)
            Text("Все отклики, интервью и следующие шаги в одном месте.")
                .font(.subheadline).foregroundStyle(.secondary)
        }.padding(.top, 3)
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metric("Активные", value: active, symbol: "briefcase.fill", color: JobStyle.accent)
            metric("Задачи сегодня", value: todayTasks.count, symbol: "checklist", color: .orange)
            metric("Интервью", value: upcoming.count, symbol: "person.2.fill", color: .green)
        }
    }

    private func metric(_ label: String, value: Int, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text("\(value)").font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(height: 115, alignment: .topLeading)
        .background(JobStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var actions: some View {
        Button { showingAdd = true } label: {
            Label("Добавить вакансию", systemImage: "plus")
                .font(.headline).frame(maxWidth: .infinity).padding(15)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var pipeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Воронка", subtitle: "Текущие статусы вакансий")
            SurfaceCard {
                VStack(spacing: 15) {
                    ForEach(VacancyStatus.allCases) { status in
                        HStack {
                            StatusPill(status: status)
                            Spacer()
                            Text("\(vacancies.filter { $0.status == status.rawValue }.count)")
                                .font(.subheadline.bold()).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Ближайшие действия")
            if todayTasks.isEmpty && upcoming.isEmpty {
                SurfaceCard { PlaceholderView(symbol: "calendar.badge.checkmark", title: "На сегодня всё", message: "Добавь follow-up или собеседование из карточки вакансии.") }
            } else {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todayTasks.prefix(4)) { task in
                            Label("\(company(task.vacancyID)): \(task.title)", systemImage: "bell")
                                .font(.subheadline)
                        }
                        ForEach(upcoming.prefix(3)) { event in
                            Label("\(company(event.vacancyID)) · \(event.at.formatted(date: .abbreviated, time: .shortened))", systemImage: "video")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}
