//
//
//  cURL.swift
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

import Foundation

extension URLRequest {

  public func cURLDescription(sessionConfiguration: URLSessionConfiguration?,
                              credential: URLCredential?,
                              authenticationMethod: String?) -> String {
      guard
          let url = self.url,
          let host = url.host,
          let method = self.httpMethod else { return "curl command could not be created" }

      var components = ["curl -v"]

      components.append("-X \(method)")

      if let credentialStorage = sessionConfiguration?.urlCredentialStorage {
          let protectionSpace = URLProtectionSpace(host: host,
                                                   port: url.port ?? 0,
                                                   protocol: url.scheme,
                                                   realm: host,
                                                   authenticationMethod: authenticationMethod)

          if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
              for credential in credentials {
                  guard let user = credential.user, let password = credential.password else { continue }
                  components.append("-u \(user):\(password)")
              }
          } else {
              if let credential = credential, let user = credential.user, let password = credential.password {
                  components.append("-u \(user):\(password)")
              }
          }
      }

      if let configuration = sessionConfiguration, configuration.httpShouldSetCookies {
          if
              let cookieStorage = configuration.httpCookieStorage,
              let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
              let allCookies = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: ";")

              components.append("-b \"\(allCookies)\"")
          }
      }

      var headers = HTTPHeaders()

      if let sessionHeaders = sessionConfiguration?.headers {
          for header in sessionHeaders where header.name != "Cookie" {
              headers[header.name] = header.value
          }
      }

      for header in self.headers where header.name != "Cookie" {
          headers[header.name] = header.value
      }

      for header in headers {
          let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
          components.append("-H \"\(header.name): \(escapedValue)\"")
      }

      if let httpBodyStream = self.httpBodyStream {
          httpBodyStream.open()

          if let json = try? JSONSerialization.jsonObject(with: httpBodyStream, options: []) as? [String: Any],
             let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) {
            let jsonString = String(decoding: jsonData, as: UTF8.self)
            let escapedBody = jsonString.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
            components.append("-H \"Content-Type: text/plain\"")
          }
      }

      if let httpBodyData = self.httpBody {
          let httpBody = String(decoding: httpBodyData, as: UTF8.self)
          var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
          escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")

          components.append("-d \"\(escapedBody)\"")
      }

      components.append("\"\(url.absoluteString)\"")

      return components.joined(separator: " \\\n\t")
  }

}

// MARK: - Alamofire

// NOTE: The following is extracted from Alamofire based on `cURLDescription()`
// See: https://github.com/hkellaway/Alamofire/blob/56ce89783d7ebd67444d09d7a0aa20ffa7aa55af/Source/Request.swift#L962

extension URLRequest {
    /// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

/// An order-preserving and case-insensitive representation of HTTP headers.
public struct HTTPHeaders {
    private var headers: [HTTPHeader] = []

    /// Creates an empty instance.
    public init() {}

    /// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
    /// name and value encountered.
    public init(_ headers: [HTTPHeader]) {
        self.init()

        headers.forEach { update($0) }
    }

    /// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
    /// and value encountered.
    public init(_ dictionary: [String: String]) {
        self.init()

        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }

    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader value.
    public mutating func update(name: String, value: String) {
        update(HTTPHeader(name: name, value: value))
    }

    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    public mutating func update(_ header: HTTPHeader) {
        guard let index = headers.index(of: header.name) else {
            headers.append(header)
            return
        }

        headers.replaceSubrange(index...index, with: [header])
    }

    /// Case-insensitively removes an `HTTPHeader`, if it exists, from the instance.
    ///
    /// - Parameter name: The name of the `HTTPHeader` to remove.
    public mutating func remove(name: String) {
        guard let index = headers.index(of: name) else { return }

        headers.remove(at: index)
    }

    /// Case-insensitively find a header's value by name.
    ///
    /// - Parameter name: The name of the header to search for, case-insensitively.
    ///
    /// - Returns:        The value of header, if it exists.
    public func value(for name: String) -> String? {
        guard let index = headers.index(of: name) else { return nil }

        return headers[index].value
    }

    /// Case-insensitively access the header with the given name.
    ///
    /// - Parameter name: The name of the header.
    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            if let value = newValue {
                update(name: name, value: value)
            } else {
                remove(name: name)
            }
        }
    }

    /// The dictionary representation of all headers.
    ///
    /// This representation does not preserve the current order of the instance.
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }

        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

extension Array where Element == HTTPHeader {
    /// Case-insensitively finds the index of an `HTTPHeader` with the provided name, if it exists.
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

extension HTTPHeaders: Collection {
    public var startIndex: Int {
        headers.startIndex
    }

    public var endIndex: Int {
        headers.endIndex
    }

    public subscript(position: Int) -> HTTPHeader {
        headers[position]
    }

    public func index(after i: Int) -> Int {
        headers.index(after: i)
    }
}

/// A representation of a single HTTP header's name / value pair.
public struct HTTPHeader: Hashable {
    /// Name of the header.
    public let name: String

    /// Value of the header.
    public let value: String

    /// Creates an instance from the given `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The name of the header.
    ///   - value: The value of the header.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: URLSessionConfiguration

extension URLSessionConfiguration {

  /// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { httpAdditionalHeaders = newValue.dictionary }
    }

}
