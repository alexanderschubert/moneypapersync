import Foundation

// MARK: - Fehler

enum PaperlessError: LocalizedError {
    case notConfigured
    case invalidURL
    case unreachable(String)
    case authFailed
    case server(Int, String)
    case decoding
    case unexpected(String)
    case fileUnreadable(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Paperless-ngx ist nicht eingerichtet."
        case .invalidURL: "Die Server-URL ist ungültig."
        case .unreachable(let message): "Server nicht erreichbar: \(message)"
        case .authFailed: "Authentifizierung fehlgeschlagen. Bitte API-Token prüfen."
        case .server(let code, let message): "Serverfehler (\(code)): \(message)"
        case .decoding: "Unerwartete Antwort des Servers."
        case .unexpected(let snippet): "Unerwartete Antwort des Servers: \(snippet)"
        case .fileUnreadable(let message): "Datei nicht lesbar: \(message)"
        }
    }

    /// Temporäre Fehler werden automatisch erneut versucht.
    var isTransient: Bool {
        switch self {
        case .unreachable: true
        case .server(let code, _): code >= 500 || code == 429 || code == 408
        case .notConfigured, .invalidURL, .authFailed, .decoding, .unexpected, .fileUnreadable: false
        }
    }
}

// MARK: - Modelle

struct PaperlessItem: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String
}

struct PaperlessMetadata: Equatable {
    var correspondents: [PaperlessItem] = []
    var documentTypes: [PaperlessItem] = []
    var tags: [PaperlessItem] = []

    static let empty = PaperlessMetadata()
    var isEmpty: Bool { correspondents.isEmpty && documentTypes.isEmpty && tags.isEmpty }
}

struct PaperlessServerInfo {
    let documentCount: Int
    let version: String?
}

struct PaperlessTaskInfo: Decodable {
    let status: String
    let result: String?
    let relatedDocument: Int?

    init(status: String, result: String?, relatedDocument: Int?) {
        self.status = status
        self.result = result
        self.relatedDocument = relatedDocument
    }

    enum CodingKeys: String, CodingKey {
        case status, result
        case relatedDocument = "related_document"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        result = try? c.decodeIfPresent(String.self, forKey: .result)
        if let intValue = try? c.decodeIfPresent(Int.self, forKey: .relatedDocument) {
            relatedDocument = intValue
        } else if let stringValue = try? c.decodeIfPresent(String.self, forKey: .relatedDocument) {
            relatedDocument = Int(stringValue)
        } else {
            relatedDocument = nil
        }
    }
}

struct PaperlessUploadRequest {
    let fileName: String
    let data: Data
    let title: String
    let created: Date?
    let correspondentID: Int?
    let documentTypeID: Int?
    let tagIDs: [Int]
}

// MARK: - TLS-Delegate

final class TLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let verify: Bool

    init(verify: Bool) {
        self.verify = verify
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if !verify,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Client

final class PaperlessClient: @unchecked Sendable {
    let baseURL: URL
    private let token: String
    private let session: URLSession

    init(baseURLString: String, token: String, verifyTLS: Bool) throws {
        var text = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PaperlessError.notConfigured }
        if !text.contains("://") { text = "https://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.host != nil else { throw PaperlessError.invalidURL }
        guard !token.isEmpty else { throw PaperlessError.notConfigured }

        baseURL = url
        self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config, delegate: TLSSessionDelegate(verify: verifyTLS), delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: Verbindung

    func testConnection() async throws -> PaperlessServerInfo {
        let (data, response) = try await send(request(path: "/api/documents/", query: [("page_size", "1")]))
        struct Page: Decodable { let count: Int }
        guard let page = try? JSONDecoder().decode(Page.self, from: data) else { throw PaperlessError.decoding }
        return PaperlessServerInfo(
            documentCount: page.count,
            version: response.value(forHTTPHeaderField: "x-version")
        )
    }

    // MARK: Stammdaten

    func fetchCorrespondents() async throws -> [PaperlessItem] { try await fetchItems("/api/correspondents/") }
    func fetchDocumentTypes() async throws -> [PaperlessItem] { try await fetchItems("/api/document_types/") }
    func fetchTags() async throws -> [PaperlessItem] { try await fetchItems("/api/tags/") }

    func fetchMetadata() async throws -> PaperlessMetadata {
        async let c = fetchCorrespondents()
        async let t = fetchDocumentTypes()
        async let g = fetchTags()
        return try await PaperlessMetadata(correspondents: c, documentTypes: t, tags: g)
    }

    private func fetchItems(_ path: String) async throws -> [PaperlessItem] {
        struct Page: Decodable {
            let results: [PaperlessItem]
            let next: String?
        }
        var items: [PaperlessItem] = []
        var pageNumber = 1
        while pageNumber <= 20 {
            let (data, _) = try await send(request(path: path, query: [
                ("page_size", "250"), ("page", String(pageNumber)), ("ordering", "name")
            ]))
            guard let page = try? JSONDecoder().decode(Page.self, from: data) else { throw PaperlessError.decoding }
            items += page.results
            if page.next == nil { break }
            pageNumber += 1
        }
        return items
    }

    // MARK: Upload

    /// Lädt ein Dokument hoch und gibt die Task-ID zurück.
    func upload(_ upload: PaperlessUploadRequest) async throws -> String {
        let boundary = "MoneyPaperSync-\(UUID().uuidString)"
        var body = Data()

        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        field("title", upload.title)
        if let created = upload.created { field("created", DateFormat.iso.string(from: created)) }
        if let id = upload.correspondentID { field("correspondent", String(id)) }
        if let id = upload.documentTypeID { field("document_type", String(id)) }
        for tag in upload.tagIDs { field("tags", String(tag)) }

        let safeName = upload.fileName.replacingOccurrences(of: "\"", with: "_")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(safeName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(upload.data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = try request(path: "/api/documents/post_document/", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120

        let (data, _) = try await send(req, body: body)
        // Antwort: JSON-String mit der Task-UUID, z. B. "3f2c…"
        if let taskID = try? JSONDecoder().decode(String.self, from: data) { return taskID }
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let taskID = (object["task_id"] ?? object["id"]) as? String { return taskID }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n")) ?? ""
        guard !raw.isEmpty, !raw.hasPrefix("<"), !raw.hasPrefix("{") else { throw PaperlessError.unexpected(Self.snippet(data)) }
        return raw
    }

    /// Fragt den Status einer Verarbeitung ab. Das Antwortformat unterscheidet sich je nach Paperless-Version
    /// (Liste, Seite mit `results` oder einzelnes Objekt), deshalb wird tolerant gelesen.
    func taskStatus(taskID: String) async throws -> PaperlessTaskInfo? {
        let (data, _) = try await send(request(path: "/api/tasks/", query: [("task_id", taskID)]))
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw PaperlessError.unexpected(Self.snippet(data))
        }
        var entries: [[String: Any]] = []
        if let list = json as? [[String: Any]] {
            entries = list
        } else if let object = json as? [String: Any] {
            if let results = object["results"] as? [[String: Any]] {
                entries = results
            } else if object["status"] != nil {
                entries = [object]
            } else if object["results"] == nil, object["count"] != nil {
                return nil
            }
        }
        guard !entries.isEmpty else {
            if json is [Any] { return nil }
            throw PaperlessError.unexpected(Self.snippet(data))
        }
        let entry = entries.first { ($0["task_id"] as? String) == taskID } ?? entries[0]
        guard let status = entry["status"] as? String else { throw PaperlessError.unexpected(Self.snippet(data)) }
        let related: Int?
        if let value = entry["related_document"] as? Int {
            related = value
        } else if let text = entry["related_document"] as? String {
            related = Int(text)
        } else {
            related = nil
        }
        let result = entry["result"] as? String
        return PaperlessTaskInfo(status: status, result: result, relatedDocument: related)
    }

    private static func snippet(_ data: Data) -> String {
        Redactor.sanitize(String(data: data.prefix(120), encoding: .utf8) ?? "")
    }

    func documentURL(id: Int) -> URL {
        baseURL.appendingPathComponent("documents/\(id)/details")
    }

    // MARK: Interna

    private func request(path: String, query: [(String, String)] = [], method: String = "GET") throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? ""
        components?.path = basePath + path
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        guard let url = components?.url else { throw PaperlessError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func send(_ request: URLRequest, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response): (Data, URLResponse)
            if let body {
                (data, response) = try await session.upload(for: request, from: body)
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let http = response as? HTTPURLResponse else { throw PaperlessError.decoding }
            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 401, 403:
                throw PaperlessError.authFailed
            default:
                let message = String(data: data.prefix(200), encoding: .utf8) ?? ""
                throw PaperlessError.server(http.statusCode, Redactor.sanitize(message))
            }
        } catch let error as PaperlessError {
            throw error
        } catch let error as URLError {
            throw PaperlessError.unreachable(Self.describe(error))
        } catch {
            throw PaperlessError.unreachable(error.localizedDescription)
        }
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed: "Host nicht gefunden"
        case .cannotConnectToHost: "Verbindung abgelehnt"
        case .timedOut: "Zeitüberschreitung"
        case .notConnectedToInternet: "Keine Netzwerkverbindung"
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
             .secureConnectionFailed, .serverCertificateNotYetValid:
            "TLS-Zertifikat nicht vertrauenswürdig"
        default: error.localizedDescription
        }
    }
}
