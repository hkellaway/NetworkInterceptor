//
//  ConsoleLoggerSniffableRequestHandler.swift
//  NetworkInterceptor
//
//  Created by Kenneth Poon on 10/7/18.
//  Copyright © 2018 Kenneth Poon. All rights reserved.
//

import Foundation

public class ConsoleLoggerSniffableRequestHandler: SniffableRequestHandler {

    fileprivate var requestCount: Int = 0
    public func sniffRequest(urlRequest: URLRequest) {
        requestCount = requestCount + 1
        let loggableText = "Request #\(requestCount): CURL => \(urlRequest.description)"
        print(loggableText)
    }
}
