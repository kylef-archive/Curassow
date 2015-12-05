# Curassow

Curassow is a Swift Nest HTTP Server. It uses the pre-fork worker model and
it's similar to Python's Gunicorn and Ruby's Unicorn.

It exposes a Nest compatible interface for your application, allowing you to
use Currasow with any Nest compatible web frameworks of your choice.

## Usage

To use Currasow, you will need to install it via the Swift Package Manager,
you can add it to the list of dependencies in your `Package.swift`:

```swift
import PackageDescription

let package = Package(
  name: "HelloWorld",
  dependencies: [
    .Package(url: "https://github.com/kylef/Currasow.git", majorVersion: 0, minor: 1),
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
  return Response(.Ok, contentType: "plain/text", body: "Hello World")
}
```

```shell
$ swift build --configuration release
```

```shell
$ ./.build/release/HelloWorld --workers 3
[arbiter] Listening on port 0.0.0.0:8000
[arbiter] Started worker process 18405
[arbiter] Started worker process 18406
[arbiter] Started worker process 18407
```

## License

Currasow is licensed under the BSD license. See [LICENSE](LICENSE) for more
info.
