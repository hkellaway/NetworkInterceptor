//
//
//  NetworkLogger.swift
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

    /// View where logs are displayed.
    public private(set) var view: NetworkLogDisplayable! {
      didSet {
        (view as? NetworkLoggerViewContainer)?.toggleLogging = self.toggle
        (view as? NetworkLoggerViewContainer)?.isLogging = isLogging
      }
    }
    
    /// Whether network logging is currently on.
    public private(set) var isLogging = false {
      didSet {
        (view as? NetworkLoggerViewContainer)?.isLogging = isLogging
      }
    }

    /// Whether verbose console logging is on.
    public var verbose: Bool = true {
      didSet {
        console.turn(on: verbose)
      }
    }

    /// Number of requests made since start.
    public private(set) var requestCount = 0 {
      didSet {
        (view as? ConsoleNetworkLoggerView)?.requestCount = requestCount
      }
    }

    // MARK: Private properties

    private let adapter: NetworkLoggerUrlProtocolAdapter
    private let console: ConsoleLogger
    
    // MARK: Init/Deinit

    public convenience init(filter customRequestFilter: RequestFilter? = nil) {
        self.init(requestFilters: [
          httpOnlyRequestFilter,
          (customRequestFilter ?? noRequestFilter),
        ])
    }
    
    public init(requestFilters: [RequestFilter],
                adapter: NetworkLoggerUrlProtocolAdapter = NetworkLoggerUrlProtocolAdapter(),
                console: ConsoleLogger = ConsoleLogger(),
                verbose: Bool = true) {
        self.requestFilters = requestFilters
        self.adapter = adapter
        self.console = console

        self.adapter.logRequest = { self.logRequest($0) }
        self.console.turn(on: verbose)
        self.attachView(ConsoleNetworkLoggerView(console: console))
    }

    // MARK: Public instance functions
    
    /// Starts recording of network requests.
    public func start() {
        guard !isLogging else {
            console.log("Attempt to `start` while already started. Returning.")
            return
        }
        
        URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
        URLSessionConfiguration._swizzleProtocolClasses()
        isLogging = true
    }
    
    /// Stops recording of networking requests.
    public func stop() {
        guard isLogging else {
            console.log("Attempt to `stop` while already stopped. Returning.")
            return
        }
        
        URLProtocol.unregisterClass(NetworkLoggerUrlProtocol.self)
        URLSessionConfiguration._swizzleProtocolClasses()
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
      view.displayRequest(urlRequest)
      return true
    }

    open func attachView(_ view: NetworkLogDisplayable) {
      self.view = view
    }

}

// MARK: - ConsoleLogger

/// Prints to console including [Nog] identifier.
open class ConsoleLogger {

  private var isOn = false

  public init() { }

  @discardableResult
  public func log(_ message: String) -> String {
    guard isOn else {
      return ""
    }
    let fullMessage = "[Nog] \(message)"
    print(fullMessage)
    return fullMessage
  }

  internal func turn(on: Bool) {
    self.isOn = on
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
