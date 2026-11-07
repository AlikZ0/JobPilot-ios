import Foundation
import SwiftData

@MainActor
enum VacancyStore {
    static func create(_ data: ValidVacancy, in context: ModelContext) throws -> Vacancy {
        let now = Date()
        let vacancy = Vacancy(company: data.company, role: data.role, url: data.url,
            salaryMin: data.salaryMin, salaryMax: data.salaryMax,
            currency: data.currency.isEmpty ? nil : data.currency,
            location: data.location.isEmpty ? nil : data.location,
            remoteEligibility: data.remote.rawValue, priority: data.priority.rawValue,
            technologies: data.technologies, source: data.source.isEmpty ? nil : data.source,
            createdAt: now, updatedAt: now, notes: data.notes)
        context.insert(vacancy)
        try context.save()
        return vacancy
    }

    static func update(_ vacancy: Vacancy, with data: ValidVacancy, in context: ModelContext) throws {
        vacancy.company = data.company; vacancy.role = data.role; vacancy.url = data.url
        vacancy.salaryMin = data.salaryMin; vacancy.salaryMax = data.salaryMax
        vacancy.currency = data.currency.isEmpty ? nil : data.currency
        vacancy.location = data.location.isEmpty ? nil : data.location
        vacancy.remoteEligibility = data.remote.rawValue; vacancy.priority = data.priority.rawValue
        vacancy.technologies = data.technologies
        vacancy.source = data.source.isEmpty ? nil : data.source
        vacancy.notes = data.notes; vacancy.updatedAt = .now
        try context.save()
    }

    static func merge(_ data: ValidVacancy, into vacancy: Vacancy, in context: ModelContext) throws {
        // Explicit, conservative merge: retain the current status and all existing history.
        if vacancy.url == nil { vacancy.url = data.url }
        if vacancy.salaryMin == nil { vacancy.salaryMin = data.salaryMin }
        if vacancy.salaryMax == nil { vacancy.salaryMax = data.salaryMax }
        if vacancy.currency == nil { vacancy.currency = data.currency }
        if vacancy.location == nil { vacancy.location = data.location }
        if vacancy.source == nil { vacancy.source = data.source }
        if vacancy.remoteEligibility == RemoteEligibility.unknown.rawValue {
            vacancy.remoteEligibility = data.remote.rawValue
        }
        var seen = Set(vacancy.technologies.map { $0.lowercased() })
        vacancy.technologies += data.technologies.filter { seen.insert($0.lowercased()).inserted }
        if !data.notes.isEmpty && !vacancy.notes.contains(data.notes) {
            vacancy.notes += (vacancy.notes.isEmpty ? "" : "\n\n") + data.notes
        }
        vacancy.updatedAt = .now
        try context.save()
    }

    static func changeStatus(_ vacancy: Vacancy, to status: VacancyStatus, in context: ModelContext, now: Date = .now) throws {
        let previous = vacancy.vacancyStatus
        guard StatusRules.shouldRecord(old: previous, new: status) else { return }
        vacancy.status = status.rawValue
        vacancy.appliedAt = StatusRules.appliedDate(current: vacancy.appliedAt, new: status, now: now)
        vacancy.updatedAt = now
        context.insert(StageEvent(vacancyID: vacancy.id, oldStatus: previous.rawValue, newStatus: status.rawValue, date: now))
        try context.save()
    }

    static func delete(_ vacancy: Vacancy, in context: ModelContext) throws {
        let id = vacancy.id
        for record in try context.fetch(FetchDescriptor<StageEvent>()).filter({ $0.vacancyID == id }) { context.delete(record) }
        for record in try context.fetch(FetchDescriptor<Contact>()).filter({ $0.vacancyID == id }) { context.delete(record) }
        let tasks = try context.fetch(FetchDescriptor<FollowUp>()).filter { $0.vacancyID == id }
        let meetings = try context.fetch(FetchDescriptor<Interview>()).filter { $0.vacancyID == id }
        for record in tasks { context.delete(record) }
        for record in meetings { context.delete(record) }
        context.delete(vacancy)
        do { try context.save() }
        catch { context.rollback(); throw error }
        for record in tasks { NotificationService.cancelFollowUp(id: record.id) }
        for record in meetings { NotificationService.cancelInterview(id: record.id) }
    }

    static func nextActionDate(for vacancyID: UUID, followUps: [FollowUp], interviews: [Interview]) -> Date? {
        let dates = followUps.filter { $0.vacancyID == vacancyID && !$0.isDone }.map(\.dueAt) +
            interviews.filter { $0.vacancyID == vacancyID && $0.at >= Date().addingTimeInterval(-3600) }.map(\.at)
        return dates.min()
    }
}
