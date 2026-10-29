import AppKit
import SwiftUI
import FreeCellCore

@MainActor final class GameModel: ObservableObject {
    @Published var session: GameSession
    @Published var selection: Source?
    @Published var hintedMove: Move?
    @Published var message = "留出空当，让每一步都有余地。"
    @Published var saveError: String?
    @Published var showNewDeal = false
    @Published var showRules = false
    @Published var confirmRestart = false
    @Published var autoCollect = false
    let saveURL: URL
    var board: Board { session.board }
    var canUndo: Bool { !session.undoStack.isEmpty }
    var canRedo: Bool { !session.redoStack.isEmpty }
    var timeLabel: String { String(format: "%02d:%02d", session.elapsedSeconds / 60, session.elapsedSeconds % 60) }

    init(saveURL: URL? = nil) {
        self.saveURL = saveURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FreeCell/game.json")
        if let restored = try? SaveFile.load(from: self.saveURL) {
            session = restored
            message = "已恢复上次的牌局，继续吧。"
        } else {
            session = GameSession(deal: UInt32.random(in: 1...32_000))
            if FileManager.default.fileExists(atPath: self.saveURL.path) {
                message = "上次存档无法读取，已开始新牌局。"
            }
        }
    }

    func newGame(deal: UInt32? = nil) {
        session = GameSession(deal: deal ?? UInt32.random(in: 1...32_000))
        clearSelection()
        message = "新的牌局，慢慢来。"
        save()
    }
    func restart() { newGame(deal: board.deal) }
    func clearSelection() { selection = nil; hintedMove = nil }
    func select(_ source: Source) {
        guard !board.isWon else { return }
        if selection == source { clearSelection(); return }
        if let selected = selection {
            let target: Destination
            switch source { case .column(let col, _): target = .column(col); case .cell(let cell): target = .cell(cell) }
            if board.canMove(Move(selected, target)) { perform(Move(selected, target)); return }
        }
        guard board.isOrdered(board.cards(at: source)) else {
            message = "只能移动红黑交替、点数递减的连续牌组。"
            clearSelection()
            return
        }
        selection = source
        hintedMove = nil
        let count = board.cards(at: source).count
        message = count > 1 ? "已选中 \(count) 张牌，点击亮起的位置移动。" : "已选中 \(board.cards(at: source)[0].name)，点击目标位置。"
    }
    func tapDestination(_ destination: Destination) {
        guard let source = selection else { return }
        perform(Move(source, destination))
    }
    @discardableResult func perform(_ move: Move) -> Bool {
        guard session.move(move, autoCollect: autoCollect) else {
            message = "这里暂时放不下。牌组移动需要足够的空当或空列。"
            return false
        }
        clearSelection()
        message = board.isWon ? "52 张牌，全部归位。漂亮！" : "好牌不急，下一步由你。"
        save()
        return true
    }
    func quickMove(_ source: Source) {
        guard let card = board.cards(at: source).first, board.cards(at: source).count == 1 else { select(source); return }
        let foundation = Move(source, .foundation(card.suit))
        if board.canMove(foundation) { perform(foundation); return }
        if case .column = source, let cell = board.cells.firstIndex(where: { $0 == nil }) {
            perform(Move(source, .cell(cell)))
        } else { select(source) }
    }
    func undo() {
        guard canUndo else { return }
        session.undo(); clearSelection(); message = "已撤销，可以换一种走法。"; save()
    }
    func redo() {
        guard canRedo else { return }
        session.redo(); clearSelection(); message = "已重做。"; save()
    }
    func hint() {
        guard let move = board.hint() else {
            message = board.isWon ? "恭喜完成本局！" : "没有可移动的牌了，试试撤销或重开本局。"
            clearSelection(); return
        }
        selection = move.source
        hintedMove = move
        let card = board.cards(at: move.source)[0]
        message = "试试把 \(card.name)\(board.cards(at: move.source).count > 1 ? " 所在的牌组" : "")移到\(move.destination.name)。"
    }
    func collect() {
        let count = session.collectSafely()
        clearSelection()
        message = count > 0 ? (board.isWon ? "52 张牌，全部归位。漂亮！" : "已安全收起 \(count) 张牌。") : "暂时没有可以安全收起的牌。"
        save()
    }
    func tick() {
        guard NSApp.isActive, board.moveCount > 0, !board.isWon, !showRules, !showNewDeal, !confirmRestart else { return }
        session.elapsedSeconds += 1
        if session.elapsedSeconds % 5 == 0 { save() }
    }
    func save() {
        do { try SaveFile.save(session, to: saveURL); saveError = nil }
        catch { saveError = "自动存档失败：\(error.localizedDescription)" }
    }
}
