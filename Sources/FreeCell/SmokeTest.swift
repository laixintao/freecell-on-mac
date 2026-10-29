import AppKit
import FreeCellCore

/// Opt-in integration checks use a separate save and dispatch mouse events to the live window.
@MainActor enum SmokeTest {
    static func run(game: GameModel, directory: String) {
        Task {
            let root = URL(fileURLWithPath: directory)
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                game.newGame(deal: 1)
                let initial = game.board
                guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
                      let content = window.contentView else { throw Failure("Native window") }
                window.setContentSize(NSSize(width: 1120, height: 820))
                try await activate(window)
                try await pause()
                try snapshot(window, to: root.appendingPathComponent("native-window.png"))
                guard let probe = findProbe(content) else { throw Failure("Board geometry") }
                @MainActor func point(_ source: Source, upperEdge: Bool = false) -> NSPoint {
                    let layout = BoardLayout(size: probe.bounds.size, columns: game.board.columns)
                    let origin = layout.origin(source)
                    return probe.convert(NSPoint(x: origin.x + layout.width / 2, y: origin.y + (upperEdge ? 12 : layout.height / 2)), to: nil)
                }
                let source = Source.column(0, initial.columns[0].count - 1)
                try "probe=\(probe.frame) bounds=\(probe.bounds) point=\(point(source)) active=\(NSApp.isActive) key=\(window.isKeyWindow)\n".write(to: root.appendingPathComponent("geometry.txt"), atomically: true, encoding: .utf8)
                try await click(point(source), in: window)
                guard game.selection == source else {
                    try snapshot(window, to: root.appendingPathComponent("selection-failure.png"))
                    throw Failure("Mouse selection: expected=\(source) actual=\(String(describing: game.selection)), message=\(game.message)")
                }
                try snapshot(window, to: root.appendingPathComponent("selected.png"))
                try await click(point(.cell(0)), in: window)
                guard game.board.cells[0] == initial.columns[0].last, game.board.moveCount == 1 else { throw Failure("Mouse click-to-move") }
                let moved = game.board
                try snapshot(window, to: root.appendingPathComponent("moved.png"))
                try menuDescription(NSApp.mainMenu).write(to: root.appendingPathComponent("menu.txt"), atomically: true, encoding: .utf8)
                try key("z", modifiers: .command, in: window)
                try await pause()
                guard game.board == initial else { throw Failure("Undo shortcut: moves=\(game.board.moveCount), undo=\(game.canUndo), redo=\(game.canRedo)") }
                try key("z", modifiers: [.command, .shift], in: window)
                try await pause()
                guard game.board == moved else { throw Failure("Redo shortcut: moves=\(game.board.moveCount), undo=\(game.canUndo), redo=\(game.canRedo)") }
                try await drag(from: point(.cell(0)), to: point(.cell(1)), in: window)
                guard game.board.cells[0] == nil, game.board.cells[1] == initial.columns[0].last else { throw Failure("Mouse drag-and-drop") }
                let dragged = game.board
                game.save()
                let restored = try SaveFile.load(from: game.saveURL)
                guard restored.board == dragged, restored.undoStack.count == 2 else { throw Failure("Save / restore") }
                game.hint()
                guard let hint = game.hintedMove, game.board.canMove(hint) else { throw Failure("Hint") }
                game.restart()
                guard game.board == initial, game.session.elapsedSeconds == 0 else { throw Failure("Restart") }
                try await pause()
                let quickSource = Source.column(2, initial.columns[2].count - 1)
                try await activate(window)
                for count in 1...2 {
                    mouse(.leftMouseDown, at: point(quickSource), in: window, clickCount: count)
                    mouse(.leftMouseUp, at: point(quickSource), in: window, clickCount: count)
                    try await Task.sleep(for: .milliseconds(70))
                }
                try await pause()
                guard game.board.cells[0] == initial.columns[2].last else { throw Failure("Double-click quick move") }
                // Exercise a legal two-card drag, not just a single-card gesture.
                game.session = try fixtureSession(columns: [[Card(8, .clubs), Card(7, .hearts)], [Card(9, .diamonds)]], foundations: [0, 0, 0, 0])
                try await pause()
                try await drag(from: point(.column(0, 0), upperEdge: true), to: point(.column(1, 0)), in: window)
                guard game.board.columns[0].isEmpty, game.board.columns[1] == [Card(9, .diamonds), Card(8, .clubs), Card(7, .hearts)] else { throw Failure("Stack drag-and-drop") }
                game.session = try fixtureSession(columns: Suit.allCases.map { [Card(13, $0)] }, foundations: [12, 12, 12, 12])
                game.collect()
                guard game.board.isWon else { throw Failure("Win detection") }
                try await pause()
                try snapshot(window, to: root.appendingPathComponent("win.png"))
                game.undo()
                guard !game.board.isWon, game.board.collected == 48 else { throw Failure("Undo winning collection") }
                game.newGame(deal: 1)
                window.setContentSize(NSSize(width: 900, height: 700))
                try await pause()
                try snapshot(window, to: root.appendingPathComponent("small-window.png"))
                game.showRules = true
                try await pause()
                if let sheet = window.sheets.first { try snapshot(sheet, to: root.appendingPathComponent("rules.png")) }
                else { throw Failure("Rules sheet") }
                game.showRules = false
                try await pause()
                game.showNewDeal = true
                try await pause()
                if let sheet = window.sheets.first { try snapshot(sheet, to: root.appendingPathComponent("new-deal.png")) }
                else { throw Failure("New deal sheet") }
                game.showNewDeal = false
                try await pause()
                game.confirmRestart = true
                try await pause()
                if let sheet = window.sheets.first { try snapshot(sheet, to: root.appendingPathComponent("restart.png")) }
                else { throw Failure("Restart sheet") }
                game.confirmRestart = false
                window.setContentSize(NSSize(width: 1120, height: 820))
                try await pause()
                try "PASS: native window, mouse selection, click-to-move, undo/redo shortcuts, single-card drag, stack drag, double-click, save/restore, hint, restart, win/undo, small window, rules/new-deal/restart sheets\n".write(to: root.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
                print("FreeCell native smoke test passed: \(root.path)")
                if CommandLine.arguments.contains("--exit-after-test") { NSApp.terminate(nil) }
            } catch {
                try? "FAIL: \(error)\n".write(to: root.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
                print("FreeCell smoke test failed: \(error)")
                if CommandLine.arguments.contains("--exit-after-test") { exit(1) }
            }
        }
    }

    private static func fixtureSession(columns: [[Card]], foundations: [Int]) throws -> GameSession {
        var board = Board(deal: 1)
        board.columns = columns + Array(repeating: [], count: 8 - columns.count)
        board.foundations = foundations
        let used = Set(columns.flatMap { $0 })
        let remaining = Suit.allCases.flatMap { suit in
            (1...13).filter { $0 > foundations[suit.rawValue] }.map { Card($0, suit) }
        }.filter { !used.contains($0) }
        board.columns[7] += remaining
        guard board.isValid else { throw Failure("Fixture") }
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameSession(deal: 1))) as! [String: Any]
        json["board"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board))
        return try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private static func findProbe(_ view: NSView) -> BoardProbeView? {
        if let probe = view as? BoardProbeView { return probe }
        for child in view.subviews { if let found = findProbe(child) { return found } }
        return nil
    }
    private static func activate(_ window: NSWindow) async throws {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<50 {
            if NSApp.isActive && window.isKeyWindow { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure("App did not acquire focus")
    }
    private static func pause() async throws { try await Task.sleep(for: .seconds(max(0.9, NSEvent.doubleClickInterval + 0.3))) }
    private static func mouse(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow, clickCount: Int = 1) {
        let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount, pressure: type == .leftMouseUp ? 0 : 1)!
        window.sendEvent(event)
    }
    private static func click(_ point: NSPoint, in window: NSWindow) async throws {
        try await activate(window)
        mouse(.leftMouseDown, at: point, in: window)
        try await Task.sleep(for: .milliseconds(60))
        mouse(.leftMouseUp, at: point, in: window)
        try await pause()
    }
    private static func drag(from start: NSPoint, to end: NSPoint, in window: NSWindow) async throws {
        try await activate(window)
        mouse(.leftMouseDown, at: start, in: window)
        for step in 1...12 {
            try await Task.sleep(for: .milliseconds(30))
            let amount = CGFloat(step) / 12
            mouse(.leftMouseDragged, at: NSPoint(x: start.x + (end.x - start.x) * amount, y: start.y + (end.y - start.y) * amount), in: window)
        }
        mouse(.leftMouseUp, at: end, in: window)
        try await pause()
    }
    private static func menuDescription(_ menu: NSMenu?, indent: String = "") -> String {
        guard let menu else { return "" }
        return menu.items.map {
            "\(indent)\($0.title) | \($0.keyEquivalent) | \($0.isEnabled) | \(String(describing: $0.action))\n" + menuDescription($0.submenu, indent: indent + "  ")
        }.joined()
    }
    private static func key(_ character: String, modifiers: NSEvent.ModifierFlags, in window: NSWindow) throws {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                                    windowNumber: window.windowNumber, context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: 6)!
        func update(_ menu: NSMenu?) {
            menu?.update()
            menu?.items.forEach { update($0.submenu) }
        }
        update(NSApp.mainMenu)
        NSApp.sendEvent(event)
        let release = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber, context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: 6)!
        NSApp.sendEvent(release)
    }
    private static func snapshot(_ window: NSWindow, to url: URL) throws {
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw Failure("Snapshot allocation") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw Failure("PNG encoding") }
        try data.write(to: url)
    }
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
