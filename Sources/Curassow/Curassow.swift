#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Nest
import Commander
import Inquiline


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
    VariadicOption("bind", [Address.ip(hostname: "0.0.0.0", port: port)], description: "The address to bind sockets."),
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
