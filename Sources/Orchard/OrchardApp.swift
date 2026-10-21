import AppKit
import SwiftUI

@main struct OrchardApp: App {
  @State private var model = ChatModel()
  var body: some Scene {
    WindowGroup("Orchard") {
      ChatView(model: model)
        .frame(minWidth: 850, minHeight: 620)
        .preferredColorScheme(.dark)
        .tint(Cyber.cyan)
        .onAppear {
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)
        }
    }.defaultSize(width: 1180, height: 800).windowStyle(.hiddenTitleBar)
  }
}

struct ChatView: View {
  @Bindable var model: ChatModel
  @State private var settings = false
  @State private var activity = true
  private let green = Cyber.cyan
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 8) {
          OrchardLogo(size: 32)
          Text("ORCHARD")
        }.font(.system(size: 19, weight: .semibold, design: .monospaced)).tracking(1)
          .foregroundStyle(green).shadow(color: green.opacity(0.25), radius: 12)
        Text("Personal intelligence.\nOn your frequency.").font(.callout).foregroundStyle(
          Cyber.secondary)
        Button {
          model.newChat()
        } label: {
          Label("New chat", systemImage: "square.and.pencil").frame(
            maxWidth: .infinity, alignment: .leading)
        }.disabled(model.busy).controlSize(.large).buttonStyle(.glass).foregroundStyle(.white)
        Divider()
        Label("APPLE FOUNDATION MODEL", systemImage: "desktopcomputer").font(
          .system(size: 9, weight: .semibold, design: .monospaced)
        ).tracking(0.8).foregroundStyle(Cyber.secondary)
        Label(
          model.available ? "Ready on this Mac" : "Not available",
          systemImage: model.available ? "checkmark.circle.fill" : "exclamationmark.circle"
        ).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(
          model.available ? green : .orange)
        Text("Chat inference stays on device. Search and remote tools use the network.").font(
          .caption
        ).foregroundStyle(Cyber.secondary)
        Toggle("Web search", isOn: $model.searchEnabled).disabled(
          model.busy || model.searchKey.isEmpty
        ).onChange(of: model.searchEnabled) { model.session = nil }
        if model.searchKey.isEmpty {
          Button("Set up search…") {
            model.loadKey()
            settings = true
          }.font(.caption).buttonStyle(.glass).foregroundStyle(.white)
        }
        Label("\(model.toolNames.count) MCP tools", systemImage: "puzzlepiece.extension").font(
          .callout)
        Spacer()
        Button {
          model.loadKey()
          settings = true
        } label: {
          Label("Settings", systemImage: "slider.horizontal.3")
        }.disabled(model.busy).buttonStyle(.glass).foregroundStyle(.white)
        Text("ORCHARD / 0.1\nON-DEVICE INTELLIGENCE").font(
          .system(size: 10, weight: .medium, design: .monospaced)
        ).foregroundStyle(Cyber.secondary)
      }.padding(22).padding(.top, 14).frame(width: 216).frame(maxHeight: .infinity).cyberGlass(
        radius: 20
      ).padding(.leading, 12).padding(.vertical, 12)
      VStack(spacing: 0) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("LOCAL / INTELLIGENCE").font(
              .system(size: 11, weight: .semibold, design: .monospaced)
            ).tracking(2).foregroundStyle(green)
            Text(model.status).font(.caption).foregroundStyle(Cyber.secondary)
          }
          Spacer()
          Button {
            activity.toggle()
          } label: {
            Image(systemName: "sidebar.right")
          }.buttonStyle(.glass).foregroundStyle(.white).help("Show tool activity")
        }.padding(22).padding(.top, 12)
        Rectangle().fill(
          LinearGradient(
            colors: [green.opacity(0.35), .white.opacity(0.04), Cyber.pink.opacity(0.2)],
            startPoint: .leading, endPoint: .trailing)
        ).frame(height: 0.5).padding(.horizontal, 22)
        if model.messages.isEmpty { welcome } else { conversation }
        if let error = model.error {
          HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle")
            Text(error).textSelection(.enabled)
            Spacer()
            Button {
              model.error = nil
            } label: {
              Image(systemName: "xmark")
            }
          }.font(.caption).padding(12).background(.orange.opacity(0.12)).padding(.horizontal, 20)
        }
        VStack(alignment: .leading, spacing: 10) {
          TextField("Ask something, or give me a small task…", text: $model.input, axis: .vertical)
            .lineLimit(1...6).textFieldStyle(.plain).font(.body).onSubmit { model.send() }.disabled(
              !model.available)
          HStack {
            Text(model.busy ? "Working on your Mac…" : "Apple Intelligence · No cloud model").font(
              .caption
            ).foregroundStyle(Cyber.secondary)
            Spacer()
            if model.busy {
              ProgressView().controlSize(.small)
              Button("Stop") { model.stop() }
            } else {
              Button {
                model.send()
              } label: {
                Image(systemName: "arrow.up").fontWeight(.bold).padding(4)
              }.buttonStyle(.glassProminent).tint(green).foregroundStyle(.black).disabled(
                model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || !model.available)
            }
          }
        }.padding(18).cyberGlass(radius: 22).shadow(color: green.opacity(0.08), radius: 22, y: 4)
          .padding(20)
      }.frame(maxWidth: .infinity)
      if activity { activityPanel.padding(.trailing, 12).padding(.vertical, 12) }
    }
    .background { CyberBackdrop() }
    .sheet(isPresented: $settings) { SettingsView(model: model) }
    .sheet(item: $model.approval, onDismiss: { model.resolveApproval(false) }) { approval in
      VStack(alignment: .leading, spacing: 18) {
        Label("Allow this MCP tool call?", systemImage: "puzzlepiece.extension").font(.title2)
        Text(approval.name).font(.headline)
        ScrollView {
          Text(approval.arguments).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: 220)
        Text("This runs on the connected server with that server’s permissions.").foregroundStyle(
          Cyber.secondary)
        HStack {
          Spacer()
          Button("Decline") { model.resolveApproval(false) }
          Button("Allow once") { model.resolveApproval(true) }.buttonStyle(.borderedProminent)
        }
      }.padding(26).frame(width: 520).background(Cyber.panel).preferredColorScheme(.dark).tint(
        green
      ).interactiveDismissDisabled()
    }
  }
  private var welcome: some View {
    VStack(alignment: .leading, spacing: 18) {
      Spacer()
      OrchardLogo(size: 96).shadow(color: green.opacity(0.13), radius: 24).padding(.bottom, 8)
      Text("YOUR MIND. EXTENDED.").font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(3).foregroundStyle(Cyber.pink)
      Text("Room to think.").font(.system(size: 44, weight: .medium, design: .rounded)).tracking(
        -1.5
      ).foregroundStyle(.white)
      Text(
        "Write, summarize, and work things out with Apple’s local model. Add tools when you need to reach further."
      ).font(.body).foregroundStyle(Cyber.secondary).fixedSize(horizontal: false, vertical: true)
      VStack(spacing: 10) {
        suggestion(
          "Find the right words",
          "Rewrite this clearly: I wanted to see if maybe we could move our meeting to Friday.",
          "text.alignleft")
        suggestion("Check a calculation", "Use the calculator to multiply 137 by 29.", "function")
        suggestion(
          "Make a small plan",
          "Give me a practical three-step plan for organizing my project notes.", "checklist")
      }.padding(.top, 12)
      Spacer()
    }.padding(40).frame(maxWidth: 650, maxHeight: .infinity, alignment: .leading)
  }
  private func suggestion(_ title: String, _ prompt: String, _ icon: String) -> some View {
    Button {
      model.input = prompt
    } label: {
      HStack {
        Image(systemName: icon).frame(width: 22).foregroundStyle(green)
        Text(title)
        Spacer()
        Image(systemName: "arrow.up.left").foregroundStyle(.tertiary)
      }.padding(12).frame(maxWidth: .infinity)
    }.buttonStyle(.plain).cyberGlass(radius: 14, interactive: true)
  }
  private var conversation: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          ForEach(model.messages) { message in
            VStack(alignment: .leading, spacing: 8) {
              Text(message.role.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.5)
                .foregroundStyle(message.role == "You" ? Cyber.pink : green)
              Text(message.text.isEmpty ? "Thinking…" : message.text).textSelection(.enabled).frame(
                maxWidth: .infinity, alignment: .leading)
            }.padding(18).background(
              RoundedRectangle(cornerRadius: 12).fill(
                message.role == "You" ? Cyber.pink.opacity(0.055) : .clear)
            ).id(message.id)
          }
        }.padding(22)
      }.onChange(of: model.messages.last?.text) {
        if let id = model.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
      }
    }
  }
  private var activityPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Circle().fill(Cyber.pink).frame(width: 5, height: 5).shadow(
          color: Cyber.pink.opacity(0.5), radius: 5)
        Text("ACTIVITY").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
          .foregroundStyle(Cyber.pink)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if model.events.isEmpty {
            Text("Tool calls will appear here. You’ll see what ran and what came back.").font(
              .caption
            ).foregroundStyle(Cyber.secondary)
          }
          ForEach(model.events) { event in
            DisclosureGroup {
              Text(event.detail).font(.caption).textSelection(.enabled)
            } label: {
              Text(event.title).font(.caption).fontWeight(.medium)
            }
          }
          if !model.sources.isEmpty {
            Divider()
            Text("SOURCES").font(.caption).foregroundStyle(Cyber.secondary)
            ForEach(model.sources) { source in
              if let url = URL(string: source.url), ["https", "http"].contains(url.scheme ?? "") {
                Link(source.title, destination: url).font(.caption)
              }
            }
          }
        }
      }
      Spacer(minLength: 0)
      Text("Chats stay in memory and clear when you quit.").font(.caption2).foregroundStyle(
        Cyber.secondary)
    }.padding(20).padding(.top, 14).frame(width: 214).frame(maxHeight: .infinity).cyberGlass(
      radius: 20, accent: Cyber.pink)
  }
}

struct SettingsView: View {
  @Bindable var model: ChatModel
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text("CONNECTIONS").font(.system(size: 21, weight: .medium, design: .monospaced)).tracking(
          2
        ).foregroundStyle(Cyber.cyan)
        Spacer()
        Button("Done") {
          model.saveKey()
          model.session = nil
          dismiss()
        }.keyboardShortcut(.defaultAction).buttonStyle(.glass).foregroundStyle(.white)
      }
      Form {
        Section("Web search") {
          SecureField("Brave Search API key", text: $model.searchKey)
          Text(
            "Stored in macOS Keychain. Only search queries go to Brave; model inference stays on your Mac."
          ).font(.caption).foregroundStyle(Cyber.secondary)
          Link(
            "Get a Brave Search API key", destination: URL(string: "https://brave.com/search/api/")!
          )
        }
        Section("MCP connection") {
          Picker("Transport", selection: $model.serverKind) {
            Text("Local process").tag("Local process")
            Text("HTTP").tag("HTTP")
          }
          TextField(
            model.serverKind == "HTTP" ? "https://server.example/mcp" : "Absolute executable path",
            text: $model.serverEndpoint)
          if model.serverKind == "Local process" {
            TextField("Arguments as a JSON array", text: $model.serverArguments)
            Text(
              "Example: [\"/path/to/server.py\"]. Connecting starts this executable with your user permissions."
            ).font(.caption).foregroundStyle(Cyber.secondary)
          } else {
            SecureField("Bearer token (optional, this session only)", text: $model.serverToken)
          }
          HStack {
            Button(model.connecting ? "Connecting…" : "Connect & discover tools") {
              Task { await model.connect() }
            }.disabled(model.connecting)
            if model.client != nil { Button("Disconnect") { Task { await model.disconnect() } } }
            if model.connecting { ProgressView().controlSize(.small) }
          }
          if !model.toolNames.isEmpty {
            Text(model.toolNames.joined(separator: ", ")).font(.caption).textSelection(.enabled)
          }
          Text(
            "One server at a time; up to 12 tools. Each MCP call requires approval. Changing tools starts a fresh model session."
          ).font(.caption).foregroundStyle(Cyber.secondary)
        }
        if let error = model.error {
          Section("Connection status") {
            Text(error).foregroundStyle(.orange).textSelection(.enabled)
          }
        }
        Section("Local model") {
          Text(model.status)
          Button("Check availability again") { model.refreshAvailability() }
        }
      }.formStyle(.grouped).scrollContentBackground(.hidden)
    }.padding(24).frame(width: 650, height: 640).background { CyberBackdrop() }
      .preferredColorScheme(.dark).tint(Cyber.cyan)
  }
}
