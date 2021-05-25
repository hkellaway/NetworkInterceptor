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
import UIKit

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

  internal init(customActions: [(title: String, handler: () -> Void)] = []) {
    self.customActions = customActions
  }

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
      ActionSheet(title: Text("Debug"), message: nil, buttons: customActions.map { ActionSheet.Button.default(Text($0.0), action: $0.1) } + [
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

// MARK: - UIKit

open class NetworkLoggerViewController: UIViewController, NetworkLogDisplayable {

  public var sessionConfiguration: URLSessionConfiguration?
  public var credential: URLCredential?
  public var authenticationMethod: String? = NSURLAuthenticationMethodDefault
  public private(set) var requestHistory: [URLRequest] = []

  private let customDebugActions: [(title: String, handler: () -> Void)]
  private var lastIndexSelected = -1

  private let actionMenuButton = UIButton(frame: .zero)
  private let tableView = UITableView(frame: .zero)

  public init(customDebugActions: [(title: String, handler: () -> Void)] = []) {
    self.customDebugActions = customDebugActions
    super.init(nibName: nil, bundle: nil)
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = self
    tableView.delegate = self

    let stackView = UIStackView(arrangedSubviews: [tableView])
    stackView.axis = .vertical
    stackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackView)
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
    ])

    actionMenuButton.setTitle("Debug", for: .normal)
    actionMenuButton.backgroundColor = .systemTeal
    stackView.insertArrangedSubview(actionMenuButton, at: 0)
    actionMenuButton.addTarget(self, action: #selector(presentDebugActions), for: .touchUpInside)
  }

  open func displayRequest(_ urlRequest: URLRequest) {
    requestHistory.insert(urlRequest, at: 0)

    DispatchQueue.main.async { [weak self] in
      self?.tableView.reloadData()
    }
  }

  public func cURLDescriptionForLastSelected() -> String {
    guard lastIndexSelected >= 0 && lastIndexSelected < requestHistory.count else {
      return "Invalid"
    }
    return cURLDescription(forRequest: requestHistory[lastIndexSelected])
  }

  public func cURLDescription(forRequest request: URLRequest) -> String {
    return request.cURLDescription(sessionConfiguration: sessionConfiguration, credential: credential, authenticationMethod: authenticationMethod)
  }

  public func requestNumber(atIndex index: Int) -> Int {
    return requestHistory.count - index
  }

  public func clear() {
    requestHistory = []
    lastIndexSelected = -1
    DispatchQueue.main.async { [weak self] in
      self?.tableView.reloadData()
    }
  }

  @objc
  private func presentDebugActions() {
    let actionSheet = UIAlertController(title: "Debug", message: nil, preferredStyle: .actionSheet)
    let clearAction: UIAlertAction = .init(title: "Clear", style: .destructive, handler: { [weak self] _ in
      self?.clear()
    })
    let copyCURL = UIAlertAction(title: "Copy cURL for #\(requestNumber(atIndex: lastIndexSelected))", style: .default, handler: { [weak self] _ in
      UIPasteboard.general.string = self?.cURLDescriptionForLastSelected() ?? ""
    })
    let cancelAction: UIAlertAction = .init(title: "Cancel", style: .cancel)
    actionSheet.addAction(copyCURL)
    customDebugActions.forEach { action in actionSheet.addAction(.init(title: action.title, style: .default, handler: { _ in action.handler() })) }
    actionSheet.addAction(clearAction)
    actionSheet.addAction(cancelAction)
    present(actionSheet, animated: true, completion: nil)
  }

}

extension NetworkLoggerViewController: UITableViewDataSource {

  public func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return requestHistory.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let request = requestHistory[indexPath.row]
    let cell = UITableViewCell()
    cell.textLabel?.numberOfLines = 2
    cell.textLabel?.text = "#\(requestNumber(atIndex: indexPath.row)) \(request.httpMethod ?? "") \(request.description)"
    return cell
  }

}

extension NetworkLoggerViewController: UITableViewDelegate {

  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.lastIndexSelected = indexPath.row

    let request = requestHistory[indexPath.row]
    let modal = UIViewController()
    modal.view.backgroundColor = .systemBackground
    let titleLabel = UILabel()
    titleLabel.text = "Request #\(requestNumber(atIndex: indexPath.row))"
    titleLabel.font = .preferredFont(forTextStyle: .title1)
    modal.view.addSubview(titleLabel)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: modal.view.leadingAnchor, constant: 8),
      titleLabel.topAnchor.constraint(equalTo: modal.view.topAnchor, constant: 8),
      titleLabel.trailingAnchor.constraint(equalTo: modal.view.trailingAnchor, constant: -8)
    ])
    let textView = UITextView()
    textView.font = .preferredFont(forTextStyle: .body)
    textView.text = cURLDescription(forRequest: request)
    textView.isUserInteractionEnabled = false
    modal.view.addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      textView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      textView.bottomAnchor.constraint(equalTo: modal.view.bottomAnchor),
      textView.widthAnchor.constraint(equalTo: modal.view.widthAnchor)
    ])
    modal.modalPresentationStyle = .popover
    present(modal, animated: true, completion: nil)
  }

}
