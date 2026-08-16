import Foundation
import Translation

protocol Translating {
    var displayName: String { get }

    func translate(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String
}

enum TranslatorError: LocalizedError {
    case unsupportedLanguage(String)
    case emptySource
    case appleTranslationFailed(String)
    case deepSeekRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let code):
            return "不支持的语言代码：\(code)"
        case .emptySource:
            return "没有可翻译的正文。"
        case .appleTranslationFailed(let message):
            return "Apple 翻译失败：\(message)"
        case .deepSeekRequestFailed(let message):
            return "DeepSeek 请求失败：\(message)"
        }
    }
}

struct PassThroughTranslator: Translating {
    var displayName: String {
        "本地占位"
    }

    func translate(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String {
        "[未配置翻译器] \(text)"
    }
}

@available(macOS 26.0, *)
struct AppleTranslator: Translating {
    var displayName: String {
        "Apple"
    }

    func translate(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslatorError.emptySource
        }

        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        let session = TranslationSession(installedSource: source, target: target)

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            throw TranslatorError.appleTranslationFailed(error.localizedDescription)
        }
    }
}

struct DeepSeekTranslator: Translating {
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    var displayName: String {
        "AI · DeepSeek"
    }

    func translate(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslatorError.emptySource
        }

        let targetName = languageName(targetLanguage)
        let sourcePart: String
        if sourceLanguage.lowercased() == "und" {
            sourcePart = ""
        } else {
            sourcePart = " from \(languageName(sourceLanguage))"
        }

        let body = DeepSeekChatRequest(
            model: model,
            messages: [
                .init(
                    role: "system",
                    content: "You are a professional translator. Translate the user's text into \(targetName). Return only the translation, without explanations."
                ),
                .init(
                    role: "user",
                    content: "Translate the following text\(sourcePart) into \(targetName):\n\n\(text)"
                )
            ],
            temperature: 0.2,
            stream: false
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "无响应内容"
                throw TranslatorError.deepSeekRequestFailed(responseBody)
            }

            let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                throw TranslatorError.deepSeekRequestFailed("响应中没有译文。")
            }

            return content
        } catch let error as TranslatorError {
            throw error
        } catch {
            throw TranslatorError.deepSeekRequestFailed(error.localizedDescription)
        }
    }

    private func languageName(_ code: String) -> String {
        switch code.lowercased() {
        case "zh-hans":
            return "Simplified Chinese"
        case "zh-hant":
            return "Traditional Chinese"
        case "en":
            return "English"
        case "ja":
            return "Japanese"
        case "ko":
            return "Korean"
        case "fr":
            return "French"
        case "de":
            return "German"
        case "es":
            return "Spanish"
        case "pt":
            return "Portuguese"
        case "it":
            return "Italian"
        case "ru":
            return "Russian"
        case "ar":
            return "Arabic"
        default:
            return code
        }
    }
}

private struct DeepSeekChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let stream: Bool
}

private struct DeepSeekChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
