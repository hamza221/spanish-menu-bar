import AppKit
import Combine
import SpanishMenuBarCore
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// How often presence and the 30-minute refresh are checked.
    private static let tickInterval: TimeInterval = 10

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var model: WordModel!
    private var timer: Timer?
    private var titleSubscription: AnyCancellable?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dictionary: SpanishDictionary
        do {
            dictionary = try SpanishDictionary.loadBundled()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Spanish Menu Bar could not load its dictionary"
            alert.informativeText = String(describing: error)
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        let store = WordStore(dictionary: dictionary, fileURL: WordStore.defaultFileURL)
        store.start()
        model = WordModel(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        // Title follows the model, including "Next" presses while the popover is open.
        titleSubscription = model.$displayed.sink { [weak self] displayed in
            self?.statusItem.button?.title = displayed?.word ?? "—"
        }

        let host = NSHostingController(rootView: WordView(model: model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(tick), name: NSWorkspace.didWakeNotification, object: nil)

        timer = Timer.scheduledTimer(timeInterval: Self.tickInterval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer?.tolerance = 2
        tick()
    }

    @objc private func tick() {
        let store = model.store
        if Presence.userIsPresent(mouseMovedWithin: Self.tickInterval + 1) {
            store.markSeen()
        }
        // Never swap the word under an open popover.
        if !popover.isShown, store.refreshIfDue() {
            model.reload()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        model.store.markSeen()
        model.reload()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
