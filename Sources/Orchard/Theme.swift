import SwiftUI

enum Cyber {
  static let cyan = Color(red: 0.25, green: 0.94, blue: 0.94)
  static let pink = Color(red: 1, green: 0.28, blue: 0.66)
  static let secondary = Color(red: 0.65, green: 0.69, blue: 0.73)
  static let panel = Color(red: 0.025, green: 0.035, blue: 0.045)
}

struct CyberGlass: ViewModifier {
  var radius: CGFloat = 18
  var accent: Color = Cyber.cyan
  var interactive = false
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  func body(content: Content) -> some View {
    content
      .background(
        reduceTransparency ? Cyber.panel : Color.black.opacity(0.56),
        in: RoundedRectangle(cornerRadius: radius)
      )
      .glassEffect(
        .clear.tint(accent.opacity(0.035)).interactive(interactive), in: .rect(cornerRadius: radius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(
            LinearGradient(
              colors: [accent.opacity(0.40), .white.opacity(0.07), accent.opacity(0.09)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7
          )
          .allowsHitTesting(false)
      }
  }
}

extension View {
  func cyberGlass(radius: CGFloat = 18, accent: Color = Cyber.cyan, interactive: Bool = false)
    -> some View
  {
    modifier(CyberGlass(radius: radius, accent: accent, interactive: interactive))
  }
}

struct CyberBackdrop: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black
        Ellipse().fill(Cyber.cyan.opacity(0.08)).frame(width: 420, height: 180).blur(radius: 85)
          .position(x: geometry.size.width * 0.48, y: geometry.size.height * 0.92)
        Ellipse().fill(Cyber.pink.opacity(0.065)).frame(width: 240, height: 300).blur(radius: 90)
          .position(x: geometry.size.width * 0.83, y: geometry.size.height * 0.24)
      }
    }.ignoresSafeArea().allowsHitTesting(false)
  }
}

struct OrchardLogo: View {
  let size: CGFloat
  private var image: NSImage? {
    let url =
      Bundle.main.url(forResource: "OrchardLogo", withExtension: "png")
      ?? Bundle.module.url(forResource: "OrchardLogo", withExtension: "png")
    return url.flatMap { NSImage(contentsOf: $0) }
  }
  var body: some View {
    Group {
      if let image {
        Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
      } else {
        Image(systemName: "leaf.fill").resizable().scaledToFit().foregroundStyle(Cyber.cyan)
      }
    }.frame(width: size, height: size).accessibilityLabel("Orchard logo")
  }
}
