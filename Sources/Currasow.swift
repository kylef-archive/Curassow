import Glibc
import Nest
import Commander
import Inquiline


extension Address : ArgumentConvertible {
  init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
      let components = value.characters.split(":").map(String.init)
      if components.count != 2 {
        throw ArgumentError.InvalidType(value: value, type: "hostname and port separated by `:`.", argument: nil)
      }

      if let port = UInt16(components[1]) {
        self = .IP(hostname: components[0], port: port)
      } else {
        throw ArgumentError.InvalidType(value: components[1], type: "number", argument: "port")
      }
    } else {
      throw ArgumentError.MissingValue(argument: nil)
    }
  }
}


@noreturn public func serve(closure: RequestType -> ResponseType) {
  command(
    Option("workers", 1),
    Option("bind", Address.IP(hostname: "0.0.0.0", port: 8000))
  ) { workers, address in
    let arbiter = Arbiter<SyncronousWorker>(application: closure, workers: workers, addresses: [address])
    try arbiter.run()
  }.run()
}
