//
//  SessionLogView.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

struct SessionLogView: View {
    @State private var logText = ""
    @State private var logCount = 0
    @State private var lightResult = ""
    @State private var isSending = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                wakeLight
                log
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .grainyBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Diagnostics").tracked(Theme.ink)
            }
        }
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: - Sections

    private var wakeLight: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake light").tracked(Theme.ink)

            HStack(spacing: 10) {
                pill("On") { await LightController.shared.setBrightness(255) }
                pill("Ramp 60s") { await LightController.shared.startRamp(seconds: 60) }
                pill("Off") { await LightController.shared.turnOff() }
            }

            Text(lightResult.isEmpty ? "Sends over Bluetooth, no alarm needed" : lightResult)
                .font(Theme.readout)
                .foregroundStyle(lightResult.isEmpty ? Theme.muted : Theme.accent)
                .animation(.default, value: lightResult)
        }
    }

    private var log: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session log").tracked(Theme.ink)
                Spacer()
                Text("\(logCount)").tracked()
            }

            TickRuler(progress: nil, height: 14)

            Text(logText)
                .font(Theme.readout)
                .foregroundStyle(Theme.muted)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                SessionLog.clear()
                refresh()
            } label: {
                Text("Clear").tracked(Theme.muted)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Bits

    private func pill(_ title: String, action: @escaping () async -> String) -> some View {
        Button {
            isSending = true
            lightResult = "sending…"
            Task {
                lightResult = await action()
                isSending = false
            }
        } label: {
            Text(title)
                .font(Theme.label)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 3).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .opacity(isSending ? 0.4 : 1)
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
