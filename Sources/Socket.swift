import Glibc


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
    descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
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
    if Glibc.listen(descriptor, backlog) == -1 {
      throw SocketError()
    }
  }

  func bind(address: String, port: Port) throws {
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(htons(in_port_t(port)))
    addr.sin_addr = in_addr(s_addr: in_addr_t(0))
    addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)

   let len = socklen_t(UInt8(sizeof(sockaddr_in)))
    guard Glibc.bind(descriptor, sockaddr_cast(&addr), len) != -1 else {
      throw SocketError()
    }
  }

  func accept() throws -> Socket {
    let descriptor = Glibc.accept(self.descriptor, nil, nil)
    if descriptor == -1 {
      throw SocketError()
    }
    return Socket(descriptor: descriptor)
  }

  func close() {
    Glibc.close(descriptor)
  }

  func send(output: String) {
    output.withCString { bytes in
      Glibc.send(descriptor, bytes, Int(strlen(bytes)), 0)
    }
  }

/*
  func read(bytes: Int) throws -> Data {
    let data = Data(capacity: bytes)
    let _ = Glibc.read(socket.descriptor, data.bytes, data.capacity)
    return data
  }
*/

  private func htons(value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8)
  }

  private func sockaddr_cast(p: UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<sockaddr> {
    return UnsafeMutablePointer<sockaddr>(p)
  }
}
