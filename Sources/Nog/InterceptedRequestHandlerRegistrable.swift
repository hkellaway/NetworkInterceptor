//
//  InterceptedRequestHandlerRegistrable.swift
//  NetworkInterceptor
//
//  Created by Kenneth Poon on 23/7/18.
//  Copyright © 2018 Kenneth Poon. All rights reserved.
//

import Foundation

public enum SniffableRequestHandlerRegistrable {
    case console(logginMode: ConsoleLoggingMode)
    
    public func requestHandler() -> SniffableRequestHandler {
        switch self {
        case .console(let loggingMode):
            return ConsoleLoggerSniffableRequestHandler(loggingMode: loggingMode)
        }
    }
}
