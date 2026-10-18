import Foundation
import SpanishMenuBarCore

struct SeenRecord: Codable, Equatable {
    var count: Int = 0
    var lastSeen: Date?
}

struct ScheduleState: Codable {
    var order: [String]
    var anchor: Date
    var offset: Int
    var records: [String: SeenRecord]
    var lastSeenToken: String?
}

struct ScheduledWord: Equatable {
    let word: String
    let senses: [Sense]
    let previous: SeenRecord?
    let date: Date
}

struct SeenWord: Identifiable {
    let word: String
    let record: SeenRecord
    let senses: [Sense]

    var id: String { word }
}

struct WordSchedule {
    static let interval: TimeInterval = 30 * 60
    static let appGroup = "group.com.hamzamahjoubi.SpanishWord"

    private let dictionary: SpanishDictionary
    private(set) var state: ScheduleState
    private let fileURL: URL

    init(dictionary: SpanishDictionary, now: Date = Date()) {
        self.dictionary = dictionary
        self.fileURL = Self.stateFileURL
        let loaded = Self.load(from: Self.stateFileURL)
        self.state = Self.normalized(loaded, words: dictionary.words, now: now)
        save()
    }

    func word(at date: Date) -> ScheduledWord? {
        guard !state.order.isEmpty else { return nil }
        let index = orderIndex(at: date)
        let word = state.order[index]
        guard let senses = dictionary.entries[word] else { return nil }
        return ScheduledWord(word: word, senses: senses, previous: state.records[word], date: date)
    }

    func nextChange(after date: Date) -> Date {
        guard date >= state.anchor else { return state.anchor }
        let slots = floor(date.timeIntervalSince(state.anchor) / Self.interval) + 1
        return state.anchor.addingTimeInterval(slots * Self.interval)
    }

    mutating func markCurrentSeen(at date: Date = Date()) {
        guard let current = word(at: date) else { return }
        let token = displayToken(at: date)
        guard state.lastSeenToken != token else { return }
        state.lastSeenToken = token
        var record = state.records[current.word] ?? SeenRecord()
        record.count += 1
        record.lastSeen = date
        state.records[current.word] = record
        save()
    }

    @discardableResult
    mutating func advance(at date: Date = Date(), markSeen: Bool = true) -> ScheduledWord? {
        if markSeen { markCurrentSeen(at: date) }
        let currentIndex = orderIndex(at: date)
        state.offset = (currentIndex + 1) % max(state.order.count, 1)
        state.anchor = date
        state.lastSeenToken = nil
        let result = word(at: date)
        if markSeen { markCurrentSeen(at: date) }
        save()
        return result
    }

    var history: [SeenWord] {
        state.records.compactMap { word, record in
            guard let senses = dictionary.entries[word], record.count > 0 else { return nil }
            return SeenWord(word: word, record: record, senses: senses)
        }
        .sorted { ($0.record.lastSeen ?? .distantPast) > ($1.record.lastSeen ?? .distantPast) }
    }

    private func orderIndex(at date: Date) -> Int {
        guard !state.order.isEmpty else { return 0 }
        let elapsed = max(0, Int(floor(date.timeIntervalSince(state.anchor) / Self.interval)))
        return (state.offset + elapsed) % state.order.count
    }

    private func displayToken(at date: Date) -> String {
        let slot = max(0, Int(floor(date.timeIntervalSince(state.anchor) / Self.interval)))
        return "\(state.anchor.timeIntervalSinceReferenceDate)-\(slot)"
    }

    private static var stateFileURL: URL {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SpanishWord", isDirectory: true)
        return base.appendingPathComponent("schedule.json")
    }

    private static func normalized(_ loaded: ScheduleState?, words: [String], now: Date) -> ScheduleState {
        guard var loaded else {
            return ScheduleState(order: words.shuffled(), anchor: now, offset: 0, records: [:], lastSeenToken: nil)
        }
        let available = Set(words)
        loaded.order.removeAll { !available.contains($0) }
        let known = Set(loaded.order)
        loaded.order.append(contentsOf: words.filter { !known.contains($0) }.shuffled())
        if loaded.order.isEmpty {
            loaded.order = words.shuffled()
            loaded.anchor = now
            loaded.offset = 0
        } else {
            loaded.offset %= loaded.order.count
        }
        return loaded
    }

    private static func load(from url: URL) -> ScheduleState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScheduleState.self, from: data)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Spanish Word: failed to save schedule: \(error)")
        }
    }
}
