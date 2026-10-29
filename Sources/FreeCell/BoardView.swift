import SwiftUI
import FreeCellCore

struct BoardLayout {
    let size: CGSize
    let columns: [[Card]]
    var margin: CGFloat { 30 }
    var gap: CGFloat { 18 }
    var width: CGFloat { min(108, (size.width - margin * 2 - gap * 7) / 8) }
    var height: CGFloat { width * 1.4 }
    var pitch: CGFloat { (size.width - margin * 2 - width) / 7 }
    var top: CGFloat { 20 }
    var tableauTop: CGFloat { top + height + 40 }
    func x(_ column: Int) -> CGFloat { margin + CGFloat(column) * pitch }
    func step(_ column: Int) -> CGFloat {
        let count = columns[column].count
        return min(34, max(width * 0.22 + 10, (size.height - tableauTop - height - 28) / CGFloat(max(1, count - 1))))
    }
    var contentHeight: CGFloat {
        max(size.height, columns.indices.map { tableauTop + CGFloat(max(0, columns[$0].count - 1)) * step($0) + height + 24 }.max() ?? size.height)
    }
    func origin(_ source: Source) -> CGPoint {
        switch source {
        case .cell(let cell): return CGPoint(x: x(cell), y: top)
        case .column(let col, let index): return CGPoint(x: x(col), y: tableauTop + CGFloat(index) * step(col))
        }
    }
    func destination(at point: CGPoint) -> Destination? {
        for index in 0..<8 where (x(index) - gap / 2 ... x(index) + width + gap / 2).contains(point.x) {
            if (top - 8 ... top + height + 8).contains(point.y) {
                return index < 4 ? .cell(index) : .foundation(Suit.allCases[index - 4])
            }
            if point.y >= tableauTop - 12 && point.y <= contentHeight { return .column(index) }
        }
        return nil
    }
}

struct BoardView: View {
    @ObservedObject var game: GameModel
    @ViewState<Source?> private var dragging: Source?
    @ViewState<CGSize> private var translation: CGSize = .zero
    @ViewState<Destination?> private var hovered: Destination?

    var body: some View {
        GeometryReader { proxy in
            let layout = BoardLayout(size: proxy.size, columns: game.board.columns)
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { game.clearSelection() }
                    ForEach(0..<4, id: \.self) { index in
                        let target = Destination.cell(index)
                        slot(layout: layout, target: target, x: layout.x(index), y: layout.top)
                        if let card = game.board.cells[index] {
                            playingCard(card, source: .cell(index), layout: layout)
                        }
                    }
                    ForEach(Suit.allCases, id: \.rawValue) { suit in
                        let target = Destination.foundation(suit)
                        let x = layout.x(suit.rawValue + 4)
                        slot(layout: layout, target: target, x: x, y: layout.top, symbol: suit.symbol)
                        if game.board.foundations[suit.rawValue] > 0 {
                            Button { game.tapDestination(target) } label: {
                                CardView(card: Card(game.board.foundations[suit.rawValue], suit), width: layout.width,
                                         selected: highlight(target))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(suit.name)收牌区，已收到 \(game.board.foundations[suit.rawValue])")
                                .offset(x: x, y: layout.top)
                        }
                    }
                    Rectangle().fill(.white.opacity(0.09)).frame(width: proxy.size.width - 60, height: 1)
                        .offset(x: 30, y: layout.tableauTop - 20)
                    ForEach(0..<8, id: \.self) { col in
                        let target = Destination.column(col)
                        slot(layout: layout, target: target, x: layout.x(col), y: layout.tableauTop)
                        ForEach(Array(game.board.columns[col].enumerated()), id: \.element.id) { index, card in
                            playingCard(card, source: .column(col, index), layout: layout)
                        }
                    }
                    if let source = dragging {
                        let origin = layout.origin(source)
                        let moving = game.board.cards(at: source)
                        ForEach(Array(moving.enumerated()), id: \.element.id) { index, card in
                            CardView(card: card, width: layout.width, selected: true)
                                .offset(x: origin.x + translation.width, y: origin.y + translation.height + CGFloat(index) * 30)
                                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
                                .allowsHitTesting(false)
                                .zIndex(100 + Double(index))
                        }
                    }
                }
                .frame(width: proxy.size.width, height: layout.contentHeight, alignment: .topLeading)
                .coordinateSpace(name: "board")
            }.scrollIndicators(.hidden)
        }.background(BoardProbe())
    }

    private func highlight(_ destination: Destination) -> Bool {
        if let dragging { return hovered == destination && game.board.canMove(Move(dragging, destination)) }
        if let hint = game.hintedMove { return hint.destination == destination }
        return game.selection.map { game.board.canMove(Move($0, destination)) } ?? false
    }

    private func slot(layout: BoardLayout, target: Destination, x: CGFloat, y: CGFloat, symbol: String = "") -> some View {
        Button { game.tapDestination(target) } label: {
            SlotView(width: layout.width, symbol: symbol, highlighted: highlight(target))
        }.buttonStyle(.plain).accessibilityLabel(target.name)
            .offset(x: x, y: y)
    }

    private func includes(_ source: Source?, card: Card) -> Bool {
        source.map { game.board.cards(at: $0).contains(card) } ?? false
    }

    private func playingCard(_ card: Card, source: Source, layout: BoardLayout) -> some View {
        let origin = layout.origin(source)
        let isTarget: Bool = {
            switch source {
            case .column(let col, let index): return index == game.board.columns[col].count - 1 && highlight(.column(col))
            case .cell(let index): return highlight(.cell(index))
            }
        }()
        return CardView(card: card, width: layout.width, selected: includes(game.selection, card: card) || isTarget)
            .opacity(includes(dragging, card: card) ? 0.25 : 1)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { game.quickMove(source) }
            .onTapGesture { game.select(source) }
            .gesture(DragGesture(minimumDistance: 5, coordinateSpace: .named("board"))
                .onChanged { value in
                    guard game.board.isOrdered(game.board.cards(at: source)) else { return }
                    if dragging == nil { dragging = source; game.selection = source; game.hintedMove = nil }
                    translation = value.translation
                    hovered = layout.destination(at: value.location)
                }
                .onEnded { value in
                    if let dragging, let target = layout.destination(at: value.location) {
                        game.perform(Move(dragging, target))
                    }
                    dragging = nil; translation = .zero; hovered = nil
                })
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(card.name)，\(sourceDescription(source))")
            .accessibilityAction { game.select(source) }
            .accessibilityAction(named: "自动移动") { game.quickMove(source) }
            .offset(x: origin.x, y: origin.y)
    }

    private func sourceDescription(_ source: Source) -> String {
        switch source { case .cell(let index): return "空当 \(index + 1)"; case .column(let col, _): return "第 \(col + 1) 列" }
    }
}

/// A transparent AppKit anchor for measuring and exercising the real SwiftUI board.
private struct BoardProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { BoardProbeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class BoardProbeView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
