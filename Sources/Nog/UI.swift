//
//
//  UI.swift
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

import SwiftUI

// MARK: - NetworkLogDisplayable

/// View to display requests.
public protocol NetworkLogDisplayable {
  func displayRequest(_ urlRequest: URLRequest)
}

/// View that displays requests to console. Deafult if no view provided.
public class ConsoleNetworkLoggerView: NetworkLogDisplayable {

  public let console: NogConsole
  var requestCount: Int = 0

  public init(console: NogConsole) {
    self.console = console
  }

  public func displayRequest(_ urlRequest: URLRequest) {
    console.debugPrint("Request #\(requestCount): URL => \(urlRequest.description)")
  }

}

// MARK: - SwiftUI

public class NetworkLoggerViewContainer: ObservableObject, NetworkLogDisplayable {

  @Published public private(set) var requests: [(id: Int, request: URLRequest)] = []
  @Published  public internal(set) var isLogging: Bool = false
  public internal(set) var toggleLogging: (() -> Void) = { }
  public var afterDisplayRequest: ((URLRequest, String) -> Void)?
  public let sessionConfiguration: URLSessionConfiguration
  public let credential: URLCredential?
  public let authenticationMethod: String?
  public let customActions: [(title: String, handler: () -> Void)]

  public init(sessionConfiguration: URLSessionConfiguration = .default,
              credential: URLCredential? = nil,
              authenticationMethod: String? = NSURLAuthenticationMethodDefault,
              customActions: [(title: String, handler: () -> Void)] = []) {
    self.sessionConfiguration = sessionConfiguration
    self.credential = credential
    self.authenticationMethod = authenticationMethod
    self.customActions = customActions
    requests = []
  }

  public func displayRequest(_ urlRequest: URLRequest) {
    requests.insert((requests.count + 1, urlRequest), at: 0)
    afterDisplayRequest?(urlRequest, cURLDescriptionForRequest(urlRequest))
  }

  public func toView() -> some View {
    return NetworkLoggerView(customActions: customActions).environmentObject(self)
  }

  internal func cURLDescriptionForRequest(atIndex index: Int) -> String {
    guard index >= 0 && index < requests.count else {
      return "Invalid"
    }
    return cURLDescriptionForRequest(requests[index].1)
  }

  internal func cURLDescriptionForRequest(_ urlRequest: URLRequest) -> String {
    return urlRequest.cURLDescription(sessionConfiguration: sessionConfiguration,
                                      credential: credential,
                                      authenticationMethod: authenticationMethod)
  }

  internal func requestDisplayNumber(forIndex index: Int) -> Int {
    return requests.count - index
  }

  internal func clear() {
    requests = []
  }

}

internal struct NetworkLoggerView: View {

  @EnvironmentObject var container: NetworkLoggerViewContainer
  @State private var isShowingDebugMenu = false
  let customActions: [(title: String, handler: () -> Void)]

  var body: some View {
    NavigationView {
      VStack {
        Button(action: { self.isShowingDebugMenu = true }, label: {
          Text("Actions")
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        })
        .background(Color.blue)
        List(Array(container.requests.enumerated()), id: \.1.id) { (index, request) in
          NavigationLink(destination:
                            NetworkRequestDetailView(index: index).environmentObject(container)
                            .navigationBarTitle("Request #\(container.requestDisplayNumber(forIndex: index))")
          ) {
            Text("#\(container.requestDisplayNumber(forIndex: index)) \(request.1.httpMethod ?? "") \(request.1.url?.absoluteString ?? "")")
          }
        }
      }
      .navigationBarTitle("")
      .navigationBarHidden(true)
    }
    .actionSheet(isPresented: $isShowingDebugMenu) {
      ActionSheet(title: Text("Actions"), message: nil, buttons: customActions.map { ActionSheet.Button.default(Text($0.0), action: $0.1) } + [
        .default(Text("Turn Logging \(container.isLogging ? "Off" : "On")"), action: container.toggleLogging),
        .destructive(Text("Clear"), action: container.clear),
        .cancel()
      ])
    }
  }

}

internal struct NetworkRequestDetailView: View {

  @EnvironmentObject var container: NetworkLoggerViewContainer
  let index: Int

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Button(action: copyCurlToClipboard) {
          Text("Copy cURL")
            .padding(8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(4)
        }
        Text(container.cURLDescriptionForRequest(atIndex: index))
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
    }
  }

  private func copyCurlToClipboard() {
    UIPasteboard.general.string = container.cURLDescriptionForRequest(atIndex: index)
  }

}
