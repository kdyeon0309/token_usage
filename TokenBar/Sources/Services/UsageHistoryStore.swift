import Foundation

actor UsageHistoryStore {
    private let fileURL: URL
    private let retentionInterval: TimeInterval
    private var cachedSamples: [UsageSample]?

    init(
        fileURL: URL = UsageHistoryStore.defaultFileURL,
        retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.fileURL = fileURL
        self.retentionInterval = retentionInterval
    }

    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TokenBar", isDirectory: true)
            .appendingPathComponent("usage-history.json")
    }

    func record(_ snapshots: [UsageSnapshot], at date: Date) throws -> [UsageSample] {
        var samples = try loadSamples()
        samples.removeAll { $0.capturedAt < date.addingTimeInterval(-retentionInterval) }

        for snapshot in snapshots {
            let sample = UsageSample(snapshot: snapshot, capturedAt: date)
            if let index = samples.lastIndex(where: { $0.provider == snapshot.provider }),
               date.timeIntervalSince(samples[index].capturedAt) < 30 {
                samples[index] = sample
            } else {
                samples.append(sample)
            }
        }

        samples.sort { $0.capturedAt < $1.capturedAt }
        try save(samples)
        cachedSamples = samples
        return samples
    }

    private func loadSamples() throws -> [UsageSample] {
        if let cachedSamples { return cachedSamples }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([UsageSample].self, from: Data(contentsOf: fileURL))
    }

    private func save(_ samples: [UsageSample]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(samples).write(to: fileURL, options: .atomic)
    }
}
