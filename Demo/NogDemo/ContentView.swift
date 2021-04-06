//
//
//  ContentView.swift
//  NogDemo
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

import Nog
import SwiftUI

extension NetworkLogger {

  static var custom: NetworkLogger {
    let networkLogger = NetworkLogger()
    networkLogger.attachView(NetworkLoggerViewController())
    return networkLogger
  }

}

struct ContentView: View {
    
  let networkLogger: NetworkLogger = .custom
    let session: URLSession = .init(configuration: .default)
    @State var isLogging = false
    @State var isPresentingLog = false
    
    var body: some View {
        VStack {
            Button("Make Request", action: makeRequest)
            Button("Present Log", action: self.presentLog)
            Button("\(isLogging ? "Stop" : "Start") Logging", action: toggleLogging)
                .foregroundColor(isLogging ? .red : .green)
        }
        .onAppear(perform: toggleLogging)
        .sheet(isPresented: $isPresentingLog) {
          NetworkLoggerView(networkLogger: networkLogger)
        }
    }
    
    func makeRequest() {
        guard let url = URL(string: "https://github.com") else {
            return
        }
        self.session.dataTask(with: URLRequest(url: url)).resume()
    }
    
    func toggleLogging() {
        networkLogger.toggle()
        self.isLogging = networkLogger.isLogging
    }

    func presentLog() {
      self.isPresentingLog = true
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
