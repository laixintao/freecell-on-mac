import Testing
import Foundation
@testable import FreeCellCore

struct GameTests {
    func emptyBoard() -> Board {
        var board = Board(deal: 1)
        board.columns = Array(repeating: [], count: 8)
        board.cells = Array(repeating: nil, count: 4)
        return board
    }

    @Test func testMicrosoftDealOneAndDeterminism() {
        let board = Board(deal: 1)
        #expect(board.columns.compactMap(\.first) == [Card(11, .diamonds), Card(2, .diamonds), Card(9, .hearts), Card(11, .clubs), Card(5, .diamonds), Card(7, .hearts), Card(7, .clubs), Card(5, .hearts)])
        #expect(board.columns.map(\.count) == [7, 7, 7, 7, 6, 6, 6, 6])
        #expect(Board(deal: 1) == board)
        #expect(Board(deal: 2) != board)
        #expect(board.isValid)
    }

    @Test func testEveryDealHasExactly52UniqueCards() {
        for seed: UInt32 in [1, 2, 617, 11982, 32000, 1_000_000, 2_147_483_647] {
            let board = Board(deal: seed)
            #expect(board.isValid)
            #expect(Set(board.columns.flatMap { $0 }).count == 52)
        }
    }

    @Test func testAlternatingDescendingTableauAndEmptyColumn() {
        var board = emptyBoard()
        board.columns[0] = [Card(7, .hearts)]
        board.columns[1] = [Card(8, .spades)]
        board.columns[2] = [Card(8, .diamonds)]
        board.columns[3] = [Card(9, .clubs)]
        #expect(board.canMove(Move(.column(0, 0), .column(1))))
        #expect(!(board.canMove(Move(.column(0, 0), .column(2)))))
        #expect(!(board.canMove(Move(.column(0, 0), .column(3)))))
        #expect(board.canMove(Move(.column(0, 0), .column(4))))
        #expect(!(board.canMove(Move(.column(0, 0), .column(0)))))
    }

    @Test func testCellsHoldOnlyOneAndOnlyExposedCards() {
        var board = emptyBoard()
        board.columns[0] = [Card(8, .clubs), Card(7, .hearts)]
        board.cells[0] = Card(2, .hearts)
        #expect(!(board.canMove(Move(.column(0, 1), .cell(0)))))
        #expect(!(board.canMove(Move(.column(0, 0), .cell(1)))))
        let result48 = board.apply(Move(.column(0, 1), .cell(1)))
        #expect(result48)
        #expect(board.columns[0] == [Card(8, .clubs)])
        #expect(board.cells[1] == Card(7, .hearts))
    }

    @Test func testFoundationRequiresMatchingSuitAndNextRank() {
        var board = emptyBoard()
        board.cells = [Card(1, .hearts), Card(2, .hearts), Card(3, .hearts), nil]
        #expect(!(board.canMove(Move(.cell(1), .foundation(.hearts)))))
        #expect(!(board.canMove(Move(.cell(0), .foundation(.diamonds)))))
        let result58 = board.apply(Move(.cell(0), .foundation(.hearts)))
        #expect(result58)
        let result59 = board.apply(Move(.cell(1), .foundation(.hearts)))
        #expect(result59)
        #expect(board.collected == 2)
        #expect(!(board.isWon))
    }

    @Test func testSupermoveCapacityExcludesEmptyDestination() {
        var board = emptyBoard()
        board.cells = [Card(1, .clubs), Card(1, .diamonds), Card(1, .hearts), nil]
        board.columns = [
            [Card(8, .clubs), Card(7, .hearts), Card(6, .clubs), Card(5, .hearts)],
            [Card(9, .hearts)], [], [Card(10, .clubs)], [Card(10, .diamonds)],
            [Card(11, .clubs)], [Card(11, .hearts)], [Card(12, .clubs)]
        ]
        #expect(board.capacity(to: 1) == 4)
        #expect(board.capacity(to: 2) == 2)
        #expect(board.canMove(Move(.column(0, 0), .column(1))))
        #expect(!(board.canMove(Move(.column(0, 0), .column(2)))))
        #expect(board.canMove(Move(.column(0, 2), .column(2))))
        board.cells[3] = Card(2, .diamonds)
        #expect(!(board.canMove(Move(.column(0, 0), .column(1)))))
    }

    @Test func testDisorderedRunsAndBadIndicesNeverMove() {
        var board = emptyBoard()
        board.columns[0] = [Card(8, .clubs), Card(7, .spades)]
        let before = board
        for move in [Move(.column(0, 0), .column(1)), Move(.column(-1, 0), .column(1)), Move(.column(0, 2), .column(1)), Move(.cell(9), .cell(0)), Move(.column(0, 1), .column(8)), Move(.column(0, 1), .cell(-1))] {
            let result86 = !(board.apply(move))
            #expect(result86)
            #expect(board == before)
        }
    }

    @Test func testSafeCollectionKeepsUsefulHighCards() {
        var board = emptyBoard()
        board.foundations = [2, 0, 0, 0]
        #expect(!(board.isSafeToCollect(Card(3, .clubs))))
        board.foundations = [2, 2, 2, 1]
        #expect(board.isSafeToCollect(Card(3, .clubs)))
        #expect(!(board.isSafeToCollect(Card(4, .clubs))))
        #expect(board.isSafeToCollect(Card(2, .spades)))
    }

    @Test func testUndoRedoAndBranching() {
        var game = GameSession(deal: 1)
        let initial = game.board
        let result104 = game.move(Move(.column(0, 6), .cell(0)))
        #expect(result104)
        let moved = game.board
        game.undo(); #expect(game.board == initial)
        game.redo(); #expect(game.board == moved)
        game.undo()
        let result109 = game.move(Move(.column(1, 6), .cell(0)))
        #expect(result109)
        #expect(game.redoStack.isEmpty)
        let branched = game.board
        game.redo(); #expect(game.board == branched)
        let result113 = !(game.move(Move(.column(1, 0), .cell(0))))
        #expect(result113)
        #expect(game.undoStack.count == 1)
    }

    @Test func testAutoCollectionIsOneUndoableTransaction() throws {
        var board = emptyBoard()
        board.cells = [Card(1, .clubs), Card(1, .diamonds), Card(1, .hearts), nil]
        board.columns[0] = [Card(1, .spades)]
        board.columns[1] = (2...13).flatMap { rank in Suit.allCases.map { Card(rank, $0) } }
        #expect(board.isValid)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(GameSession(deal: 1))) as? [String: Any])
        object["board"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board))
        var game = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: object))
        let didMove = game.move(Move(.column(0, 0), .cell(3)), autoCollect: true)
        #expect(didMove)
        #expect(game.board.collected == 4)
        #expect(game.board.moveCount == 5)
        #expect(game.undoStack.count == 1)
        #expect(game.board.isValid)
        game.undo()
        #expect(game.board == board)
        game.redo()
        #expect(game.board.collected == 4)
        #expect(game.board.isValid)
    }

    @Test func testWinAndAllCardsConserved() {
        var board = emptyBoard()
        board.foundations = [12, 12, 12, 12]
        board.cells = Suit.allCases.map { Card(13, $0) }
        #expect(board.isValid)
        #expect(!(board.isWon))
        for suit in Suit.allCases {
            let result136 = board.apply(Move(.cell(suit.rawValue), .foundation(suit)))
            #expect(result136)
            #expect(board.isValid)
        }
        #expect(board.isWon)
        #expect(board.collected == 52)
        #expect(board.legalMoves().isEmpty)
        #expect(board.hint() == nil)
    }

    @Test func testRandomLegalPlayConservesCardsAndHintsAreLegal() {
        var state: UInt64 = 1234
        for deal: UInt32 in 1...12 {
            var game = GameSession(deal: deal)
            for step in 0..<150 {
                let moves = game.board.legalMoves()
                if moves.isEmpty { break }
                if let hint = game.board.hint() { #expect(game.board.canMove(hint)) }
                state = state &* 6364136223846793005 &+ 1
                let before = game.board
                let result155 = game.move(moves[Int(state % UInt64(moves.count))], autoCollect: step % 3 == 0)
                #expect(result155)
                #expect(game.board.isValid)
                if step % 10 == 0 {
                    let after = game.board
                    game.undo(); #expect(game.board == before)
                    game.redo(); #expect(game.board == after)
                }
            }
        }
    }

    @Test func testSaveRoundTripRestoresHistoryAndTime() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("game.json")
        var game = GameSession(deal: 617)
        game.move(Move(.column(0, 6), .cell(0)))
        game.elapsedSeconds = 137
        try SaveFile.save(game, to: url)
        var restored = try SaveFile.load(from: url)
        #expect(restored.board == game.board)
        #expect(restored.elapsedSeconds == 137)
        #expect(restored.undoStack == game.undoStack)
        restored.undo()
        #expect(restored.board == Board(deal: 617))
    }

    @Test func testCorruptAndIncompleteSavesAreRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        #expect(throws: (any Error).self) { try SaveFile.load(from: url) }
        let game = GameSession(deal: 1)
        let encoded = try JSONEncoder().encode(game)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var board = try #require(object["board"] as? [String: Any])
        board["cells"] = []
        object["board"] = board
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        #expect(throws: (any Error).self) { try SaveFile.load(from: url) }
    }
}
