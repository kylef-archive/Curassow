#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Commander


public enum Address : Equatable, CustomStringConvertible {
  case IP(hostname: String, port: UInt16)
  case UNIX(path: String)

  func socket(backlog: Int32) throws -> Socket {
    switch self {
    case let IP(hostname, port):
      let socket = try Socket()
      try socket.bind(hostname, port: port)
      try socket.listen(backlog)
      socket.blocking = false
      return socket
    case let UNIX(path):
      // Delete old file if exists
      unlink(path)

      let socket = try Socket(family: AF_UNIX)
      try socket.bind(path)
      try socket.listen(backlog)
      socket.blocking = false
      return socket
    }
  }

  public var description: String {
    switch self {
    case let IP(hostname, port):
      return "\(hostname):\(port)"
    case let UNIX(path):
      return "unix:\(path)"
    }
  }
}


public func == (lhs: Address, rhs: Address) -> Bool {
  switch (lhs, rhs) {
    case let (.IP(lhsHostname, lhsPort), .IP(rhsHostname, rhsPort)):
      return lhsHostname == rhsHostname && lhsPort == rhsPort
    case let (.UNIX(lhsPath), .UNIX(rhsPath)):
      return lhsPath == rhsPath
    default:
      return false
  }
}


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
