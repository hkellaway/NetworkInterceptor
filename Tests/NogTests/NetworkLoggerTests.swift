//
//  NogTests.swift
//  NogTests
//
//  Created by Harlan Kellaway on 3/27/21.
//

import XCTest
@testable import Nog

class NetworkLoggerTests: XCTestCase {

  var sut: NetworkLogger!
  var mockAdapter: MockAdapter!
  var mockConsole: MockConsole!

  override func setUp() {
    let defaultFilters = NetworkLogger().requestFilters
    mockAdapter = MockAdapter()
    mockConsole = MockConsole()
    sut = NetworkLogger(requestFilters: defaultFilters,
                        adapter: mockAdapter)
  }

  override func tearDown() {
    sut.stop()
    sut = nil
    mockAdapter = nil
    mockConsole = nil
  }

  // MARK: - NetworkLogger

  func test_networkLogger_onInit_isNotLogging() {
    XCTAssertFalse(sut.isLogging)
  }

  func test_networkLogger_onInit_usesConsoleView() {
    let sutDefault = NetworkLogger()
    XCTAssertTrue(sutDefault.view is ConsoleNetworkLoggerView)
  }

  func test_networkLogger_onStart_isLogging() {
    sut.start()
    XCTAssertTrue(sut.isLogging)
  }

  func test_networkLogger_onStop_isNotLogging() {
    sut.start()
    sut.stop()
    XCTAssertFalse(sut.isLogging)
  }

  func test_networkLogger_whenStarted_toggle_stopsLogging() {
    sut.start()
    sut.toggle()
    XCTAssertFalse(sut.isLogging)
  }

  func test_networkLogger_whenStopped_toggle_startsLogging() {
    sut.start()
    sut.stop()
    sut.toggle()
    XCTAssertTrue(sut.isLogging)
  }

  func test_networkLogger_default_filtersOutNonHTTPRequests() {
    sut.start()
    XCTAssertTrue(sut.logRequest(.httpsRequest))
    XCTAssertFalse(sut.logRequest(.nonHttpRequest))
  }

  func test_networkLogger_emptyRequestFilters_allowsNonHTTPRequests() {
    let sutNoFilters = NetworkLogger(requestFilters: [])
    sutNoFilters.start()
    XCTAssertTrue(sutNoFilters.logRequest(.nonHttpRequest))
  }

  func test_networkLogger_whenStopped_doesNotLogRequests() {
    sut.start()
    sut.stop()
    XCTAssertFalse(sut.logRequest(.httpsRequest))
  }

  func test_networkLogger_onRequest_incrementsRequestCount() {
    sut.start()
    mockAdapter.sendMockRequest()
    mockAdapter.sendMockRequest()
    mockAdapter.sendMockRequest()
    XCTAssertEqual(sut.requestCount, 3)
  }

  // MARK: - NetworkLoggerView

  func test_consoleNetworkLoggerView_printsRequest() {
    let sutView = ConsoleNetworkLoggerView(console: mockConsole)
    sut.start()
    sut.attachView(sutView)
    mockAdapter.sendMockRequest()
    mockAdapter.sendMockRequest()
    mockAdapter.sendMockRequest()
    XCTAssertEqual(mockConsole.lastMessage, "Request #3: URL => https://github.com")
  }

  // MARK: - NogConsole

  func test_console_whenOn_prints() {
    let sut = NogConsole()
    sut.turn(on: true)
    XCTAssertEqual(sut.debugPrint("testing 1 2 3"), "[Nog] testing 1 2 3")
  }

  func test_console_whenOff_doesNotPrint() {
    let sut = NogConsole()
    sut.turn(on: false)
    XCTAssertTrue(sut.debugPrint("testing 1 2 3").isEmpty)
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

}
