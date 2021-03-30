//
//
//  Nog.swift
//  Nog
//
// Copyright (c) 2021 Harlan Kellaway
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//

import Foundation

// MARK: - NetworkLogger

/// Manages whether network logging is on and reactions to network requests.
open class NetworkLogger {
    
    // MARK: Public properties

    /// Function called when a request is logged, giving client a chance to determine whether
    /// request should be logged or not.
    public let requestFilters: [RequestFilter]
    
    /// Whether network logging is currently on.
    public private(set) var isLogging = false

    /// Number of requests made since start.
    public private(set) var requestCount = 0
    
    // MARK: Init/Deinit

    public convenience init(filter: ((URLRequest) -> Bool)? = nil) {
        let noOp: ((URLRequest) -> Bool) = { _ in return true }
        self.init(requestFilters: [
          .httpOnly,
          InjectableRequestFilter(evaluate: filter ?? noOp),
        ])
    }
    
    public init(requestFilters: [RequestFilter]) {
        self.requestFilters = requestFilters

        NotificationCenter._nog.addObserver(self,
                                            selector: #selector(logRequestFromUrlProtocol(_:)),
                                            name: ._logRequest,
                                            object: nil)
    }
    
    deinit {
        NotificationCenter._nog.removeObserver(self)
    }
    
    // MARK: Public instance functions
    
    /// Starts recording of network requests.
    public func start() {
        guard !isLogging else {
            print("[Nog] Attempt to `start` while already started. Returning.")
            return
        }
        
        URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses()
        isLogging = true
    }
    
    /// Stops recording of networking requests.
    public func stop() {
        guard isLogging else {
            print("[Nog] Attempt to `stop` while already stopped. Returning.")
            return
        }
        
        URLProtocol.unregisterClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses()
        isLogging = false
    }
    
    public func toggle() {
        if isLogging {
            stop()
        } else {
            start()
        }
    }

    @discardableResult
    open func logRequest(_ urlRequest: URLRequest) -> Result<(), NetworkLoggerError> {
      guard (requestFilters.reduce(true) { $0 && $1.evaluate(urlRequest) }) else {
        return .failure(.requestRejectedByFilter)
      }

      print("[Nog] Request #\(requestCount): URL => \(urlRequest.description)")
      return .success(())
    }
    
    // MARK: Private instance functions
    
    private func swizzleProtocolClasses() {
        let instance = URLSessionConfiguration.default
        let sessionConfigurationClass: AnyClass = object_getClass(instance)!
        let method1: Method = class_getInstanceMethod(sessionConfigurationClass, #selector(getter: sessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration._injectedProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }

    @objc
    private func logRequestFromUrlProtocol(_ notification: Notification) {
        guard let urlRequest = notification.object as? URLRequest else {
            return
        }
        requestCount = requestCount + 1
        logRequest(urlRequest)
    }

}

// MARK: NetworkLoggerUrlProtocol

class NetworkLoggerUrlProtocol: URLProtocol {
    
    open override class func canInit(with request: URLRequest) -> Bool {
        if let httpHeaders = request.allHTTPHeaderFields, httpHeaders.isEmpty {
            return false
        }
        
        if let _ = URLProtocol.property(forKey: "NetworkLoggerUrlProtocol", in: request) {
            return false
        }
        
        NotificationCenter._nog.post(name: ._logRequest, object: request)
        return false
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkLoggerUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
}

// MARK: NetworkLoggerError

public enum NetworkLoggerError: Error {
  case requestRejectedByFilter
}

// MARK: - Request Filter

open class RequestFilter {

  public init() { }

  open func evaluate(_ request: URLRequest) -> Bool {
    return true
  }

}

public class HttpRequestFilter: RequestFilter {

  public override func evaluate(_ request: URLRequest) -> Bool {
    return request.url?.scheme.flatMap { ["https", "http"].contains($0) } ?? false
  }

}

public class InjectableRequestFilter: RequestFilter {

  public let handler: (URLRequest) -> Bool

  public init(evaluate: @escaping (URLRequest) -> Bool) {
    self.handler = evaluate
  }

  public override func evaluate(_ request: URLRequest) -> Bool {
    handler(request)
  }

}

// MARK: - Extensions

public extension RequestFilter {
  static let httpOnly = HttpRequestFilter()
}

// MARK: URLSessionConfiguration

extension URLSessionConfiguration {
    
    /// Implementation of `URLSessionConfiguration.protocolClasses` used when
    /// network logging is on; ensures `NetworkLoggerUrlProtocol` is at
    /// first position
    @objc internal func _injectedProtocolClasses() -> [AnyClass]? {
        guard let injectedProtocolClasses = self._injectedProtocolClasses() else {
            return []
        }

        var protocolClasses = injectedProtocolClasses.filter {
            return $0 != NetworkLoggerUrlProtocol.self
        }
        protocolClasses.insert(NetworkLoggerUrlProtocol.self, at: 0)
        return protocolClasses
    }
    
}

// MARK: NotificationCenter

internal extension NotificationCenter {
    // Private NotificationCenter to keep usage of notifications an implementation detail
    static var _nog = NotificationCenter()
}

// MARK: Notification.Name

internal extension Notification.Name {
    static let _logRequest = Notification.Name("NogNetworkLoggerRequest")
}
