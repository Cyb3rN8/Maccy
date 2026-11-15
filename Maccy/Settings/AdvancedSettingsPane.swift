import SwiftUI
import Defaults

struct AdvancedSettingsPane: View {
  @Default(.remotePasteEnabled) private var remotePasteEnabled
  @Default(.remotePasteHosts) private var remotePasteHosts
  @Default(.remotePastePort) private var remotePastePort

  @State private var remotePasteToken = RemotePasteToken.load() ?? ""
  @State private var remotePasteTokenSaveFailed = false

  var body: some View {
    VStack(alignment: .leading) {
      Defaults.Toggle(key: .ignoreEvents) {
        Text("TurnOff", tableName: "AdvancedSettings")
      }
      Text("TurnOffDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text("TurnOffShellScript", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)
      Text("TurnOffViaMenuIconDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text("TurnOffNextShellScript", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)

      Divider()

      Defaults.Toggle(key: .clearOnQuit) {
        Text("ClearHistoryOnQuit", tableName: "AdvancedSettings")
      }.help(Text("ClearHistoryOnQuitTooltip", tableName: "AdvancedSettings"))

      Defaults.Toggle(key: .clearSystemClipboard) {
        Text("ClearSystemClipboard", tableName: "AdvancedSettings")
      }.help(Text("ClearSystemClipboardTooltip", tableName: "AdvancedSettings"))

      Divider()

      Toggle(isOn: $remotePasteEnabled) {
        Text("RemotePaste", tableName: "AdvancedSettings")
      }
      Text("RemotePasteDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)

      if remotePasteEnabled {
        Form {
          TextField(text: $remotePasteHosts, prompt: Text(verbatim: "10.0.0.2, 100.64.0.2")) {
            Text("RemotePasteHosts", tableName: "AdvancedSettings")
          }
          .help(Text("RemotePasteHostsTooltip", tableName: "AdvancedSettings"))
          TextField(text: $remotePastePort, prompt: Text(verbatim: String(RemotePasteSettings.defaultPort))) {
            Text("RemotePastePort", tableName: "AdvancedSettings")
          }
          SecureField(text: $remotePasteToken, prompt: Text(verbatim: "X-Token")) {
            Text("RemotePasteToken", tableName: "AdvancedSettings")
          }
        }
        .padding(.leading, 20)

        if remotePasteTokenSaveFailed {
          Text("RemotePasteTokenSaveFailed", tableName: "AdvancedSettings")
            .foregroundStyle(.red)
            .controlSize(.small)
        }
      }
    }
    .onChange(of: remotePasteToken) { _, newValue in
      remotePasteTokenSaveFailed = !RemotePasteToken.save(newValue)
    }
    .frame(minWidth: 350, maxWidth: 450)
    .padding()
  }
}

#Preview {
  AdvancedSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
