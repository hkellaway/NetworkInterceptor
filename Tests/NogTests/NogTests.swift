//
//  NogTests.swift
//  NogTests
//
//  Created by Harlan Kellaway on 3/27/21.
//

import XCTest
@testable import Nog

class NogTests: XCTestCase {

  let httpsRequest = URLRequest(url: URL(string: "https://github.com")!)
  let httpRequest = URLRequest(url: URL(string: "http://github.com")!)
  let nonHttpRequest = URLRequest(url: URL(string: "ftp://github.com")!)

  var sut: NetworkLogger!

  override func setUp() {
    sut = NetworkLogger()
  }

  override func tearDown() {
    sut = nil
  }

  // MARK: - NetworkLogger

  func test_networkLogger_onInit_isNotLogging() {
    XCTAssertFalse(sut.isLogging)
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

  func test_networkLogger_default_filtersOutNonHTTPRequests() {
    sut.start()
    XCTAssertTrue(sut.logRequest(httpsRequest))
    XCTAssertFalse(sut.logRequest(nonHttpRequest))
  }

  func test_networkLogger_emptyRequestFilters_allowsNonHTTPRequests() {
    let sutNoFilters = NetworkLogger(requestFilters: [])
    sutNoFilters.start()
    XCTAssertTrue(sutNoFilters.logRequest(nonHttpRequest))
  }

  // MARK: - RequestFilter

  func test_noRequestFilter_allowsAllRequests() {
    let sut: RequestFilter = noRequestFilter
    XCTAssertTrue(sut(httpRequest)
                    && sut(httpsRequest)
                    && sut(nonHttpRequest))
  }

  func test_httpRequestFilter_allowsHTTPSRequests() {
    let sut: RequestFilter = httpOnlyRequestFilter
    XCTAssertTrue(sut(httpsRequest))
  }

  func test_httpRequestFilter_allowsHTTPRequests() {
    let sut: RequestFilter = httpOnlyRequestFilter
    XCTAssertTrue(sut(httpRequest))
  }

  func test_httpRequestFilter_rejects_nonHTTPRequests() {
    let sut: RequestFilter = httpOnlyRequestFilter
    XCTAssertFalse(sut(nonHttpRequest))
  }

}
