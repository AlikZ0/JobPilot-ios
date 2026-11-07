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
                .tabItem { Label("Итоги", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        // Explicit background prevents prominent controls near the bottom
        // from tinting the translucent iOS tab bar.
        .background(JobStyle.background.ignoresSafeArea())
        .toolbarBackground(JobStyle.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .tint(JobStyle.accent)
    }
}
