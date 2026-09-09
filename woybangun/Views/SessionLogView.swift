//
//  SessionLogView.swift
//  woybangun
//
//  TEMPORARY — diagnostics for verifying the sleep session survives overnight and for
//  bringing up the wake light. Delete alongside SessionLog once both are confirmed.
//

import SwiftUI

struct SessionLogView: View {
    @State private var logText = ""
    @State private var logCount = 0
    @State private var lightResult = ""
    @State private var isSending = false

    var body: some View {
        Form {
            Section {
                Button("Light On (full)") { send { await LightController.shared.setBrightness(255) } }
                Button("Ramp Over 60s") { send { await LightController.shared.startRamp(seconds: 60) } }
                Button("Light Off", role: .destructive) { send { await LightController.shared.turnOff() } }
                if !lightResult.isEmpty {
                    LabeledContent("Result", value: lightResult)
                        .font(.caption)
                }
            } header: {
                Text("Wake Light")
            } footer: {
                Text("Sends straight to the strip over Bluetooth, without waiting for an alarm.")
            }

            Section("\(logCount) log entries, newest first") {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Clear Log") {
                    SessionLog.clear()
                    refresh()
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isSending)
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func send(_ command: @escaping () async -> String) {
        isSending = true
        lightResult = "sending…"
        Task {
            lightResult = await command()
            isSending = false
        }
    }

    private func refresh() {
        let log = SessionLog.read()
        logText = log.text
        logCount = log.total
    }
}

#Preview {
    NavigationStack { SessionLogView() }
}
