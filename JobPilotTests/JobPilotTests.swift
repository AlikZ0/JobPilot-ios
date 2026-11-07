import XCTest
import SwiftData
@testable import JobPilot

@MainActor
final class JobPilotTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Vacancy.self, StageEvent.self, Contact.self, FollowUp.self, Interview.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testValidationAndURLNormalization() throws {
        XCTAssertEqual(
            ValidationService.normalizedURL(" HTTP://Jobs.Example.COM/opening/42/?utm_source=email&ref=123#apply "),
            "https://jobs.example.com/opening/42?ref=123"
        )
        XCTAssertNil(ValidationService.normalizedURL("javascript:alert(1)"))
        var draft = VacancyDraft()
        draft.company = " Example "
        draft.role = " Frontend Developer "
        draft.salaryMin = "1000"
        draft.salaryMax = "900"
        XCTAssertThrowsError(try ValidationService.validated(draft))
        draft.salaryMax = "1500"
        draft.technologies = "React, TypeScript, react"
        let valid = try ValidationService.validated(draft)
        XCTAssertEqual(valid.technologies.count, 2)
        XCTAssertEqual(valid.company, "Example")
    }

    func testCRUDStatusHistoryAndCascadeDelete() throws {
        let context = try inMemoryContext()
        var draft = VacancyDraft()
        draft.company = "Company"
        draft.role = "React Developer"
        draft.url = "https://example.com/job/7"
        let vacancy = try VacancyStore.create(ValidationService.validated(draft), in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Vacancy>()).count, 1)
        try VacancyStore.changeStatus(vacancy, to: .applied, in: context)
        XCTAssertNotNil(vacancy.appliedAt)
        try VacancyStore.changeStatus(vacancy, to: .interview, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StageEvent>()).count, 2)
        let task = FollowUp(vacancyID: vacancy.id, title: "Write HR", dueAt: .now)
        let contact = Contact(vacancyID: vacancy.id, name: "Recruiter")
        let meeting = Interview(vacancyID: vacancy.id, at: .now)
        context.insert(task); context.insert(contact); context.insert(meeting)
        try context.save()
        try VacancyStore.delete(vacancy, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Vacancy>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StageEvent>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FollowUp>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Contact>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Interview>()).count, 0)
    }

    func testFilters() {
        let vacancy = Vacancy(company: "Demo", role: "Frontend React", remoteEligibility: RemoteEligibility.yes.rawValue,
                              priority: VacancyPriority.high.rawValue, technologies: ["React", "TypeScript"])
        XCTAssertTrue(VacancyFilter(search: "TypeScript", role: "frontend", technology: "react", priority: .high, eligibility: .yes).matches(vacancy))
        XCTAssertFalse(VacancyFilter(technology: "Vue").matches(vacancy))
        XCTAssertFalse(VacancyFilter(eligibility: .no).matches(vacancy))
    }

    func testCSVRoundTripIncludingQuotesAndNewlines() throws {
        let input = [["id", "value"], ["a,b", "say \"yes\"\nand more"]]
        let encoded = CSVCodec.encode(input)
        XCTAssertEqual(try CSVCodec.decode(encoded), input)
        XCTAssertThrowsError(try CSVCodec.decode("abc,\"unterminated"))
    }

    func testJSONRoundTripAndDuplicateImport() throws {
        let context = try inMemoryContext()
        var draft = VacancyDraft(); draft.company = "Example"; draft.role = "iOS"
        draft.url = "https://example.org/jobs/1"
        let v = try VacancyStore.create(ValidationService.validated(draft), in: context)
        context.insert(FollowUp(vacancyID: v.id, title: "Contact", dueAt: .now))
        try context.save()
        let data = try DataTransferService.exportJSON(context: context)
        let copy = try inMemoryContext()
        let first = try DataTransferService.importJSON(data, into: copy)
        XCTAssertEqual(first.vacanciesAdded, 1)
        XCTAssertEqual(first.relatedRecordsAdded, 1)
        let second = try DataTransferService.importJSON(data, into: copy)
        XCTAssertEqual(second.vacanciesAdded, 0)
        XCTAssertEqual(second.duplicatesSkipped, 1)
        XCTAssertEqual(try copy.fetch(FetchDescriptor<FollowUp>()).count, 1)
    }

    func testCSVExportAndImport() throws {
        let context = try inMemoryContext()
        context.insert(Vacancy(company: "Company, Inc.", role: "Frontend", notes: "one\ntwo"))
        try context.save()
        let csv = try DataTransferService.exportCSV(context: context)
        let target = try inMemoryContext()
        let result = try DataTransferService.importCSV(csv, into: target)
        XCTAssertEqual(result.vacanciesAdded, 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<Vacancy>()).first?.notes, "one\ntwo")
    }

    func testDateRepresentsSameInstantAcrossTimeZones() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-07T15:30:00Z"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        var yerevan = Calendar(identifier: .gregorian)
        yerevan.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Yerevan"))
        XCTAssertEqual(utc.component(.hour, from: date), 15)
        XCTAssertEqual(yerevan.component(.hour, from: date), 19)
        XCTAssertEqual(StatusRules.appliedDate(current: nil, new: .applied, now: date), date)
    }
}
