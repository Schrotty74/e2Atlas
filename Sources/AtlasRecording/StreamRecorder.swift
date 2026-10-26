import Foundation
import Darwin

/// Records a receiver's raw MPEG-TS stream to a new local file.
public enum StreamRecorder {
    /// Builds a filesystem-safe recording name from a sender and optional programme title.
    public static func filenameStem(channelName: String, programmeTitle: String? = nil) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        func clean(_ value: String) -> String {
            value.components(separatedBy: allowed.inverted).joined(separator: "_")
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-_")))
        }
        let channel = clean(channelName)
        var parts = [channel.isEmpty ? "e2Atlas" : channel]
        if let programme = programmeTitle.map(clean), !programme.isEmpty { parts.append(programme) }
        // Leave room for the timestamp and extension on filesystems with a 255-byte component limit.
        var stem = ""
        for character in parts.joined(separator: " - ") {
            guard stem.utf8.count + String(character).utf8.count <= 160 else { break }
            stem.append(character)
        }
        return stem
    }

    public enum RecordingError: Error, LocalizedError, Sendable, Equatable {
        case invalidAddress
        case invalidStream
        case transferFailed
        case noData

        public var errorDescription: String? {
            switch self {
            case .invalidAddress: "The stream address is invalid."
            case .invalidStream: "The receiver did not provide a valid MPEG-TS stream."
            case .transferFailed: "The recording was interrupted. Any valid captured data was kept."
            case .noData: "The receiver provided no stream data."
            }
        }
    }

    public static func record(
        url: URL,
        to destination: URL,
        username: String,
        password: String,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> Int64 {
        try await record(url: url, to: destination, username: username, password: password,
                         configuration: .ephemeral, progress: progress)
    }

    static func record(
        url: URL,
        to destination: URL,
        username: String,
        password: String,
        configuration: URLSessionConfiguration,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> Int64 {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              parts.host != nil, parts.user == nil, parts.password == nil else {
            throw RecordingError.invalidAddress
        }

        let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw RecordingError.transferFailed }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let transfer = Transfer(url: url, destination: destination, handle: handle, configuration: configuration,
                                username: username, password: password, progress: progress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                transfer.start(continuation)
            }
        } onCancel: {
            transfer.cancel()
        }
    }
}

// Sendability invariant: start publishes state before resuming the request;
// URLSession callbacks and file writes run on one serial delegate queue.
// Only cancellation and the task reference cross queues, protected by lock.
// Keep future mutable transfer state on that queue or under the same lock.
private final class Transfer: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let url: URL
    private let destination: URL
    private let handle: FileHandle
    private let configuration: URLSessionConfiguration
    private let username: String
    private let password: String
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var cancelled = false
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var continuation: CheckedContinuation<Int64, Error>?
    private var bytes: Int64 = 0
    private var lastProgressTime = Date.distantPast.timeIntervalSinceReferenceDate
    private var prefix = Data()
    private var validTransport = false
    private var responseAccepted = false
    private var terminalError: Error?

    init(url: URL, destination: URL, handle: FileHandle, configuration: URLSessionConfiguration,
         username: String, password: String,
         progress: @escaping @Sendable (Int64) -> Void) {
        self.url = url
        self.destination = destination
        self.handle = handle
        self.configuration = configuration
        self.username = username
        self.password = password
        self.progress = progress
    }

    func start(_ continuation: CheckedContinuation<Int64, Error>) {
        self.continuation = continuation
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("video/mp2t, application/octet-stream;q=0.9", forHTTPHeaderField: "Accept")
        let task = session.dataTask(with: request)
        lock.lock()
        self.task = task
        let shouldCancel = cancelled
        lock.unlock()
        task.resume()
        if shouldCancel { task.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard challenge.previousFailureCount == 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        guard space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
              sameOrigin(url, scheme: space.protocol, host: space.host, port: space.port),
              !username.isEmpty || !password.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: username, password: password, persistence: .none))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              sameOrigin(url, scheme: http.url?.scheme, host: http.url?.host,
                         port: http.url?.port ?? Self.defaultPort(http.url?.scheme)),
              !Self.rejectedContentType(http.value(forHTTPHeaderField: "Content-Type")) else {
            terminalError = StreamRecorder.RecordingError.invalidStream
            completionHandler(.cancel)
            return
        }
        responseAccepted = true
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard terminalError == nil, responseAccepted else { return }
        do {
            if !validTransport {
                let needed = max(0, 3 * 188 - prefix.count)
                prefix.append(data.prefix(needed))
                guard prefix.count >= 3 * 188 else { return }
                guard prefix[0] == 0x47, prefix[188] == 0x47, prefix[376] == 0x47 else {
                    terminalError = StreamRecorder.RecordingError.invalidStream
                    dataTask.cancel()
                    return
                }
                validTransport = true
                try write(prefix)
                prefix.removeAll(keepingCapacity: false)
                if data.count > needed { try write(data.dropFirst(needed)) }
            } else {
                try write(data)
            }
        } catch {
            terminalError = StreamRecorder.RecordingError.transferFailed
            dataTask.cancel()
        }
    }

    private func write<T: DataProtocol>(_ data: T) throws {
        guard !data.isEmpty else { return }
        try handle.write(contentsOf: data)
        bytes += Int64(data.count)
        publishProgress()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        do { try handle.synchronize() }
        catch { terminalError = StreamRecorder.RecordingError.transferFailed }
        do { try handle.close() }
        catch { terminalError = StreamRecorder.RecordingError.transferFailed }
        session.finishTasksAndInvalidate()

        if let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
           let fileSize = attributes[.size] as? NSNumber {
            bytes = max(bytes, fileSize.int64Value)
        }
        let callerCancelled = isCancelled
        publishProgress(force: true)
        if bytes == 0 {
            try? FileManager.default.removeItem(at: destination)
        }
        guard let continuation else { return }
        self.continuation = nil
        if bytes > 0, validTransport, terminalError == nil, (callerCancelled || error == nil) {
            continuation.resume(returning: bytes)
        } else if callerCancelled, bytes == 0, terminalError == nil {
            continuation.resume(throwing: StreamRecorder.RecordingError.noData)
        } else {
            let fallback: StreamRecorder.RecordingError = error == nil && !validTransport
                ? .invalidStream : .transferFailed
            continuation.resume(throwing: terminalError ?? fallback)
        }
    }

    private func publishProgress(force: Bool = false) {
        guard bytes > 0 else { return }
        let now = Date.timeIntervalSinceReferenceDate
        guard force || now - lastProgressTime >= 0.25 else { return }
        lastProgressTime = now
        progress(bytes)
    }

    private func sameOrigin(_ candidate: URL, scheme: String?, host: String?, port: Int?) -> Bool {
        guard let candidateScheme = candidate.scheme?.lowercased(),
              let scheme = scheme?.lowercased(), let candidateHost = candidate.host?.lowercased(),
              let host = host?.lowercased() else { return false }
        return candidateScheme == scheme && candidateHost == host
            && (candidate.port ?? Self.defaultPort(candidate.scheme)) == (port ?? Self.defaultPort(scheme))
    }

    private static func defaultPort(_ scheme: String?) -> Int? {
        switch scheme?.lowercased() { case "http": 80; case "https": 443; default: nil }
    }

    private static func rejectedContentType(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value.contains("text/") || value.contains("mpegurl") || value.contains("html") || value.contains("json")
    }
}
