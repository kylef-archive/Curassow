#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Nest
import Commander
import Inquiline


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
  var type: ArgumentType { return .option }

  init(_ name: String, _ default: ValueType, flag: Character? = nil, description: String? = nil) {
    self.name = name
    self.flag = flag
    self.description = description
    self.`default` = `default`
  }

  func parse(_ parser: ArgumentParser) throws -> ValueType {
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


func getIntEnv(_ key: String, default: Int) -> Int {
  let value = getenv(key)
  if value != nil {
    if let stringValue = String(validatingUTF8: value!), let intValue = Int(stringValue) {
      return intValue
    }
  }

  return `default`
}


struct ServeError : Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}


public func serve(_ closure: @escaping (RequestType) -> ResponseType) -> Never  {
  let port = UInt16(getIntEnv("PORT", default: 8000))
  let workers = getIntEnv("WEB_CONCURRENCY", default: 1)

  command(
    Option("worker-type", "sync"),
    Option("workers", workers, description: "The number of processes for handling requests."),
    MultiOption("bind", [Address.ip(hostname: "0.0.0.0", port: port)], description: "The address to bind sockets."),
    Option("timeout", 30, description: "Amount of seconds to wait on a worker without activity before killing and restarting the worker."),
    Flag("daemon", description: "Detaches the server from the controlling terminal and enter the background.")
  ) { workerType, workers, addresses, timeout, daemonize in
    var configuration = Configuration()
    configuration.addresses = addresses
    configuration.timeout = timeout

    if workerType == "synchronous" || workerType == "sync" {
      let arbiter = Arbiter<SynchronousWorker>(configuration: configuration, workers: workers, application: closure)
      try arbiter.run(daemonize: daemonize)
    } else if workerType == "dispatch" || workerType == "gcd" {
      let arbiter = Arbiter<DispatchWorker>(configuration: configuration, workers: workers, application: closure)
      try arbiter.run(daemonize: daemonize)
    } else {
      throw ArgumentError.invalidType(value: workerType, type: "worker type", argument: "worker-type")
    }
  }.run()
}
