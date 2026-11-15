import Foundation

// Sends text to the paste receiver on a screen-shared Mac.
// See `RemotePasteSettings` for why a posted Cmd+V cannot cross the viewer.
nonisolated enum RemotePasteClient {
  enum Failure: Error, Equatable {
    // The receiver answered but rejected the token.
    case unauthorized(host: String)
    // The receiver answered with a non-success status (e.g. its paste failed).
    case rejected(host: String, status: Int)
    // No host could be reached.
    case unreachable(String)
  }

  enum Attempt: Equatable, Sendable {
    case status(Int)
    case transportError(String)
  }

  // Per-host budget. An offline bridge address costs at most this long before
  // the next host is tried; the last host that answered is tried first.
  static let requestTimeout: TimeInterval = 2

  private static let lock = NSLock()
  nonisolated(unsafe) private static var lastReachableHost: String?

  private static let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    // Proxy tools commonly capture Tailscale's 100.64/10 range; the receiver
    // is always a direct peer.
    config.connectionProxyDictionary = [:]
    config.timeoutIntervalForRequest = requestTimeout
    config.timeoutIntervalForResource = requestTimeout
    return URLSession(configuration: config)
  }()

  // Delivers `text`, trying hosts in order. Returns the host that pasted it.
  static func deliver(
    _ text: String,
    settings: RemotePasteSettings,
    send: (URLRequest) async -> Attempt = Self.send
  ) async -> Result<String, Failure> {
    let preferred = lock.withLock { lastReachableHost }
    var lastError = "no host configured"
    for host in orderedHosts(settings.hosts, preferred: preferred) {
      guard let request = makeRequest(text: text, host: host, port: settings.port, token: settings.token) else {
        lastError = "invalid host \(host)"
        continue
      }

      switch await send(request) {
      case .transportError(let message):
        lastError = "\(host): \(message)"
        continue
      case .status(let status):
        // The receiver was reached; another host would only reach the
        // same Mac again, and retrying after a failed paste risks a
        // double paste.
        lock.withLock { lastReachableHost = host }
        if status == 401 {
          return .failure(.unauthorized(host: host))
        }
        guard (200..<300).contains(status) else {
          return .failure(.rejected(host: host, status: status))
        }
        return .success(host)
      }
    }

    return .failure(.unreachable(lastError))
  }

  static func orderedHosts(_ hosts: [String], preferred: String?) -> [String] {
    guard let preferred, hosts.contains(preferred) else {
      return hosts
    }

    return [preferred] + hosts.filter { $0 != preferred }
  }

  static func makeRequest(text: String, host: String, port: Int, token: String) -> URLRequest? {
    var components = URLComponents()
    components.scheme = "http"
    // URLComponents expects IPv6 literals in brackets.
    components.host = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
    components.port = port
    components.path = "/paste"
    guard let url = components.url,
          let body = try? JSONSerialization.data(withJSONObject: ["text": text]) else {
      return nil
    }

    var request = URLRequest(url: url, timeoutInterval: requestTimeout)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(token, forHTTPHeaderField: "X-Token")
    request.httpBody = body
    return request
  }

  private static func send(_ request: URLRequest) async -> Attempt {
    do {
      let (_, response) = try await session.data(for: request)
      return .status((response as? HTTPURLResponse)?.statusCode ?? 0)
    } catch {
      return .transportError(error.localizedDescription)
    }
  }
}
