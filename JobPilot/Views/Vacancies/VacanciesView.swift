import SwiftUI
import SwiftData

struct VacanciesView: View {
    @Query private var vacancies: [Vacancy]
    @Query private var followUps: [FollowUp]
    @Query private var interviews: [Interview]
    @State private var filter = VacancyFilter()
    @State private var showingAdd = false
    @State private var soonestFirst = true

    private var roles: [String] { Array(Set(vacancies.map(\.role))).sorted() }
    private var technologies: [String] { Array(Set(vacancies.flatMap(\.technologies))).sorted() }
    private var filtered: [Vacancy] {
        vacancies.filter(filter.matches).sorted { lhs, rhs in
            guard soonestFirst else { return lhs.updatedAt > rhs.updatedAt }
            let a = VacancyStore.nextActionDate(for: lhs.id, followUps: followUps, interviews: interviews)
            let b = VacancyStore.nextActionDate(for: rhs.id, followUps: followUps, interviews: interviews)
            if a == nil && b == nil { return lhs.updatedAt > rhs.updatedAt }
            return (a ?? .distantFuture) < (b ?? .distantFuture)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusChips
                filterControls
                ScrollView {
                    if filtered.isEmpty {
                        PlaceholderView(symbol: "tray", title: vacancies.isEmpty ? "Пока нет вакансий" : "Ничего не найдено",
                            message: vacancies.isEmpty ? "Добавь первую вакансию вручную или вставь ссылку." : "Попробуй изменить фильтры или строку поиска.")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { vacancy in
                                NavigationLink {
                                    VacancyDetailView(vacancy: vacancy)
                                } label: {
                                    SurfaceCard {
                                        VacancyRow(vacancy: vacancy, nextAction: VacancyStore.nextActionDate(for: vacancy.id, followUps: followUps, interviews: interviews))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Вакансии")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.search, prompt: "Компания, должность, стек")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Добавить вакансию")
                }
            }
            .sheet(isPresented: $showingAdd) { NavigationStack { VacancyFormView() } }
            .jobScreen()
        }
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Все", selected: filter.status == nil) { filter.status = nil }
                ForEach(VacancyStatus.allCases) { value in
                    chip(value.title, selected: filter.status == value) { filter.status = value }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? JobStyle.accent : JobStyle.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var filterControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Menu {
                    Button("Все должности") { filter.role = "" }
                    ForEach(roles, id: \.self) { role in Button(role) { filter.role = role } }
                } label: { Label(filter.role.isEmpty ? "Должность" : filter.role, systemImage: "person.text.rectangle") }

                Menu {
                    Button("Все технологии") { filter.technology = "" }
                    ForEach(technologies, id: \.self) { technology in Button(technology) { filter.technology = technology } }
                } label: { Label(filter.technology.isEmpty ? "Стек" : filter.technology, systemImage: "chevron.left.forwardslash.chevron.right") }

                Menu {
                    Button("Любой приоритет") { filter.priority = nil }
                    ForEach(VacancyPriority.allCases) { priority in
                        Button(priority.title) { filter.priority = priority }
                    }
                } label: { Label(filter.priority?.title ?? "Приоритет", systemImage: "flag") }

                Menu {
                    Button("Любая удалёнка") { filter.eligibility = nil }
                    ForEach(RemoteEligibility.allCases) { value in
                        Button(value.title) { filter.eligibility = value }
                    }
                } label: { Label(filter.eligibility?.title ?? "Удалёнка", systemImage: "globe") }

                Button {
                    soonestFirst.toggle()
                } label: {
                    Label(soonestFirst ? "Ближайшее действие" : "Недавно обновлены", systemImage: "arrow.up.arrow.down")
                }

                if filter.role != "" || filter.technology != "" || filter.priority != nil || filter.eligibility != nil {
                    Button("Сбросить") { filter = VacancyFilter(search: filter.search) }
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 17)
            .padding(.bottom, 12)
        }
    }
}
