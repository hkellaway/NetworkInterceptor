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

import Combine
import SwiftUI

// MARK: - NetworkLogger

open class NetworkLogger: ObservableObject {

  @Published public private(set) var isLogging: Bool = false
  @Published public private(set) var requests: [NogURLRequest] = []
  @Published public var verbose = true { didSet { debugLogger.turn(on: verbose) } }
  
  public var afterLogRequest: ((URLRequest) -> Void)?
  public let requestFilters: [RequestFilter]

  private var cancellables: Set<AnyCancellable> = []
  private let swizzle: _NetworkLoggingSwizzle
  private let debugLogger: ConsoleLogger

  public convenience init(customRequestFilter: RequestFilter? = nil,
                          debugLogger: ConsoleLogger = ConsoleLogger()) {
    let requestFilters: [RequestFilter] = [
      httpOnlyRequestFilter,
      (customRequestFilter ?? noRequestFilter),
    ]
    self.init(requestFilters: requestFilters,
              swizzle: _InternalNetworkLoggingSwizzle(),
              debugLogger: debugLogger)
  }

    internal init(requestFilters: [RequestFilter],
                  swizzle: _NetworkLoggingSwizzle,
                  debugLogger: ConsoleLogger) {
    self.requestFilters = requestFilters
    self.swizzle = swizzle
    self.debugLogger = debugLogger
    self.verbose = true

    NotificationCenter._nog.publisher(for: ._urlProtocolReceivedRequest)
      .compactMap { $0.object as? URLRequest }
      .sink(receiveValue: { [weak self] in _ = self?.logRequest($0) })
      .store(in: &cancellables)
  }

  public func start() {
    guard !isLogging else {
      debugLogger.log("Attempt to `start` while already started. Returning.")
      return
    }
    swizzle.commit()
    self.isLogging = true
  }

  public func stop() {
    guard isLogging else {
      debugLogger.log("Attempt to `stop` while already stopped. Returning.")
      return
    }
    swizzle.undo()
    self.isLogging = false
  }

  public func toggle() {
    if isLogging {
      stop()
    } else {
      start()
    }
  }

  public func clear() {
    requests = []
  }

  public func mockRequest(urlString: String = "https://hello.world") {
    logRequest(URLRequest(url: URL(string: urlString)!))
  }

  @discardableResult
  open func logRequest(_ urlRequest: URLRequest) -> Bool {
    guard isLogging, (requestFilters.reduce(true) { $0 && $1(urlRequest) }) else {
      return false
    }
    requests.insert(NogURLRequest(id: requests.count + 1, value: urlRequest), at: 0)
    afterLogRequest?(urlRequest)
    return true
  }

}

// MARK: - ConsoleLogger

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
