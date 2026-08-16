import Foundation
import MailTranslatorCore

@main
struct SelfTests {
    static func main() async {
        var failures = 0

        failures += testLanguageDetector()
        failures += testMailBodyExtractor()
        failures += testMailBodyCleaner()
        failures += await testTranslationCache()

        if failures == 0 {
            print("All self-tests passed.")
        } else {
            print("\(failures) self-test(s) failed.")
            exit(1)
        }
    }

    static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        failures: inout Int
    ) {
        if condition() {
            print("PASS: \(message)")
        } else {
            print("FAIL: \(message)")
            failures += 1
        }
    }

    static func testLanguageDetector() -> Int {
        var failures = 0
        let detector = LanguageDetector()

        expect(detector.isSameLanguage(.identified("en-GB"), target: "en"), "en-GB matches en", failures: &failures)
        expect(detector.isSameLanguage(.identified("zh-Hant"), target: "zh-Hans"), "zh-Hant matches zh-Hans", failures: &failures)
        expect(!detector.isSameLanguage(.identified("en"), target: "ja"), "en does not match ja", failures: &failures)
        expect(!detector.isSameLanguage(.unknown, target: "en"), "unknown does not match en", failures: &failures)

        if case .identified(let code) = detector.detect("你好世界") {
            expect(code.lowercased().hasPrefix("zh"), "CJK fallback is Chinese", failures: &failures)
        } else {
            expect(false, "CJK fallback is Chinese", failures: &failures)
        }

        return failures
    }

    static func testMailBodyExtractor() -> Int {
        var failures = 0
        let extractor = MailBodyExtractor()

        let multipart = """
        Content-Type: multipart/alternative; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/plain; charset="utf-8"

        Hello plain

        --BOUNDARY
        Content-Type: text/html; charset="utf-8"

        <html><body>Hello html</body></html>

        --BOUNDARY--
        """
        expect(
            extractor.extract(content: "fallback", source: multipart)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "Hello plain",
            "multipart prefers text/plain",
            failures: &failures
        )

        let base64 = """
        Content-Type: text/plain; charset="utf-8"
        Content-Transfer-Encoding: base64

        SGVsbG8gYmFzZTY0
        """
        expect(
            extractor.extract(content: "fallback", source: base64)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "Hello base64",
            "base64 body is decoded",
            failures: &failures
        )

        let quoted = """
        Content-Type: text/plain; charset="utf-8"
        Content-Transfer-Encoding: quoted-printable

        Hello=20quoted=20world
        """
        expect(
            extractor.extract(content: "fallback", source: quoted)
                .trimmingCharacters(in: .whitespacesAndNewlines) == "Hello quoted world",
            "quoted-printable body is decoded",
            failures: &failures
        )

        return failures
    }

    static func testMailBodyCleaner() -> Int {
        var failures = 0
        let cleaner = MailBodyCleaner()

        let body = """
        Hello world

        > old quoted line

        --
        Best regards
        """
        let cleaned = cleaner.clean(body)

        expect(
            !cleaned.contains("old quoted line"),
            "quoted lines are removed",
            failures: &failures
        )
        expect(
            !cleaned.contains("Best regards"),
            "signature after -- is removed",
            failures: &failures
        )

        return failures
    }

    static func testTranslationCache() async -> Int {
        var failures = 0
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("cache.json")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = TranslationCache(fileURL: fileURL)
        await cache.store(
            messageID: "msg-1",
            sourceCode: "en",
            targetLanguage: "zh-Hans",
            bodyHash: "hash-1",
            translatorName: "AI · DeepSeek",
            translatedText: "你好"
        )

        let cached = await cache.translation(
            messageID: "msg-1",
            sourceCode: "en",
            targetLanguage: "zh-Hans",
            bodyHash: "hash-1",
            translatorName: "AI · DeepSeek"
        )

        expect(cached?.text == "你好", "cache lookup returns translation", failures: &failures)
        expect(cached?.translatorName == "AI · DeepSeek", "cache keeps translator name", failures: &failures)

        return failures
    }
}
