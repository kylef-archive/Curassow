#if os(Linux)
import Glibc

private let sock_stream = Int32(SOCK_STREAM.rawValue)

private let system_accept = Glibc.accept
private let system_bind = Glibc.bind
private let system_close = Glibc.close
private let system_listen = Glibc.listen
private let system_read = Glibc.read
private let system_send = Glibc.send
private let system_write = Glibc.write
private let system_shutdown = Glibc.shutdown
private let system_select = Glibc.select
private let system_pipe = Glibc.pipe
#else
import Darwin.C

private let sock_stream = SOCK_STREAM

private let system_accept = Darwin.accept
private let system_bind = Darwin.bind
private let system_close = Darwin.close
private let system_listen = Darwin.listen
private let system_read = Darwin.read
private let system_send = Darwin.send
private let system_write = Darwin.write
private let system_shutdown = Darwin.shutdown
private let system_select = Darwin.select
private let system_pipe = Darwin.pipe
#endif

import fd


struct SocketError : ErrorType, CustomStringConvertible {
  let function: String
  let number: Int32

  init(function: String = __FUNCTION__) {
    self.function = function
    self.number = errno
  }

  var description: String {
    return "Socket.\(function) failed [\(number)]"
  }
}


protocol Readable {
  func read(bytes: Int) throws -> [Int8]
}


class Unreader : Readable {
  let reader: Readable
  var buffer: [Int8] = []

  init(reader: Readable) {
    self.reader = reader
  }

  func read(bytes: Int) throws -> [Int8] {
    if !buffer.isEmpty {
      let buffer = self.buffer
      self.buffer = []
      return buffer
    }

    return try reader.read(bytes)
  }

  func unread(buffer: [Int8]) {
    self.buffer += buffer
  }
}


/// Represents a TCP AF_INET/AF_UNIX socket
final public class Socket : Readable, FileDescriptor, Listener, Connection {
  typealias Port = UInt16

  public let fileNumber: FileNumber

  class func pipe() throws -> (read: Socket, write: Socket) {
    var fds: [Int32] = [0, 0]
    if system_pipe(&fds) == -1 {
      throw SocketError()
    }
    return (Socket(descriptor: fds[0]), Socket(descriptor: fds[1]))
  }

  init(family: Int32 = AF_INET) throws {
#if os(Linux)
    fileNumber = socket(family, sock_stream, 0)
#else
    fileNumber = socket(family, sock_stream, family == AF_UNIX ? 0 : IPPROTO_TCP)
#endif
    assert(fileNumber > 0)

    var value: Int32 = 1;
    guard setsockopt(fileNumber, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(sizeof(Int32))) != -1 else {
      throw SocketError(function: "setsockopt()")
    }

#if !os(Linux)
    guard setsockopt(fileNumber, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(sizeof(Int32))) != -1 else {
        throw SocketError(function: "setsockopt()")
    }
#endif
  }

  init(descriptor: FileNumber) {
    self.fileNumber = descriptor
  }

  func listen(backlog: Int32) throws {
    if system_listen(fileNumber, backlog) == -1 {
      throw SocketError()
    }
  }

  func bind(address: String, port: Port) throws {
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(htons(in_port_t(port)))
    addr.sin_addr = in_addr(s_addr: address.withCString { inet_addr($0) })
    addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)

   let len = socklen_t(UInt8(sizeof(sockaddr_in)))
    guard system_bind(fileNumber, sockaddr_cast(&addr), len) != -1 else {
      throw SocketError()
    }
  }

  func bind(path: String) throws {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)

    let lengthOfPath = path.withCString { Int(strlen($0)) }

    guard lengthOfPath < sizeofValue(addr.sun_path) else {
      throw SocketError()
    }

    withUnsafeMutablePointer(&addr.sun_path.0) { ptr in
      path.withCString {
        strncpy(ptr, $0, lengthOfPath)
      }
    }

#if os(Linux)
    let len = socklen_t(UInt8(sizeof(sockaddr_un)))
#else
    addr.sun_len = UInt8(sizeof(sockaddr_un) - sizeofValue(addr.sun_path) + lengthOfPath)
    let len = socklen_t(addr.sun_len)
#endif

    guard system_bind(fileNumber, sockaddr_cast(&addr), len) != -1 else {
      throw SocketError()
    }
  }

  public func accept() throws -> Connection {
    let descriptor = system_accept(fileNumber, nil, nil)
    if descriptor == -1 {
      throw SocketError()
    }
    return Socket(descriptor: descriptor)
  }

  func close() {
    system_close(fileNumber)
  }

  func shutdown() {
    system_shutdown(fileNumber, Int32(SHUT_RDWR))
  }

  func send(output: String) {
    output.withCString { bytes in
#if os(Linux)
    let flags = Int32(MSG_NOSIGNAL)
#else
    let flags = Int32(0)
#endif
      system_send(fileNumber, bytes, Int(strlen(bytes)), flags)
    }
  }

  func send(bytes: [UInt8]) {
#if os(Linux)
    let flags = Int32(MSG_NOSIGNAL)
#else
    let flags = Int32(0)
#endif
    system_send(fileNumber, bytes, bytes.count, flags)
  }

  func write(output: String) {
    output.withCString { bytes in
      system_write(fileNumber, bytes, Int(strlen(bytes)))
    }
  }

  func read(bytes: Int) throws -> [CChar] {
    let data = Data(capacity: bytes)
    let bytes = system_read(fileNumber, data.bytes, data.capacity)
    guard bytes != -1 else {
        throw SocketError()
    }
    return Array(data.characters[0..<bytes])
  }

  /// Returns whether the socket is set to non-blocking or blocking
  var blocking: Bool {
    get {
      let flags = fcntl(fileNumber, F_GETFL, 0)
      return flags & O_NONBLOCK == 0
    }

    set {
      let flags = fcntl(fileNumber, F_GETFL, 0)
      let newFlags: Int32

      if newValue {
        newFlags = flags & ~O_NONBLOCK
      } else {
        newFlags = flags | O_NONBLOCK
      }

      let _ = fcntl(fileNumber, F_SETFL, newFlags)
    }
  }

  /// Returns whether the socket is has the FD_CLOEXEC flag set
  var closeOnExec: Bool {
    get {
      let flags = fcntl(fileNumber, F_GETFL, 0)
      return flags & FD_CLOEXEC == 1
    }

    set {
      let flags = fcntl(fileNumber, F_GETFL, 0)
      let newFlags: Int32

      if newValue {
        newFlags = flags ^ FD_CLOEXEC
      } else {
        newFlags = flags | FD_CLOEXEC
      }

      let _ = fcntl(fileNumber, F_SETFL, newFlags)
    }
  }

  private func htons(value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8)
  }

  private func sockaddr_cast(p: UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<sockaddr> {
    return UnsafeMutablePointer<sockaddr>(p)
  }
}
