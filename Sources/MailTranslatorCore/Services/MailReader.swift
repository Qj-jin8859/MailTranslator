import AppKit
import Foundation

enum MailReaderError: LocalizedError {
    case noViewer
    case noSelection
    case appleScriptFailed(String)
    case malformedResult

    var errorDescription: String? {
        switch self {
        case .noViewer:
            return "Mail.app 当前没有打开的消息窗口。"
        case .noSelection:
            return "当前没有选中的邮件。"
        case .appleScriptFailed(let message):
            return "AppleScript 执行失败：\(message)"
        case .malformedResult:
            return "Mail.app 返回了无法解析的数据。"
        }
    }
}

struct MailReader {
    private static let delimiter = "%%CODEX_MAIL_DELIM%%"

    func currentSelection() throws -> MailSnapshot? {
        let scriptSource = """
        tell application "Mail"
            try
                if (count of message viewers) is 0 then
                    return "NO_VIEWER"
                end if
                set selectedMessages to selected messages of message viewer 1
                if (count of selectedMessages) is 0 then
                    return "NO_SELECTION"
                end if
                set m to first item of selectedMessages
                set msgID to id of m as string
                set msgSubject to subject of m as text
                set msgSender to sender of m as text
                set msgBody to content of m as text
                set msgSource to ""
                try
                    set msgSource to source of m as text
                on error
                    set msgSource to ""
                end try
                return msgID & linefeed & "%%CODEX_MAIL_DELIM%%" & linefeed & msgSubject & linefeed & "%%CODEX_MAIL_DELIM%%" & linefeed & msgSender & linefeed & "%%CODEX_MAIL_DELIM%%" & linefeed & msgBody & linefeed & "%%CODEX_MAIL_DELIM%%" & linefeed & msgSource
            on error errMsg number errNum
                return "ERROR:" & errNum & ":" & errMsg
            end try
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            throw MailReaderError.appleScriptFailed("无法创建 AppleScript 对象。")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo,
           let message = errorInfo[NSAppleScript.errorMessage] as? String {
            throw MailReaderError.appleScriptFailed(message)
        }

        guard let raw = result.stringValue else {
            throw MailReaderError.malformedResult
        }

        switch raw {
        case "NO_VIEWER":
            throw MailReaderError.noViewer
        case "NO_SELECTION":
            throw MailReaderError.noSelection
        default:
            break
        }

        if raw.hasPrefix("ERROR:") {
            throw MailReaderError.appleScriptFailed(raw)
        }

        let parts = raw.components(separatedBy: "\n\(Self.delimiter)\n")
        guard parts.count == 5 else {
            throw MailReaderError.malformedResult
        }

        return MailSnapshot(
            messageID: parts[0],
            subject: parts[1],
            sender: parts[2],
            body: parts[3],
            source: parts[4]
        )
    }
}
