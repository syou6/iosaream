import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.transport("non-http response")
            }
            var headerDict: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    headerDict[k] = v
                }
            }
            if http.statusCode == 429 {
                let retry = headerDict["Retry-After"].flatMap(TimeInterval.init)
                throw HTTPError.rateLimited(retryAfterSeconds: retry)
            }
            return HTTPResponse(statusCode: http.statusCode, headers: headerDict, body: data)
        } catch let error as HTTPError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw HTTPError.timeout
            case .cancelled: throw HTTPError.cancelled
            default: throw HTTPError.transport(error.localizedDescription)
            }
        } catch {
            throw HTTPError.transport(error.localizedDescription)
        }
    }
}
