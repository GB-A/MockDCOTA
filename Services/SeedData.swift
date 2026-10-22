import Foundation

/// Deterministic pseudo-random generator so every launch produces identical data.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum SeedData {
    /// Fixed "now" so `lastCheckIn` values are stable across runs.
    static let referenceDate = Date(timeIntervalSince1970: 1_760_000_000)

    static let stores: [Store] = {
        let partners = ["Northwind Retail", "Contoso Mobile", "Fabrikam Stores", "Tailspin Tech"]
        let cities = ["London", "Manchester", "Leeds", "Glasgow", "Bristol", "Cardiff",
                      "Edinburgh", "Belfast", "Sheffield", "Liverpool", "Dublin", "Cork"]
        return cities.enumerated().map { i, city in
            Store(id: "store-\(String(format: "%03d", i + 1))",
                  name: "\(city) Central",
                  city: city,
                  partner: partners[i % partners.count],
                  deviceCount: 0) // filled in below
        }
    }()

    static let packages: [ContentPackage] = [
        .init(id: "pkg-001", name: "Holiday Demo Loop", version: "2.1.0", sizeMB: 480, category: "Marketing"),
        .init(id: "pkg-002", name: "Trade-In Promo", version: "1.4.2", sizeMB: 120, category: "Promotion"),
        .init(id: "pkg-003", name: "Accessories Showcase", version: "3.0.0", sizeMB: 260, category: "Product"),
        .init(id: "pkg-004", name: "Store Safety Notice", version: "1.0.1", sizeMB: 12, category: "Compliance"),
        .init(id: "pkg-005", name: "Wearables Launch", version: "0.9.0", sizeMB: 910, category: "Marketing"),
    ]

    /// A 480-device sample of the fleet (the dashboard reports the full 1.4M).
    static let devices: [Device] = {
        var rng = SeededGenerator(seed: 42)
        let models = ["Demo Phone 15", "Demo Phone 16", "Demo Tablet Air", "Demo Tablet Pro", "Demo Watch"]
        let oses = ["17.6", "17.7", "18.0", "18.1"]
        let statuses: [DeviceStatus] = [.online, .online, .online, .online, .online, .online,
                                        .offline, .updating, .failed]
        return (1...480).map { n in
            let store = stores[Int.random(in: 0..<stores.count, using: &rng)]
            let status = statuses[Int.random(in: 0..<statuses.count, using: &rng)]
            let ageMinutes = status == .offline
                ? Int.random(in: 600...20_000, using: &rng)
                : Int.random(in: 0...30, using: &rng)
            return Device(
                id: "dev-\(String(format: "%05d", n))",
                serialNumber: "C02\(String(format: "%07d", 1_000_000 + n * 37))",
                model: models[Int.random(in: 0..<models.count, using: &rng)],
                osVersion: oses[Int.random(in: 0..<oses.count, using: &rng)],
                storeID: store.id,
                storeName: store.name,
                status: status,
                contentVersion: status == .failed ? nil : "2.0.\(Int.random(in: 0...3, using: &rng))",
                lastCheckIn: referenceDate.addingTimeInterval(TimeInterval(-ageMinutes * 60))
            )
        }
    }()

    /// Stores with their real device counts from the sample.
    static let storesWithCounts: [Store] = stores.map { s in
        Store(id: s.id, name: s.name, city: s.city, partner: s.partner,
              deviceCount: devices.filter { $0.storeID == s.id }.count)
    }

    static let fleetScale = 1_400_000
}
