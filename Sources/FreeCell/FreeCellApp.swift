import AppKit
import SwiftUI
import FreeCellCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var game: GameModel?
    private var keyboardMonitor: Any?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { game?.save() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.option), !event.modifierFlags.contains(.control),
                  event.charactersIgnoringModifiers?.lowercased() == "z" else { return event }
            let redo = event.modifierFlags.contains(.shift)
            let handled = MainActor.assumeIsolated {
                guard let game = self?.game, !game.showNewDeal, !game.showRules, !game.confirmRestart else { return false }
                if redo { game.redo() } else { game.undo() }
                return true
            }
            return handled ? nil : event
        }
    }
}

@main struct FreeCellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var game: GameModel
    private let smokeDirectory: String?

    init() {
        let args = CommandLine.arguments
        let index = args.firstIndex(of: "--smoke-test")
        let directory = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        smokeDirectory = directory
        let saveURL = directory.map { URL(fileURLWithPath: $0).appendingPathComponent("smoke-save.json") }
        _game = StateObject(wrappedValue: GameModel(saveURL: saveURL))
    }

    var body: some Scene {
        Window("空当接龙 · FreeCell", id: "main") {
            ContentView(game: game)
                .onAppear {
                    delegate.game = game
                    if let smokeDirectory {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            SmokeTest.run(game: game, directory: smokeDirectory)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 820)
        .commands { GameCommands(game: game) }
    }
}

struct GameCommands: Commands {
    @ObservedObject var game: GameModel
    var body: some Commands {
            CommandGroup(replacing: .newItem) {
                Button("新牌局…") { game.showNewDeal = true }.keyboardShortcut("n")
                Button("重开本局…") { game.confirmRestart = true }.keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { game.undo() }.keyboardShortcut("z")
                Button("重做") { game.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandMenu("牌局") {
                Button("提示") { game.hint() }.keyboardShortcut("i").disabled(game.board.isWon)
                Button("安全收牌") { game.collect() }.keyboardShortcut("a", modifiers: [.command, .shift]).disabled(game.board.isWon)
                Toggle("移动后自动安全收牌", isOn: $game.autoCollect)
                Divider()
                Button("取消选择") { game.clearSelection() }.keyboardShortcut(.escape, modifiers: [])
            }
            CommandGroup(replacing: .help) {
                Button("空当接龙玩法") { game.showRules = true }.keyboardShortcut("/", modifiers: [.command, .shift])
            }
    }
}
