//
//
//  Nog.swift
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

// MARK: - NetworkLogger

/// Manages whether network logging is on and reactions to network requests.
open class NetworkLogger {
    
    // MARK: Public properties

    /// Filters called when a request is logged, giving client a chance to determine whether
    /// request should be logged or not.
    public let requestFilters: [RequestFilter]

    /// View where logs are displayed.
    public private(set) var view: NetworkLogDisplayable!
    
    /// Whether network logging is currently on.
    public private(set) var isLogging = false

    /// Whether verbose console logging is on.
    public var verbose: Bool = true {
      didSet {
        console.turn(on: verbose)
      }
    }

    /// Number of requests made since start.
    public private(set) var requestCount = 0 {
      didSet {
        (view as? ConsoleNetworkLoggerView)?.requestCount = requestCount
      }
    }

    // MARK: Private properties

    private let adapter: NetworkLoggerUrlProtocolAdapter
    internal let console: NogConsole
    
    // MARK: Init/Deinit

    public convenience init(filter customRequestFilter: RequestFilter? = nil) {
        self.init(requestFilters: [
          httpOnlyRequestFilter,
          (customRequestFilter ?? noRequestFilter),
        ])
    }
    
    public init(requestFilters: [RequestFilter],
                adapter: NetworkLoggerUrlProtocolAdapter = NetworkLoggerUrlProtocolAdapter(),
                console: NogConsole = NogConsole(),
                verbose: Bool = true) {
        self.requestFilters = requestFilters
        self.adapter = adapter
        self.console = console

        self.adapter.logRequest = self.logRequest
        self.console.turn(on: verbose)
        self.attachView(ConsoleNetworkLoggerView(console: console))
    }

    // MARK: Public instance functions
    
    /// Starts recording of network requests.
    public func start() {
        guard !isLogging else {
            console.debugPrint("Attempt to `start` while already started. Returning.")
            return
        }
        
        URLProtocol.registerClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses()
        isLogging = true
    }
    
    /// Stops recording of networking requests.
    public func stop() {
        guard isLogging else {
            console.debugPrint("Attempt to `stop` while already stopped. Returning.")
            return
        }
        
        URLProtocol.unregisterClass(NetworkLoggerUrlProtocol.self)
        swizzleProtocolClasses()
        isLogging = false
    }
    
    public func toggle() {
        if isLogging {
            stop()
        } else {
            start()
        }
    }

    @discardableResult
    open func logRequest(_ urlRequest: URLRequest) -> Bool {
      guard isLogging, (requestFilters.reduce(true) { $0 && $1(urlRequest) }) else {
        return false
      }

      requestCount = requestCount + 1
      view.displayRequest(urlRequest)
      return true
    }

    open func attachView(_ view: NetworkLogDisplayable) {
      self.view = view
    }
    
    // MARK: Private instance functions
    
    private func swizzleProtocolClasses() {
        let instance = URLSessionConfiguration.default
        let sessionConfigurationClass: AnyClass = object_getClass(instance)!
        let method1: Method = class_getInstanceMethod(sessionConfigurationClass, #selector(getter: sessionConfigurationClass.protocolClasses))!
        let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration._injectedProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }

}

// MARK: NetworkLoggerUrlProtocolAdapter

/// Adapts output from UrlProtocol interception for use by NetworkLogger.
open class NetworkLoggerUrlProtocolAdapter {

  var logRequest: ((URLRequest) -> Bool)?

  public init() {
    NotificationCenter._nog.addObserver(self,
                                        selector: #selector(unwrapRequestFromNotification(_:)),
                                        name: ._urlProtocolReceivedRequest,
                                        object: nil)
  }

  deinit {
    NotificationCenter._nog.removeObserver(self)
  }

  public func requestReceived(_ urlRequest: URLRequest) {
    let _ = logRequest?(urlRequest)
  }

  @objc
  private func unwrapRequestFromNotification(_ notification: Notification) {
    guard let urlRequest = notification.object as? URLRequest else {
      return
    }
    requestReceived(urlRequest)
  }

}

// MARK: NetworkLoggerUrlProtocol

internal class NetworkLoggerUrlProtocol: URLProtocol {
    
    open override class func canInit(with request: URLRequest) -> Bool {
        if let httpHeaders = request.allHTTPHeaderFields, httpHeaders.isEmpty {
            return false
        }
        
        if let _ = URLProtocol.property(forKey: "NetworkLoggerUrlProtocol", in: request) {
            return false
        }
        
        NotificationCenter._nog.post(name: ._urlProtocolReceivedRequest, object: request)
        return false
    }
    
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty("YES", forKey: "NetworkLoggerUrlProtocol", in: mutableRequest)
        return mutableRequest.copy() as! URLRequest
    }
    
}

// MARK: NetworkLoggerView

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

// MARK: NogConsole

/// Prints to console including [Nog] identifier.
public class NogConsole {

  private(set) var isOn: Bool

  public init() {
    self.isOn = false
  }

  public func turn(on isOn: Bool) {
    self.isOn = isOn
  }

  @discardableResult
  public func debugPrint(_ message: String) -> String {
    guard isOn else {
      return ""
    }
    let message = "[Nog] \(message)"
    print(message)
    return message
  }

}

// MARK: NetworkLoggerViewController

public struct NetworkLoggerView: UIViewControllerRepresentable {
    
    public let networkLogger: NetworkLogger
    
    public init(networkLogger: NetworkLogger) {
        self.networkLogger = networkLogger
    }
    
    public func makeUIViewController(context: Context) -> NetworkLoggerViewController {
        guard let instance = networkLogger.view as? NetworkLoggerViewController else {
            networkLogger.console.debugPrint("To use NetworkLoggerView effectively, make sure NetworkLogger has a NetworkLoggerViewController as its view.")
            return NetworkLoggerViewController()
        }
        return instance
    }
    
    public func updateUIViewController(_ uiViewController: NetworkLoggerViewController, context: Context) { }
    
}

open class NetworkLoggerViewController: UIViewController, NetworkLogDisplayable {

  var requestHistory: [URLRequest] {
    return requests.reversed()
  }

  private var requests: [URLRequest] = []
  private let customDebugActions: [UIAlertAction]
    
  private let actionMenuButton = UIButton(frame: .zero)
  private let tableView = UITableView(frame: .zero)
    
  public init(customDebugActions: [UIAlertAction] = []) {
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
      stackView.topAnchor.constraint(equalTo: view.topAnchor),
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
    requests.append(urlRequest)

    DispatchQueue.main.async { [weak self] in
      self?.tableView.reloadData()
    }
  }
    
  public func clear() {
     requests = []
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
    let cancelAction: UIAlertAction = .init(title: "Cancel", style: .cancel)
    actionSheet.addAction(clearAction)
    customDebugActions.forEach { actionSheet.addAction($0) }
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
    cell.textLabel?.text = request.description
    return cell
  }

}

extension NetworkLoggerViewController: UITableViewDelegate {

  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let request = requestHistory[indexPath.row]
    let modal = UIViewController()
    let textView = UITextView()
    textView.text = request.description
    textView.isUserInteractionEnabled = false
    modal.view.addSubview(textView)
    textView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: modal.view.topAnchor),
      textView.bottomAnchor.constraint(equalTo: modal.view.bottomAnchor),
      textView.widthAnchor.constraint(equalTo: modal.view.widthAnchor),
      textView.centerXAnchor.constraint(equalTo: modal.view.centerXAnchor),
      textView.centerYAnchor.constraint(equalTo: modal.view.centerYAnchor)
    ])
    modal.modalPresentationStyle = .popover
    present(modal, animated: true, completion: nil)
  }

}

// MARK: - Request Filter

public typealias RequestFilter = (URLRequest) -> Bool

/// Request filter that allows all requests through.
public let noRequestFilter: RequestFilter = { _ in
  return true
}

/// Request filter that only allows https or http requests through.
public let httpOnlyRequestFilter: RequestFilter = {
  $0.url?.scheme.flatMap { ["https", "http"].contains($0) } ?? false
}

// MARK: - Extensions

// MARK: URLSessionConfiguration

extension URLSessionConfiguration {
    
    /// Implementation of `URLSessionConfiguration.protocolClasses` used when
    /// network logging is on; ensures `NetworkLoggerUrlProtocol` is at
    /// first position
    @objc internal func _injectedProtocolClasses() -> [AnyClass]? {
        guard let injectedProtocolClasses = self._injectedProtocolClasses() else {
            return []
        }

        var protocolClasses = injectedProtocolClasses.filter {
            return $0 != NetworkLoggerUrlProtocol.self
        }
        protocolClasses.insert(NetworkLoggerUrlProtocol.self, at: 0)
        return protocolClasses
    }
    
}

// MARK: NotificationCenter

internal extension NotificationCenter {
    // Private NotificationCenter to keep usage of notifications an implementation detail
    static var _nog = NotificationCenter()
}

// MARK: Notification.Name

internal extension Notification.Name {
    static let _urlProtocolReceivedRequest = Notification.Name("NogNetworkLoggerRequest")
}
