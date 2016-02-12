#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Nest
import Commander
import Inquiline


extension Address : ArgumentConvertible {
  init(parser: ArgumentParser) throws {
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


@noreturn public func serve(closure: RequestType -> ResponseType) {
  command(
    Option("workers", 1, description: "The number of processes for handling requests."),
    Option("bind", Address.IP(hostname: "0.0.0.0", port: 8000), description: "The address to bind sockets."),
    Option("timeout", 30, description: "Amount of seconds to wait on a worker without activity before killing and restarting the worker.")
  ) { workers, address, timeout in
    let arbiter = Arbiter<SyncronousWorker>(application: closure, workers: workers, addresses: [address], timeout: timeout)
    try arbiter.run()
  }.run()
}
