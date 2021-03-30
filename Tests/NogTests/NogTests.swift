//
//  NogTests.swift
//  NogTests
//
//  Created by Harlan Kellaway on 3/27/21.
//

import XCTest
@testable import Nog

class NogTests: XCTestCase {

  let httpRequest = URLRequest(url: URL(string: "http://github.com")!)
  let httpsRequest = URLRequest(url: URL(string: "https://github.com")!)
  let nonHttpRequest = URLRequest(url: URL(string: "ftp://github.com")!)

  func test_requestFilter_allowsAllRequests() {
    let sut = RequestFilter()
    XCTAssertTrue(sut.evaluate(httpRequest)
                    && sut.evaluate(httpsRequest)
                    && sut.evaluate(nonHttpRequest))
  }

  func test_httpRequestFilter_allowsHTTPRequests() {
    let sut = HttpRequestFilter()
    XCTAssertTrue(sut.evaluate(httpRequest))
  }

  func test_httpRequestFilter_allowsHTTPSRequests() {
    let sut = HttpRequestFilter()
    XCTAssertTrue(sut.evaluate(httpsRequest))
  }

  func test_httpRequestFilter_rejects_nonHTTRequests() {
    let sut = HttpRequestFilter()
    XCTAssertFalse(sut.evaluate(nonHttpRequest))
  }

  func test_injectableRequestFilter_callsHandler() {
    var wasCalled: Bool?
    let sut = InjectableRequestFilter(evaluate: { _ in
      wasCalled = true
      return true
    })
    let _ = sut.evaluate(httpsRequest)
    XCTAssertTrue(wasCalled!)
  }

}
