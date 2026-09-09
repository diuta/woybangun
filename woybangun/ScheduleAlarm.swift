//
//  AlarmSchedule.swift
//  woybangun
//
//  Created by Dimas Putra on 08/09/26.
//

import Foundation
import AlarmKit
import SwiftUI

struct EmptyAlarmMetadata: AlarmMetadata {}

func scheduleAlarm(input: Date) async throws {
    let hour = Calendar.current.component(.hour, from: input)
    let minute = Calendar.current.component(.minute, from: input)
    let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    let relativeTime = Alarm.Schedule.Relative(time: time)
    let schedule = Alarm.Schedule.relative(relativeTime)
    
    let stopButton = AlarmButton(
        text: "dismiss",
        textColor: .white,
        systemImageName: "stop.circle"
    )
    let alert = AlarmPresentation.Alert(
        title: "Bangun woy",
        secondaryButton: stopButton
    )
    let attributes = AlarmAttributes<EmptyAlarmMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: Color.green
    )
    
    let configuration = AlarmManager.AlarmConfiguration(
        schedule: schedule,
        attributes: attributes
    )
    
    try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration )
}
