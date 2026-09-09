//
//  SessionLog.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import Foundation

/// A plain-text log written to a file, so the record survives the app being killed.
///
/// TEMPORARY — this exists to answer one question: does the sleep session actually survive a
/// whole night on a real iPhone? Once that's confirmed, delete this file, `SessionLogView`,
/// and the calls to `SessionLog.write` scattered through `SleepSession`.
enum SessionLog {
    static let url = URL.documentsDirectory.appending(path: "session.log")

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// Appends one timestamped line.
    static func write(_ message: String) {
        let line = "\(formatter.string(from: .now))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)     // first write of the session creates the file
        }
    }

    /// Newest entries first, so an overnight run is readable without scrolling to the bottom.
    static func read(limit: Int = 40) -> (text: String, total: Int) {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return ("No entries yet.", 0)
        }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        return (lines.suffix(limit).reversed().joined(separator: "\n"), lines.count)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
        write("──────── log cleared")
    }

    /// Formats a clock time for use inside a log message.
    static func time(_ date: Date) -> String { formatter.string(from: date) }
}
