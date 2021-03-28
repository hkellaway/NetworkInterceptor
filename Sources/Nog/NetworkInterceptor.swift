//
//  NetworkInterceptor.swift
//  NetworkInterceptor
//
//  Created by Kenneth Poon on 26/5/18.
//  Copyright © 2018 Kenneth Poon. All rights reserved.
//

import Foundation

@objc public class NetworkInterceptor: NSObject {
    
    @objc public static let shared = NetworkInterceptor()
    var requestCount = 0
    
    @objc public func startRecording(){
        URLProtocol.registerClass(NetworkRequestSniffableUrlProtocol.self)
        swizzleProtocolClasses()
    }
    
    @objc public func stopRecording(){
        URLProtocol.unregisterClass(NetworkRequestSniffableUrlProtocol.self)
        swizzleProtocolClasses()
    }
    
    func sniffRequest(urlRequest: URLRequest){
        guard let scheme = urlRequest.url?.scheme,
              ["https", "http"].contains(scheme) else {
            return
        }
        requestCount = requestCount + 1
        let loggableText = "Request #\(requestCount): CURL => \(urlRequest.description)"
        print(loggableText)
    }
    
    func swizzleProtocolClasses(){
        let instance = URLSessionConfiguration.default
        let uRLSessionConfigurationClass: AnyClass = object_getClass(instance)!

        let method1: Method = class_getInstanceMethod(uRLSessionConfigurationClass, #selector(getter: uRLSessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.fakeProcotolClasses))!

        method_exchangeImplementations(method1, method2)
    }
    
}

extension URLSessionConfiguration {
    
    @objc func fakeProcotolClasses() -> [AnyClass]? {
        guard let fakeProcotolClasses = self.fakeProcotolClasses() else {
            return []
        }
        var originalProtocolClasses = fakeProcotolClasses.filter {
            return $0 != NetworkRequestSniffableUrlProtocol.self
        }
        originalProtocolClasses.insert(NetworkRequestSniffableUrlProtocol.self, at: 0)
        return originalProtocolClasses
    }
    
}
