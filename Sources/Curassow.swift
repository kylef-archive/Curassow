#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Nest
import Commander
import Inquiline


extension Address : ArgumentConvertible {
  public init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
      if value.hasPrefix("unix:") {
        let prefixEnd = value.startIndex.advancedBy(5)
        self = .UNIX(path: value[prefixEnd ..< value.endIndex])
      } else {
        let components = value.characters.split(":").map(String.init)
        if components.count != 2 {
          throw ArgumentError.InvalidType(value: value, type: "hostname and port separated by `:`.", argument: nil)
        }

        if let port = UInt16(components[1]) {
          self = .IP(hostname: components[0], port: port)
        } else {
          throw ArgumentError.InvalidType(value: components[1], type: "number", argument: "port")
        }
      }
    } else {
      throw ArgumentError.MissingValue(argument: nil)
    }
  }
}


extension ArgumentConvertible {
  init(string: String) throws {
    try self.init(parser: ArgumentParser(arguments: [string]))
  }
}


class MultiOption<T : ArgumentConvertible> : ArgumentDescriptor {
  typealias ValueType = [T]

  let name: String
  let flag: Character?
  let description: String?
  let `default`: ValueType
  var type: ArgumentType { return .Option }

  init(_ name: String, _ `default`: ValueType, flag: Character? = nil, description: String? = nil) {
    self.name = name
    self.flag = flag
    self.description = description
    self.`default` = `default`
  }

  func parse(parser: ArgumentParser) throws -> ValueType {
    var options: ValueType = []

    while let value = try parser.shiftValueForOption(name) {
      let value = try T(string: value)
      options.append(value)
    }

    if let flag = flag {
      while let value = try parser.shiftValueForFlag(flag) {
        let value = try T(string: value)
        options.append(value)
      }
    }

    if options.isEmpty {
      return `default`
    }

    return options
  }
}


@noreturn public func serve(closure: RequestType -> ResponseType) {
  command(
    Option("worker-type", "syncronous"),
    Option("workers", 1, description: "The number of processes for handling requests."),
    MultiOption("bind", [Address.IP(hostname: "0.0.0.0", port: 8000)], description: "The address to bind sockets."),
    Option("timeout", 30, description: "Amount of seconds to wait on a worker without activity before killing and restarting the worker.")
  ) { workerType, workers, addresses, timeout in
    let configuration = Configuration(addresses: addresses, timeout: timeout)

    if workerType == "synchronous" || workerType == "sync" {
      let arbiter = Arbiter<SynchronousWorker>(configuration: configuration, workers: workers, application: closure)
      try arbiter.run()
    } else {
      throw ArgumentError.InvalidType(value: workerType, type: "worker type", argument: "worker-type")
    }
  }.run()
}
