//
//  SessionLogView.swift
//  woybangun
//
//  TEMPORARY — diagnostics for verifying the sleep session survives overnight.
//

import SwiftUI

struct SessionLogView: View {
    private let session = SleepSession.shared

    @State private var logText = ""
    @State private var logCount = 0

    var body: some View {
        Form {
            Section("\(logCount) entries, newest first") {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Clear Log") {
                    session.clearLog()
                    refresh()
                }
            }
        }
        .navigationTitle("Session Log")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh() {
        let log = session.readLog()
        logText = log.text
        logCount = log.total
    }
}

#Preview {
    NavigationStack { SessionLogView() }
}
