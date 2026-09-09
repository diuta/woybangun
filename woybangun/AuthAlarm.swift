//
//  AuthAlarm.swift
//  woybangun
//
//  Created by Dimas Putra on 08/09/26.
//

import AlarmKit
import Foundation

func authAlarm() async -> Bool {
    let alarmManager = AlarmManager.shared

    do {
        let state = try await alarmManager.requestAuthorization()
        return state == .authorized
    } catch {
        return false
    }
}

func authStatus() async -> Bool {
    switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            return await authAlarm()
        case .denied:
            return false
        case .authorized:
            return true
    }
}
