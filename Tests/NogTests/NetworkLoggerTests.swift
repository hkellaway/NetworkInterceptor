//
//
//  NetworkLoggerTests.swift
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

import XCTest
@testable import Nog

@available(iOS 13.0, *)
class NogTests: XCTestCase {
    
    var sut: TestableNog!
    var mockSwizzle: MockNetworkLoggingSwizzle!
    var mockLogger: MockLogger!
    
    override func setUp() {
        mockSwizzle = MockNetworkLoggingSwizzle()
        mockLogger = MockLogger()
        sut = TestableNog(requestFilters: [httpOnlyRequestFilter], swizzle: mockSwizzle, debugLogger: mockLogger)
    }
    
    override func tearDown() {
        sut = nil
        mockSwizzle = nil
        mockLogger = nil
    }
    
    // MARK: - NetworkLogger
    
    func test_onInit_isLogging_isFalse() {
        XCTAssertFalse(sut.isLogging)
    }
    
    func test_start_setsIsLogging_toTrue() {
        sut.start()
        XCTAssertTrue(sut.isLogging)
    }
    
    func test_start_whenAlreadyStarted_logsDebugMessage() {
        sut.start()
        sut.start()
        XCTAssertEqual(mockLogger.lastMessageLogged, "[Nog] Attempt to `start` while already started. Returning.")
    }
    
    func test_start_commitsNetworkLoggingSwizzle() {
        mockSwizzle.didCommit = false
        sut.start()
        XCTAssertTrue(mockSwizzle.didCommit)
    }
    
    func test_stop_setsIsLogging_toFalse() {
        sut.start()
        sut.stop()
        XCTAssertFalse(sut.isLogging)
    }
    
    func test_stop_whenAlreadyStopped_logsDebugMessage() {
        sut.start()
        sut.stop()
        sut.stop()
        XCTAssertEqual(mockLogger.lastMessageLogged, "[Nog] Attempt to `stop` while already stopped. Returning.")
    }
    
    func test_stop_undoesNetworkLoggingSwizzle() {
        mockSwizzle.didUndo = false
        sut.start()
        sut.stop()
        XCTAssertTrue(mockSwizzle.didUndo)
    }
    
    func test_toggle_whenStarted_callsStop() {
        sut.didCallStop = false
        sut.start()
        sut.toggle()
        XCTAssertTrue(sut.didCallStop)
    }
    
    func test_toggle_whenStopped_callsStart() {
        sut.didCallStart = false
        sut.stop()
        sut.toggle()
        XCTAssertTrue(sut.didCallStart)
    }
    
    func test_logRequest_whenLoggingIsOn_storesRequest() {
        let request1 = URLRequest(url: URL(string: "https://github.com")!)
        let request2 = URLRequest(url: URL(string: "https://bitbucket.org")!)
        let request3 = URLRequest(url: URL(string: "https://gitlab.com")!)
        sut.start()
        sut.logRequest(request1)
        sut.logRequest(request2)
        sut.logRequest(request3)
        XCTAssertEqual(sut.requests, [NogURLRequest(id: 3, value: request3), NogURLRequest(id: 2, value: request2), NogURLRequest(id: 1, value: request1)])
    }
    
    func test_logRequest_whenLoggingIsOff_doesNotStoreRequest() {
        let request1 = URLRequest(url: URL(string: "https://github.com")!)
        let request2 = URLRequest(url: URL(string: "https://bitbucket.org")!)
        let request3 = URLRequest(url: URL(string: "https://gitlab.com")!)
        sut.start()
        sut.logRequest(request1)
        sut.logRequest(request2)
        sut.stop()
        sut.logRequest(request3)
        XCTAssertEqual(sut.requests, [NogURLRequest(id: 2, value: request2), NogURLRequest(id: 1, value: request1)])
    }
    
    func test_clear_removesAllStoredRequests() {
        let request1 = URLRequest(url: URL(string: "https://github.com")!)
        let request2 = URLRequest(url: URL(string: "https://bitbucket.org")!)
        sut.start()
        sut.logRequest(request1)
        sut.logRequest(request2)
        XCTAssertEqual(sut.requests, [NogURLRequest(id: 2, value: request2), NogURLRequest(id: 1, value: request1)])
        sut.clear()
        XCTAssertTrue(sut.requests.isEmpty)
    }
    
    func test_onInit_filtersForHTTPRequests() {
        let request1 = URLRequest(url: URL(string: "https://github.com")!)
        let ftpRequest = URLRequest(url: URL(string: "ftp://hello.world")!)
        let request2 = URLRequest(url: URL(string: "https://bitbucket.org")!)
        sut.start()
        sut.logRequest(request1)
        sut.logRequest(ftpRequest)
        sut.logRequest(request2)
        XCTAssertEqual(sut.requests, [NogURLRequest(id: 2, value: request2), NogURLRequest(id: 1, value: request1)])
    }
    
    func test_verbose_whenOff_doesNotLog() {
        mockLogger.lastMessageLogged = ""
        sut.verbose = false
        sut.start()
        sut.start()
        XCTAssertTrue(mockLogger.lastMessageLogged.isEmpty)
    }
    
    // MARK: - RequestFilter
    
    func test_noRequestFilter_allowsAllRequests() {
        let sut: RequestFilter = noRequestFilter
        XCTAssertTrue(sut(.httpRequest)
                        && sut(.httpsRequest)
                        && sut(.nonHttpRequest))
    }
    
    func test_httpRequestFilter_allowsHTTPSRequests() {
        let sut: RequestFilter = httpOnlyRequestFilter
        XCTAssertTrue(sut(.httpsRequest))
    }
    
    func test_httpRequestFilter_allowsHTTPRequests() {
        let sut: RequestFilter = httpOnlyRequestFilter
        XCTAssertTrue(sut(.httpRequest))
    }
    
    func test_httpRequestFilter_rejects_nonHTTPRequests() {
        let sut: RequestFilter = httpOnlyRequestFilter
        XCTAssertFalse(sut(.nonHttpRequest))
    }
    
    // MARK: - ConsoleLogger
    
    func test_console_whenOn_prints() {
        let sut = ConsoleLogger()
        sut.turn(on: true)
        XCTAssertEqual(sut.log("testing 1 2 3"), "[Nog] testing 1 2 3")
    }
    
    func test_console_whenOff_doesNotPrint() {
        let sut = ConsoleLogger()
        sut.turn(on: false)
        XCTAssertTrue(sut.log("testing 1 2 3").isEmpty)
    }
    
}

@available(iOS 13.0, *)
class TestableNog: NetworkLogger {
    
    var didCallStart = false
    var didCallStop = false
    
    override func start() {
        super.start()
        didCallStart = true
    }
    
    override func stop() {
        super.stop()
        didCallStop = true
    }
    
}
