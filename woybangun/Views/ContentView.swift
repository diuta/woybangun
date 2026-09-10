//
//  ContentView.swift
//  woybangun
//
//  Created by Dimas Putra on 08/09/26.
//

import AlarmKit
import SwiftUI

struct ContentView: View {
    @State private var store = AlarmStore()
    @State private var time = Date()
    @State private var isEditingTime = false
    @State private var errorMessage: String?

    private let session = SleepSession.shared

    private var isSleeping: Bool { session.phase != .idle }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Spacer()
                clock
                Spacer()

                actions
            }
            .padding(.horizontal, 28)
            .grainyBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingTime) {
                TimePickerSheet(time: $time)
            }
            .alert("Couldn't start", isPresented: showsError, presenting: errorMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
        .tint(Theme.accent)
        .task { await store.observeAlarm() }
        .onChange(of: store.alarm?.id, initial: true) {
            if let alarmTime = store.alarm?.time { time = alarmTime }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Woybangun").tracked(Theme.ink)
            Spacer()
            Text(isSleeping ? session.phase.rawValue : "Idle")
                .tracked(isSleeping ? Theme.accent : Theme.muted)
        }
        .padding(.top, 16)
    }

    private var clock: some View {
        VStack(spacing: 20) {
            Text(isSleeping ? "Alarm at" : "Wake up at").tracked()

            Button {
                isEditingTime = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(String(format: "%02d", component(.hour)))
                        .foregroundStyle(Theme.ink)
                    Text(":")
                        .foregroundStyle(Theme.muted)
                    Text(String(format: "%02d", component(.minute)))
                        .foregroundStyle(Theme.muted)
                }
                .font(Theme.clock)
                .monospacedDigit()
            }
            .buttonStyle(.plain)
            // Not `.disabled`: that dims the whole clock and loses the two-tone contrast.
            // The time is fixed once the night is underway, but it should still read clearly.
            .allowsHitTesting(!isSleeping)

            TickRuler(progress: session.progress)

            if isSleeping, let dawn = session.dawnDate, session.phase == .night {
                Text("Morning sounds at \(dawn.formatted(date: .omitted, time: .shortened))")
                    .tracked()
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 18) {
            Button(action: primaryAction) {
                Text(isSleeping ? "End sleep" : "Start sleep")
                    .font(Theme.body)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(isSleeping ? Theme.ink : Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 19)
                    .background {
                        if isSleeping {
                            RoundedRectangle(cornerRadius: 4).stroke(Theme.line, lineWidth: 1)
                        } else {
                            RoundedRectangle(cornerRadius: 4).fill(Theme.accent)
                        }
                    }
            }
            .buttonStyle(.plain)

            NavigationLink {
                SessionLogView()
            } label: {
                HStack(spacing: 6) {
                    Text("Diagnostics")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .tracked()
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private var showsError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func component(_ unit: Calendar.Component) -> Int {
        Calendar.current.component(unit, from: time)
    }

    /// One button for the whole flow: starting sleep also arms the alarm, so there is never a
    /// state where the soundscape is running with nothing to wake you.
    private func primaryAction() {
        if isSleeping {
            session.stop()
            return
        }
        Task {
            do {
                if store.alarm == nil {
                    try await store.setAlarm(at: time)
                }
                // `time` is what we just armed; store.alarm arrives later on the update stream.
                session.start(alarmTime: time)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
