import SwiftUI

@main
struct SpanishWordApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .onOpenURL { _ in model.activate() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.activate()
            case .background: model.deactivate()
            default: break
            }
        }
    }
}
