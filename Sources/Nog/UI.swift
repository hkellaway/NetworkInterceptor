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

public struct NetworkLoggerView: View {
    
    @EnvironmentObject var networkLogger: NetworkLogger
    @State private var isShowingDebugMenu = false
    
    public let sessionConfiguration: URLSessionConfiguration
    public let credential: URLCredential?
    public let authenticationMethod: String?
    
    private let customActions: [(title: String, handler: () -> Void)]
    
    public init(sessionConfiguration: URLSessionConfiguration = .default,
                credential: URLCredential? = nil,
                authenticationMethod: String? = NSURLAuthenticationMethodDefault,
                customActions: [(title: String, handler: () -> Void)] = []) {
        self.sessionConfiguration = sessionConfiguration
        self.credential = credential
        self.authenticationMethod = authenticationMethod
        self.customActions = customActions
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                Button(action: { self.isShowingDebugMenu = true }, label: {
                    Text("Actions")
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                })
                .background(Color.blue)
                List(networkLogger.requests) { request in
                    NavigationLink(destination:
                                    NetworkRequestDetailView(
                                        request: request,
                                        curlDescription: cURLDescriptionForRequest(request.value),
                                        copyToClipboard: { UIPasteboard.general.string = $0 })
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
                .default(Text("Turn Logging \(networkLogger.isLogging ? "Off" : "On")"), action: networkLogger.toggle),
                .destructive(Text("Clear"), action: networkLogger.clear),
                .cancel()
            ])
        }
    }
    
    private func cURLDescriptionForRequest(_ urlRequest: URLRequest) -> String {
        return urlRequest.cURLDescription(sessionConfiguration: sessionConfiguration,
                                          credential: credential,
                                          authenticationMethod: authenticationMethod)
    }
    
}

public struct NetworkRequestDetailView: View {
    
    let request: NogURLRequest
    let curlDescription: String
    let copyToClipboard: (_ text: String) -> Void
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: { copyToClipboard(curlDescription) }) {
                    Text("Copy cURL")
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                Text(curlDescription)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
    
}
