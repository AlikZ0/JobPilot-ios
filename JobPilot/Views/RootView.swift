import SwiftUI

struct RootView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Обзор", systemImage: "square.grid.2x2") }
            VacanciesView()
                .tabItem { Label("Вакансии", systemImage: "briefcase") }
            EventsView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
            StatisticsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .tint(JobStyle.accent)
    }
}
