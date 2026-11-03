import Foundation
import CoreBluetooth
import Combine

/// Optional true-real-time heart rate source: the standard Bluetooth Heart Rate Service (0x180D).
///
/// Google documents Fitbit Air / Charge 6 / Edge / Pixel Watch 2+ as able to "share heart rate"
/// with equipment and apps that use the Bluetooth Heart Rate Profile. On the Air the owner must turn
/// it on in Google Health → Connections → Fitbit Air → Share heart rate (it costs band battery).
/// Charge 6 forum reports say some receivers fail the handshake, so this source is OPT-IN and
/// best-effort: MRH1 never depends on it, HealthKit stays the source of truth.
///
/// Rules:
/// - Nothing here runs until the user taps "Connect band" (creating `CBCentralManager` shows the
///   Bluetooth permission prompt, which needs `NSBluetoothAlwaysUsageDescription`).
/// - Read-only, no pairing data stored except the peripheral UUID (UserDefaults) for reconnects.
/// - No networking. CoreBluetooth is unavailable in the Simulator (state = .unsupported).
@MainActor
final class BLEHeartRate: NSObject, ObservableObject {

    enum Status: Equatable {
        case off                 // not started (no permission prompt shown yet)
        case unsupported         // Simulator / no BLE
        case unauthorized        // user denied Bluetooth
        case poweredOff          // Bluetooth switched off
        case scanning
        case connecting(String)
        case connected(String)
        case notFound            // scan timed out: sharing not enabled on the band?

        var isConnected: Bool { if case .connected = self { return true } else { return false } }

        var text: String {
            switch self {
            case .off: return "Not connected"
            case .unsupported: return "Bluetooth not available on this device"
            case .unauthorized: return "Bluetooth access is off for MRH1 (Settings → MRH1)"
            case .poweredOff: return "Bluetooth is off"
            case .scanning: return "Looking for your band…"
            case .connecting(let n): return "Connecting to \(n)…"
            case .connected(let n): return "Live from \(n)"
            case .notFound: return "No band found. In Google Health turn on Share heart rate, then try again."
            }
        }
    }

    struct Reading: Equatable {
        let date: Date
        let bpm: Int
        let rrIntervals: [Double]   // seconds (spec unit is 1/1024 s); often empty on wrist bands
        let contact: Bool?          // nil = sensor contact not supported
        let energyKJ: Int?
    }

    nonisolated static let heartRateService = CBUUID(string: "180D")
    nonisolated static let measurementChar = CBUUID(string: "2A37")
    private static let rememberedKey = "mrh1.ble.peripheral"

    @Published private(set) var status: Status = .off
    @Published private(set) var reading: Reading?

    /// Called on the main actor for every notification (≈ 1 Hz). LiveStore merges these.
    var onReading: ((Reading) -> Void)?

    /// Only peripherals whose advertised name contains one of these are auto-picked when several
    /// HR sensors are around (gym). Empty = take the first 0x180D device.
    var preferredNames = ["Fitbit", "Air", "Charge", "Pixel"]

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var scanTimeout: Task<Void, Never>?
    private var wantsConnection = false

    // MARK: - Control

    func start() {
        wantsConnection = true
        if let central {
            if central.state == .poweredOn { connectOrScan() }
            return
        }
        // Main queue: delegate callbacks land on the main thread (see MainActor.assumeIsolated below).
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func stop() {
        wantsConnection = false
        scanTimeout?.cancel()
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        status = .off
    }

    func forgetBand() {
        UserDefaults.standard.removeObject(forKey: Self.rememberedKey)
        stop()
    }

    private func connectOrScan() {
        guard let central, wantsConnection else { return }
        // 1. Remembered band, 2. a band already connected to iOS (e.g. by Google Health), 3. scan.
        if let raw = UserDefaults.standard.string(forKey: Self.rememberedKey),
           let id = UUID(uuidString: raw),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(known)
            return
        }
        if let already = central.retrieveConnectedPeripherals(withServices: [Self.heartRateService]).first {
            connect(already)
            return
        }
        status = .scanning
        central.scanForPeripherals(withServices: [Self.heartRateService],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimeout?.cancel()
        scanTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !Task.isCancelled, self.status == .scanning else { return }
            self.central?.stopScan()
            self.status = .notFound
        }
    }

    private func connect(_ p: CBPeripheral) {
        scanTimeout?.cancel()
        central?.stopScan()
        peripheral = p
        p.delegate = self
        status = .connecting(p.name ?? "band")
        central?.connect(p, options: nil)
    }

    private func matchesPreferred(_ name: String?) -> Bool {
        guard !preferredNames.isEmpty else { return true }
        guard let name else { return false }
        return preferredNames.contains { name.localizedCaseInsensitiveContains($0) }
    }

    // MARK: - Parsing (Bluetooth SIG Heart Rate Measurement, 0x2A37)

    /// Flags bit0: HR is UInt16 · bits1-2: sensor contact · bit3: energy expended present ·
    /// bit4: RR intervals present (UInt16, 1/1024 s each).
    nonisolated static func parse(_ data: Data, at date: Date = Date()) -> Reading? {
        let b = [UInt8](data)
        guard b.count >= 2 else { return nil }
        let flags = b[0]
        var i = 1
        func u16() -> Int? {
            guard i + 1 < b.count else { return nil }
            defer { i += 2 }
            return Int(b[i]) | (Int(b[i + 1]) << 8)
        }
        let bpm: Int
        if flags & 0x01 != 0 { guard let v = u16() else { return nil }; bpm = v } else { bpm = Int(b[i]); i += 1 }
        let contact: Bool? = (flags & 0x04 != 0) ? (flags & 0x02 != 0) : nil
        var energy: Int?
        if flags & 0x08 != 0 { energy = u16() }
        var rr: [Double] = []
        if flags & 0x10 != 0 { while let v = u16() { rr.append(Double(v) / 1024) } }
        guard (25...240).contains(bpm) else { return nil }   // drop 0 = "no reading" and glitches
        return Reading(date: date, bpm: bpm, rrIntervals: rr, contact: contact, energyKJ: energy)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEHeartRate: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated {
            switch state {
            case .poweredOn: connectOrScan()
            case .unsupported: status = .unsupported
            case .unauthorized: status = .unauthorized
            case .poweredOff: status = .poweredOff
            default: break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        MainActor.assumeIsolated {
            guard self.peripheral == nil, matchesPreferred(advName ?? peripheral.name) else { return }
            connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.rememberedKey)
            peripheral.discoverServices([Self.heartRateService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.peripheral = nil
            status = .notFound
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.peripheral = nil
            guard wantsConnection else { status = .off; return }
            // Band left range or sharing was turned off: try again (connect() never times out on iOS).
            connect(peripheral)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEHeartRate: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.heartRateService }) else {
                status = .notFound
                return
            }
            peripheral.discoverCharacteristics([Self.measurementChar], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard let c = service.characteristics?.first(where: { $0.uuid == Self.measurementChar }) else { return }
            peripheral.setNotifyValue(true, for: c)
            status = .connected(peripheral.name ?? "band")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.measurementChar,
              let data = characteristic.value, let r = Self.parse(data) else { return }
        MainActor.assumeIsolated {
            reading = r
            onReading?(r)
        }
    }
}
