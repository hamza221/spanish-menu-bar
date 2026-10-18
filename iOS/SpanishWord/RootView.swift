import SpanishMenuBarCore
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                WordDetailView(model: model)
            }
            .tabItem { Label("Word", systemImage: "text.book.closed") }

            NavigationStack {
                HistoryView(history: model.history)
            }
            .tabItem { Label("Seen", systemImage: "clock.arrow.circlepath") }
        }
    }
}

private struct WordDetailView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let word = model.displayed {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(word.word)
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .layoutPriority(1)
                                    .textSelection(.enabled)
                                Spacer()
                                Button(action: model.speak) {
                                    Image(systemName: model.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Pronounce \(word.word)")
                            }
                            if let previous = word.previous, let date = previous.lastSeen {
                                Label("Last seen \(LastSeenFormatter.string(from: date))", systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(word.senses.enumerated()), id: \.offset) { index, sense in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.callout.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 22, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sense.definition)
                                            .font(.body)
                                            .textSelection(.enabled)
                                        if !sense.label.isEmpty {
                                            Text(sense.label)
                                                .font(.caption.italic())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .safeAreaInset(edge: .bottom) {
                    Button(action: model.next) {
                        Label("Next word", systemImage: "arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            } else if let error = model.loadError {
                ContentUnavailableView(
                    "Dictionary unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ProgressView("Loading dictionary…")
            }
        }
        .navigationTitle("Spanish Word")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryView: View {
    let history: [SeenWord]

    var body: some View {
        Group {
            if history.isEmpty {
                ContentUnavailableView(
                    "No words seen yet",
                    systemImage: "eyes",
                    description: Text("Open a word to add it to your history.")
                )
            } else {
                List(history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.word).font(.headline)
                            Spacer()
                            Text("×\(item.record.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let first = item.senses.first {
                            Text(first.definition)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let date = item.record.lastSeen {
                            Text("Last seen \(LastSeenFormatter.string(from: date))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Seen words")
    }
}
