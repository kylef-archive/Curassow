#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


public enum Address : CustomStringConvertible {
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
