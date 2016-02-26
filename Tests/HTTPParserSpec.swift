#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Spectre
import Nest
@testable import Curassow


extension PayloadType {
  mutating func collect() -> [UInt8] {
    var buffer: [UInt8] = []

    while true {
      if let bytes = next() {
        buffer += bytes
      } else {
        break
      }
    }

    return buffer
  }
}


func describeHTTPParser() {

describe("HTTPParser") {
  var parser: HTTPParser!
  var inSocket: Socket!
  var outSocket: Socket!

  $0.before {
    var descriptors: [Int32] = [0, 0]
    if pipe(&descriptors) == -1 {
      fatalError("HTTPParser pipe: \(errno)")
    }

    inSocket = Socket(descriptor: descriptors[0])
    outSocket = Socket(descriptor: descriptors[1])

    parser = HTTPParser(socket: inSocket)
  }

  $0.after {
    inSocket?.close()
    outSocket?.close()
  }

  $0.it("can parse a HTTP request") {
    outSocket.write("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")

    let request = try parser.parse()
    try expect(request.method) == "GET"
    try expect(request.path) == "/"
    try expect(request.headers.count) == 1

    let header = request.headers[0]
    try expect(header.0) == "Host"
    try expect(header.1) == "localhost"
  }

  $0.it("provides the message body until Content-Length value") {
    outSocket.write("GET / HTTP/1.1\r\nContent-Length: 5\r\n\r\nabcdefgh")

    var request = try parser.parse()

    let body = request.body!.collect()
    try expect(body.count) >= 5
    try expect(body[0]) == 97
    try expect(body[1]) == 98
    try expect(body[2]) == 99
    try expect(body[3]) == 100
    try expect(body[4]) == 101
  }

  $0.it("throws an error when the client uses bad HTTP syntax") {
    outSocket.write("GET /\r\nHost: localhost\r\n\r\n")
    try expect(try parser.parse()).toThrow()
  }

  $0.it("throws an error when the client uses a bad HTTP version") {
    outSocket.write("GET / HTTP/5.0\r\nHost: localhost\r\n\r\n")
    try expect(try parser.parse()).toThrow()
  }

  $0.it("throws an error when the client disconnects before sending an HTTP request") {
    outSocket.close()
    outSocket = nil

    try expect(try parser.parse()).toThrow()
  }

  $0.it("throws an error when the client disconnects before sending the entire message body") {
    outSocket.write("GET / HTTP/1.1\r\nContent-Length: 42\r\n")
    outSocket.close()
    outSocket = nil

    try expect(try parser.parse()).toThrow()
  }
}

}
