import Darwin
import Dispatch


class Data {
  let bytes: UnsafeMutablePointer<Int8>
  let capacity: Int

  init(capacity: Int) {
    bytes = UnsafeMutablePointer<Int8>(malloc(capacity + 1))
    self.capacity = capacity
  }

  deinit {
    free(bytes)
  }

  var characters: [CChar] {
    var data = [CChar](count: capacity, repeatedValue: 0)
    memcpy(&data, bytes, data.count)
    return data
  }

  var string: String {
    return String(characters)
  }
}


struct SocketError : ErrorType, CustomStringConvertible {
  let function: String
  let error: String?
  let number: Int32

  init(function: String = __FUNCTION__) {
    self.function = function
    self.number = errno
    error = String.fromCString(strerror(errno))
  }

  var description: String {
    if let error = error {
      return "\(error) from Socket.\(function) [\(number)]"
    }

    return "Socket.\(function) failed [\(number)]"
  }
}


/// Represents a TCP AF_INET socket
class Socket {
  typealias Descriptor = Int32
  typealias Port = UInt16

  let descriptor: Descriptor

  init() throws {
    descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    assert(descriptor > 0)

    var value: Int32 = 1;
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(sizeof(Int32))) != -1 else {
      throw SocketError(function: "setsockopt()")
    }
  }

  init(descriptor: Descriptor) {
    self.descriptor = descriptor
  }

  func listen(backlog: Int32) throws {
    if Darwin.listen(descriptor, backlog) == -1 {
      throw SocketError()
    }
  }

  func bind(address: String, port: Port) throws {
    var addr = sockaddr_in(
      sin_len: __uint8_t(sizeof(sockaddr_in)),
      sin_family: sa_family_t(AF_INET),
      sin_port: htons(in_port_t(port)),
      sin_addr: in_addr(s_addr: inet_addr(address)),
      sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )

    var saddr = sockaddr(
      sa_len: 0,
      sa_family: 0,
      sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )

    memcpy(&saddr, &addr, Int(addr.sin_len))

    guard Darwin.bind(descriptor, &saddr, socklen_t(addr.sin_len)) != -1 else {
      throw SocketError()
    }
  }

  func accept() throws -> Socket {
    let descriptor = Darwin.accept(self.descriptor, nil, nil)
    if descriptor == -1 {
      throw SocketError()
    }
    return Socket(descriptor: descriptor)
  }

  func close() {
    Darwin.close(descriptor)
  }

  func send(output: String) {
    output.withCString { bytes in
      Darwin.send(descriptor, bytes, Int(strlen(bytes)), 0)
    }
  }

  func consume(closure: (dispatch_source_t, Socket) -> ()) {
    let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(descriptor), 0, dispatch_get_main_queue())
    dispatch_source_set_event_handler(source) {
      closure(source, self)
    }
    dispatch_source_set_cancel_handler(source) {
      self.close()
    }
    dispatch_resume(source)
  }

  func consumeData(closure: (Socket, Data) -> ()) {
    consume { source, socket in
      let estimated = dispatch_source_get_data(source)
      let data = Data(capacity: Int(estimated))
      let _ = read(socket.descriptor, data.bytes, data.capacity)
      closure(socket, data)
    }
  }

  private func htons(value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8)
  }
}
