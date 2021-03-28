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

internal extension NotificationCenter {
    
    static var _networkLogger = NotificationCenter()
    
}

internal extension Notification.Name {
    
    static let _logRequest = Notification.Name("NetworkLoggerRequest")
    
}

public class NetworkLogger {
    
    public private(set) var isLogging = false
    
    private var requestCount = 0
    
    public init() {
        NotificationCenter._networkLogger.addObserver(self, selector: #selector(logRequest(_:)), name: ._logRequest, object: nil)
    }
    
    deinit {
        NotificationCenter._networkLogger.removeObserver(self)
    }
    
    public func start(sessionConfiguration: URLSessionConfiguration = .default) {
        URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses(sessionConfiguration: sessionConfiguration)
        sessionConfiguration.protocolClasses = [NetworkLoggerUrlProtocol.self] + (sessionConfiguration.protocolClasses ?? [])
        isLogging = true
    }
    
    public func stop(sessionConfiguration: URLSessionConfiguration = .default) {
        URLProtocol.unregisterClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses(sessionConfiguration: sessionConfiguration)
        sessionConfiguration.protocolClasses = (sessionConfiguration.protocolClasses ?? []).filter {
            $0 != NetworkLoggerUrlProtocol.self
        }
        isLogging = false
    }
    
    public func toggle(sessionConfiguration: URLSessionConfiguration = .default) {
        if isLogging {
            stop(sessionConfiguration: sessionConfiguration)
        } else {
            start(sessionConfiguration: sessionConfiguration)
        }
    }
    
    private func swizzleProtocolClasses(sessionConfiguration: URLSessionConfiguration = .default) {
        let sessionConfigurationClass: AnyClass = object_getClass(sessionConfiguration)!
        let method1: Method = class_getInstanceMethod(sessionConfigurationClass, #selector(getter: sessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration._injectedProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }
    
    @objc private func logRequest(_ notification: Notification) {
        guard let urlRequest = notification.object as? URLRequest,
              let scheme = urlRequest.url?.scheme,
              ["https", "http"].contains(scheme) else {
            return
        }
        
        requestCount = requestCount + 1
        print("[Nog] Request #\(requestCount): URL => \(urlRequest.description)")
    }
    
}

extension URLSessionConfiguration {
    
    @objc internal func _injectedProtocolClasses() -> [AnyClass]? {
        guard let injectedProtocolClasses = self._injectedProtocolClasses() else {
            return []
        }
        
        // Re-insert custom UrlProtocol if needed
        var protocolClasses = injectedProtocolClasses.filter {
            return $0 != NetworkLoggerUrlProtocol.self
        }
        protocolClasses.insert(NetworkLoggerUrlProtocol.self, at: 0)
        return protocolClasses
    }
    
}

class NetworkLoggerUrlProtocol: URLProtocol {
    
    open override class func canInit(with request: URLRequest) -> Bool {
        if let httpHeaders = request.allHTTPHeaderFields, httpHeaders.isEmpty {
            return false
        }
        
        if let _ = URLProtocol.property(forKey: "NetworkLoggerUrlProtocol", in: request) {
            return false
        }
        
        NotificationCenter._networkLogger.post(name: ._logRequest, object: request)
        return false
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkLoggerUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
}

public struct Nog {
    
    public init() { }
    
    public func speak() -> String {
        return "Hello World"
    }
    
}
