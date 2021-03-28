//
//  NogTests.swift
//  NogTests
//
//  Created by Harlan Kellaway on 3/27/21.
//

import XCTest
@testable import Nog

class NogTests: XCTestCase {
    
    var sut: Nog!

    override func setUpWithError() throws {
        sut = Nog()
    }

    override func tearDownWithError() throws {
        sut = nil
    }

    func testExample() throws {
        XCTAssertEqual(sut.speak(), "Hello World")
    }

}
