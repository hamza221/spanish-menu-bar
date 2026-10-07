import Foundation

/// Per-word history. A word counts as seen once per time it is put in the menu bar,
/// and only if the user was actually present (see `Presence` in the app target) or opened it.
public struct WordRecord: Codable, Equatable {
    public var seenCount: Int = 0
    public var lastSeen: Date?
}

/// Everything persisted between launches.
public struct PersistedState: Codable, Equatable {
    /// Words still to show in the current shuffled cycle (front is next).
    public var queue: [String] = []
    /// Word currently in the menu bar.
    public var current: String?
    /// When `current` was put in the menu bar (or last re-armed while unseen).
    public var currentShownAt: Date?
    /// Whether `current` has been seen during this display.
    public var currentSeen = false
    /// Snapshot of `current`'s record taken before this display, so the UI can show
    /// the *previous* time it was seen rather than "just now".
    public var currentPrevious: WordRecord?
    public var records: [String: WordRecord] = [:]
}

/// What the UI renders for the current word.
public struct DisplayedWord: Equatable {
    public let word: String
    public let senses: [Sense]
    /// `nil` when the word has never been seen before.
    public let previous: WordRecord?
}

/// Shuffled no-repeat rotation with persisted seen counts and timestamps.
///
/// Invariants:
/// - Every word is shown once per cycle; a new shuffle starts only when the queue is empty.
/// - A word that was not seen when its refresh interval elapses stays in the menu bar
///   (its timer is re-armed), so nobody "misses" a word while away, locked or asleep.
public final class WordStore {
    public let dictionary: SpanishDictionary
    public let refreshInterval: TimeInterval
    public private(set) var state: PersistedState
    private let fileURL: URL?

    public init(dictionary: SpanishDictionary, fileURL: URL?, refreshInterval: TimeInterval = 30 * 60) {
        self.dictionary = dictionary
        self.fileURL = fileURL
        self.refreshInterval = refreshInterval
        self.state = fileURL.flatMap(Self.load) ?? PersistedState()
        // Drop anything no longer in the dictionary (e.g. dictionary updated).
        state.queue.removeAll { dictionary.entries[$0] == nil }
    }

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpanishMenuBar", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    public var displayed: DisplayedWord? {
        guard let word = state.current, let senses = dictionary.entries[word] else { return nil }
        return DisplayedWord(word: word, senses: senses, previous: state.currentPrevious)
    }

    /// Ensures a valid current word exists (first launch / dictionary changed).
    public func start(now: Date = Date()) {
        if let current = state.current, dictionary.entries[current] != nil, state.currentShownAt != nil { return }
        advance(now: now)
    }

    /// Records that the user saw the current word. Idempotent per display.
    public func markSeen(now: Date = Date()) {
        guard let word = state.current, !state.currentSeen else { return }
        state.currentSeen = true
        var record = state.records[word] ?? WordRecord()
        record.seenCount += 1
        record.lastSeen = now
        state.records[word] = record
        save()
    }

    /// Called periodically. Returns `true` if the word changed.
    @discardableResult
    public func refreshIfDue(now: Date = Date()) -> Bool {
        guard let shownAt = state.currentShownAt, now.timeIntervalSince(shownAt) >= refreshInterval else { return false }
        guard state.currentSeen else {
            // Nobody saw it; keep it for another interval instead of skipping it.
            state.currentShownAt = now
            save()
            return false
        }
        advance(now: now)
        return true
    }

    /// Moves to the next word of the shuffled cycle, reshuffling when the cycle is complete.
    public func advance(now: Date = Date()) {
        if state.queue.isEmpty {
            state.queue = dictionary.words.shuffled()
            // Don't repeat the same word across the cycle boundary.
            if state.queue.count > 1, state.queue.first == state.current {
                state.queue.swapAt(0, state.queue.count - 1)
            }
        }
        guard !state.queue.isEmpty else { return }
        let word = state.queue.removeFirst()
        state.current = word
        state.currentShownAt = now
        state.currentSeen = false
        state.currentPrevious = state.records[word]
        save()
    }

    private static func load(from url: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedState.self, from: data)
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SpanishMenuBar: failed to save state: \(error)")
        }
    }
}
