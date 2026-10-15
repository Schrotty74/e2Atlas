import AppKit
import SwiftUI
import AtlasCore
import AtlasThemes

struct PiconView: View {
    let data: Data?
    let name: String
    var size: CGFloat = 38
    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "tv").font(.system(size: size * 0.5)).foregroundStyle(.secondary) }
        }
        .frame(width: size, height: size * 0.7)
        .accessibilityLabel("Senderlogo \(name)")
    }
}

struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency { content.background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 16)) }
        else { content.glassEffect(.regular, in: .rect(cornerRadius: 16)) }
    }
}

struct ErrorNotice: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout).foregroundStyle(.secondary)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: .rect(cornerRadius: 10))
    }
}

struct DemoPicture: View {
    var compact = false
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.init(red: 0.38, green: 0.60, blue: 0.69), .init(red: 0.12, green: 0.29, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "mountain.2.fill")
                .resizable().scaledToFit().foregroundStyle(.white.opacity(0.22)).padding(compact ? 20 : 50)
            if !compact {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESIGN-DEMO").font(.caption.weight(.semibold))
                    Text("Unterwegs\nin den Alpen").font(.system(size: 40, weight: .medium, design: .rounded))
                }.foregroundStyle(.white).padding(28).padding(.bottom, 55)
            }
        }
    }
}
