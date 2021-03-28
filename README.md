# Nog: A Delicious Network Request Logger :coffee:

[![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg)](https://swift.org/about/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-lightgray.svg)](https://raw.githubusercontent.com/hkellaway/Nog/master/LICENSE)

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

## Installation

### Installation with Swift Package Manager

See [Adding Package Dependencies to Your App](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app). Search for `Nog` with *Owner* `hkellaway`. Point to the desired version or the `master` branch for the latest.

## Credits

Nog was created by [Harlan Kellaway](http://hkellaway.github.io) forked originally from [depoon/NetworkInterceptor](https://github.com/depoon/NetworkInterceptor/releases/tag/0.0.8). :heart: :green_heart:

## License

Nog is available under the MIT license. See the [LICENSE](https://raw.githubusercontent.com/hkellaway/Nog/master/LICENSE) file for more info.
