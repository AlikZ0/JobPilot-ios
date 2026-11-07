import SwiftUI
import SwiftData

struct OverviewView: View {
    @Query private var vacancies: [Vacancy]
    @Query private var followUps: [FollowUp]
    @Query private var interviews: [Interview]
    @State private var showingAdd = false

    private var active: Int {
        vacancies.filter { $0.vacancyStatus != .rejected && $0.vacancyStatus != .offer }.count
    }
    private var todayTasks: [FollowUp] {
        followUps.filter {
            !$0.isDone && Calendar.current.isDateInToday($0.dueAt)
        }
    }
    private var overdueTasks: [FollowUp] {
        followUps.filter {
            !$0.isDone && $0.dueAt < Calendar.current.startOfDay(for: .now)
        }
    }
    private var upcoming: [Interview] {
        interviews.filter { $0.at >= .now }.sorted { $0.at < $1.at }
    }
    private func company(_ id: UUID) -> String {
        vacancies.first(where: { $0.id == id })?.company ?? "Вакансия"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    metrics
                    actions
                    pipeline
                    upcomingSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Обзор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Добавить вакансию")
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { VacancyFormView() }
            }
            .jobScreen()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Поиск работы")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text("Вакансии, собеседования и следующие шаги")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var metrics: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard("Активные вакансии", value: active,
                           symbol: "briefcase", tint: JobStyle.accent)
                metricCard("Интервью впереди", value: upcoming.count,
                           symbol: "person.2", tint: .green)
            }
            SurfaceCard {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Задачи на сегодня")
                            .font(.subheadline.weight(.semibold))
                        if overdueTasks.isEmpty {
                            Text("Запланированные follow-up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Просрочено: \(overdueTasks.count)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(todayTasks.count)")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            }
        }
    }

    private func metricCard(_ label: String, value: Int, symbol: String, tint: Color) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                Text("\(value)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        }
    }

    private var actions: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Добавить вакансию")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .foregroundStyle(.white)
            .background(JobStyle.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var pipeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Воронка", subtitle: "Текущий статус вакансий")
            SurfaceCard {
                VStack(spacing: 13) {
                    ForEach(VacancyStatus.allCases) { status in
                        HStack(spacing: 10) {
                            StatusPill(status: status)
                            Spacer()
                            Text("\(vacancies.filter { $0.status == status.rawValue }.count)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Ближайшие действия")
            if todayTasks.isEmpty && overdueTasks.isEmpty && upcoming.isEmpty {
                SurfaceCard {
                    PlaceholderView(symbol: "calendar.badge.checkmark",
                                    title: "Пока нет событий",
                                    message: "Добавь задачу или интервью из карточки вакансии.")
                }
            } else {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach((overdueTasks + todayTasks).prefix(4)) { task in
                            Label("\(company(task.vacancyID)): \(task.title)", systemImage: "bell")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(upcoming.prefix(3)) { event in
                            Label("\(company(event.vacancyID)) · \(event.at.formatted(date: .abbreviated, time: .shortened))", systemImage: "video")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
