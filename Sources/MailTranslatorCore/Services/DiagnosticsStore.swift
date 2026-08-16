import Foundation

struct DiagnosticRecord {
    let date: Date
    let message: String
}

final class DiagnosticsStore {
    static let shared = DiagnosticsStore()

    private let lock = NSLock()
    private var records: [DiagnosticRecord] = []
    private let maxRecords = 100

    private init() {}

    func record(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        records.insert(DiagnosticRecord(date: Date(), message: message), at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
    }

    func snapshot() -> [DiagnosticRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }
}
