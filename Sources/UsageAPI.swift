import Foundation

/// One usage bucket from the API, e.g. the 5-hour session or a weekly limit.
struct UsageBucket: Codable {
    let utilization: Double?
    let resets_at: String?

    var percent: Int { Int((utilization ?? 0).rounded()) }

    var resetDate: Date? {
        guard let s = resets_at else { return nil }
        return UsageBucket.iso.date(from: s) ?? UsageBucket.isoPlain.date(from: s)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

/// Response shape of GET /api/oauth/usage. Only the buckets we display are
/// modeled; the rest are ignored.
struct Usage: Codable {
    let five_hour: UsageBucket?
    let seven_day: UsageBucket?
    let seven_day_sonnet: UsageBucket?
    let seven_day_opus: UsageBucket?
}

enum UsageError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case badResponse
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .rateLimited: return "Rate limited — will retry shortly."
        case .http(let c): return "Couldn't load usage (HTTP \(c))."
        case .badResponse: return "Couldn't read the usage response."
        }
    }
}

enum UsageAPI {
    static let url = "https://api.anthropic.com/api/oauth/usage"

    /// Fetch usage, transparently refreshing the access token once on 401.
    static func fetch(token: OAuthToken) async throws -> Usage {
        var current = token
        if current.isExpired, current.refreshToken != nil {
            current = (try? await OAuth.refresh(current)) ?? current
        }
        do {
            return try await get(accessToken: current.accessToken)
        } catch UsageError.unauthorized {
            // Access token may have been revoked early — try one refresh + retry.
            guard current.refreshToken != nil else { throw UsageError.unauthorized }
            let refreshed = try await OAuth.refresh(current)
            return try await get(accessToken: refreshed.accessToken)
        }
    }

    private static func get(accessToken: String) async throws -> Usage {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(OAuth.betaHeader, forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw UsageError.badResponse }
        switch http.statusCode {
        case 200..<300:
            guard let usage = try? JSONDecoder().decode(Usage.self, from: data) else {
                throw UsageError.badResponse
            }
            return usage
        case 401, 403:
            throw UsageError.unauthorized
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retryAfter)
        default:
            throw UsageError.http(http.statusCode)
        }
    }
}
