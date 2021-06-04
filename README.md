# Nog: A Delicious Network Request Logger :coffee:

[![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg)](https://swift.org/about/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-lightgray.svg)](https://raw.githubusercontent.com/hkellaway/Nog/main/LICENSE)
[![Build Status](https://github.com/hkellaway/Nog/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/hkellaway/Nog/actions)

## Usage

> :bulb: Nog assumes usage of `URLSessionConfiguration.default`.

To start logging network requests, create an instance of `NetworkLogger` and call `start`:

``` swift
let myNetworkLogger = NetworkLogger()
myNetworkLogger.start()
```

Nog will print request URLs to the console:

```
[Nog] Request #1: URL => https://github.com/
```

To stop logging, simply call `stop`:

``` swift
myNetworkLogger.stop()
```

To check whether logging is currently on, call `isLogging`:

``` swift
myNetworkLogger.isLogging
```

See the [Demo](/Demo) project for sample usage.

### Filtering Requests

By default Nog will print out only requests that start with `https` or `http`. However, you can introduce your own additional filter to specify when requests should or shouldn't be logged.

Simply initialize `NetworkLogger` with a function that takes in a `URLRequest` and returns a `Bool`:

``` swift
let myNetworkLogger = NetworkLogger(filter: {
  $0.url?.absoluteString.contains("github") ?? false
})
```

### Displaying Requests

:construction:

```

#### Displaying Requests with SwiftUI


``` swift
// :construction:
```

#### Displaying Requests in cURL Format

When using `NetworkLoggerViewController`, the cURL representation of requests is right-at-hand.

Simply tap a request to view it's cURL representation then select **Copy cURL**.

### Advanced Usage

#### Debug Logging

By default, Nog will print messages to console to assist with debugging. Debug logs are appended with `[Nog]` to help isolate in console.

To turn off debug logging, either initialize with `verbose: false` or set at a later time:

``` swift
let quietNetworkLogger = NetworkLogger(requestFilters: [httpOnlyRequestFilter], verbose: false)
```

``` swift
let myNetworkLogger = NetworkLogger()
myNetworkLogger.verbose = false
```

#### Additional Filtering

To fully customize filtering, you can create your own `RequestFilter`s and provide an array:

``` swift
let gitHubOnlyRequestFilter: RequestFilter = {
  $0.url?.absoluteString.contains("github") ?? false
}
```

``` swift
let myNetworkLogger = NetworkLogger(requestFilters: [httpOnlyRequestFilter, gitHubOnlyRequestFilter])

```

Note: If you still want to filter out only HTTP requests like Nog does by default, make sure to include `httpOnlyRequestFilter` in the list.

#### Mocking Requests

``` swift
// :construction:
```

``` swift
let myNetworkLogger = NetworkLogger(requestFilters: [httpOnlyRequestFilter], adapter: MyNogAdapter.shared)
```

#### Custom NetworkLogger

To fully customize how `NetworkLogger` handles logging requests, ...

:construction:

## Installation

### Swift Package Manager

Point to the [latest release](https://github.com/hkellaway/Nog/releases) or to the `main` branch for the latest.

### CocoaPods

```ruby
pod 'Nog', :git => 'https://github.com/hkellaway/Nog.git', :tag => 'x.x.x'
```

```ruby
pod 'Nog', :git => 'https://github.com/hkellaway/Nog.git', :branch => 'main'
```

## Credits

Nog was created by [Harlan Kellaway](http://hkellaway.github.io) forked originally from [depoon/NetworkInterceptor](https://github.com/depoon/NetworkInterceptor/releases/tag/0.0.8). :heart: :green_heart:

## License

Nog is available under the MIT license. See the [LICENSE](https://raw.githubusercontent.com/hkellaway/Nog/main/LICENSE) file for more info.
