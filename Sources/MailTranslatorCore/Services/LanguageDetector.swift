import Foundation
import NaturalLanguage

public enum DetectedLanguage: Equatable {
    case identified(String)
    case unknown

    public var code: String? {
        switch self {
        case .identified(let code):
            return code
        case .unknown:
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .identified(let code):
            return code
        case .unknown:
            return "未知语言"
        }
    }
}

public struct LanguageDetector {
    public init() {}

    public func detect(_ text: String) -> DetectedLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unknown
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        if let language = recognizer.dominantLanguage {
            return .identified(language.rawValue)
        }

        if containsCJK(trimmed) {
            return .identified("zh-Hans")
        }

        return .unknown
    }

    public func isSameLanguage(_ language: DetectedLanguage, target: String) -> Bool {
        guard let code = language.code else { return false }
        return languageBase(code) == languageBase(target)
    }

    private func languageBase(_ code: String) -> String {
        code.lowercased()
            .split(separator: "-")
            .first
            .map(String.init) ?? code.lowercased()
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }
    }
}
