import Nest
import Commander
import Inquiline


extension UInt16 : ArgumentConvertible {
  public init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
      if let value = UInt16(value) {
        self.init(value)
      } else {
        throw ArgumentError.InvalidType(value: value, type: "number", argument: nil)
      }
    } else {
      throw ArgumentError.MissingValue(argument: nil)
    }
  }
}


@noreturn public func serve(closure: RequestType -> ResponseType) {
  command(
    Option("workers", 1),
    Option("address", "0.0.0.0"),
    Option("port", UInt16(8000))
  ) { workers, address, port in
    let arbiter = Arbiter<SyncronousWorker>(application: closure, workers: workers, addresses: [Address.IP(address: address, port: port)])
    try arbiter.run()
  }.run()
}
