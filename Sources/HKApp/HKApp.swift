import SwiftUI
import HKCore

@main
struct HKApp: App {
    @StateObject private var viewModel = SystemViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            let scoreText = viewModel.healthScore.map { "\($0.score)" } ?? "HK"
            Label(scoreText, systemImage: viewModel.statusIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Housekeeping Dashboard", id: "dashboard") {
            DashboardView(viewModel: viewModel)
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 900, height: 680)
    }
}
