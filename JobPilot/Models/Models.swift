import Foundation
import SwiftData

enum VacancyStatus: String, CaseIterable, Codable, Identifiable {
    case saved, applied, interview, offer, rejected
    var id: String { rawValue }
    var title: String {
        switch self {
        case .saved: return "Сохранено"
        case .applied: return "Откликнулся"
        case .interview: return "Собеседование"
        case .offer: return "Оффер"
        case .rejected: return "Отказ"
        }
    }
    var symbol: String {
        switch self {
        case .saved: return "bookmark"
        case .applied: return "paperplane"
        case .interview: return "person.2"
        case .offer: return "checkmark.seal"
        case .rejected: return "xmark.circle"
        }
    }
}

enum RemoteEligibility: String, CaseIterable, Codable, Identifiable {
    case unknown, yes, no
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: return "Не проверено"
        case .yes: return "Можно из Армении"
        case .no: return "Нельзя из Армении"
        }
    }
}

enum VacancyPriority: Int, CaseIterable, Codable, Identifiable {
    case low = 0, normal = 1, high = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .low: return "Низкий"
        case .normal: return "Обычный"
        case .high: return "Высокий"
        }
    }
}

enum InterviewFormat: String, CaseIterable, Codable, Identifiable {
    case online, phone, onsite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .online: return "Онлайн"
        case .phone: return "Телефон"
        case .onsite: return "Офис"
        }
    }
}

@Model
final class Vacancy {
    @Attribute(.unique) var id: UUID
    var company: String
    var role: String
    var url: String?
    var salaryMin: Double?
    var salaryMax: Double?
    var currency: String?
    var location: String?
    var remoteEligibility: String
    var status: String
    var priority: Int
    var technologies: [String]
    var source: String?
    var createdAt: Date
    var appliedAt: Date?
    var updatedAt: Date
    var notes: String

    init(id: UUID = UUID(), company: String, role: String, url: String? = nil,
         salaryMin: Double? = nil, salaryMax: Double? = nil, currency: String? = nil,
         location: String? = nil, remoteEligibility: String = RemoteEligibility.unknown.rawValue,
         status: String = VacancyStatus.saved.rawValue, priority: Int = 1,
         technologies: [String] = [], source: String? = nil,
         createdAt: Date = .now, appliedAt: Date? = nil,
         updatedAt: Date = .now, notes: String = "") {
        self.id = id
        self.company = company
        self.role = role
        self.url = url
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.currency = currency
        self.location = location
        self.remoteEligibility = remoteEligibility
        self.status = status
        self.priority = priority
        self.technologies = technologies
        self.source = source
        self.createdAt = createdAt
        self.appliedAt = appliedAt
        self.updatedAt = updatedAt
        self.notes = notes
    }

    var vacancyStatus: VacancyStatus { VacancyStatus(rawValue: status) ?? .saved }
    var vacancyPriority: VacancyPriority { VacancyPriority(rawValue: priority) ?? .normal }
    var eligibility: RemoteEligibility { RemoteEligibility(rawValue: remoteEligibility) ?? .unknown }
    var salaryDisplay: String? {
        guard salaryMin != nil || salaryMax != nil else { return nil }
        let low = salaryMin.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
        let high = salaryMax.map { $0.formatted(.number.precision(.fractionLength(0...2))) }
        let amount: String
        if let low, let high { amount = "\(low)–\(high)" }
        else if let low { amount = "от \(low)" }
        else if let high { amount = "до \(high)" }
        else { return nil }
        return [amount, currency].compactMap { $0 }.joined(separator: " ")
    }
}

@Model
final class StageEvent {
    @Attribute(.unique) var id: UUID
    var vacancyID: UUID
    var oldStatus: String
    var newStatus: String
    var date: Date
    init(id: UUID = UUID(), vacancyID: UUID, oldStatus: String, newStatus: String, date: Date = .now) {
        self.id = id; self.vacancyID = vacancyID; self.oldStatus = oldStatus
        self.newStatus = newStatus; self.date = date
    }
}

@Model
final class Contact {
    @Attribute(.unique) var id: UUID
    var vacancyID: UUID
    var name: String
    var role: String
    var email: String?
    var telegram: String?
    init(id: UUID = UUID(), vacancyID: UUID, name: String, role: String = "", email: String? = nil, telegram: String? = nil) {
        self.id = id; self.vacancyID = vacancyID; self.name = name
        self.role = role; self.email = email; self.telegram = telegram
    }
}

@Model
final class FollowUp {
    @Attribute(.unique) var id: UUID
    var vacancyID: UUID
    var title: String
    var dueAt: Date
    var isDone: Bool
    init(id: UUID = UUID(), vacancyID: UUID, title: String, dueAt: Date, isDone: Bool = false) {
        self.id = id; self.vacancyID = vacancyID; self.title = title
        self.dueAt = dueAt; self.isDone = isDone
    }
}

@Model
final class Interview {
    @Attribute(.unique) var id: UUID
    var vacancyID: UUID
    var at: Date
    var format: String
    var notes: String
    init(id: UUID = UUID(), vacancyID: UUID, at: Date, format: String = InterviewFormat.online.rawValue, notes: String = "") {
        self.id = id; self.vacancyID = vacancyID
        self.at = at; self.format = format; self.notes = notes
    }
}
