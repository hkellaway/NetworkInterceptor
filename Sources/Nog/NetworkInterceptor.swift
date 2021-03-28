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
    let networkRequestInterceptor = NetworkRequestInterceptor()
    var requestCount = 0
    
    @objc public func startRecording(){
        self.networkRequestInterceptor.startRecording()
    }
    
    @objc public func stopRecording(){
        self.networkRequestInterceptor.stopRecording()
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
    
}
