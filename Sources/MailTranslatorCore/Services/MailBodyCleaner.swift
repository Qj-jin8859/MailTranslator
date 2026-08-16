import Foundation

public struct MailBodyCleaner {
    public init() {}

    public func clean(_ body: String) -> String {
        let normalized = body.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var output: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isSignatureStart(trimmed) {
                break
            }

            if isQuotedLine(trimmed) {
                continue
            }

            if isForwardedMessageMarker(trimmed) {
                break
            }

            if isMobileSignature(trimmed) {
                break
            }

            output.append(line)
        }

        let joined = output.joined(separator: "\n")
        let collapsed = collapseBlankLines(joined)
        let result = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? body : result
    }

    private func isSignatureStart(_ line: String) -> Bool {
        line == "--"
            || line.hasPrefix("-- ")
            || line.hasPrefix("--\t")
    }

    private func isQuotedLine(_ line: String) -> Bool {
        guard line.hasPrefix(">") else { return false }

        let withoutArrows = line.drop(while: { $0 == ">" })
        return withoutArrows.first == " " || withoutArrows.isEmpty
    }

    private func isForwardedMessageMarker(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("----- original message -----")
            || lower.contains("----- forwarded message -----")
            || lower.hasPrefix("on ") && lower.contains(" wrote:")
    }

    private func isMobileSignature(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("sent from my iphone")
            || lower.contains("sent from my ipad")
            || lower.contains("sent from my")
            || lower.contains("sent from mail for windows")
            || lower.contains("get outlook for ios")
            || lower.contains("get outlook for android")
            || lower.contains("this message and any attachments are confidential")
    }

    private func collapseBlankLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var blankCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankCount += 1
                if blankCount <= 2 {
                    result.append("")
                }
            } else {
                blankCount = 0
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
