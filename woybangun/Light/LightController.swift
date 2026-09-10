//
//  LightController.swift
//  woybangun
//
//  Created by Dimas Putra on 09/09/26.
//

import CoreBluetooth
import Foundation

@MainActor
final class LightController: NSObject {
    static let shared = LightController()

    private static let serviceUUID = CBUUID(string: "91E992B2-43DF-441E-9ECB-9CD5BB334EE3")
    private static let commandUUID = CBUUID(string: "6F101BA6-507A-40ED-A04A-52897ED36232")

    private static let timeout: TimeInterval = 15

    private var central: CBCentralManager!
    private var strip: CBPeripheral?
    private var pending: CheckedContinuation<String, Never>?
    private var queuedCommand: String?
    private var timeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startRamp(seconds: Int) async -> String {
        await send("ramp:\(max(1, seconds))")
    }

    func turnOff() async -> String {
        await send("off")
    }

    func setBrightness(_ level: Int) async -> String {
        await send("on:\(min(max(level, 0), 255))")
    }

    // MARK: - One command at a time

    private func send(_ command: String) async -> String {
        guard pending == nil else { return "busy with another command" }
        guard central.state == .poweredOn else { return "bluetooth \(stateName(central.state))" }

        return await withCheckedContinuation { continuation in
            pending = continuation
            queuedCommand = command
            central.scanForPeripherals(withServices: [Self.serviceUUID])

            timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.timeout))
                guard !Task.isCancelled else { return }
                finish("timed out — strip not found")
            }
        }
    }

    private func finish(_ result: String) {
        guard let continuation = pending else { return }
        pending = nil

        timeoutTask?.cancel()
        timeoutTask = nil
        central.stopScan()
        if let strip { central.cancelPeripheralConnection(strip) }
        strip = nil
        queuedCommand = nil

        continuation.resume(returning: result)
    }

    private func stateName(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOff: "is off"
        case .unauthorized: "permission denied"
        case .unsupported: "unsupported on this device"
        case .resetting: "is resetting"
        case .unknown: "state unknown"
        case .poweredOn: "is on"
        @unknown default: "state unrecognised"
        }
    }
}

// MARK: - Finding and connecting

extension LightController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard strip == nil else { return }
        central.stopScan()
        strip = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        finish("connect failed — \(error?.localizedDescription ?? "unknown")")
    }
}

// MARK: - Writing the command

extension LightController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            finish("service not found on the strip")
            return
        }
        peripheral.discoverCharacteristics([Self.commandUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard let characteristic = service.characteristics?
            .first(where: { $0.uuid == Self.commandUUID }),
              let command = queuedCommand,
              let data = command.data(using: .utf8)
        else {
            finish("command characteristic not found")
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            finish("write failed — \(error.localizedDescription)")
        } else {
            finish("sent")
        }
    }
}
