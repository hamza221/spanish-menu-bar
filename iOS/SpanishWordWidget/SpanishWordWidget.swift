import AppIntents
import SpanishMenuBarCore
import SwiftUI
import WidgetKit

struct WordEntry: TimelineEntry {
    let date: Date
    let word: ScheduledWord?
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        let sample = ScheduledWord(
            word: "madrugada",
            senses: [Sense(definition: "early morning", type: "{f}")],
            previous: nil,
            date: Date()
        )
        return WordEntry(date: Date(), word: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        do {
            let dictionary = try SpanishDictionary.loadBundled()
            let schedule = WordSchedule(dictionary: dictionary)
            let now = Date()
            var entries = [WordEntry(date: now, word: schedule.word(at: now))]
            var date = schedule.nextChange(after: now)
            for _ in 0..<48 {
                entries.append(WordEntry(date: date, word: schedule.word(at: date)))
                date = schedule.nextChange(after: date.addingTimeInterval(1))
            }
            completion(Timeline(entries: entries, policy: .after(date)))
        } catch {
            let retry = Date().addingTimeInterval(WordSchedule.interval)
            completion(Timeline(entries: [WordEntry(date: Date(), word: nil)], policy: .after(retry)))
        }
    }

    private func entry(at date: Date) -> WordEntry {
        guard let dictionary = try? SpanishDictionary.loadBundled() else {
            return WordEntry(date: date, word: nil)
        }
        return WordEntry(date: date, word: WordSchedule(dictionary: dictionary).word(at: date))
    }
}

struct NextWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Spanish Word"
    static let description = IntentDescription("Shows the next word immediately.")

    func perform() async throws -> some IntentResult {
        let dictionary = try SpanishDictionary.loadBundled()
        var schedule = WordSchedule(dictionary: dictionary)
        schedule.advance()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        Group {
            if let word = entry.word {
                switch family {
                case .accessoryCircular:
                    Text(word.word.prefix(3))
                        .font(.system(.body, design: .rounded, weight: .bold))
                case .accessoryInline:
                    Text("🇪🇸 \(word.word)")
                case .accessoryRectangular:
                    VStack(alignment: .leading) {
                        Text(word.word).font(.headline)
                        Text(word.senses.first?.definition ?? "")
                            .font(.caption)
                            .lineLimit(1)
                    }
                default:
                    homeScreenContent(word)
                }
            } else {
                Label("Dictionary unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
            }
        }
        .widgetURL(URL(string: "spanishword://current"))
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func homeScreenContent(_ word: ScheduledWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("SPANISH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(intent: NextWordIntent()) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next word")
            }
            Spacer(minLength: 0)
            Text(word.word)
                .font(.system(family == .systemSmall ? .title2 : .title, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.65)
                .lineLimit(2)
            if family != .systemSmall, let first = word.senses.first {
                Text(first.definition)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct SpanishWordWidget: Widget {
    let kind = "SpanishWordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Spanish Word")
        .description("A new Spanish word every 30 minutes.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct SpanishWordWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpanishWordWidget()
    }
}
