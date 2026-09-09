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
    @State private var errorMessage: String?

    private let session = SleepSession.shared

    private var isSet: Bool { store.alarm != nil }
    private var isSleeping: Bool { session.phase != .idle }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .disabled(isSet)

                    if isSet {
                        Button("Cancel Alarm", role: .destructive, action: cancelAlarm)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button("Set Alarm") {
                            Task { await setAlarm() }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Section {
                    if isSleeping {
                        LabeledContent("Playing", value: session.phase.rawValue)
                        if session.phase == .night, let dawn = session.dawnDate {
                            LabeledContent("Morning sounds at") {
                                Text(dawn, format: .dateTime.hour().minute())
                            }
                        }
                        Button("End Sleep", role: .destructive) {
                            session.stop()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Button("Start Sleep", action: startSleep)
                            .frame(maxWidth: .infinity)
                            .disabled(!isSet)
                    }
                } header: {
                    Text("Sleep")
                } footer: {
                    Text("Plays a soundscape until an hour before your alarm, then fades into morning sounds. Keep the phone charging, and don't swipe the app away — that stops the audio for good.")
                }

                // TEMPORARY — for verifying the session survives a night. Delete with the log.
                Section {
                    NavigationLink("Diagnostics") {
                        SessionLogView()
                    }
                }
            }
            .navigationTitle("Alarm")
            .alert("Couldn't Set Alarm", isPresented: showsError, presenting: errorMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
        .task {
            await store.observeAlarm()
        }
        .onChange(of: store.alarm?.id, initial: true) {
            if let alarmTime = store.alarm?.time { time = alarmTime }
        }
    }

    private var showsError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func setAlarm() async {
        do {
            try await store.setAlarm(at: time)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelAlarm() {
        // The session has no endpoint without an alarm, so it goes too.
        session.stop()
        try? store.cancelAlarm()
    }

    private func startSleep() {
        guard let alarmTime = store.alarm?.time else { return }
        session.start(alarmTime: alarmTime)
    }
}

#Preview {
    ContentView()
}
