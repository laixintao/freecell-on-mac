import SwiftUI
import Combine
import FreeCellCore

struct ContentView: View {
    @ObservedObject var game: GameModel
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            LinearGradient(colors: [TableStyle.light, TableStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for x in stride(from: 0.0, to: size.width, by: 7) {
                    for y in stride(from: 0.0, to: size.height, by: 7) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(.white.opacity(0.035)))
                    }
                }
            }.allowsHitTesting(false)
            VStack(spacing: 0) {
                header
                BoardView(game: game)
                footer
            }.padding(.top, 28)
            if game.board.isWon { winOverlay }
        }
        .foregroundStyle(TableStyle.cream)
        .frame(minWidth: 900, minHeight: 700)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $game.showNewDeal) { NewDealView(game: game) }
        .sheet(isPresented: $game.showRules) { RulesView() }
        .sheet(isPresented: $game.confirmRestart) { RestartView(game: game) }
        .onReceive(timer) { _ in game.tick() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in game.save() }
        .onExitCommand { game.clearSelection() }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Image(systemName: "suit.club.fill")
                .font(.system(size: 30, weight: .regular)).foregroundStyle(TableStyle.gold)
                .frame(width: 44, height: 44)
                .accessibilityLabel("空当接龙")
            Spacer()
            metric("number", value: String(game.board.deal), help: "牌局编号")
            metric("arrow.left.arrow.right", value: String(game.board.moveCount), help: "步数")
            metric("clock", value: game.timeLabel, help: "用时")
            metric("square.stack", value: "\(game.board.collected)/52", help: "已收牌")
            Spacer()
            iconButton("arrow.clockwise", help: "重开本局（⇧⌘R）") { game.confirmRestart = true }
            iconButton("plus", help: "新牌局（⌘N）", prominent: true) { game.showNewDeal = true }
        }.padding(.horizontal, 30).padding(.top, 8).padding(.bottom, 19)
    }

    private func metric(_ symbol: String, value: String, help: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13, weight: .regular)).foregroundStyle(TableStyle.muted)
            Text(value).font(.system(size: 15, weight: .medium, design: .monospaced)).monospacedDigit()
        }.help(help).accessibilityElement(children: .ignore).accessibilityLabel("\(help) \(value)")
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
            HStack(spacing: 10) {
                iconButton("arrow.uturn.backward", help: "撤销（⌘Z）") { game.undo() }
                    .disabled(!game.canUndo).opacity(game.canUndo ? 1 : 0.3)
                iconButton("arrow.uturn.forward", help: "重做（⇧⌘Z）") { game.redo() }
                    .disabled(!game.canRedo).opacity(game.canRedo ? 1 : 0.3)
                Spacer()
                if let error = game.saveError {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(TableStyle.gold).help(error)
                }
                iconButton("lightbulb", help: "提示（⌘I）") { game.hint() }.disabled(game.board.isWon)
                iconButton("arrow.up.to.line", help: "安全收牌（⇧⌘A）") { game.collect() }.disabled(game.board.isWon)
                Spacer()
                iconButton(game.autoCollect ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack", help: "移动后自动安全收牌", prominent: game.autoCollect) {
                    game.autoCollect.toggle()
                }.accessibilityValue(game.autoCollect ? "已开启" : "已关闭")
                iconButton("questionmark", help: "玩法（⌘?）") { game.showRules = true }
            }.padding(.vertical, 14)
        }.padding(.horizontal, 30)
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.48)
            VStack(spacing: 24) {
                Image(systemName: "crown.fill").font(.system(size: 56, weight: .light)).foregroundStyle(TableStyle.gold)
                    .accessibilityLabel("恭喜，牌局已完成")
                HStack(spacing: 22) {
                    metric("arrow.left.arrow.right", value: String(game.board.moveCount), help: "步数")
                    metric("clock", value: game.timeLabel, help: "用时")
                }
                HStack(spacing: 16) {
                    iconButton("arrow.uturn.backward", help: "回看最后一步") { game.undo() }.disabled(!game.canUndo)
                    iconButton("plus", help: "再来一局", prominent: true) { game.newGame() }
                }
            }.padding(48)
                .background(TableStyle.background, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(TableStyle.gold.opacity(0.35)))
        }
    }
}

func iconButton(_ symbol: String, help: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 18, height: 20)
    }.buttonStyle(TableButtonStyle(prominent: prominent)).help(help).accessibilityLabel(help)
}

struct NewDealView: View {
    @ObservedObject var game: GameModel
    @Environment(\.dismiss) private var dismiss
    @ViewState<String> private var number = ""
    var validNumber: UInt32? {
        guard let value = UInt32(number.trimmingCharacters(in: .whitespaces)), (1...2_147_483_647).contains(value) else { return nil }
        return value
    }
    var body: some View {
        VStack(spacing: 26) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(TableStyle.gold)
            HStack(spacing: 12) {
                Image(systemName: "number").foregroundStyle(TableStyle.muted)
                TextField("", text: $number).textFieldStyle(.roundedBorder)
                    .font(.system(size: 17, design: .monospaced)).onSubmit { start() }
                    .help("牌局编号：1–2147483647；留空随机。开始后替换当前进度。")
                    .accessibilityLabel("牌局编号，留空随机")
            }
            HStack {
                iconButton("xmark", help: "取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                iconButton(number.isEmpty ? "shuffle" : "play.fill", help: "开始新牌局，替换当前进度", prominent: true) { start() }
                    .keyboardShortcut(.defaultAction).disabled(!number.isEmpty && validNumber == nil)
            }
        }.padding(32).frame(width: 280)
            .foregroundStyle(TableStyle.cream).background(TableStyle.background).preferredColorScheme(.dark)
    }
    private func start() {
        guard number.isEmpty || validNumber != nil else { return }
        game.newGame(deal: validNumber); dismiss()
    }
}

struct RestartView: View {
    @ObservedObject var game: GameModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "arrow.counterclockwise").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(TableStyle.gold)
            Text("#\(game.board.deal)").font(.system(size: 20, design: .monospaced))
            HStack(spacing: 54) {
                iconButton("xmark", help: "取消") { dismiss() }.keyboardShortcut(.cancelAction)
                iconButton("checkmark", help: "重开本局，清空当前进度与计时", prominent: true) { game.restart(); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }.padding(36).frame(width: 240)
            .foregroundStyle(TableStyle.cream).background(TableStyle.background).preferredColorScheme(.dark)
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 26) {
            HStack {
                Image(systemName: "hand.draw").font(.system(size: 25, weight: .light)).foregroundStyle(TableStyle.gold)
                Spacer()
                iconButton("xmark", help: "关闭玩法") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 22) {
                diagram(help: "红黑交替、点数递减；空列可放任意牌") {
                    ZStack(alignment: .topLeading) {
                        CardView(card: Card(8, .spades), width: 62)
                        CardView(card: Card(7, .hearts), width: 62).offset(y: 27)
                        CardView(card: Card(6, .clubs), width: 62).offset(y: 54)
                    }.frame(width: 62, height: 141)
                }
                Image(systemName: "arrow.right").foregroundStyle(TableStyle.muted)
                diagram(help: "4 个空当各放 1 张牌，可用于临时周转") {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) { SlotView(width: 34); SlotView(width: 34) }
                        HStack(spacing: 8) { SlotView(width: 34); SlotView(width: 34) }
                    }
                }
                Image(systemName: "arrow.right").foregroundStyle(TableStyle.muted)
                diagram(help: "同花色从 A 到 K 收牌，收齐 52 张获胜") {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("A"); Image(systemName: "arrow.right").font(.system(size: 11)); Text("K")
                        }.font(.system(size: 22, weight: .medium, design: .serif))
                        HStack(spacing: 7) {
                            ForEach(Suit.allCases, id: \.rawValue) { suit in
                                Text(suit.symbol).foregroundStyle(suit.isRed ? Color(red: 0.85, green: 0.36, blue: 0.37) : TableStyle.cream)
                            }
                        }.font(.system(size: 20))
                        Image(systemName: "checkmark.circle").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(TableStyle.gold)
                    }
                }
            }
            Divider()
            HStack(spacing: 42) {
                Image(systemName: "hand.point.up.left").help("点击选择，再点击目标；双击优先收牌，否则移入空当")
                Image(systemName: "arrow.up.left.and.arrow.down.right").help("拖动单牌或连续牌组；空当和空列越多，可移动的牌组越长")
                Image(systemName: "arrow.uturn.backward").help("⌘Z 撤销，⇧⌘Z 重做")
                Image(systemName: "lightbulb").help("⌘I 提示合法走法；不保证通关")
                Image(systemName: "arrow.up.to.line").help("⇧⌘A 安全收牌")
            }.font(.system(size: 20, weight: .light)).foregroundStyle(TableStyle.muted)
        }.padding(30).frame(width: 460)
            .foregroundStyle(TableStyle.cream).background(TableStyle.background).preferredColorScheme(.dark)
    }
    private func diagram<Content: View>(help: String, @ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity).help(help).accessibilityElement(children: .ignore).accessibilityLabel(help)
    }
}
