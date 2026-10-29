import SwiftUI
import FreeCellCore

// Disambiguate the classic property wrapper from the macOS 27 SDK macro of the same name.
typealias ViewState<Value> = SwiftUI.State<Value>

enum TableStyle {
    static let background = Color(red: 0.035, green: 0.17, blue: 0.16)
    static let light = Color(red: 0.09, green: 0.28, blue: 0.25)
    static let gold = Color(red: 0.89, green: 0.75, blue: 0.46)
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.92)
    static let muted = Color(red: 0.65, green: 0.76, blue: 0.71)
}

struct CardView: View {
    let card: Card
    let width: CGFloat
    var selected = false
    var faceColor: Color { card.suit.isRed ? Color(red: 0.74, green: 0.20, blue: 0.23) : Color(red: 0.12, green: 0.19, blue: 0.20) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [.white, TableStyle.cream], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(selected ? TableStyle.gold : .black.opacity(0.16), lineWidth: selected ? 3 : 0.75)
            VStack {
                HStack(spacing: 3) {
                    Text(card.label).font(.system(size: width * 0.20, weight: .semibold, design: .rounded))
                    Text(card.suit.symbol).font(.system(size: width * 0.19))
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Text(card.label).font(.system(size: width * 0.20, weight: .semibold, design: .rounded))
                    Text(card.suit.symbol).font(.system(size: width * 0.19))
                    Spacer(minLength: 0)
                }.rotationEffect(.degrees(180))
            }.padding(width * 0.065)
            if card.rank >= 11 {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).stroke(faceColor.opacity(0.13), lineWidth: 1)
                        .frame(width: width * 0.54, height: width * 0.7)
                    VStack(spacing: -3) {
                        Image(systemName: "crown").font(.system(size: width * 0.23, weight: .light))
                        Text(card.suit.symbol).font(.system(size: width * 0.39))
                    }
                }
            } else {
                Text(card.suit.symbol)
                    .font(.system(size: width * (card.rank == 1 ? 0.64 : 0.46), weight: .regular))
            }
        }
        .foregroundStyle(faceColor)
        .frame(width: width, height: width * 1.4)
        .shadow(color: .black.opacity(selected ? 0.3 : 0.18), radius: selected ? 6 : 2, y: 2)
        .accessibilityLabel(card.name)
    }
}

struct SlotView: View {
    let width: CGFloat
    var symbol: String = ""
    var highlighted = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.08))
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(highlighted ? TableStyle.gold : .white.opacity(0.18), style: StrokeStyle(lineWidth: highlighted ? 2 : 1, dash: highlighted ? [] : [5, 5]))
            if !symbol.isEmpty {
                Text(symbol).font(.system(size: width * 0.46)).foregroundStyle(highlighted ? TableStyle.gold : .white.opacity(0.16))
            } else {
                Image(systemName: "plus").font(.system(size: width * 0.2, weight: .ultraLight))
                    .foregroundStyle(highlighted ? TableStyle.gold : .white.opacity(0.18))
            }
        }.frame(width: width, height: width * 1.4)
    }
}

struct TableButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 15).padding(.vertical, 10)
            .foregroundStyle(prominent ? TableStyle.background : TableStyle.cream)
            .background(prominent ? TableStyle.gold : .white.opacity(configuration.isPressed ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(prominent ? 0 : 0.09)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
