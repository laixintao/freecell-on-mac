import Foundation

public enum Suit: Int, CaseIterable, Codable, Sendable {
    case clubs, diamonds, hearts, spades
    public var symbol: String { ["♣", "♦", "♥", "♠"][rawValue] }
    public var name: String { ["梅花", "方块", "红桃", "黑桃"][rawValue] }
    public var isRed: Bool { self == .diamonds || self == .hearts }
}

public struct Card: Hashable, Codable, Identifiable, Sendable {
    public let suit: Suit
    public let rank: Int
    public init(_ rank: Int, _ suit: Suit) { self.rank = rank; self.suit = suit }
    public var id: Int { (rank - 1) * 4 + suit.rawValue }
    public var label: String {
        switch rank { case 1: return "A"; case 11: return "J"; case 12: return "Q"; case 13: return "K"; default: return String(rank) }
    }
    public var name: String { "\(suit.name)\(label)" }
    public func canRest(on other: Card) -> Bool { rank == other.rank - 1 && suit.isRed != other.suit.isRed }
}

public enum Source: Hashable, Codable, Sendable {
    case column(Int, Int)
    case cell(Int)
}

public enum Destination: Hashable, Codable, Sendable {
    case column(Int)
    case cell(Int)
    case foundation(Suit)
    public var name: String {
        switch self {
        case .column(let i): return "第 \(i + 1) 列"
        case .cell(let i): return "第 \(i + 1) 个空当"
        case .foundation(let suit): return "\(suit.name)收牌区"
        }
    }
}

public struct Move: Equatable, Sendable {
    public let source: Source
    public let destination: Destination
    public init(_ source: Source, _ destination: Destination) { self.source = source; self.destination = destination }
}

public struct Board: Equatable, Codable, Sendable {
    public var columns: [[Card]]
    public var cells: [Card?]
    public var foundations: [Int]
    public var deal: UInt32
    public var moveCount: Int

    public init(deal: UInt32) {
        self.deal = deal
        columns = Array(repeating: [], count: 8)
        cells = Array(repeating: nil, count: 4)
        foundations = Array(repeating: 0, count: 4)
        moveCount = 0
        // Microsoft FreeCell's numbered-deal shuffle, including its C rand sequence.
        var state = deal
        var deck = (0..<52).map { Card($0 / 4 + 1, Suit(rawValue: $0 % 4)!) }
        for index in 0..<52 {
            state = state &* 214013 &+ 2531011
            let pick = Int((state >> 16) & 0x7fff) % deck.count
            columns[index % 8].append(deck[pick])
            deck[pick] = deck[deck.count - 1]
            deck.removeLast()
        }
    }

    public var collected: Int { foundations.reduce(0, +) }
    public var isWon: Bool { foundations == [13, 13, 13, 13] }
    public var emptyCells: Int { cells.filter { $0 == nil }.count }

    public func cards(at source: Source) -> [Card] {
        switch source {
        case .column(let col, let index):
            guard columns.indices.contains(col), columns[col].indices.contains(index) else { return [] }
            return Array(columns[col][index...])
        case .cell(let index):
            guard cells.indices.contains(index), let card = cells[index] else { return [] }
            return [card]
        }
    }

    public func source(of cardID: Int) -> Source? {
        for col in columns.indices {
            if let index = columns[col].firstIndex(where: { $0.id == cardID }) { return .column(col, index) }
        }
        if let cell = cells.firstIndex(where: { $0?.id == cardID }) { return .cell(cell) }
        return nil
    }

    public func isOrdered(_ cards: [Card]) -> Bool {
        !cards.isEmpty && zip(cards, cards.dropFirst()).allSatisfy { $1.canRest(on: $0) }
    }

    public func capacity(to column: Int) -> Int {
        let emptyColumns = columns.indices.filter { $0 != column && columns[$0].isEmpty }.count
        return (emptyCells + 1) * (1 << emptyColumns)
    }

    public func canMove(_ move: Move) -> Bool {
        let cards = cards(at: move.source)
        guard let first = cards.first, isOrdered(cards) else { return false }
        switch move.destination {
        case .column(let index):
            guard columns.indices.contains(index) else { return false }
            if case .column(let source, _) = move.source, source == index { return false }
            guard cards.count <= capacity(to: index) else { return false }
            return columns[index].last.map { first.canRest(on: $0) } ?? true
        case .cell(let index):
            guard cells.indices.contains(index), cells[index] == nil, cards.count == 1 else { return false }
            return true
        case .foundation(let suit):
            return cards.count == 1 && first.suit == suit && first.rank == foundations[suit.rawValue] + 1
        }
    }

    @discardableResult public mutating func apply(_ move: Move) -> Bool {
        guard canMove(move) else { return false }
        let moving = cards(at: move.source)
        switch move.source {
        case .column(let col, let index): columns[col].removeSubrange(index...)
        case .cell(let index): cells[index] = nil
        }
        switch move.destination {
        case .column(let col): columns[col].append(contentsOf: moving)
        case .cell(let index): cells[index] = moving[0]
        case .foundation(let suit): foundations[suit.rawValue] = moving[0].rank
        }
        moveCount += 1
        return true
    }

    public func isSafeToCollect(_ card: Card) -> Bool {
        guard card.rank == foundations[card.suit.rawValue] + 1 else { return false }
        return Suit.allCases.filter { $0 != card.suit }.allSatisfy {
            foundations[$0.rawValue] >= card.rank - ($0.isRed == card.suit.isRed ? 2 : 1)
        } || card.rank <= 2
    }

    public func legalMoves() -> [Move] {
        var sources = cells.indices.filter { cells[$0] != nil }.map { Source.cell($0) }
        for col in columns.indices {
            sources += columns[col].indices.map { Source.column(col, $0) }
        }
        let destinations = Suit.allCases.map { Destination.foundation($0) }
            + columns.indices.map { Destination.column($0) } + cells.indices.map { Destination.cell($0) }
        return sources.flatMap { source in destinations.map { Move(source, $0) }.filter(canMove) }
    }

    public func hint() -> Move? {
        legalMoves().enumerated().max { left, right in
            let lhs = score(left.element), rhs = score(right.element)
            return lhs == rhs ? left.offset > right.offset : lhs < rhs
        }?.element
    }

    private func score(_ move: Move) -> Int {
        let moving = cards(at: move.source)
        switch move.destination {
        case .foundation: return isSafeToCollect(moving[0]) ? 1000 : 150
        case .column(let col):
            var score = columns[col].isEmpty ? 20 : 100
            if case .cell = move.source { score += 50 }
            if case .column(_, let index) = move.source {
                if index == 0 { score += columns[col].isEmpty ? -100 : 80 }
                score += moving.count * 3
            }
            return score
        case .cell: return 0
        }
    }

    /// Reject damaged saves before their values can be used as array indexes.
    public var isValid: Bool {
        guard columns.count == 8, cells.count == 4, foundations.count == 4,
              foundations.allSatisfy({ (0...13).contains($0) }), moveCount >= 0,
              (1...2_147_483_647).contains(deal) else { return false }
        var allCards = columns.flatMap { $0 } + cells.compactMap { $0 }
        for suit in Suit.allCases where foundations[suit.rawValue] > 0 {
            allCards += (1...foundations[suit.rawValue]).map { Card($0, suit) }
        }
        return allCards.count == 52 && allCards.allSatisfy { (1...13).contains($0.rank) }
            && Set(allCards).count == 52
    }
}

public struct GameSession: Codable, Sendable {
    public private(set) var board: Board
    public private(set) var undoStack: [Board] = []
    public private(set) var redoStack: [Board] = []
    public var elapsedSeconds: Int = 0
    public init(deal: UInt32) { board = Board(deal: deal) }

    @discardableResult public mutating func move(_ move: Move, autoCollect: Bool = false) -> Bool {
        guard board.canMove(move) else { return false }
        let previous = board
        board.apply(move)
        if autoCollect { _ = collect() }
        undoStack.append(previous)
        redoStack.removeAll()
        return true
    }

    @discardableResult public mutating func collectSafely() -> Int {
        let previous = board
        let count = collect()
        if count > 0 { undoStack.append(previous); redoStack.removeAll() }
        return count
    }

    private mutating func collect() -> Int {
        var count = 0
        while let move = board.legalMoves().first(where: {
            if case .foundation = $0.destination { return board.isSafeToCollect(board.cards(at: $0.source)[0]) }
            return false
        }) {
            board.apply(move)
            count += 1
        }
        return count
    }

    public mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(board); board = previous
    }
    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(board); board = next
    }
    public var isValid: Bool {
        elapsedSeconds >= 0 && board.isValid
            && undoStack.allSatisfy { $0.isValid && $0.deal == board.deal }
            && redoStack.allSatisfy { $0.isValid && $0.deal == board.deal }
    }
}

public enum SaveFile {
    public static func load(from url: URL) throws -> GameSession {
        let session = try JSONDecoder().decode(GameSession.self, from: Data(contentsOf: url))
        guard session.isValid else { throw CocoaError(.fileReadCorruptFile) }
        return session
    }
    public static func save(_ session: GameSession, to url: URL) throws {
        guard session.isValid else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: url, options: .atomic)
    }
}
