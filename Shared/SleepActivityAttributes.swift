//
//  SleepActivityAttributes.swift
//  woybangun
//
//  Created by Dimas Putra on 10/09/26.
//

import ActivityKit
import Foundation

struct SleepActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseName: String
        var isDawn: Bool
    }

    var startedAt: Date
    var dawnDate: Date
    var endDate: Date
}

extension SleepActivityAttributes {
    var sessionRange: ClosedRange<Date> {
        startedAt...max(endDate, startedAt)
    }

    func countdownRange(from now: Date = .now) -> ClosedRange<Date> {
        now...max(endDate, now)
    }
}
