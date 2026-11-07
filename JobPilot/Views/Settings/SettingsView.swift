import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportDocument: ExportFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportFilename = "JobPilot-backup"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingImportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingImport: Data?
    @State private var importFilename = ""
    @State private var authorizationText = "Проверка…"
    @State private var result: ErrorNotice?
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearanceSection
                    notificationsSection
                    transferSection
                    privacySection
                    aboutSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                contentType: exportType, defaultFilename: exportFilename) { outcome in
                switch outcome {
                case .success:
                    result = ErrorNotice(title: "Готово", detail: "Файл сохранён. Храни резервную копию в безопасном месте.")
                case .failure(let error):
                    result = ErrorNotice(error, title: "Ошибка экспорта")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .commaSeparatedText]) { outcome in
                switch outcome {
                case .success(let url): prepareImport(url)
                case .failure(let error): result = ErrorNotice(error, title: "Не удалось выбрать файл")
                }
            }
            .confirmationDialog("Импортировать данные?", isPresented: $showingImportConfirmation, titleVisibility: .visible) {
                Button("Импортировать, пропустив дубликаты") { runImport() }
                Button("Отмена", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Файл \(importFilename). Существующие вакансии не будут удалены или перезаписаны. Дубликаты по ID или ссылке пропустятся.")
            }
            .confirmationDialog("Удалить все данные JobPilot?", isPresented: $showingDeleteConfirmation) {
                Button("Удалить все вакансии и события", role: .destructive) { eraseAll() }
            } message: {
                Text("Удалятся все локальные записи и запланированные уведомления. Сначала сохрани JSON-резервную копию.")
            }
            .alert(item: $result) { note in
                Alert(title: Text(note.title), message: Text(note.detail), dismissButton: .default(Text("Понятно")))
            }
            .task { await refreshPermission() }
            .jobScreen()
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Внешний вид")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Тема приложения")
                        .font(.subheadline.weight(.medium))
                    Picker("Тема оформления", selection: $appearance) {
                        Text("Система").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Тема оформления")
                }
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Напоминания")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge")
                            .font(.title3)
                            .foregroundStyle(JobStyle.accent)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Уведомления")
                                .font(.subheadline.weight(.semibold))
                            Text(authorizationText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    Divider()
                    Button {
                        Task { @MainActor in
                            do {
                                let granted = try await NotificationService.requestPermission()
                                await refreshPermission()
                                if !granted {
                                    result = ErrorNotice(title: "Уведомления отключены",
                                        detail: "Открой Настройки iPhone → JobPilot → Уведомления.")
                                }
                            } catch {
                                result = ErrorNotice(error)
                            }
                        }
                    } label: {
                        Label("Разрешить уведомления", systemImage: "bell.badge.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .disabled(authorizationText == "Разрешены")
                    Text("Для follow-up уведомление приходит в выбранное время, для интервью — за 30 минут.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var transferSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Резервная копия")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Button { prepareExport(type: .json) } label: {
                        settingsRow("Экспорт всех данных", symbol: "square.and.arrow.up", detail: "JSON · вакансии и события")
                    }
                    Divider()
                    Button { prepareExport(type: .commaSeparatedText) } label: {
                        settingsRow("Экспорт вакансий", symbol: "tablecells", detail: "CSV · только вакансии")
                    }
                    Divider()
                    Button { showingImporter = true } label: {
                        settingsRow("Импорт данных", symbol: "square.and.arrow.down", detail: "JSON или CSV")
                    }
                    .disabled(working)
                }
                .buttonStyle(.plain)
            }
            Text("Для восстановления после переустановки сохрани JSON-копию в «Файлах» или iCloud Drive.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsRow(_ title: String, symbol: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(JobStyle.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Данные и конфиденциальность")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Данные только на устройстве", systemImage: "iphone.gen3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Label("Удалить все данные", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "О приложении")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JobPilot")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("1.0.1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Без аккаунта, рекламы и обязательного подключения к интернету.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func refreshPermission() async {
        let status = await NotificationService.authorizationStatus()
        authorizationText = switch status {
        case .authorized, .provisional, .ephemeral: "Разрешены"
        case .denied: "Запрещены"
        case .notDetermined: "Не настроены"
        @unknown default: "Неизвестно"
        }
    }

    private func prepareExport(type: UTType) {
        do {
            exportType = type
            let data = type == .json ? try DataTransferService.exportJSON(context: modelContext) : try DataTransferService.exportCSV(context: modelContext)
            exportDocument = ExportFileDocument(bytes: data)
            exportFilename = type == .json ? "JobPilot-backup" : "JobPilot-vacancies"
            showingExporter = true
        } catch { result = ErrorNotice(error, title: "Не удалось создать резервную копию") }
    }

    private func prepareImport(_ url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        working = true
        Task {
            defer {
                if gainedAccess { url.stopAccessingSecurityScopedResource() }
                working = false
            }
            do {
                let data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
                guard data.count < 20_000_000 else { throw JobPilotError.invalid("Файл слишком большой (лимит 20 МБ).") }
                let name = url.lastPathComponent
                guard name.lowercased().hasSuffix(".json") || name.lowercased().hasSuffix(".csv") else {
                    throw JobPilotError.invalid("Поддерживаются файлы .json и .csv.")
                }
                pendingImport = data
                importFilename = name
                showingImportConfirmation = true
            } catch { result = ErrorNotice(error, title: "Не удалось открыть файл") }
        }
    }

    private func runImport() {
        guard let data = pendingImport else { return }
        defer { pendingImport = nil }
        do {
            let summary = try (importFilename.lowercased().hasSuffix(".json")
                ? DataTransferService.importJSON(data, into: modelContext)
                : DataTransferService.importCSV(data, into: modelContext))
            result = ErrorNotice(title: "Импорт завершён", detail: summary.details + " Если нужны уведомления, открой и пересохрани соответствующие события.")
        } catch { result = ErrorNotice(error, title: "Ошибка импорта") }
    }

    private func eraseAll() {
        do {
            for item in try modelContext.fetch(FetchDescriptor<StageEvent>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Contact>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<FollowUp>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Interview>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<Vacancy>()) { modelContext.delete(item) }
            try modelContext.save()
            NotificationService.cancelAll()
            result = ErrorNotice(title: "Данные удалены", detail: "Локальная база JobPilot очищена.")
        } catch { modelContext.rollback(); result = ErrorNotice(error) }
    }
}
