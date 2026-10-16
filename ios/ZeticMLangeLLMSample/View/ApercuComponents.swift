import SwiftUI

struct ApercuWordmark: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Aperçu")
                .font(LfmPalette.title(27))
                .overlay(alignment: .bottomTrailing) {
                    Rectangle().fill(LfmPalette.highlight).frame(width: 26, height: 3).offset(y: 1)
                        .accessibilityHidden(true)
                }
            Text("Assistant visuel").font(LfmPalette.body(11)).foregroundStyle(LfmPalette.secondary)
        }
        .foregroundStyle(LfmPalette.ink)
        .accessibilityElement(children: .combine)
    }
}

struct ZeticFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Propulsé par").font(LfmPalette.body(11)).foregroundStyle(LfmPalette.secondary)
            Image("ZeticLogo").resizable().scaledToFit().frame(width: 86, height: 28)
                .padding(2).background(.white, in: RoundedRectangle(cornerRadius: 2))
                .accessibilityLabel("ZETIC")
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(LfmPalette.surface)
    }
}

struct ApercuActionStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LfmPalette.medium(15))
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(12)
            .foregroundStyle(primary && enabled ? LfmPalette.onAccent : LfmPalette.ink)
            .background(primary && enabled ? LfmPalette.accent : LfmPalette.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(!enabled ? 0.5 : configuration.isPressed ? 0.8 : 1)
    }
}

struct ApercuIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 19)).frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle()).opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct LocalSessionNote: View {
    var body: some View {
        Label("Photos et conversations enregistrées sur cet iPhone.", systemImage: "iphone")
            .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
    }
}

struct ApercuMenuRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 20)).frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(LfmPalette.medium())
                    Text(subtitle).font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(LfmPalette.secondary)
            }
            .foregroundStyle(LfmPalette.ink)
            .padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().overlay(LfmPalette.divider)
    }
}
