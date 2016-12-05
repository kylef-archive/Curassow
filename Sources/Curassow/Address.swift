#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Commander


public enum Address : Equatable, CustomStringConvertible {
  case ip(hostname: String, port: UInt16)
  case unix(path: String)

  func socket(_ backlog: Int32) throws -> Socket {
    switch self {
    case let .ip(hostname, port):
      let socket = try Socket()
      try socket.bind(hostname, port: port)
      try socket.listen(backlog)
      socket.blocking = false
      return socket
    case let .unix(path):
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
    case let .ip(hostname, port):
      return "\(hostname):\(port)"
    case let .unix(path):
      return "unix:\(path)"
    }
  }
}


public func == (lhs: Address, rhs: Address) -> Bool {
  switch (lhs, rhs) {
    case let (.ip(lhsHostname, lhsPort), .ip(rhsHostname, rhsPort)):
      return lhsHostname == rhsHostname && lhsPort == rhsPort
    case let (.unix(lhsPath), .unix(rhsPath)):
      return lhsPath == rhsPath
    default:
      return false
  }
}


extension Address : ArgumentConvertible {
  public init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
      if value.hasPrefix("unix:") {
        let prefixEnd = value.index(value.startIndex, offsetBy: 5)
        self = .unix(path: value[prefixEnd ..< value.endIndex])
      } else {
        let components = value.characters.split(separator: ":").map(String.init)
        if components.count != 2 {
          throw ArgumentError.invalidType(value: value, type: "hostname and port separated by `:`.", argument: nil)
        }

        if let port = UInt16(components[1]) {
          self = .ip(hostname: components[0], port: port)
        } else {
          throw ArgumentError.invalidType(value: components[1], type: "number", argument: "port")
        }
      }
    } else {
      throw ArgumentError.missingValue(argument: nil)
    }
  }
}
