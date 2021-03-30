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

    /// Filters called when a request is logged, giving client a chance to determine whether
    /// request should be logged or not.
    public let requestFilters: [RequestFilter]
    
    /// Whether network logging is currently on.
    public private(set) var isLogging = false

    /// Whether verbose console logging is on.
    public var verbose: Bool = true {
      didSet {
        console.turn(on: verbose)
      }
    }

    /// Number of requests made since start.
    public private(set) var requestCount = 0

    // MARK: Private properties

    private let adapter: NetworkLoggerUrlProtocolAdapter
    private let console: NogConsole
    
    // MARK: Init/Deinit

    public convenience init(filter customRequestFilter: RequestFilter? = nil) {
        self.init(requestFilters: [
          httpOnlyRequestFilter,
          (customRequestFilter ?? noRequestFilter),
        ])
    }
    
    public init(requestFilters: [RequestFilter],
                adapter: NetworkLoggerUrlProtocolAdapter = NetworkLoggerUrlProtocolAdapter(),
                console: NogConsole = NogConsole(),
                verbose: Bool = true) {
        self.requestFilters = requestFilters
        self.adapter = adapter
        self.console = console

        self.adapter.logRequest = self.logRequest
        self.console.turn(on: verbose)
    }

    // MARK: Public instance functions
    
    /// Starts recording of network requests.
    public func start() {
        guard !isLogging else {
            console.debugPrint("Attempt to `start` while already started. Returning.")
            return
        }
        
        URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses()
        isLogging = true
    }
    
    /// Stops recording of networking requests.
    public func stop() {
        guard isLogging else {
            console.debugPrint("Attempt to `stop` while already stopped. Returning.")
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
    open func logRequest(_ urlRequest: URLRequest) -> Bool {
      guard isLogging, (requestFilters.reduce(true) { $0 && $1(urlRequest) }) else {
        return false
      }

      requestCount = requestCount + 1
      console.debugPrint("Request #\(requestCount): URL => \(urlRequest.description)")
      return true
    }
    
    // MARK: Private instance functions
    
    private func swizzleProtocolClasses() {
        let instance = URLSessionConfiguration.default
        let sessionConfigurationClass: AnyClass = object_getClass(instance)!
        let method1: Method = class_getInstanceMethod(sessionConfigurationClass, #selector(getter: sessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration._injectedProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }

}

// MARK: NetworkLoggerUrlProtocolAdapter

/// Adapts output from UrlProtocol interception for use by NetworkLogger.
open class NetworkLoggerUrlProtocolAdapter {

  var logRequest: ((URLRequest) -> Bool)?

  public init() {
    NotificationCenter._nog.addObserver(self,
                                        selector: #selector(unwrapRequestFromNotification(_:)),
                                        name: ._urlProtocolReceivedRequest,
                                        object: nil)
  }

  deinit {
    NotificationCenter._nog.removeObserver(self)
  }

  public func requestReceived(_ urlRequest: URLRequest) {
    let _ = logRequest?(urlRequest)
  }

  @objc
  private func unwrapRequestFromNotification(_ notification: Notification) {
    guard let urlRequest = notification.object as? URLRequest else {
      return
    }
    requestReceived(urlRequest)
  }

}

// MARK: NetworkLoggerUrlProtocol

internal class NetworkLoggerUrlProtocol: URLProtocol {
    
    open override class func canInit(with request: URLRequest) -> Bool {
        if let httpHeaders = request.allHTTPHeaderFields, httpHeaders.isEmpty {
            return false
        }
        
        if let _ = URLProtocol.property(forKey: "NetworkLoggerUrlProtocol", in: request) {
            return false
        }
        
        NotificationCenter._nog.post(name: ._urlProtocolReceivedRequest, object: request)
        return false
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkLoggerUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
}

// MARK: NogConsole

/// Prints to console including [Nog] identifier.
public class NogConsole {

  private(set) var isOn: Bool

  public init() {
    self.isOn = false
  }

  public func turn(on isOn: Bool) {
    self.isOn = isOn
  }

  @discardableResult
  public func debugPrint(_ message: String) -> String {
    guard isOn else {
      return ""
    }
    let message = "[Nog] \(message)"
    print(message)
    return message
  }

}

// MARK: - Request Filter

public typealias RequestFilter = (URLRequest) -> Bool

/// Request filter that allows all requests through.
public let noRequestFilter: RequestFilter = { _ in
  return true
}

/// Request filter that only allows https or http requests through.
public let httpOnlyRequestFilter: RequestFilter = {
  $0.url?.scheme.flatMap { ["https", "http"].contains($0) } ?? false
}

// MARK: - Extensions

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
    static let _urlProtocolReceivedRequest = Notification.Name("NogNetworkLoggerRequest")
}
