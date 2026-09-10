//
//  SleepLiveActivity.swift
//  WoybangunWidgets
//
//  Created by Dimas Putra on 10/09/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct SleepLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SleepActivityAttributes.self) { context in
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Theme.background)
            .activitySystemActionForegroundColor(Theme.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseIcon(isDawn: context.state.isDawn)
                        .font(.system(size: 20))
                        .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    AlarmTime(date: context.attributes.endDate)
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseName)
                        .tracked(Theme.muted)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        SessionProgress(range: context.attributes.sessionRange)

                        HStack {
                            Text(context.state.isDawn ? "Waking you gently" : "Morning at \(shortTime(context.attributes.dawnDate))")
                                .font(Theme.readout)
                                .foregroundStyle(Theme.muted)

                            Spacer()

                            Remaining(range: context.attributes.countdownRange())
                        }
                    }
                    .padding(.horizontal, 6)   // the region is edge-to-edge; without this it clips
                }
            } compactLeading: {
                PhaseIcon(isDawn: context.state.isDawn)
            } compactTrailing: {
                AlarmTime(date: context.attributes.endDate, size: 14)
            } minimal: {
                PhaseIcon(isDawn: context.state.isDawn)
            }
            .keylineTint(Theme.accent)
        }
    }
}

private struct LockScreenView: View {
    let attributes: SleepActivityAttributes
    let state: SleepActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Woybangun").tracked(Theme.ink)
                Spacer()
                Text(state.phaseName).tracked(Theme.accent)
            }

            HStack(alignment: .firstTextBaseline) {
                AlarmTime(date: attributes.endDate, size: 34)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Left").tracked(Theme.muted)
                    Remaining(range: attributes.countdownRange(), size: 15)
                }
            }

            SessionProgress(range: attributes.sessionRange)

            Text(state.isDawn
                 ? "Morning sounds are playing and the light is climbing."
                 : "Morning sounds at \(shortTime(attributes.dawnDate))")
                .font(Theme.readout)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
    }
}

private struct PhaseIcon: View {
    let isDawn: Bool

    var body: some View {
        Image(systemName: isDawn ? "sunrise.fill" : "moon.stars.fill")
            .foregroundStyle(Theme.accent)
    }
}

private struct AlarmTime: View {
    let date: Date
    var size: CGFloat = 17

    var body: some View {
        Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.ink)
    }
}

private struct Remaining: View {
    let range: ClosedRange<Date>
    var size: CGFloat = 13

    var body: some View {
        Text(timerInterval: range, countsDown: true)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Theme.accent)
    }
}

private struct SessionProgress: View {
    let range: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: range, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(Theme.accent)
    }
}

private func shortTime(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
}
