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

  @Published public private(set) var requests: [NogURLRequest] = []
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
    let request = NogURLRequest(id: requests.count + 1, value: urlRequest)
    requests.insert(request, at: 0)
    afterDisplayRequest?(request.value, cURLDescriptionForRequest(request))
  }

  public func toView() -> some View {
    return NetworkLoggerView(customActions: customActions).environmentObject(self)
  }

  internal func cURLDescriptionForRequest(_ request: NogURLRequest) -> String {
    return request.value.cURLDescription(sessionConfiguration: sessionConfiguration,
                                         credential: credential,
                                         authenticationMethod: authenticationMethod)
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
        List(container.requests) { request in
          NavigationLink(destination:
                            NetworkRequestDetailView(request: request).environmentObject(container)
                            .navigationBarTitle("Request #\(request.id)")
          ) {
            Text("#\(request.id) \(request.value.httpMethod ?? "") \(request.value.url?.absoluteString ?? "")")
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
  let request: NogURLRequest

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
        Text(container.cURLDescriptionForRequest(request))
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
    }
  }

  private func copyCurlToClipboard() {
    UIPasteboard.general.string = container.cURLDescriptionForRequest(request)
  }

}
