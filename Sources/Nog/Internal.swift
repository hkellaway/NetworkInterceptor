//
//
//  Internal.swift
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

// MARK: - NetworkLoggingSwizzle

internal protocol _NetworkLoggingSwizzle {
  func commit()
  func undo()
}

internal struct _InternalNetworkLoggingSwizzle: _NetworkLoggingSwizzle {

  func commit() {
    URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
    URLSessionConfiguration._swizzleProtocolClasses()
  }

  func undo() {
    URLProtocol.unregisterClass(NetworkLoggerUrlProtocol.self)
    URLSessionConfiguration._swizzleProtocolClasses()
  }

}

// MARK: - NetworkLoggerUrlProtocol

internal class NetworkLoggerUrlProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        if let httpHeaders = request.allHTTPHeaderFields, httpHeaders.isEmpty {
            return false
        }

        if let _ = URLProtocol.property(forKey: "NetworkLoggerUrlProtocol", in: request) {
            return false
        }

        DispatchQueue.main.async {
          NotificationCenter._nog.post(name: ._urlProtocolReceivedRequest, object: request)
        }
        return false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkLoggerUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }

}

// MARK: - Extensions

// MARK: URLSessionConfiguration

extension URLSessionConfiguration {

    internal static func _swizzleProtocolClasses() {
        let instance = URLSessionConfiguration.default
        let sessionConfigurationClass: AnyClass = object_getClass(instance)!
        let method1: Method = class_getInstanceMethod(sessionConfigurationClass, #selector(getter: sessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration._injectedProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }

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
