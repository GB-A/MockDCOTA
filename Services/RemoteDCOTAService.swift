import Foundation

/// Talks to the REST mock server in `mock-server/` (or any API implementing openapi.yaml).
/// Enabled with `-dcota-backend remote -dcota-base-url http://localhost:8080`.
struct RemoteDCOTAService: DCOTAService {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()

    private func send<T: Decodable>(_ method: String, _ path: String,
                                    query: [URLQueryItem] = [], body: Data? = nil) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.timeoutInterval = 10
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) }
        catch { throw DCOTAError.network(error.localizedDescription) }

        guard let http = response as? HTTPURLResponse else { throw DCOTAError.network("Invalid response") }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? Self.decoder.decode(APIErrorBody.self, from: data) {
                throw DCOTAError.from(code: err.code, message: err.message)
            }
            throw DCOTAError.server("HTTP \(http.statusCode)")
        }
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw DCOTAError.server("Malformed response: \(error.localizedDescription)") }
    }

    func fleetSummary() async throws -> FleetSummary { try await send("GET", "api/v1/fleet/summary") }

    func devices(query: DeviceQuery) async throws -> Page<Device> {
        var items = [URLQueryItem(name: "page", value: String(query.page)),
                     URLQueryItem(name: "pageSize", value: String(query.pageSize))]
        if !query.search.isEmpty { items.append(.init(name: "search", value: query.search)) }
        if let s = query.status { items.append(.init(name: "status", value: s.rawValue)) }
        return try await send("GET", "api/v1/devices", query: items)
    }

    func device(id: String) async throws -> Device { try await send("GET", "api/v1/devices/\(id)") }
    func stores() async throws -> [Store] { try await send("GET", "api/v1/stores") }
    func packages() async throws -> [ContentPackage] { try await send("GET", "api/v1/packages") }
    func deployments() async throws -> [Deployment] { try await send("GET", "api/v1/deployments") }

    func createDeployment(_ request: CreateDeploymentRequest) async throws -> Deployment {
        try await send("POST", "api/v1/deployments", body: try Self.encoder.encode(request))
    }

    func cancelDeployment(id: String) async throws -> Deployment {
        try await send("POST", "api/v1/deployments/\(id)/cancel")
    }
}
