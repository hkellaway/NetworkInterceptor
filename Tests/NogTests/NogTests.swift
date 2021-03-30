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
    XCTAssertTrue(sut.allowRequest(httpRequest)
                    && sut.allowRequest(httpsRequest)
                    && sut.allowRequest(nonHttpRequest))
  }

  func test_httpRequestFilter_allowsHTTPRequests() {
    let sut = HttpRequestFilter()
    XCTAssertTrue(sut.allowRequest(httpRequest))
  }

  func test_httpRequestFilter_allowsHTTPSRequests() {
    let sut = HttpRequestFilter()
    XCTAssertTrue(sut.allowRequest(httpsRequest))
  }

  func test_httpRequestFilter_rejects_nonHTTRequests() {
    let sut = HttpRequestFilter()
    XCTAssertFalse(sut.allowRequest(nonHttpRequest))
  }

  func test_injctableRequestFilter_callsHandler() {
    var wasCalled: Bool?
    let sut = InjectableRequestFilter(allowRequest: { _ in
      wasCalled = true
      return true
    })
    let _ = sut.allowRequest(httpsRequest)
    XCTAssertTrue(wasCalled!)
  }

}
