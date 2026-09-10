//
//  SessionLog.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import Foundation

enum SessionLog {
    static let url = URL.documentsDirectory.appending(path: "session.log")

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func write(_ message: String) {
        let line = "\(formatter.string(from: .now))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

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

    static func time(_ date: Date) -> String { formatter.string(from: date) }
}
