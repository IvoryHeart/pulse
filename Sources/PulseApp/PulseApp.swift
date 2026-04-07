import SwiftUI
import PulseCore

@main
struct PulseApp: App {
    @StateObject private var viewModel = SystemViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            let scoreText = viewModel.healthScore.map { "\($0.score)" } ?? "P"
            Label(scoreText, systemImage: viewModel.statusIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Pulse Dashboard", id: "dashboard") {
            DashboardView(viewModel: viewModel)
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 900, height: 680)
    }
}
