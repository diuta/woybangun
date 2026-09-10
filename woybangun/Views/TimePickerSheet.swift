//
//  TimePickerSheet.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import SwiftUI

struct TimePickerSheet: View {
    @Binding var time: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Wake up at")
                    .tracked()
                    .padding(.top, 24)

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.body)
                        .foregroundStyle(Theme.accent)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .presentationDetents([.height(340)])
        .presentationBackground(Theme.background)
    }
}

#Preview {
    TimePickerSheet(time: .constant(.now))
}
