import Foundation

/// One bounded ephemeral session per operation. Never logs URLs, tokens or provider responses.
final class HTTPClient: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var data = Data(); private let limit: Int; private let followRedirects: Bool
    private let lock = NSLock(); private var task: URLSessionDataTask?; private var cancelled = false
    private var continuation: CheckedContinuation<Data, Error>?; private var session: URLSession?
    init(limit: Int, followRedirects: Bool) { self.limit = limit; self.followRedirects = followRedirects }
    static func fetch(_ request: URLRequest, limit: Int = 16 * 1024 * 1024, redirects: Bool = true) async throws -> Data {
        let loader = HTTPClient(limit: limit, followRedirects: redirects)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 25; config.timeoutIntervalForResource = 90; config.urlCache = nil; config.httpCookieStorage = nil
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let session = URLSession(configuration: config, delegate: loader, delegateQueue: queue)
                loader.session = session; loader.continuation = continuation
                loader.lock.lock(); let task = session.dataTask(with: request); loader.task = task; let cancelled = loader.cancelled; loader.lock.unlock()
                if cancelled { task.cancel() }; task.resume()
            }
        }, onCancel: { loader.lock.lock(); loader.cancelled = true; let task = loader.task; loader.lock.unlock(); task?.cancel() })
    }
    private func finish(_ result: Result<Data, Error>) {
        guard let continuation else { return }; self.continuation = nil; self.session?.invalidateAndCancel(); self.session = nil; continuation.resume(with: result)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else { completionHandler(.cancel); finish(.failure(MeteorError.invalidData)); return }
        guard (200...299).contains(http.statusCode) else { completionHandler(.cancel); finish(.failure(MeteorError.http(http.statusCode))); return }
        guard response.expectedContentLength <= Int64(limit) else { completionHandler(.cancel); finish(.failure(MeteorError.tooLarge)); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard self.data.count + data.count <= limit else { dataTask.cancel(); finish(.failure(MeteorError.tooLarge)); return }; self.data.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { if let error { finish(.failure(error)) } else { finish(.success(data)) } }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Panel bearer credentials are never forwarded through a redirect.
        guard followRedirects, let url = request.url, httpURL(url.absoluteString) != nil else { completionHandler(nil); return }; completionHandler(request)
    }
    static func json(_ url: URL, body: Object? = nil, headers: [String: String] = [:], limit: Int = 16 * 1024 * 1024, redirects: Bool = true) async throws -> Any {
        var request = URLRequest(url: url); request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data = try await fetch(request, limit: limit, redirects: redirects)
        return try JSONSerialization.jsonObject(with: data)
    }
}
