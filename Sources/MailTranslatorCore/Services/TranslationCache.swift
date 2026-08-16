import Foundation

public struct CachedTranslation {
    public let text: String
    public let translatorName: String

    public init(text: String, translatorName: String) {
        self.text = text
        self.translatorName = translatorName
    }
}

public actor TranslationCache {
    static let shared = TranslationCache()

    private struct Entry: Codable {
        let messageID: String
        let sourceCode: String
        let targetLanguage: String
        let bodyHash: String
        let translatorName: String?
        let translatedText: String
        let date: Date
    }

    private var entries: [Entry] = []
    private let fileURL: URL
    private let maxEntries = 200

    public init(fileURL: URL? = nil) {
        let fileManager = FileManager.default
        if let fileURL {
            self.fileURL = fileURL
            try? fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } else {
            let baseURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory

            let directory = baseURL.appendingPathComponent(
                "MailTranslator",
                isDirectory: true
            )

            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            self.fileURL = directory.appendingPathComponent("translation-cache.json")
        }

        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    public func translation(
        messageID: String,
        sourceCode: String,
        targetLanguage: String,
        bodyHash: String,
        translatorName: String
    ) -> CachedTranslation? {
        guard let entry = entries.first(where: {
            $0.messageID == messageID
                && $0.sourceCode == sourceCode
                && $0.targetLanguage == targetLanguage
                && $0.bodyHash == bodyHash
                && $0.translatorName == translatorName
        }) else {
            return nil
        }

        return CachedTranslation(
            text: entry.translatedText,
            translatorName: entry.translatorName ?? "缓存"
        )
    }

    public func store(
        messageID: String,
        sourceCode: String,
        targetLanguage: String,
        bodyHash: String,
        translatorName: String,
        translatedText: String
    ) {
        entries.removeAll {
            $0.messageID == messageID
                && $0.sourceCode == sourceCode
                && $0.targetLanguage == targetLanguage
                && $0.bodyHash == bodyHash
                && $0.translatorName == translatorName
        }

        entries.insert(
            Entry(
                messageID: messageID,
                sourceCode: sourceCode,
                targetLanguage: targetLanguage,
                bodyHash: bodyHash,
                translatorName: translatorName,
                translatedText: translatedText,
                date: Date()
            ),
            at: 0
        )

        entries = Array(entries.sorted { $0.date > $1.date }.prefix(maxEntries))
        save()
    }

    public func removeAll() {
        entries = []
        save()
    }

    public func warmUp() {
        // 触发 actor 的延迟初始化并完成缓存加载，避免首次翻译时阻塞主线程。
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
