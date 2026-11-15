import Foundation
import Testing
@testable import Maccy

struct RemotePasteTests {
  private func resolve(
    bundleIdentifier: String? = "com.apple.ScreenSharing",
    enabled: Bool = true,
    hosts: String = "10.0.0.2, 100.64.0.2",
    port: String = "7788",
    token: String? = "secret"
  ) -> RemotePasteSettings? {
    RemotePasteSettings.resolve(
      bundleIdentifier: bundleIdentifier,
      enabled: enabled,
      hosts: hosts,
      port: port,
      loadToken: { token }
    )
  }

  @Test
  func resolvesForScreenSharingWhenConfigured() {
    #expect(resolve() == RemotePasteSettings(hosts: ["10.0.0.2", "100.64.0.2"], port: 7788, token: "secret"))
  }

  @Test
  func ignoresOtherApps() {
    #expect(resolve(bundleIdentifier: "com.apple.TextEdit") == nil)
    #expect(resolve(bundleIdentifier: nil) == nil)
  }

  @Test
  func ignoresWhenDisabledOrIncomplete() {
    #expect(resolve(enabled: false) == nil)
    #expect(resolve(hosts: " , ") == nil)
    #expect(resolve(token: nil) == nil)
    #expect(resolve(token: "  \n") == nil)
  }

  @Test
  func doesNotReadTokenForOtherApps() {
    var tokenRead = false
    _ = RemotePasteSettings.resolve(
      bundleIdentifier: "com.apple.TextEdit",
      enabled: true,
      hosts: "10.0.0.2",
      port: "7788",
      loadToken: { tokenRead = true; return "secret" }
    )
    #expect(!tokenRead)
  }

  @Test
  func parsesHostsAndPort() {
    #expect(RemotePasteSettings.parseHosts("a，b c\nb,,a") == ["a", "b", "c"])
    #expect(RemotePasteSettings.normalizedPort(" 8080 ") == 8080)
    #expect(RemotePasteSettings.normalizedPort("0") == RemotePasteSettings.defaultPort)
    #expect(RemotePasteSettings.normalizedPort("abc") == RemotePasteSettings.defaultPort)
  }

  @Test
  func buildsRequest() throws {
    let request = try #require(RemotePasteClient.makeRequest(text: "你好", host: "fd00::2", port: 7788, token: "t"))
    #expect(request.url?.absoluteString == "http://[fd00::2]:7788/paste")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "X-Token") == "t")
    let body = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: String]
    #expect(body == ["text": "你好"])
  }

  @Test
  func ordersPreferredHostFirst() {
    #expect(RemotePasteClient.orderedHosts(["a", "b", "c"], preferred: "b") == ["b", "a", "c"])
    #expect(RemotePasteClient.orderedHosts(["a", "b"], preferred: "z") == ["a", "b"])
  }

  @Test
  func failsOverOnTransportErrorOnly() async {
    let settings = RemotePasteSettings(hosts: ["bridge-\(UUID())", "tailnet-\(UUID())"], port: 7788, token: "t")
    var tried: [String] = []
    let result = await RemotePasteClient.deliver("x", settings: settings) { request in
      tried.append(request.url?.host() ?? "")
      return tried.count == 1 ? .transportError("timeout") : .status(200)
    }
    #expect(result == .success(settings.hosts[1]))
    #expect(tried == settings.hosts)
  }

  @Test
  func doesNotRetryAfterReceiverAnswers() async {
    let settings = RemotePasteSettings(hosts: ["one-\(UUID())", "two-\(UUID())"], port: 7788, token: "t")
    var attempts = 0
    let unauthorized = await RemotePasteClient.deliver("x", settings: settings) { _ in
      attempts += 1
      return .status(401)
    }
    #expect(unauthorized == .failure(.unauthorized(host: settings.hosts[0])))
    #expect(attempts == 1)

    let rejected = await RemotePasteClient.deliver("x", settings: settings) { _ in .status(500) }
    #expect(rejected == .failure(.rejected(host: settings.hosts[0], status: 500)))
  }
}
