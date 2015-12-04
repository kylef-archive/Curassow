import Darwin
import Dispatch
import Nest
import Commander
import Inquiline


@noreturn func serve(address: String, _ port: UInt16, closure: RequestType -> ResponseType) {
  let socket: Socket

  do {
    socket = try Socket()
    try socket.bind(address, port: port)
    try socket.listen(20)
  } catch {
    print(error)
    exit(1)
  }

  let hupSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, UInt(SIGHUP), 0, dispatch_get_main_queue())
  dispatch_source_set_event_handler(hupSource) { exit(0) }
  dispatch_resume(hupSource)

  let intSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, UInt(SIGINT), 0, dispatch_get_main_queue())
  dispatch_source_set_event_handler(intSource) { exit(0) }
  dispatch_resume(intSource)

  socket.consume { (source, socket) in
    let clientSocket = try? socket.accept()

    clientSocket?.consumeData { (socket, received) in
    /*
      var data = [CChar]()

      if data.capacity == 0 {
        socket.close()
      } else {
        data += received.characters
      }
    */

      // TODO: write an HTTP Parser and use the real request
      let request = Request(method: "GET", path: "/", headers: nil, body: nil)
      let response = closure(request)

      socket.send("HTTP/1.1 \(response.statusLine)\r\n")
      for (key, value) in response.headers {
        socket.send("\(key): \(value)\r\n")
      }
      socket.send("\r\n")

      if let body = response.body {
        socket.send(body)
      }

      socket.close()
    }
  }

  print("Listening on \(address):\(port)")
  dispatch_main()
}


extension UInt16 : ArgumentConvertible {
  public init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
      if let value = Int(value) {
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
    Option("address", "0.0.0.0"),
    Option("port", UInt16(8000))
  ) { address, port in
    serve(address, port, closure: closure)
  }.run()
}
