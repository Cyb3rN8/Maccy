import Foundation

// Delivery through a screen-sharing viewer to the Mac on the other side.
//
// Screen Sharing forwards only the real HID modifier state. A posted Cmd+V does
// not change `CGEventSource.flagsState(.hidSystemState)`, so the remote Mac
// receives a bare "v". The paste has to happen on the remote Mac itself: Maccy
// sends the text to a receiver running there (`POST /paste` with an `X-Token`
// header, the protocol of agent-infra's `paste-recv`), which writes its own
// clipboard and pastes locally.
nonisolated struct RemotePasteSettings: Equatable, Sendable {
  static let defaultPort = 7788
  static let viewerBundleIdentifiers: Set<String> = ["com.apple.ScreenSharing"]

  // Receiver addresses in priority order, e.g. a Thunderbolt bridge first and
  // a Tailscale address as the fallback.
  var hosts: [String]
  var port: Int
  var token: String

  // The settings to use when `bundleIdentifier` is the paste target, or `nil`
  // when remote paste does not apply. The token is read only after the cheap
  // checks pass, so ordinary pastes never touch the Keychain.
  static func resolve(
    bundleIdentifier: String?,
    enabled: Bool,
    hosts rawHosts: String,
    port rawPort: String,
    loadToken: () -> String?
  ) -> RemotePasteSettings? {
    guard enabled,
          let bundleIdentifier,
          viewerBundleIdentifiers.contains(bundleIdentifier) else {
      return nil
    }

    let hosts = parseHosts(rawHosts)
    guard !hosts.isEmpty,
          let token = loadToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !token.isEmpty else {
      return nil
    }

    return RemotePasteSettings(hosts: hosts, port: normalizedPort(rawPort), token: token)
  }

  // Splits on commas and whitespace, keeping the first occurrence of each host.
  static func parseHosts(_ raw: String) -> [String] {
    var seen = Set<String>()
    return raw
      .split(whereSeparator: { $0 == "," || $0 == "，" || $0.isWhitespace })
      .map(String.init)
      .filter { seen.insert($0).inserted }
  }

  static func normalizedPort(_ raw: String) -> Int {
    guard let port = Int(raw.trimmingCharacters(in: .whitespaces)),
          (1...65535).contains(port) else {
      return defaultPort
    }

    return port
  }
}
