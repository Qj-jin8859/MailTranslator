import Foundation
import os

enum AppLog {
    private static let subsystem = "local.codex.MailTranslator"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let mail = Logger(subsystem: subsystem, category: "mail")
    static let translation = Logger(subsystem: subsystem, category: "translation")
}
