import AppKit
import Foundation

public struct MailBodyExtractor {
    public init() {}

    public func extract(content: String, source: String) -> String {
        let extracted = extractText(from: source)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return extracted.isEmpty ? content : extracted
    }

    private func extractText(from source: String) -> String {
        guard !source.isEmpty else { return "" }

        let (headers, body) = splitHeaderAndBody(source)
        return extractText(headers: headers, body: body)
    }

    private func extractText(headers: [String], body: String) -> String {
        guard let contentType = headerValue("content-type", in: headers) else {
            return decodePart(body: body, headers: headers)
        }

        let type = mimeType(contentType)

        if type.hasPrefix("multipart/"),
           let boundary = parameter("boundary", in: contentType) {
            let parts = multipartParts(body: body, boundary: boundary)

            if let plain = parts.first(where: {
                mimeType(headerValue("content-type", in: $0.headers) ?? "text/plain") == "text/plain"
            }) {
                return extractText(headers: plain.headers, body: plain.body)
            }

            if let html = parts.first(where: {
                mimeType(headerValue("content-type", in: $0.headers) ?? "text/html") == "text/html"
            }) {
                return extractText(headers: html.headers, body: html.body)
            }

            if let first = parts.first {
                return extractText(headers: first.headers, body: first.body)
            }

            return ""
        }

        if type == "text/html" {
            return htmlToText(decodePart(body: body, headers: headers))
        }

        return decodePart(body: body, headers: headers)
    }

    private func splitHeaderAndBody(_ raw: String) -> (headers: [String], body: String) {
        let normalized = normalizeLineEndings(raw)
        guard let range = normalized.range(of: "\n\n") else {
            return ([], normalized)
        }

        let headerBlock = String(normalized[..<range.lowerBound])
        let body = String(normalized[range.upperBound...])
        return (unfoldHeaders(headerBlock), body)
    }

    private func multipartParts(
        body: String,
        boundary: String
    ) -> [(headers: [String], body: String)] {
        let delimiter = "--\(boundary)"
        let segments = body.components(separatedBy: delimiter)
        var parts: [(headers: [String], body: String)] = []

        for segment in segments {
            var part = segment
            while part.hasPrefix("\n") {
                part.removeFirst()
            }

            if part.hasPrefix("--") {
                continue
            }

            let (headers, partBody) = splitHeaderAndBody(part)
            guard !headers.isEmpty else { continue }
            parts.append((headers, partBody))
        }

        return parts
    }

    private func decodePart(body: String, headers: [String]) -> String {
        let transferEncoding = (headerValue("content-transfer-encoding", in: headers) ?? "")
            .lowercased()
        let contentType = headerValue("content-type", in: headers) ?? "text/plain; charset=utf-8"
        let charset = parameter("charset", in: contentType) ?? "utf-8"

        switch transferEncoding {
        case "base64":
            let compact = body
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\t", with: "")
            guard let data = Data(base64Encoded: compact) else { return "" }
            return string(from: data, charset: charset) ?? body

        case "quoted-printable":
            let data = decodeQuotedPrintable(body)
            return string(from: data, charset: charset) ?? body

        default:
            return body
        }
    }

    private func decodeQuotedPrintable(_ input: String) -> Data {
        let bytes = Array(input.utf8)
        var output: [UInt8] = []
        var index = 0

        while index < bytes.count {
            if bytes[index] == 61 {
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 2
                    continue
                }

                if index + 2 < bytes.count,
                   let high = hexValue(bytes[index + 1]),
                   let low = hexValue(bytes[index + 2]) {
                    output.append(UInt8(UInt16(high) * 16 + UInt16(low)))
                    index += 3
                    continue
                }

                output.append(61)
                index += 1
                continue
            }

            output.append(bytes[index])
            index += 1
        }

        return Data(output)
    }

    private func hexValue(_ byte: UInt8) -> UInt8? {
        if byte >= 48, byte <= 57 {
            return byte - 48
        }
        if byte >= 65, byte <= 70 {
            return byte - 55
        }
        if byte >= 97, byte <= 102 {
            return byte - 87
        }
        return nil
    }

    private func string(from data: Data, charset: String) -> String? {
        if let encoding = stringEncoding(for: charset),
           let text = String(data: data, encoding: encoding) {
            return text
        }

        for encoding in [String.Encoding.utf8, .isoLatin1, .windowsCP1252] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        return nil
    }

    private func stringEncoding(for charset: String) -> String.Encoding? {
        switch charset.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "us-ascii", "ascii":
            return .ascii
        case "iso-8859-1", "latin1", "latin-1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        case "utf-16", "utf16":
            return .utf16
        default:
            return nil
        }
    }

    private func htmlToText(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else {
            return html
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            return attributed.string
        }

        return html
    }

    private func headerValue(_ name: String, in headers: [String]) -> String? {
        let target = name.lowercased()

        for header in headers {
            guard let colon = header.firstIndex(of: ":") else { continue }
            let key = header[..<colon].trimmingCharacters(in: .whitespaces)
            guard key.lowercased() == target else { continue }

            let valueStart = header.index(after: colon)
            return String(header[valueStart...]).trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    private func mimeType(_ contentType: String) -> String {
        let first = contentType.split(separator: ";", maxSplits: 1).first
        return (first.map(String.init) ?? contentType)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    private func parameter(_ name: String, in contentType: String) -> String? {
        for component in contentType.components(separatedBy: ";").dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }

            let key = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
            guard key == name.lowercased() else { continue }

            var value = String(pair[1]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            return value
        }

        return nil
    }

    private func unfoldHeaders(_ headerBlock: String) -> [String] {
        var unfolded: [String] = []

        for line in headerBlock.components(separatedBy: "\n") {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                let continuation = line.trimmingCharacters(in: .whitespaces)
                if let last = unfolded.popLast() {
                    unfolded.append(last + " " + continuation)
                }
            } else {
                unfolded.append(line)
            }
        }

        return unfolded
    }

    private func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
