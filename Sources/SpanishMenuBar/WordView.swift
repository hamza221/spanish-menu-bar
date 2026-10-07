import AVFoundation
import SpanishMenuBarCore
import SwiftUI

@MainActor
final class WordModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var displayed: DisplayedWord?
    @Published private(set) var isSpeaking = false
    let store: WordStore
    private let synthesizer = AVSpeechSynthesizer()

    init(store: WordStore) {
        self.store = store
        displayed = store.displayed
        super.init()
        synthesizer.delegate = self
    }

    func reload() { displayed = store.displayed }

    /// The popover is open, so the outgoing word was seen, and so is the incoming one.
    func next() {
        stopSpeaking()
        store.markSeen()
        store.advance()
        store.markSeen()
        reload()
    }

    /// Pronounces the current word with the best installed Spanish system voice.
    func speak() {
        guard let word = displayed?.word else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = Self.spanishVoice
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// An Enhanced/Premium Spanish voice if the user downloaded one (System Settings → Accessibility →
    /// Spoken Content), preferring Spain (es-ES); otherwise the system's default es-ES voice.
    private static var spanishVoice: AVSpeechSynthesisVoice? {
        let upgraded = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("es") && $0.quality != .default }
            .max { lhs, rhs in
                (lhs.quality.rawValue, lhs.language == "es-ES" ? 1 : 0) < (rhs.quality.rawValue, rhs.language == "es-ES" ? 1 : 0)
            }
        return upgraded ?? AVSpeechSynthesisVoice(language: "es-ES")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = synthesizer.isSpeaking }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = synthesizer.isSpeaking }
    }
}

struct WordView: View {
    @ObservedObject var model: WordModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let word = model.displayed {
                header(word)
                Divider().padding(.vertical, 10)
                senses(word.senses)
            } else {
                Text("No word available").foregroundStyle(.secondary)
            }
            Divider().padding(.vertical, 10)
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private func header(_ word: DisplayedWord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.word)
                    .font(.system(size: 26, weight: .bold))
                    .textSelection(.enabled)
                Button {
                    model.speak()
                } label: {
                    Image(systemName: model.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Pronounce (⌘P)")
                .accessibilityLabel("Pronounce \(word.word)")
                .keyboardShortcut("p")
            }
            if let previous = word.previous, let lastSeen = previous.lastSeen {
                Label {
                    Text("Last time seen \(LastSeenFormatter.string(from: lastSeen))")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func senses(_ senses: [Sense]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(senses.enumerated()), id: \.offset) { index, sense in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sense.definition)
                                .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 260)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
            Spacer()
            Button {
                model.next()
            } label: {
                Label("Next", systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }
}
