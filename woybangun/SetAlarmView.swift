//
//  HomePage.swift
//  woybangun
//
//  Created by Dimas Putra on 08/09/26.
//

import SwiftUI
import AlarmKit

struct SetAlarmView: View {
    @State private var isAuthenticated: Bool = false
    @State private var time = Date()

    var body: some View {
        VStack (spacing: 30) {
            HStack {
                Text("Your alarm will be set at:")
                Spacer()
                DatePicker(
                    "",
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
            }
            
            Button {
                setAlarm(input: time)
            } label: {
                Text("Save")
            }
        }
        .padding(30)
        .task {
            isAuthenticated = await authStatus()
        }
    }
}

#Preview {
    SetAlarmView()
}
