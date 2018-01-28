# Curassow

[![Build Status](https://travis-ci.org/kylef/Curassow.svg?branch=master)](https://travis-ci.org/kylef/Curassow)

Curassow is a Swift [Nest](https://github.com/nestproject/Nest)
HTTP Server. It uses the pre-fork worker model and it's similar to Python's
Gunicorn and Ruby's Unicorn.

It exposes a [Nest-compatible interface](https://github.com/nestproject/Nest)
for your application, allowing you to use Curassow with any Nest compatible
web frameworks of your choice.

## Documentation

Full documentation can be found on the Curassow website:
https://curassow.fuller.li

## Usage

To use Curassow, you will need to install it via the Swift Package Manager,
you can add it to the list of dependencies in your `Package.swift`:

```swift
import PackageDescription

let package = Package(
    name: "HelloWorld",
    dependencies: [
       .package(url: "https://github.com/kylef/Curassow.git", from: "0.6.0"),
    ]
)
```

Afterwards you can place your web application implementation in `Sources`
and add the runner inside `main.swift` which exposes a command line tool to
run your web application:

```swift
import Curassow
import Inquiline


serve { request in
  return Response(.ok, contentType: "text/plain", body: "Hello World")
}
```

Then build and run your application:

```shell
$ swift build --configuration release
```

### Example Application

You can find a [hello world example](https://github.com/kylef/Curassow-example-helloworld) application that uses Curassow.

## License

Curassow is licensed under the BSD license. See [LICENSE](LICENSE) for more
info.
