import AVFoundation
import Foundation
import SpanishMenuBarCore
import WidgetKit

@MainActor
final class AppModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var displayed: ScheduledWord?
    @Published private(set) var history: [SeenWord] = []
    @Published private(set) var isSpeaking = false
    @Published private(set) var loadError: String?

    private var schedule: WordSchedule?
    private let synthesizer = AVSpeechSynthesizer()
    private var timer: Timer?

    override init() {
        super.init()
        synthesizer.delegate = self
        do {
            schedule = WordSchedule(dictionary: try SpanishDictionary.loadBundled())
            reload(markSeen: false)
        } catch {
            loadError = String(describing: error)
        }
    }

    func activate() {
        reload(markSeen: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshForTimeChange() }
        }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
        stopSpeaking()
    }

    func next() {
        stopSpeaking()
        guard var schedule else { return }
        let previous = schedule.advance()
        self.schedule = schedule
        displayed = previous
        history = schedule.history
        WidgetCenter.shared.reloadAllTimelines()
    }

    func speak() {
        guard let word = displayed?.word else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func refreshForTimeChange() {
        let oldWord = displayed?.word
        reload(markSeen: true)
        if displayed?.word != oldWord {
            stopSpeaking()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func reload(markSeen: Bool) {
        guard var schedule else { return }
        let current = schedule.word(at: Date())
        if markSeen { schedule.markCurrentSeen() }
        self.schedule = schedule
        displayed = current
        history = schedule.history
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
